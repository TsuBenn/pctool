use std::collections::{HashMap, VecDeque};
use std::fs::{self, File};
use std::hash::Hash;
use std::io::{BufWriter, Write};
use std::path::{Path, PathBuf};
use std::sync::{
    atomic::{AtomicBool, AtomicU8, AtomicUsize, Ordering},
    mpsc, Arc, Mutex,
};
use std::thread;

use flate2::{write::ZlibEncoder, Compression};
use godot::{global::Error, prelude::*};
use image::{imageops::FilterType, Rgba, RgbaImage};
use lopdf::{
    content::{Content, Operation},
    Document, Object, ObjectId,
};
use rayon::prelude::*;

const MM_TO_PT: f32 = 72.0 / 25.4;
const MM_PER_INCH: f32 = 25.4;

// Hard RAM budgets for decoded source images and parsed source PDFs
const MAX_IMAGE_CACHE_BYTES: usize = 256 * 1024 * 1024; // 256 MB
const MAX_PDF_CACHE_BYTES: usize = 128 * 1024 * 1024;   // 128 MB

// Export status codes for GDScript polling
const STATUS_IDLE: u8 = 0;
const STATUS_RUNNING: u8 = 1;
const STATUS_DONE: u8 = 2;
const STATUS_FAILED: u8 = 3;
const STATUS_CANCELLED: u8 = 4;

// Process-wide lock to prevent concurrent exports from doubling RAM budgets
static GLOBAL_EXPORT_ACTIVE: AtomicBool = AtomicBool::new(false);

struct ExportLockGuard;
impl Drop for ExportLockGuard {
    fn drop(&mut self) {
        GLOBAL_EXPORT_ACTIVE.store(false, Ordering::SeqCst);
    }
}

struct Asset {
    source_path: String,
    is_pdf: bool,
}

#[derive(Clone, Copy, Debug)]
struct PerspectivePins {
    enabled: bool,
    corners: [Vector2; 4], // [Top-Left, Top-Right, Bottom-Right, Bottom-Left] in [0..1] UV space
}

impl Default for PerspectivePins {
    fn default() -> Self {
        Self {
            enabled: false,
            corners: [
                Vector2::new(0.0, 0.0),
                Vector2::new(1.0, 0.0),
                Vector2::new(1.0, 1.0),
                Vector2::new(0.0, 1.0),
            ],
        }
    }
}

#[derive(Clone)]
struct TileData {
    asset_id: String,
    index: i64, // 0-based PDF page index (always 0 for images)
    frame_rect_mm: Rect2,
    asset_rect_mm: Rect2, // Relative to frame_rect_mm's top-left
    border_width_mm: f32,
    border_color: Color,
    perspective: PerspectivePins,
}

struct Payloads {
    paper_size_mm: Vector2,
    dpi: i64,
    assets: HashMap<String, Asset>,
    pages: Vec<Vec<TileData>>,
}

#[derive(GodotClass)]
#[class(init, base=RefCounted)]
struct RsExportEngine {
    payloads: Option<Payloads>,
    thread_limit: usize, // 0 = use 100% of available hardware threads
    ticks_done: Arc<AtomicUsize>,
    total_ticks: Arc<AtomicUsize>,
    status: Arc<AtomicU8>,
    cancel_flag: Arc<AtomicBool>,
    base: Base<RefCounted>,
}

#[godot_api]
impl RsExportEngine {
    #[func]
    fn new_engine(paper_size_mm: Vector2, dpi: i64) -> Gd<Self> {
        Gd::from_init_fn(|base| Self {
            payloads: Some(Payloads {
                paper_size_mm,
                dpi,
                assets: HashMap::new(),
                pages: Vec::new(),
            }),
            thread_limit: 0, // Default: 100% max CPU cores
            ticks_done: Arc::new(AtomicUsize::new(0)),
            total_ticks: Arc::new(AtomicUsize::new(0)),
            status: Arc::new(AtomicU8::new(STATUS_IDLE)),
            cancel_flag: Arc::new(AtomicBool::new(false)),
            base,
        })
    }

    /// Adjusts worker thread count:
    /// `<= 0` uses 100% of logical CPU cores; `>= 1` caps workers to that exact count.
    #[func]
    fn set_thread_count(&mut self, threads: i64) {
        if threads <= 0 {
            self.thread_limit = 0;
        } else {
            let max_hw = thread::available_parallelism()
                .map(|n| n.get())
                .unwrap_or(4);
            self.thread_limit = (threads as usize).min(max_hw).max(1);
        }
    }

    /// Returns the number of logical hardware threads detected on this machine.
    #[func]
    fn get_max_hardware_threads(&self) -> i64 {
        thread::available_parallelism()
            .map(|n| n.get() as i64)
            .unwrap_or(4)
    }

    #[func]
    fn add_asset(&mut self, asset_id: String, source_path: String, is_pdf: bool) -> bool {
        if let Some(payloads) = &mut self.payloads {
            payloads.assets.insert(
                asset_id,
                Asset {
                    source_path,
                    is_pdf,
                },
            );
            true
        } else {
            godot_error!("No payload initialized! (add_asset)");
            false
        }
    }

    #[func]
    fn add_tile(
        &mut self,
        asset_id: String,
        frame_rect_mm: Rect2,
        asset_rect_mm: Rect2,
        index: i64,
        page_index: i64,
        border_width_mm: f32,
        border_color: Color,
    ) -> bool {
        if let Some(payloads) = &mut self.payloads {
            let idx = page_index as usize;
            if payloads.pages.len() <= idx {
                payloads.pages.resize_with(idx + 1, Vec::new);
            }
            payloads.pages[idx].push(TileData {
                asset_id,
                frame_rect_mm,
                asset_rect_mm,
                index,
                border_width_mm,
                border_color,
                perspective: PerspectivePins::default(),
            });
            true
        } else {
            godot_error!("No payload initialized! (add_tile)");
            false
        }
    }

