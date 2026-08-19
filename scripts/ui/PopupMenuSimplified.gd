extends PopupMenu
class_name PopupMenuSimplified

@export var items: Array[String] = []:
	set(new_items):
		items = new_items
		if is_node_ready():
			_update_items()

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# index_pressed.connect(id_pressed.emit)
	about_to_popup.connect(_prepare)
	exclusive = true
	_update_items()

func _prepare():
	position = get_parent().get_global_mouse_position()

func _update_items() -> void:
	clear()
	var next_id: int = 0

	for item in items:
		if item == "-" or item == "---":
			add_separator()
		elif item.begins_with("-") and item.ends_with("-"):
			var header_text: String = item.trim_prefix("-").trim_suffix("-").strip_edges()
			add_separator(header_text)
		else:
			# Assigns sequential IDs strictly to selectable items
			add_item(item, next_id)
			next_id += 1
