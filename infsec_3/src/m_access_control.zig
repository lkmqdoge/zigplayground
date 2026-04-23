const std = @import("std");

// Мандатная пб
// Нет чтения наверх
// Нет записи вниз 

pub const MAC_AccessMatrix = struct {
    pub const AccessErrors = error {
        AccessDenied,
        ReadAccessDenied,
        WriteAccessDenied,
        UserNotExist,
        ResourceNotExist,
    };

    pub const AccessActionType = enum {
        Read,
        Write,
    };

    pub const AccessLevel = enum(u8) {
        Public,
        Restricted,
        Confidential,
        Secret,
        TopSecret
    };

    pub const User = struct {
        name: []const u8,
        access_level: AccessLevel = .Public,
    };

    pub const Resource = struct {
        name: []const u8,
        access_level: AccessLevel = .Public,
    };

    admin_id: u32,
    users: std.ArrayList(User) = .empty,
    resources: std.ArrayList(Resource) = .empty,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, admin_id: u32) MAC_AccessMatrix {
        const res: MAC_AccessMatrix = .{
            .allocator = allocator,
            .admin_id = admin_id,
        };
        return res;
    }

    pub fn deinit(self: *MAC_AccessMatrix) void {
        self.users.deinit(self.allocator);
        self.resources.deinit(self.allocator);
    }

    pub fn addUser(self: *MAC_AccessMatrix, username: []const u8, al: AccessLevel) !void {
        try self.users.append(self.allocator, .{
            .name = username,
            .access_level = al,
        });
    }

    pub fn addResource(self: *MAC_AccessMatrix, resname: []const u8, al: AccessLevel) !void {
        try self.resources.append(self.allocator, .{
            .name = resname,
            .access_level = al,
        });
    }

    pub fn getUserId(self: *MAC_AccessMatrix, username: []const u8) !u32 {
        for (self.users.items, 0..) |user, i| {
            if (std.mem.eql(u8, user.name, username)) 
                return @intCast(i);
        }
        return error.UserNotExist;
    }

    pub fn getResourceId(self: *MAC_AccessMatrix, resname: []const u8) !u32 {
        for (self.resources.items, 0..) |res, i| {
            if (std.mem.eql(u8, res.name, resname))
                return @intCast(i);
        }
        return error.ResourceNotExist;
    }

    pub fn changeResourceAccessLevel(
        self: *MAC_AccessMatrix,
        user_id: u32,
        res_id: u32,
        new_access_level: AccessLevel,
    ) !void {
        if (user_id != self.admin_id)
            return error.AccessDenied;
        
        self.resources.items[res_id].access_level = new_access_level;
    }

    pub fn changeUserAccessLevel(
        self: *MAC_AccessMatrix,
        user_id: u32,
        to_user_id: u32,
        new_access_level: AccessLevel,
    ) !void {
        if (user_id != self.admin_id)
            return error.AccessDenied;
        
        self.resources.items[to_user_id].access_level = new_access_level;
    }
    pub fn readResource(self: *MAC_AccessMatrix, user_id: u32, res_id: u32) !void {
        if (!self.checkAccessLevel(user_id, res_id, .Read))
            return error.ReadAccessDenied; 
        const res = &self.resources.items[res_id];
        var strbuf: [128]u8 = undefined;
        const s = try std.fmt.bufPrint(&strbuf, "res/{s}", .{res.name});
        
        var buf: [1024]u8 = undefined;
        std.debug.print("{s}\n", .{try std.fs.cwd().readFile(s, &buf)});
    }

    pub fn writeResource(self: *MAC_AccessMatrix, user_id: u32, res_id: u32, content: []const u8) !void {
        if (!self.checkAccessLevel(user_id, res_id, .Write))
            return error.WriteAccessDenied; 

        const res = &self.resources.items[res_id];
        var strbuf: [128]u8 = undefined;
        const s = try std.fmt.bufPrint(&strbuf, "res/{s}", .{res.name});
        var f = try std.fs.cwd().openFile(s, .{.mode = .write_only});
        defer f.close();
        var buf: [1024]u8 = undefined;
        var writer = f.writer(&buf);
        const iow = &writer.interface;
        try iow.writeAll(content);
        try iow.flush();
    }

    fn checkAccessLevel(
        self: *MAC_AccessMatrix,
        user_id: u32,
        res_id: u32,
        t: AccessActionType
    ) bool {    
        if (user_id == self.admin_id)
            return true;

        const u = &self.users.items[user_id];
        const r = &self.resources.items[res_id];

        return switch (t) {
            .Read => @intFromEnum(r.access_level) <= @intFromEnum(u.access_level),
            .Write => @intFromEnum(r.access_level) >= @intFromEnum(u.access_level),
        };
    }
};
