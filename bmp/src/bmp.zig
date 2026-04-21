const std = @import("std");

const Pixel = extern struct {
    blue: u8 = 0,
    green: u8 = 0,
    red: u8 = 0,
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

pub const BmpImage = struct {
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
        res.fh = try ior.takeStruct(BitMapFileHeader, .little);
        res.ih = try ior.takeStruct(BitMapInfoHeader, .little);
        res.allocator = allocator;

        const w: u32 = @intCast(res.ih.biWidth);
        const h: u32 = @intCast(res.ih.biHeight);

        const padding = 4 - ((3 * w) % 4) % 4;
        const num_of_pixels: usize = @intCast(w * h);
        res.data = try allocator.alloc(Pixel, num_of_pixels);

        try r.seekTo(res.fh.bfOffBits);
        var idx: usize = 0;
        for (0..h) |_| {
            for (0..w) |_| {
                res.data[idx] = try ior.takeStruct(Pixel, .little);
                idx += 1;
            }
            try r.seekBy(padding);
        }

        return res;
    }

    pub fn deinit(self: *BmpImage) void {
        self.allocator.free(self.data);
    }

    pub fn clone(self: *BmpImage) !BmpImage {
        var res: BmpImage = undefined;
        res.fh = self.fh;
        res.ih = self.ih;
        res.allocator = self.allocator;
        res.data = try self.allocator.dupe(Pixel, self.data);
        return res;
    }

    pub fn cloneEmpty(self: *BmpImage) !BmpImage {
        var res: BmpImage = undefined;
        res.fh = self.fh;
        res.ih = self.ih;
        res.allocator = self.allocator;
        res.data = try self.allocator.alloc(Pixel, self.data.len);
        return res;
    }

    pub fn writeToDisk(self: *BmpImage, path: []const u8) !void {
        const f = try std.fs.cwd().createFile(path, .{});
        defer f.close();
        var buf: [1024]u8 = undefined;
        var writer = f.writer(&buf);
        const iw = &writer.interface;

        const w: u32 = @intCast(self.ih.biWidth);
        const h: u32 = @intCast(self.ih.biHeight);

        try iw.writeStruct(self.fh, .little);
        try iw.writeStruct(self.ih, .little);
        const padding = 4 - ((3 * w) % 4) % 4;

        var idx: usize = 0;
        for (0..h) |_| {
            for (0..w) |_| {
                try iw.writeStruct(self.data[idx], .little);
                idx += 1;
            }
            const zero: [3]u8 = .{0, 0, 0};
            try iw.writeAll(zero[0..padding]);
        }
    }

    pub fn takeChannels(self: *BmpImage) !struct {BmpImage, BmpImage, BmpImage} {
        var b = try self.cloneEmpty();
        var g = try self.cloneEmpty();
        var r = try self.cloneEmpty();
        
        for (0..self.data.len) |i| {
            b.data[i] = .{ .blue = self.data[i].blue }; 
            g.data[i] = .{ .green = self.data[i].green };
            r.data[i] = .{ .red = self.data[i].red };
        }

        return .{ b, g, r };
    }

    pub fn debugLogHeaders(self: *BmpImage) void {
        std.debug.print("Тип:              {x}\n", .{self.fh.bfType});
        std.debug.print("Размер заголовка: {d} байт\n", .{self.fh.bfSize});
        std.debug.print("рез1:             {d}\n", .{self.fh.bfReserved1});
        std.debug.print("рез2:             {d}\n", .{self.fh.bfReserved2});
        std.debug.print("Смещение:         {d}\n", .{self.fh.bfOffBits});
        std.debug.print("размер:           {d}:{d}\n", .{ self.ih.biWidth, self.ih.biHeight });
        std.debug.print("размер заголовка: {d}\n", .{self.ih.biSize});
        std.debug.print("биты:             {d}\n", .{self.ih.biBitCount});
    }
};
