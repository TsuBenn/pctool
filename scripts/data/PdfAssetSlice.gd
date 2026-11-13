class_name PdfAssetSlice
extends AssetData

var pdf_asset: PdfAssetData
var start: int:
	set(new):
		start = new
		emit_changed()
var end: int:
	set(new):
		end = new
		emit_changed()

func _init(_pdf_asset: PdfAssetData, _start: int = start, _end: int = pdf_asset.page_count) -> void:
	pdf_asset = _pdf_asset
	source_path = _pdf_asset.source_path
	display_name = _pdf_asset.display_name
	start = _start
	end = _end
	id = AssetData.get_id()

func get_count() -> int:
	return end - start + 1

func get_size(index: int) -> Vector2i:
	return pdf_asset.sizes[index]
