use godot::prelude::*;

mod preview_texture_engine;
mod pdf_engine;

struct RustExtension;


#[gdextension]
unsafe impl ExtensionLibrary for RustExtension {}

