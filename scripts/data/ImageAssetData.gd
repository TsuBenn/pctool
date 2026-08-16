class_name ImageAssetData
extends AssetData

var preview_texture: Texture2D
var original_image: Image
var pixel_dimensions: Vector2i

func _init(new_id: String = "", file_name: String = "", path: String = "", tex: Texture2D = null, img: Image = null, dim: Vector2i = Vector2i.ZERO) -> void:
	id = new_id
	display_name = file_name
	source_path = path
	preview_texture = tex
	original_image = img
	pixel_dimensions = dim

func get_count() -> int:
	return 1

func get_image(index: int) -> Image:
	return original_image

func get_preview_texture(index: int) -> Texture2D:
	return preview_texture

static func create_from_file(path: String) -> ImageAssetData:
	if not FileAccess.file_exists(path):
		push_error("ImageAssetData: File from path \"%s\" does not exists!" % path)
		return null

	var img_buffer: PackedByteArray = FileAccess.get_file_as_bytes(path)
	if img_buffer.is_empty():
		push_error("ImageAssetData: File from path \"%s\" is empty!" % path)
		return null

	var img: Image = Image.new()
	var err: Error = FAILED

	var ext: String = path.get_extension().to_lower()

	if ext in ["jpg", "jpeg"]:
		err = img.load_jpg_from_buffer(img_buffer)
		if err != OK: err = img.load_png_from_buffer(img_buffer)
		if err != OK: err = img.load_webp_from_buffer(img_buffer)
	if ext == "png":
		err = img.load_png_from_buffer(img_buffer)
		if err != OK: err = img.load_jpg_from_buffer(img_buffer)
		if err != OK: err = img.load_webp_from_buffer(img_buffer)
	if ext == "webp":
		err = img.load_webp_from_buffer(img_buffer)
		if err != OK: err = img.load_jpg_from_buffer(img_buffer)
		if err != OK: err = img.load_png_from_buffer(img_buffer)

	if err != OK:
		push_error("ImageAssetData: Image from path \"%s\" is unsupported or corrupted" % path)
		return null

	var tex: Texture2D = ImageTexture.create_from_image(img)
	var dim = Vector2i(img.get_width(), img.get_height())
	var file_name = path.get_file()
	var new_id = Marshalls.raw_to_base64(Crypto.new().generate_random_bytes(8))

	return ImageAssetData.new(new_id, file_name, path, tex, img, dim)
