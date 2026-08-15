@tool
extends HBoxContainer
class_name LabeledOptionButton

# Custom signal so parent menus know when an option was chosen
signal item_selected(index: int)

@export var label: String = "Option:":
	set(new_text):
		label = new_text
		if is_node_ready():
			$Label.text = label

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

@export var selected_index: int = 0:
	set(new_index):
		selected_index = new_index
		if is_node_ready():
			if $OptionButton.get_item_count() > selected_index and selected_index >= 0:
				$OptionButton.selected = selected_index


func _ready() -> void:
	$Label.text = label
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
	for item in items:
		if item == "-" or item == "---":
			# Add a simple horizontal divider line
			$OptionButton.add_separator()
		elif item.begins_with("-") and item.ends_with("-"):
			# Add a section header (e.g. "- Selection Tools -" becomes "Selection Tools")
			var header_text: String = item.trim_prefix("-").trim_suffix("-").strip_edges()
			$OptionButton.add_separator(header_text)
		else:
			# Regular selectable option
			$OptionButton.add_item(item)

	if items.size() > 0 and selected_index < $OptionButton.get_item_count() and selected_index >= 0:
		$OptionButton.selected = selected_index


func _on_option_button_item_selected(index: int) -> void:
	selected_index = index
	item_selected.emit(index)
