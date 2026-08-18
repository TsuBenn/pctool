extends VBoxContainer
class_name CanvasPanel

signal on_photo_item_selected(photo_item: PhotoItemData)

enum ZoomPreset {
	PERCENT_50,
	PERCENT_100,
	PERCENT_150,
	PERCENT_200,
	CUSTOM,
}

var selected_photo_items: Array[PhotoItemData] = []

enum AddAssetAction { ADD, INCREMENT, FORCE_ADD }

@export var photo_tile_view_instance: PackedScene

var document_data: DocumentData

var print_layout: PrintLayout = PrintLayout.new()
var current_page_index: int = 0

@onready var paper_container: ScrollContainer = %PaperContainer
@onready var paper_margins_container: MarginContainer = %PaperMarginsContainer
@onready var paper_sheet: PanelContainer = %PaperSheet

@onready var photo_tiles_container: Control = %PhotoTilesContainer

@onready var margins_overlay: Control = %MarginOverlay

@onready var first_page_button: Button = %FirstPageButton
@onready var previous_page_button: Button = %PreviousPageButton
@onready var page_spin_box: SpinBox = %PageSpinBox
@onready var next_page_button: Button = %NextPageButton
@onready var last_page_button: Button = %LastPageButton

@onready var zoom_presets_option_button: OptionButton = %ZoomPresetsOptionButton
@onready var zoom_slider: HSlider = %ZoomSlider

@onready
var duplicate_assets_confirmation_dialog: ConfirmationDialog = %DuplicateAssetsConfirmationDialog

var view_scale: float = 1.0:
	set(new):
		view_scale = new
		_sync_ui()
@export var vertical_padding: int = 40
@export var horizontal_padding: int = 60

func advance_page(delta: int) -> bool:
	var new = clamp(current_page_index + delta, 0, print_layout.total_pages - 1)
	if current_page_index != new:
		current_page_index = new
		_sync_ui()
		return true
	return false

func _ready() -> void:
	paper_container.resized.connect(_sync_ui)
	margins_overlay.draw.connect(_draw_margins_overlay)
	paper_container.gui_input.connect(_on_paper_container_gui_input)
	first_page_button.pressed.connect(
		func():
			var new = 0
			if current_page_index != new:
				current_page_index = new
				_sync_ui()
	)
	previous_page_button.pressed.connect(
		func():
			advance_page(-1)
	)
	next_page_button.pressed.connect(
		func():
			advance_page(1)
	)
	last_page_button.pressed.connect(
		func():
			var new = print_layout.total_pages - 1
			if current_page_index != new:
				current_page_index = new
				_sync_ui()
	)
	zoom_presets_option_button.item_selected.connect(
		func(new):
			var selected_id = zoom_presets_option_button.get_item_id(new)
			match selected_id:
				ZoomPreset.PERCENT_50:
					zoom_slider.value = 50
				ZoomPreset.PERCENT_100:
					zoom_slider.value = 100
				ZoomPreset.PERCENT_150:
					zoom_slider.value = 150
				ZoomPreset.PERCENT_200:
					zoom_slider.value = 200
	)
	zoom_slider.value_changed.connect(
		func(new):
			view_scale = new / 100
			match int(new):
				50:
					zoom_presets_option_button.selected = zoom_presets_option_button.get_item_index(
						ZoomPreset.PERCENT_50
					)
				100:
					zoom_presets_option_button.selected = zoom_presets_option_button.get_item_index(
						ZoomPreset.PERCENT_100
					)
				150:
					zoom_presets_option_button.selected = zoom_presets_option_button.get_item_index(
						ZoomPreset.PERCENT_150
					)
				200:
					zoom_presets_option_button.selected = zoom_presets_option_button.get_item_index(
						ZoomPreset.PERCENT_200
					)
				_:
					var custom_index = zoom_presets_option_button.get_item_index(ZoomPreset.CUSTOM)
					zoom_presets_option_button.selected = custom_index
					zoom_presets_option_button.set_item_text(
						custom_index, "Custom (%d%%)" % (view_scale * 100)
					)
	)

	paper_margins_container.add_theme_constant_override("margin_top", vertical_padding)
	paper_margins_container.add_theme_constant_override("margin_bottom", vertical_padding)
	paper_margins_container.add_theme_constant_override("margin_left", horizontal_padding)
	paper_margins_container.add_theme_constant_override("margin_right", horizontal_padding)

	duplicate_assets_confirmation_dialog.ok_button_text = "Increment Quantity"
	duplicate_assets_confirmation_dialog.add_button("Add as New Item", false, "add_new")

	duplicate_assets_confirmation_dialog.canceled.connect(
		func():
			assets_on_hold.clear()
	)
	duplicate_assets_confirmation_dialog.confirmed.connect(
		func():
			if not assets_on_hold:
				return
			add_asset_to_sheet(assets_on_hold, AddAssetAction.INCREMENT)
			assets_on_hold.clear()
	)
	duplicate_assets_confirmation_dialog.custom_action.connect(
		func(action):
			if not assets_on_hold or action != "add_new":
				return
			add_asset_to_sheet(assets_on_hold, AddAssetAction.FORCE_ADD)
			duplicate_assets_confirmation_dialog.hide()
			assets_on_hold.clear()
	)


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	# Only accept drops that carry our specific asset payload
	if data is Dictionary and data.get("type") == "asset_data_group":
		return true
	return false


