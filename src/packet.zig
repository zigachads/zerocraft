const std = @import("std");

/// A generic minecraft packet
pub fn Packet(comptime Data: type) type {
    return struct {
        const Self = @This();

        id: i32,
        data: Data,

        pub fn write(self: *const Self, writer: anytype) !void {
            var counting_writer_stream = std.io.countingWriter(std.io.null_writer);
            var counting_writer = counting_writer_stream.writer();

            // Calculate the packet length
            try std.leb.writeILEB128(counting_writer, self.id);
            try self.data.write(counting_writer);

            // Send the packet length
            try std.leb.writeILEB128(writer, counting_writer_stream.bytes_written);

            // Send the packet
            try std.leb.writeILEB128(writer, self.id);
            try self.data.write(writer);
        }

        pub fn read(reader: anytype, allocator: std.mem.Allocator) !Self {

            // Receive the packet length
            const packet_length = try std.leb.readILEB128(i32, reader);
            _ = packet_length;

            const packet_id = try std.leb.readILEB128(i32, reader);

            const data = try Data.read(reader, allocator);

            return Self{
                .data = data,
                .id = packet_id,
            };
        }
    };
}

/// A length-delimited string
pub const String = struct {
    const Self = @This();

    data: []const u8,

    pub fn write(self: *const Self, writer: anytype) !void {
        try std.leb.writeILEB128(writer, self.data.len);
        try writer.writeAll(self.data);
    }

    pub fn read(reader: anytype, allocator: std.mem.Allocator) !String {
        const length = try std.leb.readILEB128(i32, reader);
        const data = try allocator.alloc(u8, @intCast(usize, length));

        _ = try reader.readAll(data);

        return Self{
            .data = data,
        };
    }
};
