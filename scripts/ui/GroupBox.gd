@tool
extends Container
class_name GroupBox

@export var title: String = "Title":
	set(new):
		title = new
		if is_node_ready():
			label.text = new
			_update_position.call_deferred()

@export var title_padding: int = 4:
	set(new):
		title_padding = max(new,0)
		if is_node_ready():
			_update_position()

@export var padding: int = 12:
	set(new):
		padding = max(new,0)
		if is_node_ready():
			_update_position()
			update_minimum_size()

@export_enum("Left", "Center", "Right") var text_alignment: String = "Left":
	set(new):
		text_alignment = new
		_update_position()

@export var show_border: bool = true:
	set(new):
		show_border = new
		if is_node_ready():
			_update_position()

@export var emphasized: bool = true:
	set(new):
		emphasized = new
		if is_node_ready():
			_update_position()

@export_group("Collapsable", "collapse_")
@export var collapse_enabled: bool = false:
	set(new):
		collapse_enabled = new
		if is_node_ready():
			_update_position()

@export var collapse_folded: bool = false:
	set(new):
		collapse_folded = new
		if is_node_ready():
			_update_position()

@export var collapse_button_spacing: int = 10:
	set(new):
		collapse_button_spacing = max(new, 0)
		if is_node_ready():
			_update_position()

@export var collapse_button_offset: int = -2:
	set(new):
		collapse_button_offset = max(new,-10)
		if is_node_ready():
			_update_position()

@export_group("Content_margin", "margin_")
@export var margin_left: int = 6:
	set(new):
		margin_left = max(new,0)
		if is_node_ready():
			_update_position()
			update_minimum_size()
@export var margin_top: int = 6:
	set(new):
		margin_top = max(new,0)
		if is_node_ready():
			_update_position()
			update_minimum_size()
@export var margin_right: int = 6:
	set(new):
		margin_right = max(new,0)
		if is_node_ready():
			_update_position()
			update_minimum_size()
@export var margin_bottom: int = 6:
	set(new):
		margin_bottom = max(new,0)
		if is_node_ready():
			_update_position()
			update_minimum_size()

@onready var label: Label = %Label
@onready var internal_control: Control = %InternalControl
@onready var panel_container: PanelContainer = %PanelContainer
@onready var collapse_button: CheckBox = %CollapseButton

@onready var button: Button = %Button

func _notification(what: int) -> void:
	if what == NOTIFICATION_SORT_CHILDREN:
		_update_position()

func _ready() -> void:
	# add_child(internal_control, false, INTERNAL_MODE_FRONT)
	label.text = title
	button.toggled.connect(
		func(new):
			collapse_folded = new
	)
	_update_position()

	resized.connect(_update_position)

func _get_minimum_size() -> Vector2:
	if not internal_control:
		return Vector2.ZERO
	var max_h = 0
	var max_w = 0
	for child in get_children():
		if child != internal_control:
			max_h = max(max_h, child.get_minimum_size().y)
			max_w = max(max_w, child.get_minimum_size().x)
	return Vector2(
		max(padding*2 + label.size.x,(max_w + (margin_left + margin_right) if max_w > 0 else 0)),
	max(22, 16 + (max_h + (margin_top + margin_bottom) if max_h > 0 else 0) if not collapse_folded else 22)
	)

func _update_position():
	if not internal_control or not label or not panel_container or not collapse_button:
		return

	panel_container.self_modulate = Color.WHITE if show_border else Color.TRANSPARENT
	label.theme_type_variation = "EmphasisLabel" if emphasized else ""

	button.disabled = not collapse_enabled
	button.button_pressed = collapse_enabled and collapse_folded
	collapse_button.visible = collapse_enabled
	collapse_button.button_pressed = not collapse_folded

	if size.y <= 22:
		panel_container.offset_bottom = -10
	else:
		panel_container.offset_bottom = 0

	internal_control.size = size

	match text_alignment:
		"Left":
			collapse_button.offset_transform_position.x = padding - 2 + collapse_button_offset
			label.offset_transform_position.x = padding + (int(collapse_button.size.x) + collapse_button_offset - (12 - collapse_button_spacing) if collapse_enabled else 0)
		"Center":
			collapse_button.offset_transform_position.x = (size.x - label.size.x)/2 - collapse_button.size.x + collapse_button_offset + (12 - collapse_button_spacing)
			label.offset_transform_position.x = (size.x - label.size.x)/2
		"Right":
			collapse_button.offset_transform_position.x = size.x - label.size.x - padding - collapse_button.size.x + collapse_button_offset + (12 - collapse_button_spacing)
			label.offset_transform_position.x = size.x - label.size.x - padding

	var mat: ShaderMaterial = panel_container.material as ShaderMaterial
	if mat:
		mat.set_shader_parameter(
			"cutout_rect",
			Vector4(
				label.offset_transform_position.x - title_padding - (int(collapse_button.size.x) + collapse_button_offset - (12 - collapse_button_spacing) if collapse_enabled else 0),
				0,
				label.size.x + title_padding*2 + ((int(collapse_button.size.x) + collapse_button_offset - (12 - collapse_button_spacing)) if collapse_enabled else 0),
				2
			)
		)

	for child in get_children():
		if child != internal_control:
			child.visible = not collapse_enabled or not collapse_folded
			var content_x = panel_container.position.x + margin_left
			var content_y = panel_container.position.y + margin_top + 6
			var content_w = panel_container.size.x - (margin_left + margin_right)
			var content_h = panel_container.size.y - (margin_top + margin_bottom) - 6
			fit_child_in_rect(child, Rect2(content_x, content_y, content_w, content_h))

