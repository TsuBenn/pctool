use std::{
    collections::{HashMap, HashSet, hash_map::Entry},
    fmt::Display,
    sync::{
        Arc,
        mpsc::{Receiver, Sender},
    },
};

use dashmap::DashMap;
use godot::{classes::Texture2D, prelude::*};

use crate::render_engine::{ImageEngine, PdfEngine};

// use crate::render_engine::RsPdfEngine;

#[derive(GodotClass)]
#[class(base=RefCounted)]
struct RsPreviewTextureEngine {
    base: Base<RefCounted>,

    caches: HashMap<TextureKey, CacheTexture>,
    current_epoch: u64,
    byte_caches: Arc<DashMap<String, Arc<[u8]>>>,

    cache_misses: HashSet<TileRequest>,
    caching: HashSet<TextureKey>,

    cache_byte_size: i64,

    request_channel: Sender<Vec<TileRequest>>,
    provider_channel: Receiver<Vec<TileResult>>,
}

#[derive(Hash, Eq, PartialEq, Clone, Debug)]
struct TextureKey {
    asset_id: String,
    asset_index: i64,
    size_tier: i64,
}

impl TextureKey {
    pub fn from_request(req: &TileRequest) -> Self {
        Self {
            asset_id: req.asset_id.clone(),
            asset_index: req.asset_index,
            size_tier: req.size_tier,
        }
    }
}

#[derive(Hash, Eq, PartialEq, Clone, Debug)]
struct TileRequest {
    asset_id: String,
    source_path: String,
    asset_index: i64,
    asset_type: String,
    size_tier: i64,
}

#[derive(GodotClass)]
#[class(init, base=RefCounted)]
struct GdTileResult {
    #[var]
    asset_id: GString,
    #[var]
    asset_index: i64,
    #[var]
    size_tier: i64,
    #[var]
    width: i64,
    #[var]
    height: i64,
    #[var]
    pixel_bytes: PackedByteArray,
    base: Base<RefCounted>,
}

#[derive(Debug)]
struct TileResult {
    asset_id: String,
    asset_index: i64,
    size_tier: i64,
    width: u32,
    height: u32,
    pixel_bytes: Vec<u8>,
}

#[godot_api]
impl GdTileResult {
    fn new(tile_result: TileResult) -> Gd<Self> {
        Gd::from_init_fn(|base| Self {
            asset_id: GString::from(&tile_result.asset_id),
            asset_index: tile_result.asset_index,
            size_tier: tile_result.size_tier,
            width: tile_result.width as i64,
            height: tile_result.height as i64,
            pixel_bytes: tile_result.pixel_bytes.into(),
            base,
        })
    }
}

struct CacheTexture {
    texture: Gd<Texture2D>,
    size_tier: i64,
    epoch: u64,
    byte_size: i64,
}

impl CacheTexture {
    fn is_used(&self) -> bool {
        self.texture.get_reference_count() > 1
    }
}

impl Display for CacheTexture {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(
            f,
            "(size_tier: {}, size_mb: {:.3}MB, epoch: {})",
            self.size_tier,
            (self.byte_size as f64) / 1024.0 / 1024.0,
            self.epoch
        )
    }
}

