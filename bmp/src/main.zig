const std = @import("std");

const Pixel = packed struct {
    blue: u8,
    green: u8,
    red: u8,
};

const BitMapFileHeader = packed struct {
    bfType: u16,
    bfSize: u32, bfReserved1: u16,
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

const BmpImage = struct {
    fh: BitMapFileHeader,
    ih: BitMapInfoHeader,
    data: []Pixel,
    allocator: std.mem.Allocator,

    pub fn init(path: []const u8, allocator: std.mem.Allocator) !BmpImage {
        const f = try std.fs.cwd().openFile(path, .{});
        defer f.close();
        var buf: [1024]u8 = undefined;
        var r = f.reader(&buf); 
        const ior = &r.interface;
        var res: BmpImage = undefined;
        res.fh = try ior.takeStruct(BitMapFileHeader,  .little);
        res.ih = try ior.takeStruct(BitMapInfoHeader, .little);
        res.allocator = allocator;
        const padding = (4-((3*res.ih.biWidth)%4))%4;
        const num_of_pixels = res.ih.biWidth*res.ih.biHeight;
        res.data = try allocator.alloc(Pixel, num_of_pixels);
        try r.seekTo(res.fh.bfOffBits);
        var idx: usize = 0;
        for (0..res.ih.biHeight) |_|{
            for (0..res.ih.biWidth) |_|{
                res.data[idx] = ior.takeStruct(Pixel, .little); 
                idx+=1; 
            }
            try f.seekBy(padding);
        }

        return res;
    }

    pub fn deinit(self: BmpImage) void {
        self.allocator.free(self.data);
    }

    pub fn debugLogHeaders(self: BmpImage) void {
        std.debug.print("Тип:              {x}\n",      .{self.fh.bfType});
        std.debug.print("Размер заголовка: {d} байт\n", .{self.fh.bfSize});
        std.debug.print("рез1:             {d}\n",      .{self.fh.bfReserved1});
        std.debug.print("рез2:             {d}\n",      .{self.fh.bfReserved2});
        std.debug.print("Смещение:         {d}\n",      .{self.fh.bfOffBits});
        std.debug.print("размер:           {d}:{d}\n",  .{self.ih.biWidth,
                                                          self.ih.biHeight});
        std.debug.print("размер заголовка: {d}\n",      .{self.ih.biSize});
        std.debug.print("биты:             {d}\n",      .{self.ih.biBitCount});
        
    }
};


pub fn main() !void {
    var gpa = std.heap.DebugAllocator(.{}){};
    defer if (gpa.deinit() == .leak) {
        std.log.err("Memory leak", .{});
    };
    const allocator = gpa.allocator();
    const bmp = try BmpImage.init("image.bmp", allocator);
    bmp.debugLogHeaders(); 
    defer bmp.deinit();
}
