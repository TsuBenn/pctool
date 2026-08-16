extends Control

func _ready() -> void:
	get_window().min_size = Vector2i(800, 600)
	get_tree().node_added.connect(_on_node_added)
	_apply_nearest_filter(get_tree().root)

func _on_node_added(node: Node) -> void:
	_apply_nearest_filter(node)

func _apply_nearest_filter(node: Node) -> void:
	if node is Viewport:
		node.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	elif node is CanvasItem:
		node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
