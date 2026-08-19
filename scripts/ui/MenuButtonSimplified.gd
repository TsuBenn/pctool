@tool
extends MenuButton
class_name MenuButtonSimplified

signal id_pressed(id: int)

@export var label: String = "Menu":
	set(new):
		label = new
		text = new

@export var items: Array[String] = []:
	set(new_items):
		items = new_items
		_update_items()


func _ready() -> void:
	text = label
	# Connect id_pressed (not index_pressed) so IDs match even with separators
	if not Engine.is_editor_hint():
		get_popup().id_pressed.connect(id_pressed.emit)
	_update_items()


func _update_items() -> void:
	var popup: PopupMenu = get_popup()
	if popup == null:
		return

	popup.clear()
	var next_id: int = 0

	for raw_item in items:
		var item: String = raw_item.strip_edges()

		if item == "-" or item == "---":
			popup.add_separator()
		elif item.begins_with("-") and item.ends_with("-"):
			var header_text: String = item.trim_prefix("-").trim_suffix("-").strip_edges()
			popup.add_separator(header_text)
		else:
			# Check for shortcut separator: "Label | Ctrl+S"
			var parts: PackedStringArray = item.split("|")
			var item_text: String = parts[0].strip_edges()
			var shortcut: Shortcut = null

			if parts.size() > 1:
				var shortcut_str: String = parts[1].strip_edges()
				shortcut = _parse_shortcut_string(shortcut_str)

			popup.add_item(item_text, next_id)

			if shortcut:
				var item_idx: int = popup.get_item_index(next_id)
				popup.set_item_shortcut(item_idx, shortcut, true) # true = global shortcut listener

			next_id += 1


## Parses a string like "Ctrl+S", "Ctrl+Shift+E", "Delete", "Esc" into a Shortcut resource
func _parse_shortcut_string(str_def: String) -> Shortcut:
	var tokens: PackedStringArray = str_def.split("+")
	var key_event: InputEventKey = InputEventKey.new()

	for token in tokens:
		var clean_token: String = token.strip_edges().to_lower()
		match clean_token:
			"ctrl", "control":
				key_event.ctrl_pressed = true
			"shift":
				key_event.shift_pressed = true
			"alt":
				key_event.alt_pressed = true
			"meta", "cmd", "super":
				key_event.meta_pressed = true
			"esc", "escape":
				key_event.keycode = KEY_ESCAPE
			"del", "delete":
				key_event.keycode = KEY_DELETE
			"space":
				key_event.keycode = KEY_SPACE
			"enter", "return":
				key_event.keycode = KEY_ENTER
			_:
				# Parse single character (e.g. 'A', 'N', 'S', 'E', '0')
				if clean_token.length() == 1:
					key_event.keycode = OS.find_keycode_from_string(clean_token.to_upper())
				else:
					key_event.keycode = OS.find_keycode_from_string(token.strip_edges())

	if key_event.keycode == KEY_NONE:
		return null

	key_event.pressed = true
	var sc: Shortcut = Shortcut.new()
	sc.events = [key_event]
	return sc
