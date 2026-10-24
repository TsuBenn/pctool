use std::{fs::File, io::Read};

use godot::{classes::{Os, ProjectSettings}, prelude::*};
use image::ImageFormat;

use crate::render_engine;

#[derive(GodotClass)]
#[class(init, base=RefCounted)]
pub struct ImageUtil {
    base: Base<RefCounted>,
}

#[derive(GodotClass)]
#[class(init, base=RefCounted)]
pub struct ImageInfo {
    #[var]
    size: Vector2i,
    #[var]
    error: GString,
    base: Base<RefCounted>,
}

#[godot_api]
pub impl ImageInfo {
    #[func]
    fn new(size: Vector2i, error: GString) -> Gd<ImageInfo> {
        Gd::from_init_fn(|base| Self { base, size, error })
    }
}

#[godot_api]
pub impl ImageUtil {
    #[func]
    pub fn get_image_info(path: GString) -> Gd<ImageInfo> {
        match ImageUtil::is_supported(&path.to_string()) {
            Ok(b) => {
                if !b {
                    return ImageInfo::new(
                        Vector2i::ZERO,
                        GString::from("Not supported Image format"),
                    );
                }
            }
            Err(e) => return ImageInfo::new(Vector2i::ZERO, GString::from(&e)),
        }

        match image::image_dimensions(path.to_string()) {
            Ok((width, height)) => {
                ImageInfo::new(Vector2i::new(width as i32, height as i32), GString::new())
            }
            Err(e) => ImageInfo::new(Vector2i::ZERO, GString::from(&e.to_string())),
        }
    }

    pub fn get_format(path: &str) -> Result<ImageFormat, String> {
        let mut file = File::open(path).map_err(|e| e.to_string())?;
        let mut buffer = [0; 32];
        let n = file.read(&mut buffer).map_err(|e| e.to_string())?;

        image::guess_format(&buffer[..n]).map_err(|e| e.to_string())
    }

    pub fn get_format_from_bytes(bytes: &[u8]) -> Option<ImageFormat> {
        image::guess_format(bytes).ok()
    }

    fn is_supported(path: &str) -> Result<bool, String> {
        match ImageUtil::get_format(path) {
            Ok(format) => match format {
                image::ImageFormat::Png => Ok(true),
                image::ImageFormat::Jpeg => Ok(true),
                image::ImageFormat::WebP => Ok(true),
                _ => Ok(false),
            },
            _ => Err("Not an Image file".to_owned()),
        }
    }
}

#[derive(GodotClass)]
#[class(init, base=RefCounted)]
pub struct PdfUtil {
    base: Base<RefCounted>,
}

#[derive(GodotClass)]
#[class(init, base=RefCounted)]
pub struct PdfInfo {
    #[var]
    sizes: Array<Vector2i>,
    #[var]
    count: i64,
    #[var]
    error: GString,
    base: Base<RefCounted>,
}

#[godot_api]
pub impl PdfInfo {
    #[func]
    fn new(sizes: Array<Vector2i>, count: i64, error: GString) -> Gd<PdfInfo> {
        Gd::from_init_fn(|base| Self {
            base,
            sizes,
            count,
            error,
        })
    }
}

#[godot_api]
impl PdfUtil {

    pub fn get_library_location() -> Option<String> {
        let os = Os::singleton().get_name();
        if os == "Linux" {
            Some(ProjectSettings::singleton().globalize_path("user://").to_string())
        } else if os == "Windows" {
            Some(ProjectSettings::singleton().globalize_path("user://").to_string())
        } else {
            None
        }
    }

    #[func]
    pub fn get_pdf_info(path: String) -> Gd<PdfInfo> {
        let page_infos = (|| -> Result<(i64, Vec<Vector2i>), String> {

            let Some(lib) = PdfUtil::get_library_location() else {
                return Err("PDF Library not found!".to_owned());
            };

            pdfium::set_library_location(&lib);

            let document =
            pdfium::PdfiumDocument::new_from_path(path, None)
                .map_err(|_| lib)?;

            let page_count = document.pages().page_count();
            let page_sizes: Vec<Vector2i> = document
                .pages()
                .into_iter()
                .map(|p| {
                    let p = p.unwrap();
                    Vector2i::new(
                        (p.width() * 72.0 * 300.0) as i32,
                        (p.height() * 72.0 * 300.0) as i32,
                    )
                })
                .collect();
            Ok((page_count as i64, page_sizes))
        })();

        match page_infos {
            Ok((count, sizes)) => PdfInfo::new(sizes.to_godot(), count, GString::new()),
            Err(error) => PdfInfo::new(
                array![],
                0,
                GString::from(&error),
            ),
        }
    }
}
