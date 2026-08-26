@tool
extends HBoxContainer
class_name LabeledOptionButton

# Emits the logical ID of the selected option (skipping separators)
signal item_selected(id: int)

@export var label: String = "Option:":
	set(new_text):
		label = new_text
		if is_node_ready():
			$Label.text = label

@export var disabled: bool = false:
	set(new_val):
		disabled = new_val
		if is_node_ready():
			$OptionButton.disabled = new_val

@export_enum("Label", "OptionButton") var expand_on: String = "Label":
	set(new_value):
		expand_on = new_value
		if is_node_ready():
			match new_value:
				"Label":
					$Label.size_flags_horizontal = SizeFlags.SIZE_EXPAND_FILL
					$OptionButton.size_flags_horizontal = SizeFlags.SIZE_FILL
				"OptionButton":
					$Label.size_flags_horizontal = SizeFlags.SIZE_FILL
					$OptionButton.size_flags_horizontal = SizeFlags.SIZE_EXPAND_FILL

@export var items: Array[String] = []:
	set(new_items):
		items = new_items
		if is_node_ready():
			_update_items()

@export var selected: int = 0:
	set(new_id):
		selected = new_id
		if is_node_ready():
			_select_by_id(selected)

@export var button_width: int = 100:
	set(new):
		button_width = max(new, 0)
		if is_node_ready():
			$OptionButton.custom_minimum_size = Vector2(new, 0)
			$OptionButton.fit_to_longest_item = new == 0

func _ready() -> void:
	$Label.text = label
	$OptionButton.disabled = disabled
	$OptionButton.custom_minimum_size = Vector2(button_width, 0)
	$OptionButton.fit_to_longest_item = button_width == 0
	match expand_on:
		"Label":
			$Label.size_flags_horizontal = SizeFlags.SIZE_EXPAND_FILL
			$OptionButton.size_flags_horizontal = SizeFlags.SIZE_FILL
		"OptionButton":
			$Label.size_flags_horizontal = SizeFlags.SIZE_FILL
			$OptionButton.size_flags_horizontal = SizeFlags.SIZE_EXPAND_FILL
	_update_items()

	if not Engine.is_editor_hint():
		$OptionButton.item_selected.connect(_on_option_button_item_selected)

func _update_items() -> void:
	$OptionButton.clear()
	var next_id: int = 0

	for item in items:
		if item == "-" or item == "---":
			$OptionButton.add_separator()
		elif item.begins_with("-") and item.ends_with("-"):
			var header_text: String = item.trim_prefix("-").trim_suffix("-").strip_edges()
			$OptionButton.add_separator(header_text)
		else:
			# Assigns sequential IDs strictly to selectable items
			$OptionButton.add_item(item, next_id)
			next_id += 1

	_select_by_id(selected)


func _select_by_id(id: int) -> void:
	var item_index: int = $OptionButton.get_item_index(id)
	if item_index != -1:
		$OptionButton.selected = item_index


func _on_option_button_item_selected(index: int) -> void:
	var id: int = $OptionButton.get_item_id(index)
	selected = id
	item_selected.emit(id)
