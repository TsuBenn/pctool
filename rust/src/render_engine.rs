use std::{fs, io::Cursor, sync::OnceLock};

use fast_image_resize::Resizer;
use godot::classes::{Os, ProjectSettings};
use godot::prelude::*;

use image::{ImageFormat, ImageReader};
use pdfium_render::prelude::*;

use crate::util::ImageUtil;

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

    let os = Os::singleton().get_name();
    let path = if os == "Linux" {
        Some(ProjectSettings::singleton().globalize_path("user://libpdfium.so"))
    } else if os == "Windows" {
        Some(ProjectSettings::singleton().globalize_path("user://pdfium.dll"))
    } else {
        None
    };

    let Some(path) = path else {
        return Err("Pdf Engine is not supported on this platform!".to_owned());
    };

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

        let pdf_bytes = match fs::read(pdf_path) {
            Ok(bytes) => bytes,
            Err(error) => {
                result.set("error", &GString::from(&error.to_string()));
                return result;
            }
        };
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
    pub fn render_image(
        bytes: &[u8],
        target_width: u32,
        format: Option<ImageFormat>,
    ) -> Result<(Vec<u8>, u32, u32), String> {
        let format = match format {
            Some(f) => Some(f),
            _ => ImageUtil::get_format_from_bytes(bytes),
        };
        match format {
            Some(ImageFormat::Jpeg) => ImageEngine::decode_jpeg(bytes, target_width),
            Some(ImageFormat::WebP) => ImageEngine::decode_webp(bytes, target_width),
            Some(ImageFormat::Png) => ImageEngine::decode_png(bytes, target_width),
            _ => Err("Can't render image!".to_owned()),
        }
    }

    fn decode_png(bytes: &[u8], target_width: u32) -> Result<(Vec<u8>, u32, u32), String> {
        // let start = Instant::now();

        let mut reader = ImageReader::new(Cursor::new(bytes));
        reader.set_format(ImageFormat::Png);
        let img = reader.decode().map_err(|e| e.to_string())?.into_rgba8();

        let (w, h) = img.dimensions();
        let (dw, dh) = (
            target_width,
            (target_width as f64 * h as f64 / w as f64) as u32,
        );
        let mut dst =
            fast_image_resize::images::Image::new(dw, dh, fast_image_resize::PixelType::U8x4);

        let mut resizer = Resizer::new();
        resizer
            .resize(&img, &mut dst, None)
            .map_err(|e| e.to_string())?;

        // godot_print!("PNG: {}ms", start.elapsed().as_millis());

        Ok((dst.into_vec(), dw, dh))
    }

    fn decode_webp(bytes: &[u8], target_width: u32) -> Result<(Vec<u8>, u32, u32), String> {
        // let start = Instant::now();

        let decoder = webpx::Decoder::new(bytes).map_err(|e| e.to_string())?;
        let info = decoder.info();
        let width = info.width;
        let height = info.height;

        let result = decoder
            .scale(
                target_width,
                (height as f64 / width as f64 * target_width as f64) as u32,
            )
            .decode_rgba_raw()
            .map_err(|e| e.to_string());

        // godot_print!("WEBP: {}ms", start.elapsed().as_millis());

        result
    }

    fn decode_jpeg(bytes: &[u8], target_width: u32) -> Result<(Vec<u8>, u32, u32), String> {
        // let start = Instant::now();

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

        // godot_print!("JPEG: {}ms", start.elapsed().as_millis());

        Ok((output.pixels, output.width as u32, output.height as u32))
    }
}
