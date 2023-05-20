pub const MinecraftVersion = struct {
    name: []const u8,
    protocol: i32,
};

pub const MinecraftPlayer = struct {
    id: []const u8,
    name: []const u8,
};

pub const TextComponent = struct {
    text: []const u8,
};

pub const StatusResponse = struct {
    version: MinecraftVersion,
    players: struct {
        max: i32,
        online: i32,
        sample: []MinecraftPlayer,
    },
    description: TextComponent,
    favicon: ?[]const u8,
    enforcesSecureChat: bool,
};
