extends FileDialog

# StyleBox Overrides
@export var normal_style: StyleBox
@export var hover_style: StyleBox
@export var pressed_style: StyleBox
@export var hover_pressed_style: StyleBox

# Font Color Overrides
@export var font_color: Color = Color.WHITE
@export var font_hover_color: Color = Color.WHITE
@export var font_pressed_color: Color = Color.WHITE
@export var font_hover_pressed_color: Color = Color.WHITE

# Font Overrides
@export var custom_font: Font

func _ready() -> void:
	await get_tree().process_frame
	_override_menu_button_styles()

func _override_menu_button_styles() -> void:
	var menu_buttons: Array[Node] = find_children("*", "MenuButton", true, false)

	for node in menu_buttons:
		if node is MenuButton:
			_apply_styles_to_button(node)

func _apply_styles_to_button(btn: MenuButton) -> void:
	# Apply StyleBoxes
	if normal_style:
		btn.add_theme_stylebox_override("normal", normal_style)
	if hover_style:
		btn.add_theme_stylebox_override("hover", hover_style)
	if pressed_style:
		btn.add_theme_stylebox_override("pressed", pressed_style)
	if hover_pressed_style:
		btn.add_theme_stylebox_override("hover_pressed", hover_pressed_style)

	# Apply Font Colors
	btn.add_theme_color_override("font_color", font_color)
	btn.add_theme_color_override("font_hover_color", font_hover_color)
	btn.add_theme_color_override("font_pressed_color", font_pressed_color)
	btn.add_theme_color_override("font_hover_pressed_color", font_hover_pressed_color)

	# Apply Font and Font Size
	if custom_font:
		btn.add_theme_font_override("font", custom_font)
