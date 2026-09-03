extends Window
class_name AdvancedCroppingWindow

var photo_item: PhotoItemData:
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

var sub_asset_index: int

var old_framing: Dictionary[int, PhotoItemData.Framing] = {}:
	set(new):
		old_framing = new.duplicate()

@export var frame_margin: int = 60
@export var zoom_scale: int = 100:
	set(new):
		zoom_scale = clamp(new, 20, 100)
		_sync_ui()

@onready var summary_label: Label = %SummaryLabel

@onready var previous_sub_asset_button: Button = %PreviousSubAssetButton
@onready var sub_asset_spin_box: LabeledSpinBox = %SubAssetSpinBox
@onready var selected_asset_label: Label = %SelectedAssetLabel
@onready var next_sub_asset_button: Button = %NextSubAssetButton

@onready var photo_item_panel: PanelContainer = %PhotoItemPanel
@onready var photo_item_background: Panel = %PhotoItemBackground
@onready var photo_item_image: TextureRect = %PhotoItemImage
@onready var photo_item_frame: Panel = %PhotoItemFrame

@onready var zoom_spin_box: LabeledSpinBox = %ZoomSpinBox
@onready var offset_x_spin_box: LabeledSpinBox = %OffsetXSpinBox
@onready var offset_y_spin_box: LabeledSpinBox = %OffsetYSpinBox

@onready var cancel_button: Button = %CancelButton
@onready var done_button: Button = %DoneButton

@onready var zoom_scale_spin_box: LabeledSpinBox = %ZoomScaleSpinBox
@onready var zoom_scale_slider: HSlider = %ZoomScaleSlider

func _ready() -> void:
	zoom_spin_box.value_changed.connect(
		func(new):
			photo_item.set_framing_scale(sub_asset_index, new/100, true)
	)
	offset_x_spin_box.value_changed.connect(
		func(new):
			photo_item.set_framing_offset_x(sub_asset_index, new/100)
	)
	offset_y_spin_box.value_changed.connect(
		func(new):
			photo_item.set_framing_offset_y(sub_asset_index, new/100)
	)
	next_sub_asset_button.pressed.connect(
		func():
			sub_asset_index += 1
			_sync_ui()
	)
	previous_sub_asset_button.pressed.connect(
		func():
			sub_asset_index -= 1
			_sync_ui()
	)
	zoom_scale_spin_box.value_changed.connect(
		func(new):
			zoom_scale = new
	)
	zoom_scale_slider.value_changed.connect(
		func(new):
			zoom_scale = new
	)
	done_button.pressed.connect(
		func():
			hide()
	)
	cancel_button.pressed.connect(
		func():
			cancel()
			hide()
	)
	min_size = Vector2(730,440)
	# size_changed.connect(_sync_ui)
	photo_item_panel.resized.connect(_sync_ui)
	close_requested.connect(
		func():
			cancel()
			hide()
	)
	photo_item_panel.gui_input.connect(panel_gui_input)
	_sync_ui()

var _is_panning: bool = false

func panel_gui_input(event: InputEvent):
	if event is InputEventMouseButton:
		if event.is_pressed():
			if event.button_index == MOUSE_BUTTON_LEFT:
				_is_panning = true
			elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
				if event.ctrl_pressed:
					zoom_scale *= 1.1
				else:
					zoom_spin_box.value *= 1.05 if event.shift_pressed else 1.2
					zoom_spin_box.value = max(zoom_spin_box.value, 100)
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				if event.ctrl_pressed:
					zoom_scale /= 1.1
				else:
					zoom_spin_box.value /= 1.05 if event.shift_pressed else 1.2
					zoom_spin_box.value = max(zoom_spin_box.value, 100)
		elif event.is_released():
			if event.button_index == MOUSE_BUTTON_LEFT:
				_is_panning = false
	if event is InputEventMouseMotion:
		if _is_panning:
			var image_rect = photo_item.get_image_rect_mm(sub_asset_index)
			var px = ((image_rect.size - photo_item.size_mm)*_get_scale()*(zoom_scale/100.0)/2)
			var framing = photo_item.get_framing(sub_asset_index)
			framing.offset.x -= (event.relative.x/px.x) if px.x > 0 else 0
			framing.offset.y += (event.relative.y/px.y) if px.y > 0 else 0

			photo_item.set_framing_offset(sub_asset_index, framing.offset)

func cancel():
	photo_item.framings = old_framing.duplicate()
	photo_item.emit_changed()
	old_framing = {}

func request_open(item: PhotoItemData, index: int = 0):
	if item:
		photo_item = item
		sub_asset_index = index
		photo_item_image.texture = photo_item.asset.get_preview_texture(index)
		old_framing = photo_item.framings
		popup_centered(get_parent().get_window().size*0.8)
		_sync_ui()

func _get_scale():
	var scale_x: float = (photo_item_panel.size.x - frame_margin*2) / photo_item.size_mm.x
	var scale_y: float = (photo_item_panel.size.y - frame_margin*2) / photo_item.size_mm.y

	return min(scale_x, scale_y)

func _sync_ui():
	if not photo_item:
		return

	sub_asset_index = clamp(sub_asset_index, 0, photo_item.asset.get_count() - 1)
	summary_label.text = "Size: %dmm x %dmm" % [photo_item.size_mm.x, photo_item.size_mm.y]

	var framing = photo_item.get_framing(sub_asset_index)

	var scale = _get_scale()
	var image_rect = photo_item.get_image_rect_mm(sub_asset_index)

	zoom_scale_slider.set_value_no_signal(zoom_scale)
	zoom_scale_spin_box.set_value_no_signal(zoom_scale)

	photo_item_background.custom_minimum_size = photo_item.size_mm * scale * (zoom_scale/100.0)
	photo_item_frame.custom_minimum_size = photo_item.size_mm * scale * (zoom_scale/100.0)

	photo_item_image.custom_minimum_size = image_rect.size * scale * (zoom_scale/100.0)
	photo_item_image.offset_transform_position = image_rect.position * scale * (zoom_scale/100.0)

	var mat: ShaderMaterial = photo_item_image.material as ShaderMaterial
	if mat:
		var f_size = photo_item_frame.custom_minimum_size
		var pos = photo_item_image.offset_transform_position

		mat.set_shader_parameter("frame_rect", Vector4(max(-pos.x,0), max(-pos.y,0), f_size.x, f_size.y))


	selected_asset_label.text = photo_item.asset.display_name
	sub_asset_spin_box.set_value_no_signal(sub_asset_index + 1)

	sub_asset_spin_box.suffix = "/%s" % photo_item.asset.get_count()

	zoom_spin_box.set_value_no_signal(framing.scale * 100)
	offset_x_spin_box.set_value_no_signal(framing.offset.x*100)
	offset_y_spin_box.set_value_no_signal(framing.offset.y*100)
