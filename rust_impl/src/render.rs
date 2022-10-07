use crate::decode::Img;

#[repr(packed(1))]
#[derive(Default, Clone, Copy)]
struct Vertex {
    pos: [f32; 2],
    uv: [f32; 2],
}

static mut VERTICES: [Vertex; 4] = [
    Vertex { pos: [-1.0, 1.0], uv: [-1.0, 1.0] },
    Vertex { pos: [-1.0, -1.0], uv: [-1.0, -1.0] },
    Vertex { pos: [1.0, -1.0], uv: [1.0, -1.0] },
    Vertex { pos: [1.0, 1.0], uv: [1.0, 1.0] },
];

pub fn init(glfw: &glfw::Glfw) -> glow::Context {
    let frag_src = include_str!("shaders/shader.frag");
    let vert_src = include_str!("shaders/shader.vert");

    let gl = unsafe { glow::Context::from_loader_function(|s| glfw.get_proc_address_raw(s)) };
}

pub fn resize(width: i32, height: i32) {}

pub fn render() {}

pub fn set_texture(img: Img) {}
