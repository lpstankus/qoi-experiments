const std = @import("std");
const Allocator = std.mem.Allocator;

const DecodeError = error{
    MalformedHeader,
    MissingData,
    OutOfMemory,
    FailedToReadFile,
};

const Colorspace = enum(u8) { SRGB = 0, LINEAR = 1 };

const Pixel = std.meta.Vector(4, u8);

const Optag = enum(u8) {
    RGB,
    RGBA,
    INDEX,
    DIFF,
    LUMA,
    RUN,

    pub fn parseByte(byte: u8) Optag {
        switch (byte) {
            0xFE => return .RGB,
            0xFF => return .RGBA,
            else => return switch (byte >> 6) {
                0b00 => .INDEX,
                0b01 => .DIFF,
                0b10 => .LUMA,
                0b11 => .RUN,
                else => unreachable,
            },
        }
    }
};

pub const Img = struct {
    width: u32,
    height: u32,
    channels: u8,
    colorspace: Colorspace,
    data: []u8,

    const MAGIC = "qoif";
    const MAX_BYTES = 1024 * 1024 * 1024;

    pub fn fromPath(path: []const u8, alloc: Allocator) DecodeError!Img {
        const file = try std.fs.cwd().openFile(path, .{}) catch error.FailedToReadFile;
        const data = try file.readToEndAlloc(alloc, MAX_BYTES) catch error.FailedToReadFile;
        defer alloc.free(data);
        return fromBytes(data, alloc);
    }

    pub fn fromBytes(bytes: []const u8, alloc: Allocator) DecodeError!Img {
        if (bytes.len < 14 or !std.mem.eql(u8, bytes[0..4], MAGIC)) return error.MalformedHeader;

        const width = std.mem.readIntBig(u32, bytes[4..8]);
        const height = std.mem.readIntBig(u32, bytes[8..12]);
        const channels = if (bytes[12] == 3 or bytes[12] == 4) bytes[12] else return error.MalformedHeader;
        const colorspace = if (bytes[13] <= 1) @intToEnum(Colorspace, bytes[13]) else return error.MalformedHeader;

        var data = try alloc.alloc(u8, width * height * channels);
        errdefer alloc.free(data);

        var running = [_]Pixel{.{ 0, 0, 0, 0 }} ** 64;
        var prev_pixel = Pixel{ 0, 0, 0, 0 };

        var di: usize = 0;
        var bi: usize = 14;
        while (di < data.len) {
            try assert_capacity(bi, bytes);
            switch (Optag.parseByte(bytes[bi])) {
                .RGB => {
                    try assert_capacity(bi + 3, bytes);
                    prev_pixel[0] = bytes[bi + 1];
                    prev_pixel[1] = bytes[bi + 2];
                    prev_pixel[2] = bytes[bi + 3];
                    bi += 4;
                },
                .RGBA => {
                    try assert_capacity(bi + 4, bytes);
                    prev_pixel[0] = bytes[bi + 1];
                    prev_pixel[1] = bytes[bi + 2];
                    prev_pixel[2] = bytes[bi + 3];
                    prev_pixel[3] = bytes[bi + 4];
                    bi += 5;
                },
                .INDEX => {
                    prev_pixel = running[bytes[bi]];
                    bi += 1;
                },
                .DIFF => {
                    const r_diff = ((bytes[bi] >> 4) & 0b11) -% 2;
                    const g_diff = ((bytes[bi] >> 2) & 0b11) -% 2;
                    const b_diff = ((bytes[bi] >> 0) & 0b11) -% 2;
                    prev_pixel +%= Pixel{ r_diff, g_diff, b_diff, 0 };
                    bi += 1;
                },
                .LUMA => {
                    try assert_capacity(bi + 2, bytes);
                    const g_diff = (bytes[bi] & 0x3F) -% 32;
                    const r_diff = g_diff +% (bytes[bi + 1] >> 4) -% 8;
                    const b_diff = g_diff +% (bytes[bi + 1] >> 0) -% 8;
                    prev_pixel +%= Pixel{ r_diff, b_diff, g_diff, 0 };
                    bi += 2;
                },
                .RUN => {
                    var run = bytes[bi] & 0x3F;
                    while (run >= 0) : (run -= 1) {
                        data[di + 0] = prev_pixel[0];
                        data[di + 1] = prev_pixel[1];
                        data[di + 2] = prev_pixel[2];
                        if (channels == 4) data[di + 3] = prev_pixel[3];
                        di += channels;
                    }
                    bi += 1;
                    continue;
                },
            }
            running[hash(prev_pixel)] = prev_pixel;
            data[di + 0] = prev_pixel[0];
            data[di + 1] = prev_pixel[1];
            data[di + 2] = prev_pixel[2];
            if (channels == 4) data[di + 3] = prev_pixel[3];
            di += channels;
        }

        return Img{
            .width = width,
            .height = height,
            .channels = channels,
            .colorspace = colorspace,
            .data = data,
        };
    }

    inline fn assert_capacity(i: usize, bytes: []const u8) DecodeError!void {
        if (i >= bytes.len) return error.MissingData;
    }

    inline fn hash(p: Pixel) usize {
        return (@as(usize, p[0]) * 3 + @as(usize, p[1]) * 5 + @as(usize, p[2]) * 7 + @as(usize, p[3]) * 11) % 64;
    }
};
