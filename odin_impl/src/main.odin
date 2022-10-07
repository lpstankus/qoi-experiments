package qoi

import "core:fmt"

QUAD_VERT :: [12]f32{ -1.0, 1.0, -1.0, -1.0, 1.0, 1.0, 1.0, 1.0, 1.0, -1.0, -1.0, -1.0 }

main :: proc() {
    image, err := decode_from_path("images/baboon.qoi")
    /* fmt.printf("%v\n", image); */
}