    #[func]
    fn set_last_tile_perspective(
        &mut self,
        page_index: i64,
        p0: Vector2,
        p1: Vector2,
        p2: Vector2,
        p3: Vector2,
    ) -> bool {
        let Some(payloads) = &mut self.payloads else {
            godot_error!("No payload initialized! (set_last_tile_perspective)");
            return false;
        };
        let Some(page) = payloads.pages.get_mut(page_index as usize) else {
            godot_error!("Invalid page_index {} (set_last_tile_perspective)", page_index);
            return false;
        };
        let Some(last_tile) = page.last_mut() else {
            godot_error!("No tile found on page {} (set_last_tile_perspective)", page_index);
            return false;
        };

        last_tile.perspective = PerspectivePins {
            enabled: true,
            corners: [p0, p1, p2, p3],
        };
        true
    }

    /// Starts continuous cross-page multi-threaded PDF export asynchronously.
    #[func]
    fn export_as_pdf(&mut self, output_path: String) -> Error {
        if self.status.load(Ordering::Acquire) == STATUS_RUNNING {
            godot_error!("Export is already running on this engine!");
            return Error::ERR_BUSY;
        }

        if GLOBAL_EXPORT_ACTIVE
            .compare_exchange(false, true, Ordering::SeqCst, Ordering::SeqCst)
            .is_err()
        {
            godot_error!("Another export is already in progress!");
            return Error::ERR_BUSY;
        }

        let Some(payloads) = self.payloads.take() else {
            GLOBAL_EXPORT_ACTIVE.store(false, Ordering::SeqCst);
            godot_error!("No payload initialized or already exported! (export_as_pdf)");
            return Error::ERR_UNCONFIGURED;
        };

        if payloads.pages.is_empty() {
            GLOBAL_EXPORT_ACTIVE.store(false, Ordering::SeqCst);
            godot_error!("Cannot export a 0-page PDF.");
            self.payloads = Some(payloads);
            return Error::ERR_INVALID_DATA;
        }

        let tile_count: usize = payloads.pages.iter().map(|p| p.len()).sum();
        self.total_ticks.store((tile_count * 3).max(1), Ordering::Release);
        self.ticks_done.store(0, Ordering::Release);
        self.cancel_flag.store(false, Ordering::Release);
        self.status.store(STATUS_RUNNING, Ordering::Release);

        let max_hw = thread::available_parallelism()
            .map(|n| n.get())
            .unwrap_or(4);
        let num_threads = if self.thread_limit == 0 {
            max_hw
        } else {
            self.thread_limit.min(max_hw).max(1)
        };

        let ticks_counter = Arc::clone(&self.ticks_done);
        let status_flag = Arc::clone(&self.status);
        let cancel_flag = Arc::clone(&self.cancel_flag);

        thread::spawn(move || {
            let _lock_guard = ExportLockGuard;
            let path = Path::new(&output_path);

            let export_result = run_pipelined_pdf_export(
                &payloads,
                path,
                num_threads,
                &ticks_counter,
                &cancel_flag,
            );

            match export_result {
                Ok(()) => {
                    status_flag.store(STATUS_DONE, Ordering::Release);
                }
                Err(_) if cancel_flag.load(Ordering::Acquire) => {
                    let _ = fs::remove_file(path);
                    status_flag.store(STATUS_CANCELLED, Ordering::Release);
                }
                Err(e) => {
                    let _ = fs::remove_file(path);
                    godot_error!("Output path: {}", output_path);
                    godot_error!("PDF export failed: {}", e);
                    status_flag.store(STATUS_FAILED, Ordering::Release);
                }
            }
        });

        Error::OK
    }

    #[func]
    fn cancel_export(&self) {
        self.cancel_flag.store(true, Ordering::Release);
    }

    #[func]
    fn get_progress(&self) -> f32 {
        let total = self.total_ticks.load(Ordering::Acquire);
        if total == 0 {
            return 0.0;
        }
        let done = self.ticks_done.load(Ordering::Acquire);
        (done as f32 / total as f32).clamp(0.0, 1.0)
    }

    /// 0 = Idle, 1 = Running, 2 = Done, 3 = Failed, 4 = Cancelled
    #[func]
    fn get_status(&self) -> i64 {
        self.status.load(Ordering::Acquire) as i64
    }

    #[func]
    fn export_as_png(&self, _output_path: String) -> Error {
        Error::OK
    }
}

// ============================================================================
// Thread-Safe Byte-Budgeted LRU Cache
// ============================================================================

struct ByteBudgetCache<K, V> {
    map: HashMap<K, (V, usize)>,
    order: VecDeque<K>,
    current_bytes: usize,
    max_bytes: usize,
}

impl<K: Eq + Hash + Clone, V> ByteBudgetCache<K, V> {
    fn new(max_bytes: usize) -> Self {
        Self {
            map: HashMap::new(),
            order: VecDeque::new(),
            current_bytes: 0,
            max_bytes,
        }
    }

    fn get_cloned(&mut self, key: &K) -> Option<V>
    where
        V: Clone,
    {
        if self.map.contains_key(key) {
            if let Some(pos) = self.order.iter().position(|k| k == key) {
                if let Some(k) = self.order.remove(pos) {
                    self.order.push_back(k);
                }
            }
            return self.map.get(key).map(|(v, _)| v.clone());
        }
        None
    }

    fn insert(&mut self, key: K, value: V, size_bytes: usize) {
        if let Some((_, old_size)) = self.map.remove(&key) {
            self.current_bytes = self.current_bytes.saturating_sub(old_size);
            if let Some(pos) = self.order.iter().position(|k| k == &key) {
                self.order.remove(pos);
            }
        }

        while self.current_bytes + size_bytes > self.max_bytes && !self.order.is_empty() {
            if let Some(oldest_key) = self.order.pop_front() {
                if let Some((_, evicted_size)) = self.map.remove(&oldest_key) {
                    self.current_bytes = self.current_bytes.saturating_sub(evicted_size);
                }
            }
        }

        self.current_bytes += size_bytes;
        self.order.push_back(key.clone());
        self.map.insert(key, (value, size_bytes));
    }
}

// ============================================================================
// Streaming PDF Writer
// ============================================================================

