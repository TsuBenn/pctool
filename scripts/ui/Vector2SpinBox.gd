@tool
extends HFlowContainer
class_name Vector2SpinBox

signal value_changed(new_value: Vector2)

@export var value: Vector2 = Vector2.ZERO:
	set(new):
		value = new.clamp(min_value, max_value)
		if is_node_ready():
			_update()

@export var default_value: Vector2 = Vector2.ZERO:
	set(new):
		default_value = new.clamp(min_value, max_value)
		if is_node_ready():
			_update()

@export var max_value: Vector2 = Vector2(100,100):
	set(new):
		max_value = new
		if is_node_ready():
			_update()

@export var min_value: Vector2 = Vector2(-100,-100):
	set(new):
		min_value = new
		if is_node_ready():
			_update()

@export var step: float = 0.1:
	set(new):
		step = new
		if is_node_ready():
			_update()

@export var reset_button: bool = false:
	set(new):
		reset_button = new
		if is_node_ready():
			_update()

@export var unit: String = "":
	set(new):
		unit = new
		if is_node_ready():
			_update()

@export var show_arrows: bool = false:
	set(new):
		show_arrows = new
		if is_node_ready():
			_update()

@export var spinbox_width: int = 0:
	set(new):
		spinbox_width = new
		if is_node_ready():
			_update()

@onready var x_spin_box: LabeledSpinBox = %XSpinBox
@onready var y_spin_box: LabeledSpinBox = %YSpinBox

func _update():
	x_spin_box.show_arrows = show_arrows
	y_spin_box.show_arrows = show_arrows
	x_spin_box.max_value = max_value.x
	y_spin_box.max_value = max_value.y
	x_spin_box.min_value = min_value.x
	y_spin_box.min_value = min_value.y
	x_spin_box.step = step
	y_spin_box.step = step
	x_spin_box.reset_button = reset_button
	y_spin_box.reset_button = reset_button
	x_spin_box.default_value = default_value.x
	y_spin_box.default_value = default_value.y
	x_spin_box.set_value_no_signal(value.x)
	y_spin_box.set_value_no_signal(value.y)
	x_spin_box.suffix = unit
	y_spin_box.suffix = unit
	x_spin_box.spinbox_width = spinbox_width
	y_spin_box.spinbox_width = spinbox_width

func _ready() -> void:
	x_spin_box.value_changed.connect(
		func(new):
			var new_value = value
			new_value.x = new
			_on_spin_box_value_changed(new_value)
	)
	y_spin_box.value_changed.connect(
		func(new):
			var new_value = value
			new_value.y = new
			_on_spin_box_value_changed(new_value)
	)
	_update()

func set_value_no_signal(new_value: Vector2):
	value = new_value

func _on_spin_box_value_changed(new_value: Vector2):
	value = new_value
	value_changed.emit(new_value)
