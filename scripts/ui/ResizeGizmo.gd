@tool
extends Control
class_name ResizeGizmo

signal on_resized_preview(resized_rect: Rect2)
signal on_resized_commit(resized_rect: Rect2)

@export var ratio_locked: bool = true

@export var constrain_rect: Rect2

@export var min_size: Vector2 = Vector2(20.0,20.0)
@export var max_size: Vector2 = Vector2(10000.0,10000.0)

@export var moveable: bool = false:
	set(new):
		moveable = new
		if is_node_ready():
			%Border.mouse_filter = MOUSE_FILTER_STOP if new else MOUSE_FILTER_IGNORE

@onready var tl_handle: Control = %TLHandle
@onready var tr_handle: Control = %TRHandle
@onready var bl_handle: Control = %BLHandle
@onready var br_handle: Control = %BRHandle

@onready var l_handle: Control = %LHandle
@onready var t_handle: Control = %THandle
@onready var r_handle: Control = %RHandle
@onready var b_handle: Control = %BHandle

var _is_grabbed: bool = false
var _init_pos: Vector2 = Vector2.ZERO

var _locked_horizontal: bool = false
var _locked_vertical: bool = false
var _init_ratio: float = 1

var _centeralize_cursor: Vector2 = Vector2.ZERO

func knob_input(event: InputEvent, direction: String):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.is_pressed():
				_is_grabbed = true
				_locked_horizontal = false
				_locked_vertical = false
				_init_ratio = custom_minimum_size.aspect()
				match direction:
					"br":
						_init_pos = offset_transform_position
						_centeralize_cursor = offset_transform_position + custom_minimum_size - get_parent().get_local_mouse_position()
					"bl":
						_init_pos = offset_transform_position + custom_minimum_size*Vector2(1,0)
						_centeralize_cursor = offset_transform_position + custom_minimum_size*Vector2(0,1) - get_parent().get_local_mouse_position()
					"tr":
						_init_pos = offset_transform_position + custom_minimum_size*Vector2(0,1)
						_centeralize_cursor = offset_transform_position + custom_minimum_size*Vector2(1,0) - get_parent().get_local_mouse_position()
					"tl":
						_init_pos = offset_transform_position + custom_minimum_size
						_centeralize_cursor = offset_transform_position - get_parent().get_local_mouse_position()
					"t":
						_init_pos = offset_transform_position + custom_minimum_size*Vector2(0,1)
						_centeralize_cursor = Vector2(0,offset_transform_position.y - get_parent().get_local_mouse_position().y)
						_locked_horizontal = true
					"b":
						_init_pos = offset_transform_position
						_centeralize_cursor = Vector2(0,offset_transform_position.y + custom_minimum_size.y - get_parent().get_local_mouse_position().y)
						_locked_horizontal = true
					"r":
						_init_pos = offset_transform_position
						_centeralize_cursor = Vector2(offset_transform_position.x + custom_minimum_size.x - get_parent().get_local_mouse_position().x,0)
						_locked_vertical = true
					"l":
						_init_pos = offset_transform_position + custom_minimum_size*Vector2(1,0)
						_centeralize_cursor = Vector2(offset_transform_position.x - get_parent().get_local_mouse_position().x,0)
						_locked_vertical = true
			else :
				_is_grabbed = false
				on_resized_commit.emit(Rect2(offset_transform_position, custom_minimum_size))
	elif event is InputEventMouseMotion:
		if _is_grabbed:
			if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
				_is_grabbed = false
				return
			if Input.is_key_pressed(KEY_SHIFT):
				ratio_locked = false
			else:
				ratio_locked = true

			var new_pos = get_parent().get_local_mouse_position() + _centeralize_cursor

			if constrain_rect != Rect2(0,0,0,0):
				new_pos = new_pos.clamp(constrain_rect.position, constrain_rect.position + constrain_rect.size)

			var ratio = _init_ratio

			var new_pos_x = min(new_pos.x,_init_pos.x)
			if _locked_horizontal:
				new_pos_x = offset_transform_position.x

			var new_pos_y = min(new_pos.y,_init_pos.y)
			if _locked_vertical:
				new_pos_y = offset_transform_position.y

			var new_size_x = abs(_init_pos.x - new_pos.x)
			if _locked_horizontal:
				new_size_x = custom_minimum_size.x

			var new_size_y = abs(_init_pos.y - new_pos.y)
			if _locked_vertical:
				new_size_y = custom_minimum_size.y

			var new_position: Vector2 = Vector2(new_pos_x, new_pos_y)
			var new_size: Vector2 = Vector2(new_size_x, new_size_y)

			if ratio_locked and not _locked_horizontal and not _locked_vertical:
				if new_size_x/ratio > new_size_y:
					new_size = Vector2(new_size_x, new_size_x/ratio)
				else:
					new_size = Vector2(new_size_y*ratio, new_size_y)

			offset_transform_position = new_position
			custom_minimum_size = new_size

			on_resized_preview.emit(Rect2(new_position, new_size))

func resize(new_position: Vector2, new_size: Vector2):
	resize_no_signal(new_position, new_size)
	on_resized_preview.emit(Rect2(new_position, new_size))

func resize_no_signal(new_position: Vector2, new_size: Vector2):
	offset_transform_position = new_position
	custom_minimum_size = new_size

func _ready() -> void:
	offset_transform_enabled = true
	offset_transform_visual_only = false
	tl_handle.gui_input.connect(func(event): knob_input(event, "tl"))
	tr_handle.gui_input.connect(func(event): knob_input(event, "tr"))
	bl_handle.gui_input.connect(func(event): knob_input(event, "bl"))
	br_handle.gui_input.connect(func(event): knob_input(event, "br"))
	l_handle.gui_input.connect(func(event): knob_input(event, "l"))
	t_handle.gui_input.connect(func(event): knob_input(event, "t"))
	r_handle.gui_input.connect(func(event): knob_input(event, "r"))
	b_handle.gui_input.connect(func(event): knob_input(event, "b"))

