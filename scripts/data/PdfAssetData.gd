class_name PdfAssetData
extends AssetData

var sizes: Array[Vector2i]
var page_count: int

func _init(new_id: String, file_name: String, path: String, pages: int, page_sizes: Array[Vector2i]) -> void:
	id = new_id
	display_name = file_name
	source_path = path
	page_count = pages
	sizes = page_sizes
	for i in range(page_count):
		PreviewTextureEngine.request_texture(self, i, 128)


func get_count() -> int:
	return page_count

func get_size(index: int) -> Vector2i:
	return sizes[index]

static func create_from_file(path: String, info: PdfInfo = null) -> PdfAssetData:
	if info == null:
		info = PdfUtil.get_pdf_info(path)
	if not info.error.is_empty():
		push_error(info.error)
		return null
	return PdfAssetData.new(AssetData.get_id(), path.get_file(), path, info.count, info.sizes)

static func is_valid_pdf(file_path: String) -> bool:
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		print("Failed to open file: ", file_path)
		return false

	# Read the first 5 bytes to check for the standard "%PDF-" signature
	var header = file.get_buffer(5).get_string_from_ascii()
	return header == "%PDF-"
