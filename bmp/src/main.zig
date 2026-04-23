const std = @import("std");
const bmp = @import("bmp.zig");

pub fn main() !void {
    var gpa = std.heap.DebugAllocator(.{}){};
    defer if (gpa.deinit() == .leak) {
        std.log.err("Memory leak", .{});
    };
    const allocator = gpa.allocator();

    const argv = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, argv);

    if (argv.len == 1) {
        std.debug.print(
        \\Usage:
        \\      bmp <filename>
        ++ "\n", .{});
        return;
    }

    var image = try bmp.BmpImage.init("image.bmp", allocator);
    defer image.deinit();
    image.debugLogHeaders();

    var g = try image.grayScale();
    defer g.deinit();
    try g.writeToDisk("GRAY.bmp");

    for (0..8) |bit| {
        var p = try g.BitPlane(@intCast(bit));
        defer p.deinit();
        var buf: [32]u8 = undefined;
        const s = try std.fmt.bufPrint(&buf, "BITPLANE_{d}.bmp", .{bit});
        try p.writeToDisk(s);
    }

    // var channels = try bmp.takeChannels();
    // defer inline for (&channels)|*c| {
    //     c.deinit(); 
    // };
    //
    // try channels.@"0".writeToDisk("BLUE.bmp");
    // try channels.@"2".writeToDisk("RED.bmp");
    // try channels.@"1".writeToDisk("GREEN.bmp");
}