#[godot_api]
impl IRefCounted for RsPreviewTextureEngine {
    fn init(base: Base<RefCounted>) -> Self {
        let (req_tx, req_rx) = std::sync::mpsc::channel();
        let (prov_tx, prov_rx) = std::sync::mpsc::channel();
        let byte_caches: Arc<DashMap<String, Arc<[u8]>>> = Arc::new(DashMap::new());

        let byte_caches_clone = Arc::clone(&byte_caches);

        std::thread::spawn(move || {
            let req_rx = req_rx;
            let prov_tx = prov_tx;
            let byte_caches = byte_caches_clone;

            while let Ok(requests) = req_rx.recv() {
                let requests: Vec<TileRequest> = requests;

                if requests.is_empty() {
                    continue;
                }

                let thread_count = std::thread::available_parallelism()
                    .map(|n| n.get())
                    .unwrap_or(4)
                    .min(requests.len());
                let load_per_thread = (requests.len() + thread_count - 1) / thread_count;

                let thread_loads: Vec<Vec<TileRequest>> = requests
                    .chunks(load_per_thread)
                    .map(|chunk| chunk.to_vec())
                    .collect();

                let mut thread_handles = vec![];

                for (_i, loads) in thread_loads.into_iter().enumerate() {
                    let byte_cache_ref = Arc::clone(&byte_caches);
                    let prov_tx_ref = prov_tx.clone();
                    let handle = std::thread::spawn(move || {
                        let loads = loads;
                        let prov_tx = prov_tx_ref;
                        if loads.len() == 0 {
                            return;
                        }
                        let mut this_results = vec![];
                        for load in &loads {
                            let bytes = {
                                if byte_cache_ref.contains_key(&load.asset_id) {
                                    byte_cache_ref.get(&load.asset_id).unwrap()
                                } else {
                                    let bytes = match std::fs::read(&load.source_path) {
                                        Ok(b) => b,
                                        Err(e) => {
                                            godot_error!(
                                                "Failed to cache asset bytes via source path: {} (Error: {})",
                                                load.source_path,
                                                e.to_string()
                                            );
                                            continue;
                                        }
                                    };
                                    byte_cache_ref.insert(load.asset_id.clone(), bytes.into());
                                    byte_cache_ref.get(&load.asset_id).unwrap()
                                }
                            };
                            if &load.asset_type == "pdf" {
                                let render = PdfEngine::render_page(
                                    &(*bytes),
                                    load.asset_index,
                                    load.size_tier,
                                );
                                let (pixel_bytes, width, height) = match render {
                                    Ok((pixel_bytes, width, height)) => {
                                        (pixel_bytes, width, height)
                                    }
                                    Err(e) => {
                                        godot_error!(
                                            "Failed to Render PDF (asset_id: {}, page: {}, error: {})!",
                                            load.asset_id,
                                            load.asset_index,
                                            e
                                        );
                                        continue;
                                    }
                                };
                                this_results.push(TileResult {
                                    asset_id: load.asset_id.clone(),
                                    asset_index: load.asset_index,
                                    size_tier: load.size_tier,
                                    width,
                                    height,
                                    pixel_bytes,
                                });
                            } else if &load.asset_type == "image" {
                                let Ok((pixel_bytes, width, height)) = ImageEngine::render_image(
                                    &(*bytes),
                                    load.size_tier as u32,
                                    None,
                                ) else {
                                    godot_error!(
                                        "Failed to Render Image (asset_id: {})!",
                                        load.asset_id
                                    );
                                    continue;
                                };
                                this_results.push(TileResult {
                                    asset_id: load.asset_id.clone(),
                                    asset_index: load.asset_index,
                                    size_tier: load.size_tier,
                                    width,
                                    height,
                                    pixel_bytes,
                                });
                            }
                        }
                        if !this_results.is_empty() {
                            match prov_tx.send(this_results) {
                                Err(e) => {
                                    godot_print!(
                                        "Failed to send tile results to provider channel! (Error: {})",
                                        e.to_string()
                                    );
                                }
                                _ => {}
                            };
                        }
                    });
                    thread_handles.push(handle);
                }

                for handle in thread_handles {
                    match handle.join() {
                        Err(_) => {
                            godot_print!("Failed to join threads!");
                            return;
                        }
                        _ => {}
                    }
                }
            }
        });

        Self {
            base,
            caches: HashMap::new(),
            byte_caches,
            cache_byte_size: 0,
            current_epoch: 0,
            cache_misses: HashSet::new(),
            caching: HashSet::new(),
            request_channel: req_tx,
            provider_channel: prov_rx,
        }
    }
}

const MAX_CACHE_SIZE_BYTES: i64 = 300 * 1024 * 1024; // 300 MB
const SIZE_TIER: &[i64] = &[128, 256, 512, 1024, 2048, 4096];

#[godot_api]
impl RsPreviewTextureEngine {
    #[func]
    fn request(
        &mut self,
        asset_id: String,
        asset_index: i64,
        asset_type: String,
        source_path: String,
        target_px_width: i64,
        report: bool,
    ) -> Option<Gd<Texture2D>> {
        let tier = SIZE_TIER
            .iter()
            .cloned()
            .position(|s| s >= (target_px_width as f64 * 2 as f64) as i64)
            .unwrap_or(SIZE_TIER.len() - 1) as i64;

        let texture_key = TextureKey {
            asset_id: asset_id.clone().into(),
            asset_index,
            size_tier: SIZE_TIER[tier as usize],
        };
        // if !self.byte_caches.contains_key(&asset_id) {
        //     self.byte_caches.insert(asset_id.clone(), std::fs::read(&source_path).unwrap().into());
        // }
        loop {
            match self.caches.get_mut(&texture_key) {
                Some(cache) => {
                    return Some(cache.texture.clone());
                }
                None => {
                    if report {
                        self.cache_misses.insert(TileRequest {
                            asset_id: asset_id.clone(),
                            source_path,
                            asset_index,
                            asset_type: asset_type,
                            size_tier: SIZE_TIER[tier as usize],
                        });
                    }
                    if let Some(lower_tier) = self
                        .caches
                        .iter()
                        .filter(|x| x.0.asset_id == asset_id && x.0.asset_index == asset_index)
                        .max_by_key(|x| x.0.size_tier)
                    {
                        return Some(lower_tier.1.texture.clone());
                    }
                    break;
                }
            }
        }
        None
    }

    #[func]
    fn has_misses(&self) -> bool {
        return !self.cache_misses.is_empty();
    }

