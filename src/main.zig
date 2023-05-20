const std = @import("std");
const types = @import("types.zig");
const Packet = @import("packet.zig").Packet;
const String = @import("packet.zig").String;

pub const StatusPacket = struct {
    const Self = @This();

    allocator: std.mem.Allocator,
    data: types.StatusResponse,

    pub fn write(self: *const Self, writer: anytype) !void {
        const json = try std.json.stringifyAlloc(
            self.allocator,
            self.data,
            .{},
        );

        const string = String{
            .data = json,
        };
        try string.write(writer);
    }
};

pub const Handshake = struct {
    const Self = @This();

    protocol_version: i32,
    server_address: []const u8,
    server_port: u16,
    next_state: i32,

    pub fn write(self: *const Self, writer: anytype) !void {
        _ = writer;
        _ = self;
    }

    pub fn read(reader: anytype, allocator: std.mem.Allocator) !Self {
        const protocol_version = try std.leb.readILEB128(i32, reader);
        const server_address = try String.read(reader, allocator);
        const server_port = try reader.readIntBig(u16);
        const next_state = try std.leb.readILEB128(i32, reader);

        return Self{
            .protocol_version = protocol_version,
            .server_address = server_address.data,
            .server_port = server_port,
            .next_state = next_state,
        };
    }
};

pub fn handle_status(
    allocator: std.mem.Allocator,
    reader: anytype,
    writer: anytype,
) !void {
    _ = try std.leb.readILEB128(i32, reader);
    const status_request_packet_id = try std.leb.readILEB128(i32, reader);
    std.debug.assert(status_request_packet_id == 0x00);

    const status_packet = Packet(StatusPacket){
        .id = 0x0,
        .data = .{
            .allocator = allocator,
            .data = .{
                .version = .{
                    .name = "1.19.4",
                    .protocol = 762,
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

    const ping_request_length = try std.leb.readILEB128(i32, reader);
    const ping_request_id = try std.leb.readILEB128(i32, reader);
    std.debug.assert(ping_request_id == 0x01);
    const ping_request_payload = try std.leb.readILEB128(i32, reader);

    try std.leb.writeILEB128(writer, ping_request_length);
    try std.leb.writeILEB128(writer, ping_request_id);
    try std.leb.writeILEB128(writer, ping_request_payload);
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

        const packet_length = try std.leb.readILEB128(i32, reader);
        std.log.debug("packet length: {d}", .{packet_length});
        const packet_id = try std.leb.readILEB128(i32, reader);
        std.log.debug("packet id: 0x{X}", .{packet_id});

        switch (packet_id) {
            0x00 => {
                const handshake_packet = try Handshake.read(reader, allocator);
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
                    },
                }
            },
            else => {},
        }
    }
}
