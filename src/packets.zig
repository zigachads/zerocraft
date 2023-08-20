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

pub const LoginDisconnect = struct {
    const Self = @This();

    reason: []const u8,

    pub fn write(self: *const Self, writer: anytype) !void {
        const reason = String{
            .data = self.reason,
        };
        try reason.write(writer);
    }
};

pub const LoginStart = struct {
    const Self = @This();

    player_name: []const u8,
    player_uuid: ?u128,

    pub fn read(reader: anytype, allocator: std.mem.Allocator) !Self {
        const player_name = try String.read(reader, allocator);
        const has_player_uuid = try reader.readByte();
        var player_uuid: ?u128 = null;

        if (has_player_uuid == 0x01)
            player_uuid = try std.leb.readULEB128(u128, reader);

        return Self{
            .player_name = player_name.data,
            .player_uuid = player_uuid,
        };
    }

    pub fn write(self: *const Self, writer: anytype) !void {
        _ = writer;
        _ = self;
    }
};

pub const LoginSuccess = struct {
    const Self = @This();

    player_uuid: u128,
    player_name: []const u8,

    pub fn read(reader: anytype, allocator: std.mem.Allocator) !Self {
        _ = allocator;
        _ = reader;
        return error.Unimplemented;
    }

    pub fn write(self: *const Self, writer: anytype) !void {
        try std.leb.writeULEB128(writer, self.player_uuid);

        const player_name = String{
            .data = self.player_name,
        };
        try player_name.write(writer);

        const property_count: u32 = 0;
        try std.leb.writeULEB128(writer, property_count);
    }
};

pub const Handshake = struct {
    const Self = @This();

    protocol_version: u32,
    server_address: []const u8,
    server_port: u16,
    next_state: u32,

    pub fn write(self: *const Self, writer: anytype) !void {
        _ = writer;
        _ = self;
    }

    pub fn read(reader: anytype, allocator: std.mem.Allocator) !Self {
        const protocol_version = try std.leb.readULEB128(u32, reader);
        const server_address = try String.read(reader, allocator);
        const server_port = try reader.readIntBig(u16);
        const next_state = try std.leb.readULEB128(u32, reader);

        return Self{
            .protocol_version = protocol_version,
            .server_address = server_address.data,
            .server_port = server_port,
            .next_state = next_state,
        };
    }
};
