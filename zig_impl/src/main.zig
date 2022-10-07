const std = @import("std");
const Img = @import("decode.zig").Img;

pub fn main() anyerror!void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    const images = [_][]const u8{
        "images/dice.qoi",
        "images/kodim10.qoi",
        "images/qoi_logo.qoi",
        "images/testcard.qoi",
        "images/testcard_rgba.qoi",
        "images/wikipedia_008.qoi",
    };
    for (images) |image| {
        var i: usize = 0;
        while (i < 10) : (i += 1) {
            const img = try Img.fromPath(image, alloc);
            alloc.free(img.data);
        }
    }
}
