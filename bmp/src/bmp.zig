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

    pub fn init(io: std.Io,  allocator: std.mem.Allocator, path: []const u8) !BmpImage {
        const f = try std.Io.Dir.cwd().openFile(io, path, .{});
        defer f.close(io);
        var buf: [1024]u8 = undefined;
        var r = f.reader(io, &buf);
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

    pub fn writeToDisk(self: *BmpImage, io: std.Io, path: []const u8) !void {
        const f = try std.Io.Dir.cwd().createFile(io, path, .{});
        defer f.close(io);
        var buf: [1024]u8 = undefined;
        var writer = f.writer(io, &buf);
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

    pub fn BitPlane(self: *BmpImage, bit: u3) !BmpImage {
        var res = try self.cloneEmpty();
        for (0..self.data.len) |i| {
            const one: u8 = 1;
            res.data[i] = .{
                .blue = (one << bit) & self.data[i].blue,
                .green = (one << bit) & self.data[i].green,
                .red = (one << bit) & self.data[i].red,
            };
        }
        return res;
    }

    pub fn grayScale(self: *BmpImage) !BmpImage {
        var res = try self.cloneEmpty();
        for (0..self.data.len) |i| {
            var sum: u32 = 0;
            sum += self.data[i].blue;
            sum += self.data[i].green;
            sum += self.data[i].red;
            const average: u8 = @intCast(sum / 3);
            res.data[i] = .{
                .blue = average,
                .green = average,
                .red = average,
            };
        }

        return res;
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
