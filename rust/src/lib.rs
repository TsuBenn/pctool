use godot::prelude::*;

mod preview_texture_engine;
mod render_engine;
mod util;
mod export_engine;
mod data;

struct RustExtension;


#[gdextension]
unsafe impl ExtensionLibrary for RustExtension {}

