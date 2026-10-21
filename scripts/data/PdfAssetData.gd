class_name PdfAssetData
extends AssetData

var raw_file_buf: PackedByteArray
var sizes: Array[Vector2i]
var page_count: int

func _init(new_id: String, file_name: String, path: String, buf: PackedByteArray, pages: int, page_sizes: Array[Vector2i]) -> void:
	id = new_id
	display_name = file_name
	source_path = path
	raw_file_buf = buf
	page_count = pages
	sizes = page_sizes


func get_count() -> int:
	return page_count

func get_bytes() -> PackedByteArray:
	return raw_file_buf

func get_size(index: int) -> Vector2i:
	return sizes[index]

func get_thumbnail(index: int) -> Texture2D:
	return PreviewTextureEngine.request(self, index, 256, true)

func get_image(index: int, size: Vector2i) -> Image:

	var x = size.x

	var result = PdfEngine.render_page_gd(raw_file_buf, index, x)

	if not result["error"].is_empty():
		push_error(result["error"])
		return null

	var image = Image.create_from_data(
		result["width"], result["height"], false, Image.FORMAT_RGBA8, result["pixels"]
	)

	return image

func clean() -> void:
	raw_file_buf.clear()
	pass


static func create_from_file(path: String, buf: PackedByteArray) -> PdfAssetData:
	var start = Time.get_ticks_usec()
	var pages = PdfEngine.get_pdf_infos(path)
	if not pages["error"].is_empty():
		push_error(pages["error"])
		return null
	var end = Time.get_ticks_usec()
	print((end - start)/1000.0)
	return PdfAssetData.new(AssetData.get_id(), path.get_file(), path, buf, pages["count"], pages["sizes"])


static func is_valid_pdf(file_path: String) -> bool:
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		print("Failed to open file: ", file_path)
		return false

	# Read the first 5 bytes to check for the standard "%PDF-" signature
	var header = file.get_buffer(5).get_string_from_ascii()
	return header == "%PDF-"
