use std::{collections::HashSet, sync::mpsc::{Receiver, Sender}};

use godot::prelude::*;

#[derive(GodotClass)]
#[class(init, base=RefCounted)]
struct RsPreviewTextureEngine {
    base: Base<RefCounted>,

    requests_channel: Option<Sender<(i64, TileRequest)>>,
    provider_channel: Option<Receiver<BatchResult>>,
    pending: HashSet<TileRequest>,
}

struct TileRequest {
    asset_id: String,
    asset_type: String,
    asset_index: i64,
    asset_bytes: Vec<u8>,
}

struct BatchResult {
    batch_id: i64,
    textures: Vec<(TileRequest, Vec<u8>)>
}

#[godot_api]
impl RsPreviewTextureEngine {

    #[func]
    fn request_batch(&self, batch_id: i64, requests: Vec<AnyDictionary>) {
    }
}
