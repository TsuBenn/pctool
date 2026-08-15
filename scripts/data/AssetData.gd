@abstract
class_name AssetData
extends RefCounted

var id: int
var display_name: String
var source_path: String

@abstract func get_count() -> int
@abstract func get_preview_texture(index: int) -> Texture2D
@abstract func get_image(index: int) -> Image

func _ready() -> void:
	pass # Replace with function body.
