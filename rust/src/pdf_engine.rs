use std::sync::OnceLock;

use godot::{classes::{ProjectSettings}, prelude::*};
use pdfium_render::prelude::*;

static PDFIUM: OnceLock<Pdfium> = OnceLock::new();

#[derive(GodotClass)]
#[class(init, base=RefCounted)]
pub struct PdfEngine {
    base: Base<RefCounted>
}

fn get_pdfium() -> Result<&'static Pdfium, String> {
    if let Some(pdfium) = PDFIUM.get() {
        return Ok(pdfium);
    }

    let path = ProjectSettings::singleton().globalize_path("res://bin/linux/libpdfium.so");

    let bindings = Pdfium::bind_to_library(path.to_string()).map_err(|e| e.to_string())?;

    let _ = PDFIUM.set(Pdfium::new(bindings));

    PDFIUM.get().ok_or_else(|| "Failed to initialize Pdfium!".to_string())
}

#[godot_api]
impl PdfEngine {
    #[func]
    pub fn check_pdfium(library_path: GString) -> GString {
        match Pdfium::bind_to_library(library_path.to_string()) {
            Ok(_bindings) => "Pdfium loaded successfully!".into(),
            _ => "Failed to load Pdfium!".into()
        }
    }

    #[func]
    pub fn get_pdf_page_count(pdf_path: GString) -> Dictionary<GString, Variant> {
        let mut result = Dictionary::new();

        let page_count = (|| -> Result<i64, String> {
            let pdfium = get_pdfium()?;

            let document = pdfium.load_pdf_from_file(&pdf_path.to_string(), None).map_err(|e| e.to_string())?;

            Ok(document.pages().len() as i64)
        })();

        match page_count {
            Ok(i) => {
                result.set("count", i);
                result.set("error", &GString::new());
            }
            Err(error) => result.set("error", &GString::from(error.as_str()))
        }

        result
    }

    #[func]
    pub fn render_page(
        pdf_bytes: PackedByteArray,
        page_index: i64,
        target_width: i64,
    ) -> Dictionary<GString, Variant> {
        let mut result = Dictionary::new();

        let rendered = (|| -> Result<(Vec<u8>, u32, u32), String> {
            if page_index < 0 || page_index > u16::MAX as i64 {
                return Err("Invalid page index".into());
            }

            if target_width <= 0 || target_width > 8192 {
                return Err("Target width must be between 1 and 8192".into());
            }

            let pdfium = get_pdfium()?;

            let document = pdfium.load_pdf_from_byte_vec(pdf_bytes.as_slice().to_vec() as Vec<u8>, None).map_err(|e| e.to_string())?;

            let page = document.pages().get(page_index as i32).map_err(|e| e.to_string())?;

            let bitmap = page.render_with_config(&PdfRenderConfig::new().set_target_width(target_width as i32)).map_err(|e| e.to_string())?;

            let image = bitmap.as_image().map_err(|e| e.to_string())?.to_rgba8();

            let width = image.width();
            let height = image.height();
            let pixels = image.into_raw();

            Ok((pixels,width,height))
        })();

        match rendered {
            Ok((pixels, width, height)) => {
                let mut packed_pixels = PackedByteArray::new();

                for byte in pixels {
                    packed_pixels.push(byte);
                }

                result.set("pixels", &packed_pixels);
                result.set("width", width as i64);
                result.set("height", height as i64);
                result.set("error", &GString::new());
            }
            Err(error) => {
                result.set("error", &GString::from(error.as_str()));
            }
        }

        result
    }
}
