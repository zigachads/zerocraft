const std = @import("std");
const status = @import("status.zig");

pub fn handle_status(
    allocator: std.mem.Allocator,
    reader: anytype,
    writer: anytype,
) !void {
    _ = try std.leb.readILEB128(i32, reader);
    const status_request_packet_id = try std.leb.readILEB128(i32, reader);
    std.debug.assert(status_request_packet_id == 0x00);

    const status_response = status.StatusResponse{
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
    };

    const status_response_str = try std.json.stringifyAlloc(
        allocator,
        status_response,
        .{},
    );

    var counting_writer_stream = std.io.countingWriter(std.io.null_writer);
    var counting_writer = counting_writer_stream.writer();
    try std.leb.writeILEB128(counting_writer, @intCast(i32, 0x00));

    try std.leb.writeILEB128(counting_writer, status_response_str.len);
    try counting_writer.writeAll(status_response_str);

    try std.leb.writeILEB128(writer, counting_writer_stream.bytes_written);
    try std.leb.writeILEB128(writer, @intCast(i32, 0x00));

    try std.leb.writeILEB128(writer, status_response_str.len);
    try writer.writeAll(status_response_str);

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
                const protocol_version = try std.leb.readILEB128(i32, reader);
                std.log.debug("protocol version: {d}", .{protocol_version});
                std.debug.assert(protocol_version >= 762);

                const server_address_len = try std.leb.readILEB128(i32, reader);
                const server_address = try allocator.alloc(u8, @intCast(usize, server_address_len));
                _ = try reader.readAll(server_address);
                std.log.debug("server address: {s}", .{server_address});

                const server_port = try reader.readIntBig(u16);
                std.log.debug("server port: {d}", .{server_port});

                const next_state = try std.leb.readILEB128(i32, reader);
                std.log.debug("next state: {d}", .{next_state});

                switch (next_state) {
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