func _drop_data(at_position: Vector2, data: Variant) -> void:
	if data is Dictionary and data.get("type") == "asset_data_group":
		var dropped_assets: Array[AssetData] = data.get("assets")
		if dropped_assets:
			add_asset_to_sheet(dropped_assets)

func setup(data):
	document_data = data
	document_data.changed.connect(_sync_ui)
	_sync_ui()

var _is_panning: bool = false


func _on_paper_container_gui_input(event: InputEvent):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.is_pressed():
				_deselect_all_photo_items()
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			if event.is_pressed():
				_is_panning = true
				paper_container.mouse_default_cursor_shape = CursorShape.CURSOR_DRAG
			elif event.is_released():
				_is_panning = false
				paper_container.mouse_default_cursor_shape = CursorShape.CURSOR_ARROW
			accept_event()
		elif event.is_pressed():
			if event.ctrl_pressed:
				if event.button_index == MOUSE_BUTTON_WHEEL_UP:
					zoom_slider.value += 10
					accept_event()
				if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
					zoom_slider.value -= 10
					accept_event()
			else:
				if event.button_index == MOUSE_BUTTON_WHEEL_UP and paper_container.scroll_vertical <= floor(paper_container.get_v_scroll_bar().min_value):
					if advance_page(-1):
						paper_container.set_deferred("scroll_vertical", paper_container.get_v_scroll_bar().max_value - paper_container.get_v_scroll_bar().page)
					accept_event()
				if event.button_index == MOUSE_BUTTON_WHEEL_DOWN and paper_container.scroll_vertical >= floor(paper_container.get_v_scroll_bar().max_value - paper_container.get_v_scroll_bar().page):
					if advance_page(1):
						paper_container.scroll_vertical = 0
					accept_event()
	if event is InputEventMouseMotion and _is_panning:
		paper_container.scroll_horizontal -= int(event.relative.x)
		paper_container.scroll_vertical -= int(event.relative.y)
		accept_event()


func _get_px_per_mm_scale() -> float:
	var scale_w = (paper_container.size.x - horizontal_padding * 2) / document_data.paper_size_mm.x
	var scale_h = (paper_container.size.y - vertical_padding * 2) / document_data.paper_size_mm.y
	var fit_scale = min(scale_w, scale_h) * view_scale
	return fit_scale


func _get_preview_size(scale_px_per_mm: float) -> Vector2:
	return document_data.paper_size_mm * scale_px_per_mm


func _draw_margins_overlay():
	if not is_node_ready() or not document_data:
		return

	var preview_margins = (
		(document_data.margins_mm / document_data.paper_size_mm.x) * margins_overlay.size.x
	)

	var overlay_w = margins_overlay.size.x - preview_margins * 2
	var overlay_h = margins_overlay.size.y - preview_margins * 2

	var rect = Rect2(preview_margins, preview_margins, overlay_w, overlay_h)

	margins_overlay.draw_rect(rect, Color.from_rgba8(0, 0, 0, int(255 * 0.3)), false, 0.5, true)


var assets_on_hold: Array[AssetData]


