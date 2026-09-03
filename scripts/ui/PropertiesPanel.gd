extends VBoxContainer
class_name PropertiesPanel

signal add_asset_to_sheet(asset_datas: Array[AssetData])
signal request_advanced_cropping()

var document_data: DocumentData

var sub_asset_index: int = 0

var photo_item: PhotoItemData = null:
	set(new):
		if photo_item == new:
			return
		if photo_item and photo_item.changed.is_connected(_sync_ui):
			photo_item.changed.disconnect(_sync_ui)
		if new:
			new.changed.connect(_sync_ui)
		photo_item = new
		if not is_node_ready():
			return
		_sync_ui()

enum {
		PRESET_3_BY_4,
		PRESET_4_BY_6,
		PRESET_CUSTOM,
	}

@onready var properties_scroll_container: ScrollContainer = %PropertiesScrollContainer
@onready var properties_empty_state_label: Label = %PropertiesEmptyStateLabel

@onready var lock_ratio_check_button: CheckBox = %LockRatioCheckButton

@onready var properties_width_spin_box: LabeledSpinBox = %PropertiesWidthSpinBox
@onready var properties_height_spin_box: LabeledSpinBox = %PropertiesHeightSpinBox

@onready var properties_presets_option_button: LabeledOptionButton = %PropertiesPresetsOptionButton

@onready var decrement_quantity_button: Button = %DecrementQuantityButton
@onready var quantity_spin_box: LabeledSpinBox = %QuantitySpinBox
@onready var increment_quantity_button: Button = %IncrementQuantityButton

@onready var filter_mode_option_button: LabeledOptionButton = %FilterModeOptionButton

@onready var sub_asset_spin_box: LabeledSpinBox = %SubAssetSpinBox
@onready var fitting_mode_option_button: LabeledOptionButton = %FittingModeOptionButton

@onready var advanced_cropping_button: Button = %AdvancedCroppingButton

@onready var border_enabled_check_button: LabeledCheckButton = %BorderEnabledCheckButton
@onready var border_thickness_spin_box: LabeledSpinBox = %BorderThicknessSpinBox

@onready var properties_remove_button: Button = %PropertiesRemoveButton
@onready var properties_duplicate_button: Button = %PropertiesDuplicateButton

func setup(data: DocumentData):
	document_data = data
	document_data.changed.connect(_on_document_changed)

var lock_ratio: bool:
	get:
		return lock_ratio_check_button.button_pressed

func _ready() -> void:
	lock_ratio_check_button.toggled.connect(_on_document_changed)
	advanced_cropping_button.pressed.connect(request_advanced_cropping.emit)
	properties_remove_button.pressed.connect(
		func():
			var to_remove: PhotoItemData = photo_item
			self.photo_item = null
			document_data.remove_photo_item(to_remove)
	)
	properties_duplicate_button.pressed.connect(
		func():
			var to_duplicate: Array[AssetData] = []
			to_duplicate.assign([photo_item.asset])
			add_asset_to_sheet.emit(to_duplicate, CanvasPanel.AddAssetAction.FORCE_ADD, true)
	)
	border_enabled_check_button.toggled.connect(
		func(new):
			photo_item.border_enabled = new
	)
	border_thickness_spin_box.value_changed.connect(
		func(new):
			photo_item.border_width = new
	)
	filter_mode_option_button.item_selected.connect(
		func(new):
			photo_item.filter_mode = new
	)
	fitting_mode_option_button.item_selected.connect(
		func(new):
			photo_item.set_framing(sub_asset_index, photo_item.get_framing(sub_asset_index).scale, photo_item.get_framing(sub_asset_index).offset, new)
	)
	decrement_quantity_button.pressed.connect(
		func():
			photo_item.quantity = max(photo_item.quantity - 1, 1)
	)
	increment_quantity_button.pressed.connect(
		func():
			photo_item.quantity = max(photo_item.quantity + 1, 1)
	)
	quantity_spin_box.value_changed.connect(
		func(new):
			photo_item.quantity = new
	)
	properties_presets_option_button.item_selected.connect(
		func(new):
			match new:
				PRESET_3_BY_4:
					photo_item.size_mm = Vector2(30.0,40.0)
				PRESET_4_BY_6:
					photo_item.size_mm = Vector2(40.0,60.0)
	)
	properties_width_spin_box.value_changed.connect(
		func(new):
			var aspect = photo_item.size_mm.aspect()
			if aspect == 0:
				lock_ratio_check_button.button_pressed = false
			photo_item.size_mm = Vector2(new, (new / aspect) if lock_ratio else photo_item.size_mm.y)
			match photo_item.size_mm:
				Vector2(30.0,40.0):
					properties_presets_option_button.selected = PRESET_3_BY_4
				Vector2(40.0,60.0):
					properties_presets_option_button.selected = PRESET_4_BY_6
				_:
					properties_presets_option_button.selected = PRESET_CUSTOM
	)
	properties_height_spin_box.value_changed.connect(
		func(new):
			photo_item.size_mm = Vector2((new * photo_item.size_mm.aspect()) if lock_ratio else photo_item.size_mm.x, new)
			match photo_item.size_mm:
				Vector2(30.0,40.0):
					properties_presets_option_button.selected = PRESET_3_BY_4
				Vector2(40.0,60.0):
					properties_presets_option_button.selected = PRESET_4_BY_6
				_:
					properties_presets_option_button.selected = PRESET_CUSTOM
	)
	_sync_ui()

func _get_maximum_photo_item_size() -> Vector2:
	var max_w: float = document_data.paper_size_mm.x - document_data.margins_mm * 2
	var max_h: float = document_data.paper_size_mm.y - document_data.margins_mm * 2

	var photo_aspect: float = photo_item.size_mm.aspect()

	if lock_ratio:
		if max_w/max_h < photo_aspect:
			max_h = max_w / photo_aspect
		else :
			max_w = max_h * photo_aspect

	return Vector2(max_w, max_h)

func _on_document_changed():
	if not photo_item or not is_node_ready():
		return

	var max_size = _get_maximum_photo_item_size()

	properties_width_spin_box.max_value = max_size.x
	properties_height_spin_box.max_value = max_size.y

func _sync_ui():
	if photo_item:
		var framing = photo_item.get_framing(sub_asset_index)

		properties_scroll_container.visible = true
		properties_empty_state_label.visible = false
		match photo_item.size_mm:
			Vector2(30.0,40.0):
				properties_presets_option_button.selected = PRESET_3_BY_4
			Vector2(40.0,60.0):
				properties_presets_option_button.selected = PRESET_4_BY_6
			_:
				properties_presets_option_button.selected = PRESET_CUSTOM
		properties_width_spin_box.set_value_no_signal(photo_item.size_mm.x)
		properties_height_spin_box.set_value_no_signal(photo_item.size_mm.y)
		quantity_spin_box.set_value_no_signal(photo_item.quantity)
		filter_mode_option_button.selected = photo_item.filter_mode
		sub_asset_spin_box.max_value = photo_item.asset.get_count()
		sub_asset_spin_box.value = sub_asset_index + 1
		sub_asset_spin_box.suffix = "/%d" % photo_item.asset.get_count()
		fitting_mode_option_button.selected = framing.fitting_mode

		border_enabled_check_button.button_pressed = photo_item.border_enabled
		border_thickness_spin_box.set_value_no_signal(photo_item.border_width)

	else:
		properties_scroll_container.visible = false
		properties_empty_state_label.visible = true