    #[func]
    fn provide(&mut self) {
        let requests: Vec<TileRequest> = self
            .cache_misses
            .drain()
            .filter(|req| {
                let key = TextureKey::from_request(req);
                if self.caches.contains_key(&key) {
                    return false;
                }
                if !self.caching.contains(&key) {
                    self.caching.insert(key);
                    return true;
                } else {
                    return false;
                }
            })
            .collect();
        self.current_epoch += 1;
        for cache in &mut self.caches {
            if cache.1.texture.get_reference_count() > 1 {
                cache.1.epoch = self.current_epoch;
            }
        }
        if requests.is_empty() {
            self.cache_check();
            return;
        }
        match self.request_channel.send(requests) {
            Err(e) => godot_print!("{}", e.to_string()),
            Ok(()) => {}
        };
    }

    #[func]
    fn poll(&self) -> Vec<Gd<GdTileResult>> {
        match self.provider_channel.try_recv() {
            Ok(tile_results) => {
                let mut results = vec![];
                for tile in tile_results {
                    results.push(GdTileResult::new(tile));
                }
                results
            }
            Err(_) => vec![],
        }
    }

    #[func]
    fn cache(
        &mut self,
        asset_id: GString,
        asset_index: i64,
        size_tier: i64,
        texture: Gd<Texture2D>,
    ) {
        let texture_key = TextureKey {
            asset_id: asset_id.clone().into(),
            asset_index,
            size_tier,
        };
        self.caching.remove(&texture_key);
        let cache_texture = CacheTexture {
            byte_size: (texture.get_width() * texture.get_height() * 4) as i64,
            texture,
            size_tier,
            epoch: self.current_epoch,
        };
        let new_byte_size = cache_texture.byte_size;
        match self.caches.entry(texture_key) {
            Entry::Vacant(v) => {
                self.cache_byte_size += new_byte_size;
                v.insert(cache_texture);
            }
            _ => {}
        }
        self.cache_check();
    }

    #[func]
    fn cache_check(&mut self) {
        // for cache in self.caches.iter() {
        //     godot_print!("In use: {} at {} (is_used: {}; epoch: {})", cache.0.asset_id, cache.0.size_tier, cache.1.is_used(), cache.1.epoch);
        // }
        if self.cache_byte_size >= MAX_CACHE_SIZE_BYTES {
            let mut remove_candidate: Vec<(&TextureKey, &CacheTexture)> =
                self.caches.iter().filter(|i| !i.1.is_used()).collect();
            remove_candidate.sort_by(|a, b| {
                b.1.epoch
                    .cmp(&a.1.epoch)
                    .then_with(|| a.1.byte_size.cmp(&b.1.byte_size))
            });
            let mut to_remove: Vec<TextureKey> = vec![];
            while self.cache_byte_size >= (MAX_CACHE_SIZE_BYTES as f64 * 0.8) as i64 {
                match remove_candidate.pop() {
                    Some((key, value)) => {
                        self.cache_byte_size -= value.byte_size;
                        to_remove.push(key.clone())
                    }
                    None => break,
                }
            }
            for key in to_remove {
                self.caches.remove(&key);
            }
        }
        // godot_print!(
        //     "Cache size: {:.3}MB, cache count: {}, byte cache: {:.3}MB",
        //     self.cache_byte_size as f64 / 1024.0 / 1024.0,
        //     self.caches.len(),
        //     self.byte_caches.iter().map(|b| b.value().len()).sum::<usize>() as f64/ 1024.0/ 1024.0
        // );
    }

    #[func]
    fn release_asset_cache(&mut self, asset_id: String) {
        let to_remove: Vec<TextureKey> = self
            .caches
            .iter()
            .filter(|a| a.0.asset_id == asset_id)
            .map(|a| a.0.clone())
            .collect();
        for key in to_remove {
            self.cache_byte_size -= self.caches.get(&key).unwrap().byte_size;
            self.caches.remove(&key);
            self.byte_caches.remove(&key.asset_id);
        }
    }

    #[func]
    fn cache_cleanup(&mut self) {
        let to_remove: Vec<TextureKey> = self
            .caches
            .iter()
            .filter(|i| !i.1.is_used() || i.1.size_tier != 128)
            .map(|i| i.0.clone())
            .collect();
        for key in to_remove {
            self.cache_byte_size -= self.caches.get(&key).unwrap().byte_size;
            self.caches.remove(&key);
        }
        // godot_print!(
        //     "Cache size: {:.3}MB, cache count: {}, byte cache: {:.3}MB",
        //     self.cache_byte_size as f64 / 1024.0 / 1024.0,
        //     self.caches.len(),
        //     self.byte_caches.iter().map(|b| b.value().len()).sum::<usize>() as f64/ 1024.0/ 1024.0
        // );
    }
}
