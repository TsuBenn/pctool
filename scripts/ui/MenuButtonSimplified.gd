@tool
extends MenuButton
class_name MenuButtonSimplified

signal id_pressed(id: int)

@export var label: String = "Menu":
	set(new):
		label = new
		if is_node_ready():
			text = new

@export var items: Array[String] = []:
	set(new_items):
		items = new_items
		if is_node_ready():
			_update_items()

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	get_popup().index_pressed.connect(id_pressed.emit)
	text = label
	_update_items()

func _update_items() -> void:
	get_popup().clear()
	var next_id: int = 0

	for item in items:
		if item == "-" or item == "---":
			get_popup().add_separator()
		elif item.begins_with("-") and item.ends_with("-"):
			var header_text: String = item.trim_prefix("-").trim_suffix("-").strip_edges()
			get_popup().add_separator(header_text)
		else:
			# Assigns sequential IDs strictly to selectable items
			get_popup().add_item(item, next_id)
			next_id += 1