struct StreamingPdf {
    writer: BufWriter<File>,
    offsets: Vec<u64>,
    bytes_written: u64,
}

impl StreamingPdf {
    fn create(out_path: &Path) -> Result<Self, String> {
        if let Some(parent) = out_path.parent() {
            if !parent.as_os_str().is_empty() {
                fs::create_dir_all(parent).map_err(|e| e.to_string())?;
            }
        }

        let file = File::create(out_path).map_err(|e| e.to_string())?;
        let mut pdf = Self {
            writer: BufWriter::with_capacity(512 * 1024, file),
            offsets: Vec::new(),
            bytes_written: 0,
        };

        pdf.write_raw(b"%PDF-1.7\n%\xE2\xE3\xCF\xD3\n")?;
        Ok(pdf)
    }

    #[inline]
    fn write_raw(&mut self, data: &[u8]) -> Result<(), String> {
        self.writer.write_all(data).map_err(|e| e.to_string())?;
        self.bytes_written += data.len() as u64;
        Ok(())
    }

    fn reserve_id(&mut self) -> u32 {
        self.offsets.push(0);
        self.offsets.len() as u32
    }

    fn write_object(&mut self, id: u32, body: &[u8]) -> Result<(), String> {
        self.offsets[(id - 1) as usize] = self.bytes_written;
        self.write_raw(format!("{} 0 obj\n", id).as_bytes())?;
        self.write_raw(body)?;
        self.write_raw(b"\nendobj\n")
    }

    fn write_stream(
        &mut self,
        id: u32,
        dict_entries: &str,
        stream_bytes: &[u8],
    ) -> Result<(), String> {
        self.offsets[(id - 1) as usize] = self.bytes_written;
        let header = format!(
            "{} 0 obj\n<< {} /Length {} >>\nstream\n",
            id,
            dict_entries,
            stream_bytes.len()
        );
        self.write_raw(header.as_bytes())?;
        self.write_raw(stream_bytes)?;
        self.write_raw(b"\nendstream\nendobj\n")
    }

    fn finish(mut self, catalog_id: u32) -> Result<(), String> {
        let xref_offset = self.bytes_written;
        let obj_count = self.offsets.len() + 1;

        self.write_raw(format!("xref\n0 {}\n", obj_count).as_bytes())?;
        self.write_raw(b"0000000000 65535 f \n")?;
        for offset in std::mem::take(&mut self.offsets) {
            self.write_raw(format!("{:010} 00000 n \n", offset).as_bytes())?;
        }

        let trailer = format!(
            "trailer\n<< /Size {} /Root {} 0 R >>\nstartxref\n{}\n%%EOF\n",
            obj_count, catalog_id, xref_offset
        );
        self.write_raw(trailer.as_bytes())?;
        self.writer.flush().map_err(|e| e.to_string())
    }
}

// ============================================================================
// Continuous Cross-Page Producer-Consumer Pipeline
// ============================================================================

struct PreparedImageTile {
    width: u32,
    height: u32,
    compressed_rgb: Vec<u8>,
    compressed_alpha: Option<Vec<u8>>,
    draw_rect_mm: Rect2,
}

struct CompletedTilePacket {
    page_idx: usize,
    tile_idx: usize,
    prepared_img: Option<PreparedImageTile>,
}

