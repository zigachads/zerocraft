const std = @import("std");
const types = @import("types.zig");
const Packet = @import("packet.zig").Packet;
const String = @import("packet.zig").String;
const packets = @import("packets.zig");

pub fn handle_status(
    allocator: std.mem.Allocator,
    reader: anytype,
    writer: anytype,
) !void {
    _ = try std.leb.readULEB128(u32, reader);
    const status_request_packet_id = try std.leb.readULEB128(u32, reader);
    std.debug.assert(status_request_packet_id == 0x00);

    const status_packet = Packet(packets.StatusPacket){
        .id = 0x0,
        .data = .{
            .allocator = allocator,
            .data = .{
                .version = .{
                    .name = "1.20.1",
                    .protocol = 763,
                },
                .players = .{
                    .max = 69420,
                    .online = 69,
                    .sample = &.{},
                },
                .description = .{
                    .text = "Ziggy Server",
                },
                .favicon = null,
                .enforcesSecureChat = false,
            },
        },
    };

    try status_packet.write(writer);

    const ping_request_length = try std.leb.readULEB128(u32, reader);
    const ping_request_id = try std.leb.readULEB128(u32, reader);
    std.debug.assert(ping_request_id == 0x01);
    const ping_request_payload = try std.leb.readULEB128(u32, reader);

    try std.leb.writeULEB128(writer, ping_request_length);
    try std.leb.writeULEB128(writer, ping_request_id);
    try std.leb.writeULEB128(writer, ping_request_payload);
}

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var server = std.net.StreamServer.init(.{});

    defer server.deinit();

    var addr = try std.net.Address.parseIp("::", 25565);
    try server.listen(addr);

    while (true) {
        const conn = try server.accept();
        defer conn.stream.close();

        const reader = conn.stream.reader();
        const writer = conn.stream.writer();

        const packet_length = try std.leb.readULEB128(u32, reader);
        std.log.debug("packet length: {d}", .{packet_length});
        const packet_id = try std.leb.readULEB128(u32, reader);
        std.log.debug("packet id: 0x{X}", .{packet_id});

        switch (packet_id) {
            0x00 => {
                const handshake_packet = try packets.Handshake.read(reader, allocator);
                std.log.debug("received handshake: {d}, {s}, {d}, {d}", .{
                    handshake_packet.protocol_version,
                    handshake_packet.server_address,
                    handshake_packet.server_port,
                    handshake_packet.next_state,
                });

                switch (handshake_packet.next_state) {
                    1 => {
                        try handle_status(allocator, reader, writer);
                        continue;
                    },
                    else => {
                        // TODO: handle login packet 👀
                        const login_start = try Packet(packets.LoginStart).read(reader, allocator);
                        std.log.debug("received login packet: {s}, {?}", .{
                            login_start.data.player_name,
                            login_start.data.player_uuid,
                        });

                        const login_success = Packet(packets.LoginSuccess){
                            .id = 0x02,
                            .data = .{
                                .player_uuid = login_start.data.player_uuid.?,
                                .player_name = login_start.data.player_name,
                            },
                        };
                        try login_success.write(writer);

                        //const disconnect_packet = Packet(LoginDisconnectPacket){
                        //    .id = 0x00,
                        //    .data = .{
                        //        .reason = "bruh",
                        //    },
                        //};
                        //try disconnect_packet.write(writer);
                    },
                }
            },
            else => {},
        }
    }
}
