mod decode;
mod events;
mod render;

use glfw::WindowMode::Windowed;

fn main() {
    let mut glfw = glfw::init(glfw::FAIL_ON_ERRORS).expect("Failed to initialize GLFW");
    let (mut window, events) = glfw.create_window(1280, 720, "qoiv", Windowed).expect("Failed to create a GLFW window");
    window.set_key_polling(true);

    render::init(&glfw);

    let args: Vec<String> = std::env::args().collect();
    let _ = decode::Img::from_path(&args[1]).expect("Failed to read image");

    while !window.should_close() {
        glfw.poll_events();
        for (_, event) in glfw::flush_messages(&events) {
            events::handle_window_event(&mut window, event);
        }
    }
}
