class_name PreviewTextureEngine
extends RefCounted

var engine: RsPreviewTextureEngine = RsPreviewTextureEngine.new()

func request(tile: PhotoTile, px_per_mm: float, report: bool):
	var asset: AssetData = tile.photo_item.asset
	var index: int = tile.sub_asset_index
	var type: String

	if asset is GroupAssetData:
		asset = asset.get_child(index)
		index = 0;

	if asset is ImageAssetData:
		type = "image"
	elif asset is PdfAssetData:
		type = "pdf"

	return engine.request(
		asset.id,
		index,
		type,
		asset.get_bytes(),
		min(int(tile.photo_item.get_image_rect_mm(index).size.x * px_per_mm), int(asset.get_size(index).x)),
		report
	)

func has_misses() -> bool:
	return engine.has_misses()

func poll() -> bool:
	var results: Array[GdTileResult] = engine.poll()
	if results.is_empty():
		return false
	for tile: GdTileResult in results:
		var width = tile.width
		var height = tile.height
		var pixels = tile.pixel_bytes
		var image = Image.create_from_data(width, height, false, Image.FORMAT_RGBA8, pixels)
		var tex = ImageTexture.create_from_image(image)
		engine.cache(tile.asset_id, tile.asset_index, tile.size_tier, Engine.get_frames_drawn(), tex)
	return true

func provide():
	engine.provide()