fn run_pipelined_pdf_export(
    payloads: &Payloads,
    out_path: &Path,
    num_threads: usize,
    ticks_done: &AtomicUsize,
    cancel_flag: &AtomicBool,
) -> Result<(), String> {
    let pool = rayon::ThreadPoolBuilder::new()
        .num_threads(num_threads)
        .thread_name(|idx| format!("pdf-worker-{}", idx))
        .build()
        .map_err(|e| format!("Failed to build Rayon thread pool: {}", e))?;

    // Flatten ALL image tiles across ALL pages into one global task list so workers
    // never pause at page boundaries.
    let mut image_tasks: Vec<(usize, usize, &TileData)> = Vec::new();
    for (page_idx, tiles) in payloads.pages.iter().enumerate() {
        for (tile_idx, tile) in tiles.iter().enumerate() {
            if let Some(asset) = payloads.assets.get(&tile.asset_id) {
                if !asset.is_pdf {
                    image_tasks.push((page_idx, tile_idx, tile));
                }
            }
        }
    }

    // If the entire export has very few image tiles, let each tile split rows across cores
    let parallelize_rows = image_tasks.len() < num_threads;

    // Bounded channel caps in-flight compressed tiles in RAM to `num_threads * 2`
    let (tx, rx) = mpsc::sync_channel::<Result<CompletedTilePacket, String>>(num_threads * 2);

    let image_cache: Mutex<ByteBudgetCache<String, Arc<RgbaImage>>> =
        Mutex::new(ByteBudgetCache::new(MAX_IMAGE_CACHE_BYTES));
    let decode_locks: Mutex<HashMap<String, Arc<Mutex<()>>>> = Mutex::new(HashMap::new());

    // Run Rayon producer pool and sequential disk writer concurrently via `std::thread::scope`
    thread::scope(|s| {
        // PRODUCER: Saturates all `num_threads` cores continuously across all pages
        s.spawn(|| {
            pool.install(|| {
                image_tasks.par_iter().for_each_with(tx, |sender, &(page_idx, tile_idx, tile)| {
                    if cancel_flag.load(Ordering::Acquire) {
                        return;
                    }

                    let Some(asset) = payloads.assets.get(&tile.asset_id) else {
                        ticks_done.fetch_add(2, Ordering::Relaxed);
                        let _ = sender.send(Ok(CompletedTilePacket {
                            page_idx,
                            tile_idx,
                            prepared_img: None,
                        }));
                        return;
                    };

                    let src_rgba = match get_or_decode_image(
                        &tile.asset_id,
                        Path::new(&asset.source_path),
                        &image_cache,
                        &decode_locks,
                    ) {
                        Ok(img) => img,
                        Err(e) => {
                            let _ = sender.send(Err(e));
                            return;
                        }
                    };
                    ticks_done.fetch_add(1, Ordering::Relaxed);

                    if cancel_flag.load(Ordering::Acquire) {
                        return;
                    }

                    let Some((processed_rgba, draw_rect_mm)) = process_tile_image(
                        &src_rgba,
                        tile,
                        payloads.dpi,
                        parallelize_rows,
                        cancel_flag,
                    ) else {
                        ticks_done.fetch_add(1, Ordering::Relaxed);
                        let _ = sender.send(Ok(CompletedTilePacket {
                            page_idx,
                            tile_idx,
                            prepared_img: None,
                        }));
                        return;
                    };
                    drop(src_rgba);

                    match compress_rgba_tile(&processed_rgba, draw_rect_mm) {
                        Ok(prepared) => {
                            ticks_done.fetch_add(1, Ordering::Relaxed);
                            let _ = sender.send(Ok(CompletedTilePacket {
                                page_idx,
                                tile_idx,
                                prepared_img: Some(prepared),
                            }));
                        }
                        Err(e) => {
                            let _ = sender.send(Err(e));
                        }
                    }
                });
            });
        });

        // CONSUMER: Receives completed tiles, reorders per page, and flushes straight to disk
        let mut pdf = StreamingPdf::create(out_path)?;
        let pages_id = pdf.reserve_id();

        let page_w_pt = payloads.paper_size_mm.x * MM_TO_PT;
        let page_h_pt = payloads.paper_size_mm.y * MM_TO_PT;

        let mut pdf_doc_cache: ByteBudgetCache<PathBuf, Document> =
            ByteBudgetCache::new(MAX_PDF_CACHE_BYTES);
        let mut streamed_pdf_forms: HashMap<(String, i64), (u32, [f32; 4])> = HashMap::new();

        // Buffer out-of-order completed tiles indexed by `(page_idx, tile_idx)`
        let mut ready_tiles: HashMap<(usize, usize), Option<PreparedImageTile>> = HashMap::new();
        let mut channel_closed = false;

        let mut page_ids = Vec::with_capacity(payloads.pages.len());

        for (page_idx, tiles) in payloads.pages.iter().enumerate() {
            if cancel_flag.load(Ordering::Acquire) {
                return Err("Export cancelled by user".to_string());
            }

            let mut ops: Vec<Operation> = Vec::new();
            let mut xobject_refs: Vec<String> = Vec::new();

            for (tile_idx, tile) in tiles.iter().enumerate() {
                if cancel_flag.load(Ordering::Acquire) {
                    return Err("Export cancelled by user".to_string());
                }

                let Some(asset) = payloads.assets.get(&tile.asset_id) else {
                    ticks_done.fetch_add(3, Ordering::Relaxed);
                    continue;
                };

                let res_name = format!("X{}", tile_idx);
                let frame_x = tile.frame_rect_mm.position.x * MM_TO_PT;
                let frame_w = tile.frame_rect_mm.size.x * MM_TO_PT;
                let frame_h = tile.frame_rect_mm.size.y * MM_TO_PT;
                let frame_y = page_h_pt - (tile.frame_rect_mm.position.y * MM_TO_PT) - frame_h;

                if asset.is_pdf {
                    let key = (tile.asset_id.clone(), tile.index);
                    if !streamed_pdf_forms.contains_key(&key) {
                        let path = PathBuf::from(&asset.source_path);
                        if pdf_doc_cache.get_cloned(&path).is_none() {
                            let file_size = fs::metadata(&path).map(|m| m.len() as usize).unwrap_or(0);
                            let doc = Document::load(&path)
                                .map_err(|e| format!("Failed to load PDF '{:?}': {}", path, e))?;
                            pdf_doc_cache.insert(path.clone(), doc, file_size.saturating_mul(2));
                        }

                        let src_doc = pdf_doc_cache.get_cloned(&path).unwrap();
                        let pdf_page_num = (tile.index.max(0) as u32) + 1;
                        let form_data = stream_pdf_page(&mut pdf, &src_doc, pdf_page_num)?;
                        streamed_pdf_forms.insert(key.clone(), form_data);
                    }
                    ticks_done.fetch_add(2, Ordering::Relaxed);

                    let (form_id, bbox) = streamed_pdf_forms[&key];

                    let abs_asset_x_mm = tile.frame_rect_mm.position.x + tile.asset_rect_mm.position.x;
                    let abs_asset_y_mm = tile.frame_rect_mm.position.y + tile.asset_rect_mm.position.y;
                    let asset_x = abs_asset_x_mm * MM_TO_PT;
                    let asset_w = tile.asset_rect_mm.size.x * MM_TO_PT;
                    let asset_h = tile.asset_rect_mm.size.y * MM_TO_PT;
                    let asset_y = page_h_pt - (abs_asset_y_mm * MM_TO_PT) - asset_h;

                    let orig_w = (bbox[2] - bbox[0]).max(0.001);
                    let orig_h = (bbox[3] - bbox[1]).max(0.001);
                    let sx = asset_w / orig_w;
                    let sy = asset_h / orig_h;
                    let tx = asset_x - (bbox[0] * sx);
                    let ty = asset_y - (bbox[1] * sy);

                    ops.push(Operation::new("q", vec![]));
                    ops.push(Operation::new(
                        "re",
                        vec![frame_x.into(), frame_y.into(), frame_w.into(), frame_h.into()],
                    ));
                    ops.push(Operation::new("W", vec![]));
                    ops.push(Operation::new("n", vec![]));
                    ops.push(Operation::new(
                        "cm",
                        vec![sx.into(), 0.into(), 0.into(), sy.into(), tx.into(), ty.into()],
                    ));
                    ops.push(Operation::new(
                        "Do",
                        vec![Object::Name(res_name.as_bytes().to_vec())],
                    ));
                    ops.push(Operation::new("Q", vec![]));

                    xobject_refs.push(format!("/{} {} 0 R", res_name, form_id));
                } else {
                    // Wait until `(page_idx, tile_idx)` arrives from the Rayon workers
                    while !ready_tiles.contains_key(&(page_idx, tile_idx)) {
                        if cancel_flag.load(Ordering::Acquire) {
                            return Err("Export cancelled by user".to_string());
                        }
                        if channel_closed {
                            return Err("Worker channel closed unexpectedly".to_string());
                        }
                        match rx.recv() {
                            Ok(Ok(pkt)) => {
                                ready_tiles.insert((pkt.page_idx, pkt.tile_idx), pkt.prepared_img);
                            }
                            Ok(Err(err_msg)) => return Err(err_msg),
                            Err(_) => {
                                channel_closed = true;
                            }
                        }
                    }

                    let Some(prepared) = ready_tiles.remove(&(page_idx, tile_idx)).flatten() else {
                        ticks_done.fetch_add(1, Ordering::Relaxed);
                        continue;
                    };

                    let draw_rect_mm = prepared.draw_rect_mm;
                    let img_obj_id = write_prepared_image(&mut pdf, prepared)?;

                    let draw_x = draw_rect_mm.position.x * MM_TO_PT;
                    let draw_w = draw_rect_mm.size.x * MM_TO_PT;
                    let draw_h = draw_rect_mm.size.y * MM_TO_PT;
                    let draw_y = page_h_pt - (draw_rect_mm.position.y * MM_TO_PT) - draw_h;

                    ops.push(Operation::new("q", vec![]));
                    ops.push(Operation::new(
                        "cm",
                        vec![
                            draw_w.into(),
                            0.into(),
                            0.into(),
                            draw_h.into(),
                            draw_x.into(),
                            draw_y.into(),
                        ],
                    ));
                    ops.push(Operation::new(
                        "Do",
                        vec![Object::Name(res_name.as_bytes().to_vec())],
                    ));
                    ops.push(Operation::new("Q", vec![]));

                    xobject_refs.push(format!("/{} {} 0 R", res_name, img_obj_id));
                }

                if tile.border_width_mm > 0.0 {
                    let bw = tile.border_width_mm * MM_TO_PT;
                    let half_bw = bw * 0.5;
                    ops.push(Operation::new("q", vec![]));
                    ops.push(Operation::new("w", vec![bw.into()]));
                    ops.push(Operation::new(
                        "RG",
                        vec![
                            tile.border_color.r.into(),
                            tile.border_color.g.into(),
                            tile.border_color.b.into(),
                        ],
                    ));
                    ops.push(Operation::new(
                        "re",
                        vec![
                            (frame_x + half_bw).into(),
                            (frame_y + half_bw).into(),
                            (frame_w - bw).max(0.0).into(),
                            (frame_h - bw).max(0.0).into(),
                        ],
                    ));
                    ops.push(Operation::new("S", vec![]));
                    ops.push(Operation::new("Q", vec![]));
                }

                ticks_done.fetch_add(1, Ordering::Relaxed);
            }

            let content_bytes = Content { operations: ops }
                .encode()
                .map_err(|e| e.to_string())?;
            let mut content_enc = ZlibEncoder::new(Vec::new(), Compression::fast());
            content_enc
                .write_all(&content_bytes)
                .map_err(|e| e.to_string())?;
            let compressed_content = content_enc.finish().map_err(|e| e.to_string())?;

            let content_id = pdf.reserve_id();
            pdf.write_stream(content_id, "/Filter /FlateDecode", &compressed_content)?;

            let page_id = pdf.reserve_id();
            let page_dict = format!(
                "<< /Type /Page /Parent {} 0 R /MediaBox [0 0 {:.4} {:.4}] /Contents {} 0 R /Resources << /XObject << {} >> >> >>",
                pages_id,
                page_w_pt,
                page_h_pt,
                content_id,
                xobject_refs.join(" ")
            );
            pdf.write_object(page_id, page_dict.as_bytes())?;
            page_ids.push(page_id);
        }

        let kids_str: String = page_ids
            .iter()
            .map(|id| format!("{} 0 R", id))
            .collect::<Vec<_>>()
            .join(" ");
        let pages_dict = format!(
            "<< /Type /Pages /Kids [ {} ] /Count {} >>",
            kids_str,
            page_ids.len()
        );
        pdf.write_object(pages_id, pages_dict.as_bytes())?;

        let catalog_id = pdf.reserve_id();
        let catalog_dict = format!("<< /Type /Catalog /Pages {} 0 R >>", pages_id);
        pdf.write_object(catalog_id, catalog_dict.as_bytes())?;

        pdf.finish(catalog_id)
    })
}

