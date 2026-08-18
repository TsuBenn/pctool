extends MarginContainer
class_name Toolbar

enum  {
	PAPER_PRESET_A4,
	PAPER_PRESET_A3,
	PAPER_PRESET_A5,
	PAPER_PRESET_CUSTOM,
}

enum {
		DPI_72,
		DPI_96,
		DPI_150,
		DPI_300,
		DPI_600,
		DPI_1200,
	}

var document_data: DocumentData

@onready var paper_option_button: LabeledOptionButton = %PaperOptionButton
@onready var width_spin_box: LabeledSpinBox = %WidthSpinBox
@onready var height_spin_box: LabeledSpinBox = %HeightSpinBox
@onready var dpi_option_button: LabeledOptionButton = %DPIOptionButton
@onready var orientation_option_button: LabeledOptionButton = %OrientationOptionButton
@onready var paper_margins_spin_box: LabeledSpinBox = %PaperMarginsSpinBox
@onready var spacing_spin_box: LabeledSpinBox = %SpacingSpinBox


func setup(data: DocumentData):
	document_data = data
	document_data.changed.connect(_sync_ui)
	_sync_ui()


func _ready() -> void:
	paper_option_button.item_selected.connect(
		func(new):
			match new:
				PAPER_PRESET_A4: _set_preset_size(Vector2(210, 297))
				PAPER_PRESET_A3: _set_preset_size(Vector2(297, 420))
				PAPER_PRESET_A5: _set_preset_size(Vector2(148, 210))
			)
	dpi_option_button.item_selected.connect(
		func(new):
			match new:
				DPI_72: document_data.dpi = 72
				DPI_96: document_data.dpi = 96
				DPI_150: document_data.dpi = 150
				DPI_300: document_data.dpi = 300
				DPI_600: document_data.dpi = 600
				DPI_1200: document_data.dpi = 1200
			)
	width_spin_box.value_changed.connect(
		func(new):
			document_data.paper_size_mm = Vector2(new, document_data.paper_size_mm.y)
			document_data.is_landscape = _get_landscape(document_data.paper_size_mm)
	)
	height_spin_box.value_changed.connect(
		func(new):
			document_data.paper_size_mm = Vector2(document_data.paper_size_mm.x, new)
			document_data.is_landscape = _get_landscape(document_data.paper_size_mm)
	)
	orientation_option_button.item_selected.connect(
		func(new):
			var is_land: bool = new == 1
			document_data.is_landscape = is_land
			var w: float = document_data.paper_size_mm.x
			var h: float = document_data.paper_size_mm.y
			if is_land:
				document_data.paper_size_mm = Vector2(max(w, h), min(w, h))
			else:
				document_data.paper_size_mm = Vector2(min(w, h), max(w, h))
	)
	paper_margins_spin_box.value_changed.connect(func(new): document_data.margins_mm = new)
	spacing_spin_box.value_changed.connect(func(new): document_data.spacing_mm = new)

func _set_preset_size(portrait_size: Vector2) -> void:
	if document_data.is_landscape:
		document_data.paper_size_mm = Vector2(portrait_size.y, portrait_size.x)
	else:
		document_data.paper_size_mm = portrait_size


func _get_landscape(size_mm: Vector2) -> bool:
	if size_mm.x > size_mm.y:
		return true
	else:
		return false


func _get_paper_preset(size_mm: Vector2):
	size_mm = Vector2(min(size_mm.x, size_mm.y), max(size_mm.x, size_mm.y))
	match size_mm:
		Vector2(210, 297):
			return PAPER_PRESET_A4
		Vector2(297, 420):
			return PAPER_PRESET_A3
		Vector2(148, 210):
			return PAPER_PRESET_A5
		_:
			return PAPER_PRESET_CUSTOM


func _sync_ui():
	paper_option_button.selected = _get_paper_preset(document_data.paper_size_mm)
	width_spin_box.set_value_no_signal(document_data.paper_size_mm.x)
	height_spin_box.set_value_no_signal(document_data.paper_size_mm.y)
	match document_data.dpi:
		72:
			dpi_option_button.selected = 72
		96:
			dpi_option_button.selected = 96
		150:
			dpi_option_button.selected = 150
		300:
			dpi_option_button.selected = 300
		600:
			dpi_option_button.selected = 600
		1200:
			dpi_option_button.selected = 1200
	orientation_option_button.selected = int(document_data.is_landscape)
	paper_margins_spin_box.set_value_no_signal(document_data.margins_mm)
	spacing_spin_box.set_value_no_signal(document_data.spacing_mm)
	pass
