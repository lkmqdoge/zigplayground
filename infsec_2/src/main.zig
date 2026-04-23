const std = @import("std");


const AccessError = error {
    UserNotExist,
    ResourceNotExist,
};

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


    pub fn findUser(self: *AccessMatrix, username: []const u8) !u32 {
        for (self.users.items, 0..)|*user, i| {
            if (std.mem.eql(u8, user.name, username)) {
                return @intCast(i);
            }
        }
        return error.UserNotExist;
    }

    pub fn findResource(self: *AccessMatrix, resname: []const u8) !u32 {
        for (self.resources.items, 0..)|*res, i| {
            if (std.mem.eql(u8, res.path, resname)) {
                return @intCast(i);
            }
        }
        return error.ResourceNotExist;
    }

    pub fn login(self: *AccessMatrix, username: []const u8) !u32 {
        return try self.findUser(username);
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

    const respath = "res/";
    pub fn readResource(self: *AccessMatrix, user_id: u32, res_id: u32) !void {
        if (!self.checkPermissions(user_id, res_id, Permission.read)) {
            std.debug.print("User {s} has no read permission\n", .{self.users.items[user_id].name});
            return;
        }
        var strbuf: [64]u8 = undefined;
        const path = try std.fmt.bufPrint(&strbuf,"{s}{s}", .{respath, self.resources.items[res_id].path});
        var buf: [4096]u8 = undefined;
        const content = try std.fs.cwd().readFile(path, &buf);
        std.debug.print("{s}", .{content});
    }

    pub fn writeResource(self: *AccessMatrix, user_id: u32, res_id: u32, content: []const u8) !void {
        if (!self.checkPermissions(user_id, res_id, Permission.write)) {
            std.debug.print("User {s} has no write permission\n", .{self.users.items[user_id].name});
            return;
        }
        var strbuf: [64]u8 = undefined;
        const path = try std.fmt.bufPrint(&strbuf,"{s}{s}", .{respath, self.resources.items[res_id].path});
        var buf: [4096]u8 = undefined;
        const f = try std.fs.cwd().openFile(path, .{.mode = .write_only});
        defer f.close();
        var writer = f.writer(&buf);
        const iow = &writer.interface;
        try iow.writeAll(content);
        try iow.flush();
    }

    pub fn grantToUser(self: *AccessMatrix, user_id: u32, user_id_dst: u32, res_id: u32, p: u8) !void {
        if (!self.checkPermissions(user_id, res_id, Permission.grant)) {
            std.debug.print("User {s} has no grant permission", .{self.users.items[user_id].name});
            return;
        }
        const old = self.users.items[user_id_dst].permissions.get(res_id) orelse 0;
        try self.users.items[user_id_dst].permissions.put(res_id, old | p);
    }

    fn checkPermissions(self: *AccessMatrix, user_id: u32, res_id: u32, p: u8) bool {
        const user = &self.users.items[user_id];
        const user_p = user.permissions.get(res_id) orelse 0;
        return (user_p & p) != 0;
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

    try std.fs.File.stdout().writeAll("login: ");
    var user_input = try ior.takeDelimiterInclusive('\n');
    var current_user_id = am.login(user_input[0 .. user_input.len - 1]) catch {
        std.debug.print("User doesnt exist", .{});
        return;
    };

    const Commands = enum {
        q,
        grant,
        write,
        read,
        perms,
        table,
        login,
    };

    am.debugPrintAccessMatrix();

    menu: while (true) {
        const s = try std.fmt.bufPrint(&buf, "{s}$ ", .{am.users.items[@intCast(current_user_id)].name});
        try std.fs.File.stdout().writeAll(s);
        user_input = try ior.takeDelimiterInclusive('\n');
        const input = std.meta.stringToEnum(Commands, user_input[0 .. user_input.len - 1]) orelse {
            std.debug.print("Unknown command\n", .{});
            continue;
        };

        switch (input) {
            .login => {
                try std.fs.File.stdout().writeAll("login: ");
                user_input = try ior.takeDelimiterInclusive('\n');
                const new_user_id = am.login(user_input[0 .. user_input.len - 1]) catch {
                    std.debug.print("user not exist\n", .{});
                    continue;
                };
                current_user_id = new_user_id;
            },
            .read => {
                try std.fs.File.stdout().writeAll("resource name: ");
                user_input = try ior.takeDelimiterInclusive('\n');
                const res_id = am.findResource(user_input[0 .. user_input.len - 1]) catch {
                    std.debug.print("file not exist\n", .{});
                    continue;
                };
                try am.readResource(current_user_id, res_id);
            },
            .write => {
                try std.fs.File.stdout().writeAll("resource name: ");
                user_input = try ior.takeDelimiterInclusive('\n');
                const res_id = am.findResource(user_input[0 .. user_input.len - 1]) catch {
                    std.debug.print("file not exist\n", .{});
                    continue;
                };

                try std.fs.File.stdout().writeAll("Text to write: ");
                user_input = try ior.takeDelimiterInclusive('\n');
                try am.writeResource( current_user_id, res_id, user_input);
            },
            .grant => {
                try std.fs.File.stdout().writeAll("grant to user: ");
                user_input = try ior.takeDelimiterInclusive('\n');
                const to_user = am.findUser(user_input[0 .. user_input.len - 1]) catch {
                    std.debug.print("user not exist\n", .{});
                    continue;
                };

                try std.fs.File.stdout().writeAll("resource: ");
                user_input = try ior.takeDelimiterInclusive('\n');
                const res_id = am.findResource(user_input[0 .. user_input.len - 1]) catch {
                    std.debug.print("resource not exist\n", .{});
                    continue;
                };

                try std.fs.File.stdout().writeAll("permission: ");
                user_input = try ior.takeDelimiterInclusive('\n');

                const perms = enum {grant, write, read};
                const perm_input = std.meta.stringToEnum(perms, user_input[0 .. user_input.len - 1]) orelse {
                    std.debug.print("Unknown command\n", .{});
                    continue;
                };
                const perm: u8 = switch (perm_input) {
                    .grant => AccessMatrix.Permission.grant,
                    .write => AccessMatrix.Permission.write,
                    .read => AccessMatrix.Permission.read,
                };
                try am.grantToUser( current_user_id, to_user, res_id, perm);
            },
            .table => am.debugPrintAccessMatrix(),
            .q => break :menu,
            else => try std.fs.File.stdout().writeAll("Invalid Input\n"),
        }
    }
}