// ============================================================================
// Image Loading, Parallel Processing, & Fast Channel Compression
// ============================================================================

fn get_or_decode_image(
    asset_id: &str,
    path: &Path,
    cache: &Mutex<ByteBudgetCache<String, Arc<RgbaImage>>>,
    decode_locks: &Mutex<HashMap<String, Arc<Mutex<()>>>>,
) -> Result<Arc<RgbaImage>, String> {
    if let Some(img) = cache.lock().unwrap().get_cloned(&asset_id.to_string()) {
        return Ok(img);
    }

    let asset_lock = {
        let mut locks = decode_locks.lock().unwrap();
        Arc::clone(
            locks
                .entry(asset_id.to_string())
                .or_insert_with(|| Arc::new(Mutex::new(()))),
        )
    };
    let _guard = asset_lock.lock().unwrap();

    if let Some(img) = cache.lock().unwrap().get_cloned(&asset_id.to_string()) {
        return Ok(img);
    }

    let raw_bytes =
        fs::read(path).map_err(|e| format!("Failed to read image '{:?}': {}", path, e))?;
    let format = image::guess_format(&raw_bytes).map_err(|e| e.to_string())?;
    let img = image::load_from_memory_with_format(&raw_bytes, format).map_err(|e| e.to_string())?;
    drop(raw_bytes);

    let rgba = Arc::new(img.to_rgba8());
    let byte_size = (rgba.width() as usize) * (rgba.height() as usize) * 4;
    cache
        .lock()
        .unwrap()
        .insert(asset_id.to_string(), Arc::clone(&rgba), byte_size);

    Ok(rgba)
}

