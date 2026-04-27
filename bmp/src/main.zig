const std = @import("std");
const bmp = @import("bmp.zig");

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;
    const io = init.io;
    const args = try init.minimal.args.toSlice(init.arena.allocator());

    if (args.len == 1) {
        std.debug.print(
        \\Usage:
        \\      bmp <filename>
        ++ "\n", .{});
        return;
    }

    var image = try bmp.BmpImage.init(io, allocator, "image.bmp");
    defer image.deinit();
    image.debugLogHeaders();

    var g = try image.grayScale();
    defer g.deinit();
    try g.writeToDisk(io, "GRAY.bmp");

    for (0..8) |bit| {
        var p = try g.BitPlane(@intCast(bit));
        defer p.deinit();
        var buf: [32]u8 = undefined;
        const s = try std.fmt.bufPrint(&buf, "BITPLANE_{d}.bmp", .{bit});
        try p.writeToDisk(io, s);
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
