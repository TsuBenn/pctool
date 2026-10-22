use std::{fs::{self, File}, io::{Cursor, Read}, time::Instant};

use godot::prelude::*;
use image::{ImageFormat};
use turbojpeg::Image;
use webpx::{Encoder, Unstoppable};

use crate::render_engine;

#[derive(GodotClass)]
#[class(init, base=RefCounted)]
pub struct ImageUtil {
    base: Base<RefCounted>
}

#[derive(GodotClass)]
#[class(init, base=RefCounted)]
pub struct ImageInfo {
    #[var]
    size: Vector2i,
    #[var]
    error: GString,
    base: Base<RefCounted>
}

#[godot_api]
pub impl ImageInfo {
    #[func]
    fn new(size: Vector2i, error: GString) -> Gd<ImageInfo> {
        Gd::from_init_fn(|base| Self {
            base,
            size,
            error
        })
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
                        Variant::nil().to(),
                        GString::from("Not supported Image format")
                    )
                }
            }
            Err(e) => {
                return ImageInfo::new(
                    Variant::nil().to(),
                    GString::from(&e)
                )
            }
        }

        match image::image_dimensions(path.to_string()) {
            Ok((width, height)) => {
                ImageInfo::new(
                    Vector2i::new(width as i32, height as i32),
                    GString::new()
                )
            },
            Err(e) => {
                ImageInfo::new(
                    Variant::nil().to(),
                    GString::from(&e.to_string()),
                )
            }
        }
    }

    fn get_format(path: &str) -> Result<ImageFormat, String> {
        let mut file = File::open(path).map_err(|e| e.to_string())?;
        let mut buffer = [0; 32];
        let n = file.read(&mut buffer).map_err(|e| e.to_string())?;

        image::guess_format(&buffer[..n]).map_err(|e| e.to_string())
    }

    fn is_supported(path: &str) -> Result<bool, String> {
        match ImageUtil::get_format(path) {
            Ok(format) => {
                match format {
                    image::ImageFormat::Png => Ok(true),
                    image::ImageFormat::Jpeg => Ok(true),
                    image::ImageFormat::WebP => Ok(true),
                    _ => Ok(false)
                }
            }
            _ => Err("Not an Image file".to_owned())
        }
    }

    fn decode_png(path: &str) -> Result<(Vec<u8>, u32, u32), String> {
        let bytes = fs::read(path).unwrap();
        let mut decoder = png::Decoder::new(Cursor::new(&bytes));
        decoder.set_transformations(png::Transformations::EXPAND | png::Transformations::STRIP_16);
        let mut reader = decoder.read_info().unwrap();

        let mut buf = vec![0; reader.output_buffer_size().unwrap()];
        let info = reader.next_frame(&mut buf).unwrap();
        buf.truncate(info.buffer_size());

        let rgb: Vec<u8> = match info.color_type {
            png::ColorType::Rgb => buf,
            png::ColorType::Rgba => buf
                .chunks_exact(4)
                .flat_map(|p| [p[0], p[1], p[2]])
                .collect(),
            png::ColorType::Grayscale => buf
                .iter()
                .flat_map(|&g| [g, g, g])
                .collect(),
            png::ColorType::GrayscaleAlpha => buf
                .chunks_exact(2)
                .flat_map(|p| [p[0], p[0], p[0]])
                .collect(),
            png::ColorType::Indexed => return Err("unexpected indexed output".into()),
        };

        Ok((rgb, info.width, info.height))
    }

    pub fn get_bytes(path: &str) -> Result<(Vec<u8>, &'static str), String> {
        let format = ImageUtil::get_format(path)?;
        let bytes;
        let format_str;

        match format {
            image::ImageFormat::Jpeg => {
                bytes = fs::read(path).unwrap();
                format_str = "jpeg";
            },
            image::ImageFormat::WebP => {
                bytes = fs::read(path).unwrap();
                format_str = "webp";
            },
            image::ImageFormat::Png => {
                let mut start = Instant::now();
                let img = ImageUtil::decode_png(path).unwrap();
                godot_print!("Decode image: {}ms", start.elapsed().as_millis());
                // if !img.has_alpha() {
                    let img = Image {
                        pixels: img.0.as_slice(),
                        width: img.1 as usize,
                        height: img.2 as usize,
                        pitch: img.1 as usize * 3,
                        format: turbojpeg::PixelFormat::RGB
                    };
                    start =  Instant::now();
                    let mut compressor = turbojpeg::Compressor::new().unwrap();
                    compressor.set_quality(100).unwrap();
                    compressor.set_subsamp(turbojpeg::Subsamp::Sub2x2).unwrap();
                    compressor.set_optimize(true).unwrap();
                    godot_print!("Setting up compressor: {}ms", start.elapsed().as_millis());
                    start = Instant::now();
                    bytes = compressor.compress_to_vec(img).unwrap();
                    format_str = "jpeg";
                // } else {
                //     let rgb_img = img.to_rgba8();
                //     let encoder = Encoder::new_rgba(rgb_img.as_raw(), rgb_img.width(), rgb_img.height());
                //     bytes = encoder.quality(90.0).method(0).encode(Unstoppable).unwrap();
                //     format_str = "webp"
                // }
                godot_print!("Encode image: {}ms", start.elapsed().as_millis());
            },
            _ => {return Err("Unsupported Image format".to_owned());}
        }


        Ok((bytes, format_str))
    }
}

#[derive(GodotClass)]
#[class(init, base=RefCounted)]
pub struct PdfUtil {
    base: Base<RefCounted>
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
    base: Base<RefCounted>
}

#[godot_api]
pub impl PdfInfo {
    #[func]
    fn new(sizes: Array<Vector2i>, count: i64, error: GString) -> Gd<PdfInfo> {
        Gd::from_init_fn(|base| Self {
            base,
            sizes,
            count,
            error
        })
    }
}

#[godot_api]
impl PdfUtil {
    #[func]
    pub fn get_pdf_info(path: String) -> Gd<PdfInfo> {
        let page_infos = (|| -> Result<(i64, Vec<Vector2i>), String> {
            let pdfium = render_engine::get_pdfium()?;

            let document = pdfium
                .load_pdf_from_file(&path, None)
                .map_err(|e| e.to_string())?;

            let page_count = document.pages().len();
            let page_sizes: Vec<Vector2i> = document
                .pages()
                .iter()
                .map(|p| {
                    Vector2i::new(
                        (p.width().to_inches() * 300.0) as i32,
                        (p.height().to_inches() * 300.0) as i32,
                    )
                })
                .collect();
            Ok((page_count as i64, page_sizes))
        })();

        match page_infos {
            Ok((count, sizes)) => PdfInfo::new(
                sizes.to_godot(),
                count,
                GString::new()
            ),
            Err(error) => PdfInfo::new(
                Variant::nil().to(),
                Variant::nil().to(),
                GString::from(&error)
            )
        }
    }
}
