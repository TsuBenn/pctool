use godot::{global::Error, prelude::*};

struct RsDocumentData {
    paper_size_mm: (f64, f64),
    dpi: u64,
    tiles: Vec<TileData>,
}

struct TileData {
    source_path: String,
    index: u64,
    page: u64,
    rect_mm: (f64, f64, f64, f64),
}

#[derive(GodotClass)]
#[class(init, base=RefCounted)]
struct RsExportEngine {
    base: Base<RefCounted>
}

#[godot_api]
impl RsExportEngine {
    #[func]
    fn export_pdf() -> Error {
        Error::OK
    }
    #[func]
    fn export_png() -> Error {
        Error::OK
    }
}