fn process_tile_image(
    src_rgba: &RgbaImage,
    tile: &TileData,
    dpi: i64,
    parallelize_rows: bool,
    cancel_flag: &AtomicBool,
) -> Option<(RgbaImage, Rect2)> {
    let (img_w_px, img_h_px) = src_rgba.dimensions();
    if img_w_px == 0 || img_h_px == 0 {
        return None;
    }

    let frame_x0 = tile.frame_rect_mm.position.x;
    let frame_y0 = tile.frame_rect_mm.position.y;
    let frame_x1 = frame_x0 + tile.frame_rect_mm.size.x;
    let frame_y1 = frame_y0 + tile.frame_rect_mm.size.y;

    let asset_x0 = frame_x0 + tile.asset_rect_mm.position.x;
    let asset_y0 = frame_y0 + tile.asset_rect_mm.position.y;
    let asset_w_mm = tile.asset_rect_mm.size.x;
    let asset_h_mm = tile.asset_rect_mm.size.y;
    let asset_x1 = asset_x0 + asset_w_mm;
    let asset_y1 = asset_y0 + asset_h_mm;

    if asset_w_mm <= 0.0 || asset_h_mm <= 0.0 {
        return None;
    }

    let vis_x0 = frame_x0.max(asset_x0);
    let vis_y0 = frame_y0.max(asset_y0);
    let vis_x1 = frame_x1.min(asset_x1);
    let vis_y1 = frame_y1.min(asset_y1);

    if vis_x1 <= vis_x0 || vis_y1 <= vis_y0 {
        return None;
    }

    let draw_rect_mm = Rect2::new(
        Vector2::new(vis_x0, vis_y0),
        Vector2::new(vis_x1 - vis_x0, vis_y1 - vis_y0),
    );

    let target_dpi = dpi.clamp(72, 600) as f32;
    let target_w = ((draw_rect_mm.size.x / MM_PER_INCH) * target_dpi)
        .round()
        .max(1.0) as u32;
    let target_h = ((draw_rect_mm.size.y / MM_PER_INCH) * target_dpi)
        .round()
        .max(1.0) as u32;

    if tile.perspective.enabled {
        let u_min = (vis_x0 - asset_x0) / asset_w_mm;
        let u_max = (vis_x1 - asset_x0) / asset_w_mm;
        let v_min = (vis_y0 - asset_y0) / asset_h_mm;
        let v_max = (vis_y1 - asset_y0) / asset_h_mm;

        let processed = dewarp_visible_region(
            src_rgba,
            tile.perspective.corners,
            target_w,
            target_h,
            (u_min, u_max),
            (v_min, v_max),
            parallelize_rows,
            cancel_flag,
        )?;

        return Some((processed, draw_rect_mm));
    }

    let px_per_mm_x = img_w_px as f32 / asset_w_mm;
    let px_per_mm_y = img_h_px as f32 / asset_h_mm;

    let crop_x = ((vis_x0 - asset_x0) * px_per_mm_x).floor().max(0.0) as u32;
    let crop_y = ((vis_y0 - asset_y0) * px_per_mm_y).floor().max(0.0) as u32;
    let crop_w = ((vis_x1 - vis_x0) * px_per_mm_x)
        .ceil()
        .max(1.0)
        .min((img_w_px - crop_x) as f32) as u32;
    let crop_h = ((vis_y1 - vis_y0) * px_per_mm_y)
        .ceil()
        .max(1.0)
        .min((img_h_px - crop_y) as f32) as u32;

    let cropped = image::imageops::crop_imm(src_rgba, crop_x, crop_y, crop_w, crop_h).to_image();

    let processed = if crop_w > target_w || crop_h > target_h {
        image::imageops::resize(
            &cropped,
            target_w.min(crop_w),
            target_h.min(crop_h),
            FilterType::Triangle,
        )
    } else {
        cropped
    };

    Some((processed, draw_rect_mm))
}

fn compute_homography_cols(p: [Vector2; 4]) -> [[f32; 3]; 3] {
    let [p0, p1, p2, p3] = p;

    let dx1 = p1.x - p2.x;
    let dx2 = p3.x - p2.x;
    let dx3 = p0.x - p1.x + p2.x - p3.x;

    let dy1 = p1.y - p2.y;
    let dy2 = p3.y - p2.y;
    let dy3 = p0.y - p1.y + p2.y - p3.y;

    if dx3.abs() < 0.0001 && dy3.abs() < 0.0001 {
        return [
            [p1.x - p0.x, p1.y - p0.y, 0.0],
            [p2.x - p1.x, p2.y - p1.y, 0.0],
            [p0.x, p0.y, 1.0],
        ];
    }

    let det = (dx1 * dy2) - (dx2 * dy1);
    if det.abs() < 0.00001 {
        return [[1.0, 0.0, 0.0], [0.0, 1.0, 0.0], [0.0, 0.0, 1.0]];
    }

    let g = ((dx3 * dy2) - (dx2 * dy3)) / det;
    let h = ((dx1 * dy3) - (dx3 * dy1)) / det;

    let a = p1.x - p0.x + (g * p1.x);
    let b = p3.x - p0.x + (h * p3.x);
    let c = p0.x;

    let d = p1.y - p0.y + (g * p1.y);
    let e = p3.y - p0.y + (h * p3.y);
    let f = p0.y;

    [[a, d, g], [b, e, h], [c, f, 1.0]]
}

#[inline]
fn sample_bilinear(img: &RgbaImage, u: f32, v: f32) -> Rgba<u8> {
    let (w, h) = img.dimensions();
    let x = (u * (w as f32 - 1.0)).clamp(0.0, w as f32 - 1.0);
    let y = (v * (h as f32 - 1.0)).clamp(0.0, h as f32 - 1.0);

    let x0 = x.floor() as u32;
    let y0 = y.floor() as u32;
    let x1 = (x0 + 1).min(w - 1);
    let y1 = (y0 + 1).min(h - 1);

    let fx = x - x0 as f32;
    let fy = y - y0 as f32;
    let inv_fx = 1.0 - fx;
    let inv_fy = 1.0 - fy;

    let p00 = img.get_pixel(x0, y0).0;
    let p10 = img.get_pixel(x1, y0).0;
    let p01 = img.get_pixel(x0, y1).0;
    let p11 = img.get_pixel(x1, y1).0;

    let w00 = inv_fx * inv_fy;
    let w10 = fx * inv_fy;
    let w01 = inv_fx * fy;
    let w11 = fx * fy;

    let mut out = [0u8; 4];
    for c in 0..4 {
        let val = p00[c] as f32 * w00
            + p10[c] as f32 * w10
            + p01[c] as f32 * w01
            + p11[c] as f32 * w11;
        out[c] = val.round().clamp(0.0, 255.0) as u8;
    }
    Rgba(out)
}

