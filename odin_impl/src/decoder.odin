package qoi

import "core:fmt"
import "core:math"
import "core:mem"
import "core:os"
import "core:slice"

Err :: enum {
    Success,
    InvalidFormat,
    FailedToReadFile,
}

Pixel :: distinct [4]u8

Optag_8bit :: enum u8 {
    RGB  = 254,
    RGBA = 255,
}

Optag_2bit :: enum u8 {
    INDEX = 0,
    DIFF  = 64,
    LUMA  = 128,
    RUN   = 192,
}

Colorspace :: enum u8 {
    SRGB   = 0,
    LINEAR = 1,
}

Image :: struct {
    width: u32,
    height: u32,
    channels: u8,
    colorspace: Colorspace,
    data: []Pixel,
}

@(private)
hash :: proc(col: Pixel) -> u64 {
    return (u64(col[0]) * 3 + u64(col[1]) * 5 + u64(col[2]) * 7 + u64(col[3]) * 11) % 64
}

decode_from_bytes :: proc(bytes: []byte) -> (Image, Err) {
    magic := "qoif"
    if mem.compare(transmute([]u8) magic, bytes[0:4]) != 0 do return {}, .InvalidFormat

    using im : Image
    {
        arr := slice.reinterpret([]u32, bytes[4:12])
        width  = arr[0]
        height = arr[1]
    }
    channels   = bytes[12]
    colorspace = Colorspace(bytes[13])

    err : mem.Allocator_Error
    data, err  = mem.make_slice([]Pixel, int(width) * int(height))
    if err != .None {
        fmt.println("Failed to allocate buffer: ", err)
        return {}, .InvalidFormat
    }
    fmt.println(int(width) * int(height), len(data))

    running : [64]Pixel
    prev_pixel : Pixel = { 0, 0, 0, 255 }

    i : u64 = 0
    for ptr := 14; ptr < len(bytes); {
        switch (Optag_8bit(bytes[ptr])) {
            case .RGB: {
                pixel : Pixel = { bytes[ptr + 1], bytes[ptr + 2], bytes[ptr + 3], prev_pixel[3] }
                running[hash(pixel)] = pixel
                prev_pixel           = pixel
                data[i]              = pixel
                ptr += 4
                i   += 1
                continue
            }
            case .RGBA: {
                pixel : Pixel = { bytes[ptr + 1], bytes[ptr + 2], bytes[ptr + 3], bytes[ptr + 4] }
                running[hash(pixel)] = pixel
                prev_pixel           = pixel
                data[i]              = pixel
                ptr += 5
                i   += 1
                continue
            }
        }

        switch (Optag_2bit(bytes[ptr] & 0xC0)) {
            case .INDEX: {
                pixel := running[bytes[ptr] & 0x3F]
                prev_pixel = pixel
                data[i]    = pixel
                ptr += 1
                i   += 1
                continue
            }
            case .DIFF: {
                pixel : Pixel = {
                    prev_pixel[0] + ((bytes[ptr] >> 4) & 0x03) - 2,
                    prev_pixel[1] + ((bytes[ptr] >> 2) & 0x03) - 2,
                    prev_pixel[2] + ((bytes[ptr] >> 0) & 0x03) - 2,
                    prev_pixel[3],
                }
                running[hash(pixel)] = pixel
                prev_pixel           = pixel
                data[i]              = pixel
                ptr += 1
                i   += 1
                continue
            }
            case .LUMA: {
                g_diff := (bytes[ptr] & 0x3F) - 32
                r_diff := (bytes[ptr + 1] & 0xF0) + g_diff
                b_diff := (bytes[ptr + 1] & 0x0F) + g_diff

                pixel : Pixel = {
                    prev_pixel[0] + r_diff - 32,
                    prev_pixel[1] + g_diff - 32,
                    prev_pixel[2] + b_diff - 32,
                    prev_pixel[3],
                }
                running[hash(pixel)] = pixel
                prev_pixel           = pixel
                data[i]              = pixel
                ptr += 2
                i   += 1
                continue
            }
            case .RUN: {
                run := u64(bytes[ptr] & 0x3F)
                for it := i; it < i + run; it += 1 do data[it] = prev_pixel
                ptr += 1
                i   += run
                continue
            }
        }
    }

    return im, .Success;
}

decode_from_path :: proc(path: string) -> (Image, Err) {
    bytes, rc := os.read_entire_file(path)
    if !rc do return {}, .FailedToReadFile
    return decode_from_bytes(bytes)
}
