use std::{fs, sync::OnceLock};

use fast_image_resize::{ResizeOptions, Resizer, images::Image};
use godot::{classes::ProjectSettings, prelude::*};
use image::ImageReader;
use pdfium_render::prelude::*;

pub static PDFIUM: OnceLock<Pdfium> = OnceLock::new();

#[derive(GodotClass)]
#[class(init, base=RefCounted)]
pub struct PdfEngine {
    base: Base<RefCounted>,
}

pub fn get_pdfium() -> Result<&'static Pdfium, String> {
    if let Some(pdfium) = PDFIUM.get() {
        return Ok(pdfium);
    }

    let path = ProjectSettings::singleton().globalize_path("res://bin/linux/libpdfium.so");

    let bindings = Pdfium::bind_to_library(path.to_string()).map_err(|e| e.to_string())?;

    let _ = PDFIUM.set(Pdfium::new(bindings));

    PDFIUM
        .get()
        .ok_or_else(|| "Failed to initialize Pdfium!".to_string())
}

#[godot_api]
impl PdfEngine {
    pub fn render_page(
        pdf_bytes: &[u8],
        page_index: i64,
        target_width: i64,
    ) -> Result<(Vec<u8>, u32, u32), String> {
        if page_index < 0 || page_index > u16::MAX as i64 {
            return Err("Invalid page index".into());
        }

        if target_width <= 0 || target_width > 8192 {
            return Err("Target width must be between 1 and 8192".into());
        }

        let pdfium = get_pdfium()?;

        let document = pdfium
            .load_pdf_from_byte_vec(pdf_bytes.to_vec() as Vec<u8>, None)
            .map_err(|e| e.to_string())?;

        let page = document
            .pages()
            .get(page_index as i32)
            .map_err(|e| e.to_string())?;

        let bitmap = page
            .render_with_config(&PdfRenderConfig::new().set_target_width(target_width as i32))
            .map_err(|e| e.to_string())?;

        let image = bitmap.as_image().map_err(|e| e.to_string())?.to_rgba8();

        let width = image.width();
        let height = image.height();
        let pixels = image.into_raw();

        Ok((pixels, width, height))
    }

    #[func]
    pub fn render_page_gd(
        pdf_path: String,
        page_index: i64,
        target_width: i64,
    ) -> Dictionary<GString, Variant> {
        let mut result = Dictionary::new();

        let pdf_bytes = fs::read(pdf_path).unwrap();
        let rendered = PdfEngine::render_page(pdf_bytes.as_slice(), page_index, target_width);

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

#[derive(GodotClass)]
#[class(init, base=RefCounted)]
pub struct ImageEngine {
    base: Base<RefCounted>,
}

#[godot_api]
impl ImageEngine {
    pub fn render_image(bytes: &[u8], target_width: u32) -> Result<(Vec<u8>, u32, u32), String> {
        if ImageEngine::is_jpeg(bytes) {
            return ImageEngine::decode_jpeg(bytes, target_width);
        } else if ImageEngine::is_webp(bytes) {
            return ImageEngine::decode_webp(bytes, target_width);
        }
        Err("Can't render image!".to_owned())
    }

    fn decode_webp(bytes: &[u8], target_width: u32) -> Result<(Vec<u8>, u32, u32), String> {
        let decoder = webpx::Decoder::new(bytes).map_err(|e| e.to_string())?;
        let info = decoder.info();
        let width = info.width;
        let height = info.height;

        decoder
            .scale(
                target_width,
                (height as f64 / width as f64 * target_width as f64) as u32,
            )
            .decode_rgba_raw()
            .map_err(|e| e.to_string())
    }

    fn decode_jpeg(bytes: &[u8], target_width: u32) -> Result<(Vec<u8>, u32, u32), String> {
        let mut decompresser = turbojpeg::Decompressor::new().map_err(|e| e.to_string())?;

        let header = decompresser.read_header(bytes).map_err(|e| e.to_string())?;
        let width = header.width;

        let scaling_factors = turbojpeg::Decompressor::supported_scaling_factors();
        let best_scaling = scaling_factors
            .iter()
            .min_by_key(|sf| {
                let scaled_w = (width as f32 * sf.num() as f32 / sf.denom() as f32) as i32;
                (scaled_w - target_width as i32).abs()
            })
            .copied()
            .unwrap_or(turbojpeg::ScalingFactor::new(1, 1));

        decompresser
            .set_scaling_factor(best_scaling)
            .map_err(|e| e.to_string())?;

        let scaled_header = header.scaled(best_scaling);

        let mut output = turbojpeg::Image {
            pixels: vec![0; 4 * scaled_header.width * scaled_header.height],
            width: scaled_header.width,
            height: scaled_header.height,
            pitch: 4 * scaled_header.width,
            format: turbojpeg::PixelFormat::RGBA,
        };

        decompresser
            .decompress(bytes, output.as_deref_mut())
            .map_err(|e| e.to_string())?;

        Ok((output.pixels, output.width as u32, output.height as u32))
    }

    fn is_jpeg(bytes: &[u8]) -> bool {
        bytes.starts_with(&[0xFF, 0xD8, 0xFF])
    }

    fn is_webp(bytes: &[u8]) -> bool {
        bytes.len() > 12 && &bytes[0..4] == b"RIFF" && &bytes[8..12] == b"WEBP"
    }
}
