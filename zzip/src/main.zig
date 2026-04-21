const std = @import("std");

const PPM = struct {
    
};

const HCoder = struct {

};

pub fn main() !void {
    var gpa = std.heap.DebugAllocator(.{}){};
    const allocator = gpa.allocator();
    defer if (gpa.deinit() == .leak) {
        std.debug.print("Memory leak(\n", .{});
    };

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