func add_asset_to_sheet(
	asset_datas: Array[AssetData], add_asset_action: AddAssetAction = AddAssetAction.ADD, select_on_add: bool = false
):

	var on_hold: bool = false
	var duplicated_count: int = 0
	for asset in asset_datas:
		var incremented: bool = false
		match add_asset_action:
			AddAssetAction.ADD:
				for photo_item in document_data.photo_items:
					if photo_item.asset.id == asset.id:
						duplicated_count += 1
						duplicate_assets_confirmation_dialog.dialog_text = (
							'%s already on the paper sheet.\nWould you like to:\n - Increment its existing Photo Item quantity?\n - Add a new Photo Item itself?'
							% ("Asset of name " + str(asset.display_name) + " is" if duplicated_count == 1 else "There are " + str(duplicated_count) + " assets that are")
						)
						duplicate_assets_confirmation_dialog.popup_centered(Vector2i(180, 60))
						on_hold = true
						break
			AddAssetAction.INCREMENT:
				for photo_item in document_data.photo_items:
					if photo_item.asset.id == asset.id:
						photo_item.quantity += 1
						document_data.emit_changed()
						incremented = true

		if on_hold:
			assets_on_hold.append(asset)
			continue
		if incremented:
			continue

		var item: PhotoItemData = PhotoItemData.new()
		item.asset = asset
		item.size_mm = Vector2(30.0, 40.0)
		item.quantity = 1
		document_data.add_photo_item_no_signal(item)
		if select_on_add:
			_deselect_all_photo_items()
			selected_photo_items.append(item)
			on_photo_item_selected.emit(item)

	document_data.emit_changed()


func reinstantiate_photo_tile_views(scale_px_per_mm: float = _get_px_per_mm_scale()):
	for tile in photo_tiles_container.get_children():
		photo_tiles_container.remove_child(tile)
		tile.queue_free()

	current_page_index = clamp(current_page_index, 0, print_layout.total_pages)

	var new_tiles: Array[PhotoTile] = print_layout.get_page_tiles(current_page_index)

	for new_tile in new_tiles:
		var new_tile_view = photo_tile_view_instance.instantiate()

		photo_tiles_container.add_child(new_tile_view)
		new_tile_view.setup(new_tile, scale_px_per_mm, new_tile.photo_item in selected_photo_items, document_data.spacing_mm)
		new_tile_view.on_tile_view_clicked.connect(_on_tile_view_clicked)

func _deselect_all_photo_items(update_properties: bool = true):
	selected_photo_items.clear()
	for tile_view: PhotoTileView in photo_tiles_container.get_children():
		tile_view.is_selected = false
	if update_properties:
		on_photo_item_selected.emit(null)


func _on_tile_view_clicked(tile: PhotoTileView):
	if tile.photo_item in selected_photo_items:
		for tile_view: PhotoTileView in photo_tiles_container.get_children():
			if tile_view.photo_item == tile.photo_item:
				tile_view.is_selected = false
		selected_photo_items.erase(tile.photo_item)
		if selected_photo_items.size() > 0:
			on_photo_item_selected.emit(selected_photo_items.back())
		else:
			on_photo_item_selected.emit(null)
	else:
		_deselect_all_photo_items(false)
		for tile_view: PhotoTileView in photo_tiles_container.get_children():
			if tile_view.photo_item == tile.photo_item:
				tile_view.is_selected = true
		selected_photo_items.append(tile.photo_item)
		on_photo_item_selected.emit(tile.photo_item)
	pass

func _sync_ui():
	if not is_node_ready() or not document_data:
		return

	await get_tree().process_frame

	var scale_px_per_mm = _get_px_per_mm_scale()

	print_layout = ExportEngine._calculate_layout(document_data)

	var old_size: Vector2 = paper_sheet.custom_minimum_size
	var new_size: Vector2 = _get_preview_size(scale_px_per_mm)
	paper_sheet.custom_minimum_size = new_size

	reinstantiate_photo_tile_views(scale_px_per_mm)

	var delta: Vector2 = (new_size - old_size) * 0.5

	# Apply the scroll offset after ScrollContainer updates its scroll limits
	_apply_scroll_offset.call_deferred(delta)

	margins_overlay.queue_redraw()

	page_spin_box.suffix = "/" + str(print_layout.total_pages)
	advance_page(0)
	page_spin_box.set_value_no_signal(current_page_index + 1)

	# Responsive breakpoints
	zoom_presets_option_button.visible = paper_container.size.x > 238
	var show_page_nav: bool = paper_container.size.x > 158
	next_page_button.visible = show_page_nav
	previous_page_button.visible = show_page_nav


func _apply_scroll_offset(delta: Vector2) -> void:
	paper_container.set_deferred(
		"scroll_horizontal", paper_container.scroll_horizontal + int(delta.x)
	)
	# paper_container.set_deferred(
	# 	"scroll_vertical", paper_container.scroll_vertical + int(delta.y)
	# )
