@abstract
class_name AssetData
extends Resource

var id: String
var display_name: String
var source_path: String

@abstract func get_count() -> int
@abstract func get_preview_texture(index: int) -> Texture2D
@abstract func get_image(index: int) -> Image
