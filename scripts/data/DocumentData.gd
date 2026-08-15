class_name DocumentData
extends Resource

var paper_size_mm: Vector2 = Vector2(210,297)
var dpi: int = 300
var is_landscape: bool = false
var margins_mm: float = 5.0
var spacing_mm: float = 5.0

var assets: Array[AssetData] = []
var photo_items: Array[PhotoItemData] = []

func _ready() -> void:
	pass # Replace with function body.