fn dewarp_visible_region(
    rgba: &RgbaImage,
    pins: [Vector2; 4],
    out_w: u32,
    out_h: u32,
    u_range: (f32, f32),
    v_range: (f32, f32),
    parallelize_rows: bool,
    cancel_flag: &AtomicBool,
) -> Option<RgbaImage> {
    let cols = compute_homography_cols(pins);
    let mut raw_buf = vec![0u8; (out_w as usize) * (out_h as usize) * 4];
    let row_stride = (out_w as usize) * 4;

    let u_span = u_range.1 - u_range.0;
    let v_span = v_range.1 - v_range.0;
    let inv_w = 1.0 / (out_w as f32);
    let inv_h = 1.0 / (out_h as f32);

    let process_row = |(py, row_bytes): (usize, &mut [u8])| {
        if py & 31 == 0 && cancel_flag.load(Ordering::Relaxed) {
            return;
        }

        let dest_v = v_range.0 + ((py as f32 + 0.5) * inv_h) * v_span;
        for px in 0..out_w as usize {
            let dest_u = u_range.0 + ((px as f32 + 0.5) * inv_w) * u_span;

            let proj_x = cols[0][0] * dest_u + cols[1][0] * dest_v + cols[2][0];
            let proj_y = cols[0][1] * dest_u + cols[1][1] * dest_v + cols[2][1];
            let proj_z = cols[0][2] * dest_u + cols[1][2] * dest_v + cols[2][2];

            if proj_z.abs() < 1e-6 {
                continue;
            }

            let src_u = proj_x / proj_z;
            let src_v = proj_y / proj_z;

            if (0.0..=1.0).contains(&src_u) && (0.0..=1.0).contains(&src_v) {
                let sampled = sample_bilinear(rgba, src_u, src_v).0;
                let offset = px * 4;
                row_bytes[offset..offset + 4].copy_from_slice(&sampled);
            }
        }
    };

    if parallelize_rows {
        raw_buf
            .par_chunks_mut(row_stride)
            .enumerate()
            .for_each(process_row);
    } else {
        raw_buf
            .chunks_mut(row_stride)
            .enumerate()
            .for_each(process_row);
    }

    if cancel_flag.load(Ordering::Acquire) {
        return None;
    }

    RgbaImage::from_raw(out_w, out_h, raw_buf)
}

/// Splits RGB/Alpha channels via raw slice chunks and compresses both in parallel with `rayon::join`.
fn compress_rgba_tile(rgba: &RgbaImage, draw_rect_mm: Rect2) -> Result<PreparedImageTile, String> {
    let (w, h) = rgba.dimensions();
    let pixel_count = (w * h) as usize;
    let raw = rgba.as_raw();

    let mut rgb_bytes = vec![0u8; pixel_count * 3];
    let mut alpha_bytes = vec![0u8; pixel_count];
    let mut has_transparency = false;

    for (i, chunk) in raw.chunks_exact(4).enumerate() {
        let rgb_idx = i * 3;
        rgb_bytes[rgb_idx] = chunk[0];
        rgb_bytes[rgb_idx + 1] = chunk[1];
        rgb_bytes[rgb_idx + 2] = chunk[2];
        let a = chunk[3];
        alpha_bytes[i] = a;
        if a < 255 {
            has_transparency = true;
        }
    }

    let (rgb_res, alpha_res) = rayon::join(
        || {
            let mut enc = ZlibEncoder::new(Vec::new(), Compression::fast());
            enc.write_all(&rgb_bytes).map_err(|e| e.to_string())?;
            enc.finish().map_err(|e| e.to_string())
        },
        || -> Result<Option<Vec<u8>>, String> {
            if !has_transparency {
                return Ok(None);
            }
            let mut enc = ZlibEncoder::new(Vec::new(), Compression::fast());
            enc.write_all(&alpha_bytes).map_err(|e| e.to_string())?;
            enc.finish().map(Some).map_err(|e| e.to_string())
        },
    );

    Ok(PreparedImageTile {
        width: w,
        height: h,
        compressed_rgb: rgb_res?,
        compressed_alpha: alpha_res?,
        draw_rect_mm,
    })
}

fn write_prepared_image(pdf: &mut StreamingPdf, prepared: PreparedImageTile) -> Result<u32, String> {
    let smask_entry = if let Some(compressed_alpha) = prepared.compressed_alpha {
        let smask_id = pdf.reserve_id();
        let smask_dict = format!(
            "/Type /XObject /Subtype /Image /Width {} /Height {} /ColorSpace /DeviceGray /BitsPerComponent 8 /Filter /FlateDecode",
            prepared.width, prepared.height
        );
        pdf.write_stream(smask_id, &smask_dict, &compressed_alpha)?;
        format!(" /SMask {} 0 R", smask_id)
    } else {
        String::new()
    };

    let img_id = pdf.reserve_id();
    let img_dict = format!(
        "/Type /XObject /Subtype /Image /Width {} /Height {} /ColorSpace /DeviceRGB /BitsPerComponent 8 /Filter /FlateDecode{}",
        prepared.width, prepared.height, smask_entry
    );
    pdf.write_stream(img_id, &img_dict, &prepared.compressed_rgb)?;

    Ok(img_id)
}

// ============================================================================
// PDF Page Streaming (Clones lopdf resources directly into StreamingPdf)
// ============================================================================

