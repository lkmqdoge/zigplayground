const std = @import("std");
const mac = @import("m_access_control.zig");

fn get_user_input(ior: *std.Io.Reader) ![] const u8{
    const s = try ior.takeDelimiterInclusive('\n');
    return s[0 .. s.len - 1];
}

fn main_menu(io: std.Io) !void {
    const MainMenuOpts = enum {
        levels,
        login,
        table,
        read,
        chres,
        chuser,
        write,
        q,
        exit,
    };

    var buf: [1024]u8 = undefined;
    var stdin = std.Io.File.stdin().reader(io, &buf);
    const ior = &stdin.interface;

    menu: while (true) {
        std.debug.print("Login: ", .{});
        var user_input = try get_user_input(ior);
        const current_user_id = ma.getUserId(user_input) catch {
            std.debug.print("User {s} does not exist\n", .{user_input});
            continue;
        };

        login: while (true) {
            const user = &ma.users.items[current_user_id];
            std.debug.print("{s} | {s} $ ", .{user.name, @tagName(user.access_level)});
            user_input = try get_user_input(ior);
            const opt = std.meta.stringToEnum(MainMenuOpts, user_input) orelse {
                std.debug.print("Unknown command", .{});
                continue;
            };
            switch (opt) {
                .table => {
                    for (ma.resources.items) |*res|
                        std.debug.print("{s:>8} {s:<8}\n", .{res.name, @tagName(res.access_level)});
                    std.debug.print("\n", .{});
                    for (ma.users.items) |*usr|
                        std.debug.print("{s:>8} {s:<8}\n", .{usr.name, @tagName(usr.access_level)});
                    std.debug.print("\n", .{});
                },
                .levels => {
                    const levels = std.meta.fieldNames(mac.MAC_AccessMatrix.AccessLevel);
                    std.debug.print("{s}", .{levels[0]});
                    for (levels[1 .. levels.len])|level|
                        std.debug.print(" -> {s}", .{level});
                    std.debug.print("\n", .{});
                },
                .write => {// Ниже нелья писать
                    std.debug.print("resource: ", .{});
                    user_input = try get_user_input(ior);
                    const res_id = ma.getResourceId(user_input) catch {
                        std.debug.print("Resource {s} does not exist\n", .{user_input});
                        continue;
                    };
                    user_input = try ior.takeDelimiterInclusive('\n');
                    ma.writeResource(io, current_user_id, res_id, user_input) catch {
                        std.debug.print("Access Denied\n", .{});
                    };
                },
                .read => { // Выше нельзя чиатьт
                    std.debug.print("resource: ", .{});
                    user_input = try get_user_input(ior);
                    const res_id = ma.getResourceId(user_input) catch {
                        std.debug.print("Resource {s} does not exist\n", .{user_input});
                        continue;
                    };
                    ma.readResource(io, current_user_id, res_id) catch {
                        std.debug.print("Access Denied\n", .{});
                    };
                },
                .chuser => {
                    std.debug.print("User: ", .{});
                    user_input = try get_user_input(ior);
                    const user_id = ma.getResourceId(user_input) catch {
                        std.debug.print("User {s} does not exist\n", .{user_input});
                        continue;
                    };

                    std.debug.print("Level: ", .{});
                    user_input = try get_user_input(ior);
                    const level = std.meta.stringToEnum(mac.MAC_AccessMatrix.AccessLevel, user_input) orelse {
                        std.debug.print("Invalid level name\n", .{});
                        continue;
                    };
                    ma.changeUserAccessLevel(current_user_id, user_id, level) catch {
                        std.debug.print("Access Denied\n", .{});
                        continue;
                    };
                },
                .chres => {
                    std.debug.print("resource: ", .{});
                    user_input = try get_user_input(ior);
                    const res_id = ma.getResourceId(user_input) catch {
                        std.debug.print("Resource {s} does not exist\n", .{user_input});
                        continue;
                    };
                    std.debug.print("Level: ", .{});
                    user_input = try get_user_input(ior);
                    const level = std.meta.stringToEnum(mac.MAC_AccessMatrix.AccessLevel, user_input) orelse {
                        std.debug.print("Invalid level name\n", .{});
                        continue;
                    };
                    ma.changeResourceAccessLevel(current_user_id, res_id, level) catch {
                        std.debug.print("Access Denied\n", .{});
                        continue;
                    };
                },
                .q, .exit => break :menu,
                .login => break :login,
            }
        }
    }
}

var ma: mac.MAC_AccessMatrix = undefined;

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;
    const io = init.io;
    ma = .init(allocator, 0);
    defer ma.deinit();    
    try ma.addUser("Admin", .TopSecret);
    try ma.addUser("Alex", .Public);
    try ma.addUser("Brock", .Confidential);
    try ma.addUser("Cat", .Restricted);
    try ma.addUser("Dima", .Secret);
    try ma.addUser("Eve", .TopSecret);

    try ma.addResource("res_1", .Public);
    try ma.addResource("res_2", .Restricted);
    try ma.addResource("res_3", .Confidential);
    try ma.addResource("res_4", .TopSecret);

    try main_menu(io);
}
