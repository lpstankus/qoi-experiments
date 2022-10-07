use glfw::{Action, Key, Modifiers, Window};

pub fn handle_window_event(window: &mut Window, event: glfw::WindowEvent) {
    match event {
        glfw::WindowEvent::Key(key, _, action, modifiers) => handle_key_event(window, key, action, modifiers),
        _ => {}
    }
}

fn handle_key_event(window: &mut Window, key: Key, action: Action, modifier: Modifiers) {
    match (key, action, modifier) {
        (Key::Escape, Action::Press, _) => window.set_should_close(true),
        _ => {}
    }
}
