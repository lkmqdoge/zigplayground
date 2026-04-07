const std = @import("std");

const Pixel = packed struct {
    blue: u8,
    green: u8,
    red: u8,
};

const BitMapFileHeader = packed struct {
    bfType: u16,
    bfSize: u32,
    bfReserved1: u16,
    bfReserved2: u16,
    bfOffBits: u32,
};

const BitMapInfoHeader = packed struct {
    biSize: u32,
    biWidth: i32,
    biHeight: i32,
    biPlanes: u16,
    biBitCount: u16,
    biCompression: u32,
    biSizeImage: u32,
    biXPelsPerMeter: i32,
    biYPelsPerMeter: i32,
    biClrUsed: u32,
    biClrImportant: u32,
};

fn read_data(
    f: *std.fs.File,
    fh: *BitMapFileHeader,
    ih: *BitMapInfoHeader,
    allocator: std.mem.Allocator,
) ![]Pixel {
    const padding = (4-((3*ih.biWidth)%4))%4;
    const num_of_pixels = ih.biWidth*ih.biHeight;
    var pixels = try allocator.alloc(Pixel, num_of_pixels);

    try f.seekTo(fh.bfOffBits);
    var p_idx: usize = 0;
    for (0..ih.biHeight) |_| {
        for (0..ih.biWidth) |_| {
            var b: u8 = 0;
            var g: u8 = 0;
            var r: u8 = 0;

            try f.read(&b);
            try f.read(&g);
            try f.read(&r);
            
            pixels[p_idx] = Pixel{
                .blue = b,
                .green = g,
                .red = r,
            };

            p_idx+=1;
        }
        try f.seekBy(padding);
    }
    return pixels;
}

pub fn main() !void {
    const f = try std.fs.cwd().openFile("test.bmp", .{});
    defer f.close();

    var buf: [1024]u8 = undefined;
    var r = f.reader(&buf);
    const ior = &r.interface;
    const fh: BitMapFileHeader = try ior.takeStruct(BitMapFileHeader, .little);
    const ih: BitMapInfoHeader = try ior.takeStruct(BitMapInfoHeader, .little);
    std.debug.print("Тип:              {x}\n", .{fh.bfType});
    std.debug.print("Размер заголовка: {}\n", .{fh.bfSize});
    std.debug.print("Смещение:         {d}\n", .{fh.bfOffBits});
    std.debug.print("размер:           {d}:{d}\n", .{ih.biWidth, ih.biHeight});
}
