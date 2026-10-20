use godot::prelude::*;

mod preview_texture_engine;
mod render_engine;
mod util;

struct RustExtension;


#[gdextension]
unsafe impl ExtensionLibrary for RustExtension {}

