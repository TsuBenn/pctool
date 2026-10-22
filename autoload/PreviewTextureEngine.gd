extends Node

signal cache_updated

var engine: RsPreviewTextureEngine = RsPreviewTextureEngine.new()

var request_timeout: Timer = Timer.new()
var cache_cleanup_timeout: Timer = Timer.new()

func _ready() -> void:
	request_timeout.wait_time = 0.5
	request_timeout.one_shot = true
	request_timeout.timeout.connect(provide)

	cache_cleanup_timeout.wait_time = 10
	cache_cleanup_timeout.one_shot = true
	cache_cleanup_timeout.timeout.connect(occasional_cleanup)

	add_child(request_timeout)
	add_child(cache_cleanup_timeout)

func occasional_cleanup():
	engine.cache_cleanup()
	RenderingServer.force_draw()

func _process(_delta: float) -> void:
	poll()

func request_texture(asset: AssetData, index: int, target_width: int) -> Texture2D:
	var texture = request(asset, index, target_width, true)
	if texture == null:
		provide()
		while not poll():
			pass
		texture = request(asset, index, target_width, true)
	return texture

func request_tile(tile: PhotoTile, px_per_mm, report: bool) -> Texture2D:
	return request(tile.photo_item.asset, tile.sub_asset_index, int(tile.photo_item.get_image_rect_mm(tile.sub_asset_index).size.x * px_per_mm), report)

func request(asset: AssetData, index: int, target_width: int, report: bool) -> Texture2D:
	var type: String

	if asset is GroupAssetData:
		asset = asset.get_child(index)
		index = 0;

	if asset is ImageAssetData:
		type = "image"
	elif asset is PdfAssetData:
		type = "pdf"

	if report:
		request_timeout.start()

	return engine.request(
		asset.id,
		index,
		type,
		asset.source_path,
		min(target_width, int(asset.get_size(index).x)),
		report
	)

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
		engine.cache(tile.asset_id, tile.asset_index, tile.size_tier, tex)
	# engine.cache_check()
	cache_cleanup_timeout.start()
	cache_updated.emit()
	return true

func provide():
	request_timeout.stop()
	engine.provide()

func release(asset: AssetData):
	engine.release_asset_cache(asset.id)
