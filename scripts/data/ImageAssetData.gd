class_name ImageAssetData
extends AssetData

var pixel_dimensions: Vector2i

func _init(
	new_id: String = "",
	file_name: String = "",
	path: String = "",
	dim: Vector2i = Vector2i.ZERO,
) -> void:
	id = new_id
	display_name = file_name
	source_path = path
	pixel_dimensions = dim

func get_count() -> int:
	return 1

func get_size(_index: int) -> Vector2i:
	return pixel_dimensions

static func create_from_file(path: String, info: ImageInfo = null) -> ImageAssetData:
	if info == null:
		info = ImageUtil.get_image_info(path);

	if not info.error.is_empty():
		push_error(info.error)
		return null
	return ImageAssetData.new(AssetData.get_id(), path.get_file().get_basename(), path, info.size)
