@tool
class_name DragBox
extends Control

signal value_changed(new_val: float)
signal value_commit(new_val: float)

@onready var label: Label = %Label
@onready var suffix_label: Label = %SuffixLabel
@onready var prefix_label: Label = %PrefixLabel
@onready var line_edit: LineEdit = %LineEdit
@onready var underline: Line2D = %Underline

var signal_change: bool = true

@export var value: float = 0:
	set(new):
		value = clamp(snappedf(new, step), min_value, max_value)
		if signal_change:
			value_changed.emit(value)
		if is_node_ready():
			_sync_ui.call_deferred()

@export var step: float = 1:
	set(new):
		step = new
		value = snappedf(value, new)
		max_value = snappedf(max_value, new)
		min_value = snappedf(min_value, new)
		if is_node_ready():
			_sync_ui.call_deferred()

@export var max_value: float = 100:
	set(new):
		max_value = snappedf(new, step)
		if value > max_value:
			value = min(new, value)
		if is_node_ready():
			_sync_ui.call_deferred()

@export var min_value: float = 0:
	set(new):
		min_value = snappedf(new, step)
		if value < min_value:
			value = max(new, value)
		if is_node_ready():
			_sync_ui.call_deferred()

@export var suffix: String = "":
	set(new):
		suffix = new
		if is_node_ready():
			_sync_ui.call_deferred()

@export var prefix: String = "":
	set(new):
		prefix = new
		if is_node_ready():
			_sync_ui.call_deferred()

@export var hint: bool = false:
	set(new):
		hint = new
		if is_node_ready():
			_sync_ui.call_deferred()

@export var show_box: bool = false:
	set(new):
		show_box = new
		if is_node_ready():
			_sync_ui.call_deferred()

var timer: Timer = Timer.new()

var original_mouse_pos: Vector2i
var original_value: float
var delta: float
var is_draggin: bool = false
var drag_intensity: float = 20
var init_drag: float = 20

func set_value_no_signal(new_value: float):
	signal_change = false
	value = new_value
	signal_change = true

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if timer:
				timer.stop()
			if event.is_released():
				underline.visible = hint
				if is_draggin:
					value_commit.emit(value)
					is_draggin = false
				else:
					line_edit.grab_focus()
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
				get_viewport().warp_mouse(original_mouse_pos)
			if event.is_pressed():
				underline.visible = true
				original_mouse_pos = get_global_mouse_position()
				delta = 0
				original_value = value
				# Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			accept_event()
		elif event.is_pressed() and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			value += step
			timer.start()
			accept_event()
		elif event.is_pressed() and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			value -= step
			timer.start()
			accept_event()
	if event is InputEventMouseMotion:
		if is_draggin:
			delta += event.relative.x * (0.1 if event.shift_pressed else 1.0)
			value = original_value + (delta/drag_intensity)
			accept_event()
		elif Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and abs(get_global_mouse_position().x - original_mouse_pos.x) >= init_drag:
			original_mouse_pos = get_global_mouse_position()
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			is_draggin = true
			accept_event()

func _ready() -> void:
	underline.default_color = label.get_theme_color("font_color")

	timer.wait_time = 0.2
	timer.one_shot = true
	timer.timeout.connect(func(): value_commit.emit(value))

	add_child(timer)

	focus_entered.connect(func():
		line_edit.grab_focus()
	)
	line_edit.text_submitted.connect(func(new):
		value = float(new)
		value_commit.emit(value)
		line_edit.release_focus()
	)
	line_edit.editing_toggled.connect(func(edit):
		if not edit:
			line_edit.release_focus()
	)
	line_edit.focus_exited.connect(func():
		label.visible = !show_box
		line_edit.flat = true
		underline.visible = hint
		line_edit.self_modulate = Color.from_rgba8(0,0,0,0) if not show_box else Color.WHITE
		_sync_ui()
	)
	line_edit.focus_entered.connect(func():
		line_edit.self_modulate = Color.WHITE
		label.visible = false
		line_edit.flat = !show_box
		underline.visible = false
	)
	_sync_ui.call_deferred()

func _sync_ui():
	if not is_node_ready():
		return

	line_edit.text = String.num(snappedf(value, step), step_decimals(step))
	label.text = line_edit.text
	line_edit.flat = !show_box
	line_edit.self_modulate = Color.from_rgba8(0,0,0,0) if not show_box else Color.WHITE
	underline.self_modulate = Color.from_rgba8(0,0,0,0) if show_box else Color.WHITE
	label.visible = !show_box
	suffix_label.text = suffix
	prefix_label.text = prefix

	suffix_label.visible = !suffix.is_empty()
	prefix_label.visible = !prefix.is_empty()

	var font = line_edit.get_theme_font("font")
	var font_size = line_edit.get_theme_font_size("font_size")

	var text_size = font.get_string_size(line_edit.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)

	if not is_draggin:
		underline.visible = hint

	underline.set_point_position.call_deferred(0, (prefix_label.get_minimum_size() + Vector2(12,0) if prefix_label.visible else prefix_label.get_minimum_size()*Vector2(0,1) + Vector2(6,0)) - Vector2(0,2))
	underline.set_point_position.call_deferred(1, underline.get_point_position(0) + Vector2(text_size.x, 0))
