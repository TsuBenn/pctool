class_name PreviewTextureEngine
extends RefCounted

class CacheTexture:
	var texture: Texture2D
	var ref_count: int
	var last_used_frame: int
	var size_bytes: int

	func _init(tex: Texture2D, ref: int, last: int, size: int) -> void:
		texture = tex
		ref_count = ref
		last_used_frame = last
		size_bytes = size

var batch_id: int

# [AssetData, Page index]
var caches: Dictionary[Array, CacheTexture] = {}
var cache_size: int = 0

var misses: Array[PhotoTile]

var resize: Array[PhotoTile]

var rs_engine: RsPreviewTextureEngine = RsPreviewTextureEngine.new()

const CACHE_MAX = 512*(1024**2)

# Get texture from key
# If report is on and the key is missing then note down
func request(tile: PhotoTile, report: bool) -> Texture2D:
	var asset = tile.photo_item.asset
	var index = tile.sub_asset_index

	if asset is PdfAssetData:
		return null

	if asset is GroupAssetData:
		asset = asset.get_child(index)
		if asset is ImageAssetData:
			index = 0

	if caches.has([asset, index]):
		caches[[asset, index]].ref_count += 1
		return caches[[asset, index]].texture

	if report and not misses.has(tile):
		misses.append(tile)

	return null

# Start sending workload to Rust
# Wrap tiles into a struct Rust understands
func provide():
	pass

#
func cache_check():
	if cache_size < CACHE_MAX:
		print("Cache count: %d" % caches.size())
		print("Cache size: %d MB" % (cache_size/(1024**2.0)))
		return

	var removal_candidates: Array[Array] = []
	for cache in caches:
		if caches[cache].ref_count == 0:
			removal_candidates.append(cache)

	removal_candidates.sort_custom(
		func(a,b):
			if caches[a].last_used_frame > caches[b].last_used_frame:
				return true
			return false
	)

	while cache_size > (CACHE_MAX*0.8):
		var to_remove = removal_candidates.pop_back()
		if to_remove:
			cache_size -= caches[to_remove].size_bytes
			caches.erase(to_remove)
		else:
			break

	print("Cache count: %d" % caches.size())
	print("Cache size: %d MB" % (cache_size/(1024**2.0)))
