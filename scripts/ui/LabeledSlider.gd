@tool
extends HBoxContainer
class_name LabeledSlider

signal value_changed(new_value: float)

@export var label: String = "Label":
	set(new_label):
		label = new_label
		if is_node_ready():
			$Label.text = new_label

@export_enum("Label", "Slider") var expand_mode: String = "Slider":
	set(new_val):
		expand_mode = new_val
		if is_node_ready():
			match new_val:
				"Label":
					$HSlider.size_flags_horizontal = Control.SIZE_FILL
					$Label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				"Slider":
					$HSlider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
					$Label.size_flags_horizontal = Control.SIZE_FILL

@export var slider_width: int = 0:
	set(new_val):
		if new_val < 0:
			return
		slider_width = new_val
		if is_node_ready():
			$HSlider.custom_minimum_size = Vector2i(new_val, 0)

@export var editable: bool = true:
	set(new_val):
		editable = new_val
		if is_node_ready():
			$HSlider.editable = value

@export var tick_count: float = 0.0:
	set(new_val):
		tick_count = new_val
		if is_node_ready():
			$HSlider.tick_count = value

@export var ticks_on_borders: bool = false:
	set(new_val):
		ticks_on_borders = new_val
		if is_node_ready():
			$HSlider.ticks_on_borders = value

@export var value: float = 0.0:
	set(new_val):
		value = new_val
		if is_node_ready():
			$HSlider.value = value

@export var min_value: float = 0.0:
	set(new_min):
		min_value = new_min
		if is_node_ready():
			$HSlider.min_value = min_value

@export var max_value: float = 100.0:
	set(new_max):
		max_value = new_max
		if is_node_ready():
			$HSlider.max_value = max_value

@export var step: float = 1.0:
	set(new_step):
		step = new_step
		if is_node_ready():
			$HSlider.step = step


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$Label.text = label
	$HSlider.editable = editable
	$HSlider.tick_count = tick_count
	$HSlider.ticks_on_borders = ticks_on_borders
	$HSlider.value = value
	$HSlider.min_value = min_value
	$HSlider.max_value = max_value
	$HSlider.step = step
	$HSlider.custom_minimum_size = Vector2i(slider_width, 0)
	match expand_mode:
		"Label":
			$HSlider.size_flags_horizontal = Control.SIZE_FILL
			$Label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		"Slider":
			$HSlider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			$Label.size_flags_horizontal = Control.SIZE_FILL

	if not Engine.is_editor_hint():
		$HSlider.value_changed.connect(_on_slider_value_changed)


func _on_slider_value_changed(new_value: float) -> void:
	value = new_value
	value_changed.emit(new_value)