fn stream_pdf_page(
    pdf: &mut StreamingPdf,
    src_doc: &Document,
    page_num: u32,
) -> Result<(u32, [f32; 4]), String> {
    let pages = src_doc.get_pages();
    let &src_page_id = pages
        .get(&page_num)
        .ok_or_else(|| format!("PDF page {} not found", page_num))?;

    let bbox = get_page_bbox(src_doc, src_page_id)?;
    let raw_content = src_doc.get_page_content(src_page_id);

    let mut content_enc = ZlibEncoder::new(Vec::new(), Compression::fast());
    content_enc
        .write_all(&raw_content)
        .map_err(|e| e.to_string())?;
    let compressed_content = content_enc.finish().map_err(|e| e.to_string())?;

    let mut id_map: HashMap<ObjectId, u32> = HashMap::new();
    let resources_str = match src_doc.get_page_resources(src_page_id) {
        Ok((Some(res_dict), _)) => {
            serialize_cloned_object(src_doc, pdf, &Object::Dictionary(res_dict.clone()), &mut id_map)?
        }
        Ok((None, res_ids)) if !res_ids.is_empty() => {
            serialize_cloned_object(src_doc, pdf, &Object::Reference(res_ids[0]), &mut id_map)?
        }
        _ => "<< >>".to_string(),
    };

    let form_id = pdf.reserve_id();
    let form_dict = format!(
        "/Type /XObject /Subtype /Form /FormType 1 /BBox [{:.4} {:.4} {:.4} {:.4}] /Resources {} /Filter /FlateDecode",
        bbox[0], bbox[1], bbox[2], bbox[3], resources_str
    );
    pdf.write_stream(form_id, &form_dict, &compressed_content)?;

    Ok((form_id, bbox))
}

fn get_page_bbox(doc: &Document, page_id: ObjectId) -> Result<[f32; 4], String> {
    let mut curr_id = Some(page_id);
    while let Some(id) = curr_id {
        let dict = doc.get_dictionary(id).map_err(|e| e.to_string())?;
        if let Ok(box_obj) = dict.get(b"CropBox").or_else(|_| dict.get(b"MediaBox")) {
            let resolved = match box_obj {
                Object::Reference(r) => doc.get_object(*r).map_err(|e| e.to_string())?,
                other => other,
            };
            if let Object::Array(arr) = resolved {
                if arr.len() == 4 {
                    let mut nums = [0.0f32; 4];
                    for (i, item) in arr.iter().enumerate() {
                        nums[i] = match item {
                            Object::Real(f) => *f,
                            Object::Integer(n) => *n as f32,
                            _ => 0.0,
                        };
                    }
                    return Ok(nums);
                }
            }
        }
        curr_id = dict.get(b"Parent").ok().and_then(|p| p.as_reference().ok());
    }
    Err("Could not resolve CropBox or MediaBox for PDF page".into())
}

fn serialize_cloned_object(
    src_doc: &Document,
    pdf: &mut StreamingPdf,
    obj: &Object,
    id_map: &mut HashMap<ObjectId, u32>,
) -> Result<String, String> {
    match obj {
        Object::Reference(old_id) => {
            if let Some(&new_id) = id_map.get(old_id) {
                return Ok(format!("{} 0 R", new_id));
            }
            let new_id = pdf.reserve_id();
            id_map.insert(*old_id, new_id);

            let target = src_doc.get_object(*old_id).map_err(|e| e.to_string())?;
            match target {
                Object::Stream(stream) => {
                    let mut entries = Vec::new();
                    for (k, v) in stream.dict.iter() {
                        if k == b"Length" || k == b"Parent" {
                            continue;
                        }
                        let key_str = format_pdf_name(k);
                        let val_str = serialize_cloned_object(src_doc, pdf, v, id_map)?;
                        entries.push(format!("{} {}", key_str, val_str));
                    }
                    pdf.write_stream(new_id, &entries.join(" "), &stream.content)?;
                }
                other => {
                    let serialized = serialize_cloned_object(src_doc, pdf, other, id_map)?;
                    pdf.write_object(new_id, serialized.as_bytes())?;
                }
            }
            Ok(format!("{} 0 R", new_id))
        }
        Object::Dictionary(dict) => {
            let mut entries = Vec::new();
            for (k, v) in dict.iter() {
                if k == b"Parent" {
                    continue;
                }
                let key_str = format_pdf_name(k);
                let val_str = serialize_cloned_object(src_doc, pdf, v, id_map)?;
                entries.push(format!("{} {}", key_str, val_str));
            }
            Ok(format!("<< {} >>", entries.join(" ")))
        }
        Object::Array(arr) => {
            let mut items = Vec::with_capacity(arr.len());
            for item in arr {
                items.push(serialize_cloned_object(src_doc, pdf, item, id_map)?);
            }
            Ok(format!("[ {} ]", items.join(" ")))
        }
        Object::Name(name) => Ok(format_pdf_name(name)),
        Object::String(bytes, lopdf::StringFormat::Hexadecimal) => {
            let hex: String = bytes.iter().map(|b| format!("{:02X}", b)).collect();
            Ok(format!("<{}>", hex))
        }
        Object::String(bytes, _) => {
            let mut escaped = String::from("(");
            for &b in bytes {
                match b {
                    b'(' | b')' | b'\\' => {
                        escaped.push('\\');
                        escaped.push(b as char);
                    }
                    _ => escaped.push(b as char),
                }
            }
            escaped.push(')');
            Ok(escaped)
        }
        Object::Integer(n) => Ok(n.to_string()),
        Object::Real(f) => Ok(format!("{:.6}", f)),
        Object::Boolean(b) => Ok(if *b { "true" } else { "false" }.to_string()),
        Object::Null => Ok("null".to_string()),
        Object::Stream(_) => Ok("null".to_string()),
    }
}

fn format_pdf_name(bytes: &[u8]) -> String {
    let mut out = String::from("/");
    for &b in bytes {
        if b.is_ascii_graphic()
            && !matches!(
                b,
                b'#' | b'(' | b')' | b'<' | b'>' | b'[' | b']' | b'{' | b'}' | b'/' | b'%'
            )
        {
            out.push(b as char);
        } else {
            out.push_str(&format!("#{:02X}", b));
        }
    }
    out
}
