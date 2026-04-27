const std = @import("std");

const PPM = struct {
    const PPMContext = struct { 
        next: std.ArrayList([]const u8),
        context: []const u8,
        already_encountered: u32,
    };

    order: u32,

    pub fn init(order: u32) PPM {
        return .{
            .order = order,
        };
    }

    pub fn encodeByte(self: *PPM, context: []u8, byte: u8) void {
    }
};

const HCoder = struct {

};

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;

    const test_string = "abracadabra";
    var map = std.StringHashMap(std.ArrayList([]const u8 )).init(allocator);
    defer {
        var it = map.iterator();
        while (it.next()) |entry| {
            entry.value_ptr.deinit(allocator);
        }
        map.deinit();
    }

    try map.put("ab", .empty);
    try map.getPtr("ab").?.append(allocator, test_string);
    const str = map.get("ab").?.items[0];
    std.debug.print("{s}", .{str});
}

