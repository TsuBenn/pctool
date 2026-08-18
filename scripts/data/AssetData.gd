@abstract class_name AssetData
extends Resource

@export var id: String
@export var display_name: String
@export var source_path: String

@abstract func get_count() -> int
@abstract func get_preview_texture(index: int) -> Texture2D
@abstract func get_image(index: int) -> Image
