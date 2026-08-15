@tool
extends PanelContainer
class_name PanelHeader

@export var title: String = "Header":
	set(new_title):
		title = new_title
		if is_node_ready():
			$MarginContainer/Label.text = new_title;

@export_enum("Left", "Center", "Right") var title_alignment: String = "Center":
	set(new_alignment):
		title_alignment = new_alignment
		if is_node_ready():
			var new_a: HorizontalAlignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_CENTER
			match new_alignment:
				"Left": new_a = HorizontalAlignment.HORIZONTAL_ALIGNMENT_LEFT
				"Center": new_a = HorizontalAlignment.HORIZONTAL_ALIGNMENT_CENTER
				"Right": new_a = HorizontalAlignment.HORIZONTAL_ALIGNMENT_RIGHT
			$MarginContainer/Label.horizontal_alignment = new_a

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$MarginContainer/Label.text = title
	var new_a: HorizontalAlignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_CENTER
	match title_alignment:
		"Left": new_a = HorizontalAlignment.HORIZONTAL_ALIGNMENT_LEFT
		"Center": new_a = HorizontalAlignment.HORIZONTAL_ALIGNMENT_CENTER
		"Right": new_a = HorizontalAlignment.HORIZONTAL_ALIGNMENT_RIGHT
	$MarginContainer/Label.horizontal_alignment = new_a
