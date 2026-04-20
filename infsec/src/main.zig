const std = @import("std");


const AccessMatrix = struct {
    users:      std.ArrayList(User),
    resources:  std.ArrayList(Resource),
    allocator:  std.mem.Allocator,

    const Permission = struct {
        pub const forbidden:   u8 = 0;
        pub const grant:       u8 = 1 << 0;
        pub const write:       u8 = 1 << 1;
        pub const read:        u8 = 1 << 2;
        pub const write_grant: u8 = write | grant;
        pub const read_grant:  u8 = read  | grant;
        pub const full_access: u8 = read  | write | grant;
    };

    const User = struct {
        name: []const u8,
        permissions: std.AutoHashMap(u32, u8), // (resource_id, permission)
    };

    const Resource = struct {
        path: []const u8,
    };

    pub fn init(allocator: std.mem.Allocator) !AccessMatrix {
        var res: AccessMatrix = .{
            .users = .empty,
            .resources = .empty,
            .allocator = allocator,
        };
        try res.users.append(allocator, .{
            .name = "Admin",
            .permissions = .init(allocator),
        });

        return res;
    }

    pub fn deinit(self: *AccessMatrix) void {
        for (self.users.items) |*user| {
            user.permissions.deinit();
        }
        self.users.deinit(self.allocator);
        self.resources.deinit(self.allocator);
    }

    pub fn login(self: *AccessMatrix, username: []const u8) i32 {
        for (self.users.items, 0..)|*user, i| {
            if (std.mem.eql(u8, user.name, username)) {
                return @intCast(i);
            }
        }
        return -1;
    }

    pub fn addUser(self: *AccessMatrix, name:[]const u8) !void {
        const user:User = .{
            .name = name,
            .permissions = .init(self.allocator),
        };
        try self.users.append(self.allocator, user);
    }

    pub fn addResource(self: *AccessMatrix, res:Resource) !void {
        const idx: u32 = @intCast(self.resources.items.len);
        try self.resources.append(self.allocator, res);
        try self.users.items[0].permissions.put(idx, Permission.full_access);
    }

    pub fn debugPrintAccessMatrix(self: *AccessMatrix) void {
        for (self.users.items) |*user| {
            std.debug.print("{s:>8}", .{user.name});
        }
        std.debug.print("\n", .{});
        for (self.resources.items, 0..) |*res, i| {
            for (self.users.items) |*user| {
                const res_idx: u32 = @intCast(i);
                std.debug.print("{b:>8}", .{
                    if (user.permissions.contains(res_idx))
                        user.permissions.get(res_idx).?
                    else 0
                });
            }
            std.debug.print("{s:>8}\n", .{res.path});
        }
    }
};

pub fn main() !void {
    var gpa = std.heap.DebugAllocator(.{}){};
    defer if (gpa.deinit() == .leak) {
        std.log.err("Memory leak", .{});
    };
    const allocator = gpa.allocator();

    var am: AccessMatrix = try .init(allocator);
    defer am.deinit();

    try am.addUser("Alex");
    try am.addUser("Block");
    try am.addUser("Cement");
    try am.addUser("Dawn");
    try am.addUser("Eve");
    try am.addUser("Foma");

    try am.addResource(.{.path = "res_1"});
    try am.addResource(.{.path = "res_2"});
    try am.addResource(.{.path = "res_3"});
    try am.addResource(.{.path = "res_4"});

    var buf: [1024]u8 = undefined;
    var stdin = std.fs.File.stdin().reader(&buf);
    var ior = &stdin.interface;
    var current_user_id: i32 = -1;

    try std.fs.File.stdout().writeAll("login: ");
    var user_input = try ior.takeDelimiterInclusive('\n');

    current_user_id = am.login(user_input[0 .. user_input.len - 1]);
    if (current_user_id < 0) return;

    const Commands = enum {
        q,
        grant,
        write,
        read,
        table,
    };
    menu: while (true) {
        try std.fs.File.stdout().writeAll(am.users.items[@intCast(current_user_id)].name);
        user_input = try ior.takeDelimiterInclusive('\n');
        const input = std.meta.stringToEnum(Commands, user_input[0 .. user_input.len - 1]) orelse {
            std.debug.print("Unknown command\n", .{});
            return;
        };
        switch (input) {
            .table => am.debugPrintAccessMatrix(),
            .q => break :menu,
            else => try std.fs.File.stdout().writeAll("Invalid Input\n"),
        }
    }
}
