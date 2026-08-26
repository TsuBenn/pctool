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
		title_padding = new
		if is_node_ready():
			_update_position()

@export var padding: int = 12:
	set(new):
		padding = new
		if is_node_ready():
			_update_position()


@export var content_margin: int = 6:
	set(new):
		content_margin = new
		if is_node_ready():
			_update_position()

@export_enum("Left", "Center", "Right") var text_alignment: String = "Left":
	set(new):
		text_alignment = new
		_update_position()

@onready var label: Label = %Label
@onready var internal_control: Control = %InternalControl
@onready var panel_container: PanelContainer = %PanelContainer

func _notification(what: int) -> void:
	if what == NOTIFICATION_SORT_CHILDREN:
		_update_position()

func _ready() -> void:
	# add_child(internal_control, false, INTERNAL_MODE_FRONT)
	label.text = title
	_update_position()

	resized.connect(_update_position)

func _update_position():
	if not internal_control or not label or not panel_container:
		return
	internal_control.size = size

	match text_alignment:
		"Left":
			label.offset_transform_position.x = padding
		"Center":
			label.offset_transform_position.x = (size.x - label.size.x)/2
		"Right":
			label.offset_transform_position.x = size.x - label.size.x - padding

	var mat: ShaderMaterial = panel_container.material as ShaderMaterial
	if mat:
		mat.set_shader_parameter("cutout_rect", Vector4(label.offset_transform_position.x - title_padding, 0, label.size.x + title_padding*2, 2))

	for child in get_children():
		if child != internal_control:
			var content_x = panel_container.position.x + content_margin
			var content_y = panel_container.position.y + content_margin
			var content_w = panel_container.size.x - content_margin*2
			var content_h = panel_container.size.y - content_margin*2
			fit_child_in_rect(child, Rect2(content_x, content_y, content_w, content_h))


