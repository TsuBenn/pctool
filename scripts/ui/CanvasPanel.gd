extends VBoxContainer
class_name CanvasPanel

signal on_photo_item_selected(photo_item: PhotoItemData, sub_asset_index: int)

enum ZoomPreset {
	PERCENT_50,
	PERCENT_100,
	PERCENT_150,
	PERCENT_200,
	CUSTOM,
}

var selected_photo_item: PhotoItemData = null
var selected_sub_asset_index: int = 0

enum AddAssetAction { ADD, INCREMENT, FORCE_ADD }

@export var photo_tile_view_instance: PackedScene

var document_data: DocumentData

var print_layout: PrintLayout = PrintLayout.new()
var current_page_index: int = 0

@onready var paper_container: Control = %PaperContainer
@onready var paper_anchor: Control = %PaperAnchor

@onready var paper_sheet: PanelContainer = %PaperSheet

@onready var photo_tiles_container: Control = %PhotoTilesContainer

@onready var margins_overlay: Control = %MarginOverlay

@onready var paper_container_v_scrollbar: VScrollBar = %PaperContainerVScrollBar
@onready var paper_container_h_scrollbar: HScrollBar = %PaperContainerHScrollBar

@onready var first_page_button: Button = %FirstPageButton
@onready var previous_page_button: Button = %PreviousPageButton
@onready var page_spin_box: SpinBox = %PageSpinBox
@onready var next_page_button: Button = %NextPageButton
@onready var last_page_button: Button = %LastPageButton

@onready var zoom_presets_option_button: OptionButton = %ZoomPresetsOptionButton
@onready var zoom_slider: HSlider = %ZoomSlider

@onready var canvas_context_menu: PopupMenuSimplified = %CanvasContextMenu
@onready var photo_tile_context_menu: PopupMenuSimplified = %PhotoTileContextMenu

@onready
var duplicate_assets_confirmation_dialog: ConfirmationDialog = %DuplicateAssetsConfirmationDialog

var view_scale: float = 1.0:
	set(new):
		view_scale = new
		_sync_ui()

var view_offset: Vector2 = Vector2.ZERO:
	set(new):
		view_offset = _clamp_offset(new)
		paper_anchor.offset_transform_enabled = true
		paper_anchor.offset_transform_position = view_offset
		update_scrollbars()

var offset_padding: Vector2:
	get:
		if paper_sheet.is_node_ready():
			return Vector2(paper_padding*2,paper_padding)
		else:
			return Vector2.ZERO


@export var paper_padding: int = 16

func advance_page(delta: int) -> bool:
	var new = clamp(current_page_index + delta, 0, print_layout.total_pages - 1)
	if current_page_index != new:
		current_page_index = new
		_sync_ui()
		return true
	return false

func _ready() -> void:
	canvas_context_menu.id_pressed.connect(_on_canvas_context_menu_pressed)
	photo_tile_context_menu.id_pressed.connect(_on_photo_tile_context_menu_pressed)
	paper_container.resized.connect(
	func():
		_sync_ui()
	)
	paper_container_v_scrollbar.value_changed.connect(
		func(new):
			view_offset.y = -new
	)
	paper_container_h_scrollbar.value_changed.connect(
		func(new):
			view_offset.x = -new
	)
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

			var custom_index = zoom_presets_option_button.get_item_index(ZoomPreset.CUSTOM)
			zoom_presets_option_button.set_item_text(
				custom_index, "Custom"
			)
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


func _drop_data(_at_position: Vector2, data: Variant) -> void:
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
				accept_event()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if event.is_pressed():
				_open_canvas_context_menu()
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			if event.is_pressed():
				_is_panning = event.is_pressed()
				paper_container.mouse_default_cursor_shape = CursorShape.CURSOR_DRAG
			elif event.is_released():
				_is_panning = event.is_pressed()
				paper_container.mouse_default_cursor_shape = CursorShape.CURSOR_ARROW
			accept_event()
		elif event.is_pressed():
			if event.ctrl_pressed:
				if event.button_index == MOUSE_BUTTON_WHEEL_UP:
					zoom_slider.value += 10
				elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
					zoom_slider.value -= 10
				accept_event()
			else:
				if event.button_index == MOUSE_BUTTON_WHEEL_UP:
					if view_offset.y == _get_clamped().y:
						if advance_page(-1):
							view_offset.y = -_get_clamped().y
					view_offset.y += 20
					accept_event()
				elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
					if view_offset.y == -_get_clamped().y:
						if advance_page(1):
							view_offset.y = _get_clamped().y
					view_offset.y -= 20
					accept_event()
	elif event is InputEventMouseMotion:
		if _is_panning:
			if Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE):
				view_offset += event.relative
				accept_event()
			else:
				_is_panning = false
				paper_container.mouse_default_cursor_shape = CursorShape.CURSOR_ARROW

enum {
		CANVAS_FIT_TO_WINDOW,
		CANVAS_CENTER_TO_WINDOW,
		CANVAS_ZOOM_IN,
		CANVAS_ZOOM_OUT,
		CANVAS_ROTATE_PAPER,
	}

enum {
		TILE_INCREMENT,
		TILE_DECREMENT,
		TILE_COPY_PROPERTIES,
		TILE_PASTE_PROPERTIES,
		TILE_DUPLICATE,
		TILE_REMOVE,
	}

var photo_item_clipboard: PhotoItemData = null
var photo_item_clipboard_sub_asset_index: int = 0

func _on_canvas_context_menu_pressed(id: int):
	match id:
		CANVAS_FIT_TO_WINDOW:
			zoom_slider.value = 100
			view_offset = Vector2.ZERO
		CANVAS_CENTER_TO_WINDOW:
			view_offset = Vector2.ZERO
		CANVAS_ZOOM_IN:
			zoom_slider.value += 10
		CANVAS_ZOOM_OUT:
			zoom_slider.value -= 10
		CANVAS_ROTATE_PAPER:
			document_data.is_landscape = not document_data.is_landscape

func _open_canvas_context_menu():
	canvas_context_menu.set_item_text(canvas_context_menu.get_item_index(CANVAS_ROTATE_PAPER), "Switch to Portrait" if document_data.is_landscape else "Switch to Landscape")
	canvas_context_menu.popup()

func _on_photo_tile_context_menu_pressed(id: int):
	var item = selected_photo_item
	if item:
		match id:
			TILE_INCREMENT:
				item.quantity += 1
			TILE_DECREMENT:
				item.quantity -= 1
			TILE_COPY_PROPERTIES:
				_copy_properties()
			TILE_PASTE_PROPERTIES:
				_paste_properties()
			TILE_DUPLICATE:
				var to_duplicate: Array[AssetData] = []
				to_duplicate.assign([item.asset])
				add_asset_to_sheet(to_duplicate, CanvasPanel.AddAssetAction.FORCE_ADD, true)
			TILE_REMOVE:
				selected_photo_item = null
				on_photo_item_selected.emit(null, 0)
				document_data.remove_photo_item(item)
				pass

func _copy_properties():
	if selected_photo_item:
		photo_item_clipboard = selected_photo_item.duplicate()
		photo_item_clipboard_sub_asset_index = selected_sub_asset_index

func _paste_properties():
	if photo_item_clipboard == null:
		Global.notice("Cannot Paste Properties", "Photo Item Data clipboard is empty, copy something first!")

	selected_photo_item.size_mm = photo_item_clipboard.size_mm
	selected_photo_item.rotation = photo_item_clipboard.rotation
	selected_photo_item.flipped_h = photo_item_clipboard.flipped_h
	selected_photo_item.flipped_v = photo_item_clipboard.flipped_v
	selected_photo_item.quantity = photo_item_clipboard.quantity
	selected_photo_item.filter_mode = photo_item_clipboard.filter_mode
	#selected_photo_item.fitting_mode = photo_item_clipboard.fitting_mode
	#selected_photo_item.scale = photo_item_clipboard.scale
	#selected_photo_item.offset = photo_item_clipboard.offset
	selected_photo_item.border_enabled = photo_item_clipboard.border_enabled
	selected_photo_item.border_width = photo_item_clipboard.border_width
	selected_photo_item.border_color = photo_item_clipboard.border_color


func _open_photo_tile_context_menu(tile: PhotoTileView):
	_deselect_all_photo_items(false)
	for tile_view: PhotoTileView in photo_tiles_container.get_children():
		if tile_view.photo_item == tile.photo_item:
			tile_view.is_selected = true
	selected_photo_item = tile.photo_item
	selected_sub_asset_index = tile.photo_tile.sub_asset_index
	on_photo_item_selected.emit(tile.photo_item, tile.photo_tile.sub_asset_index)
	photo_tile_context_menu.set_item_disabled(photo_tile_context_menu.get_item_index(TILE_PASTE_PROPERTIES), photo_item_clipboard == null)
	photo_tile_context_menu.popup()

func _get_px_per_mm_scale() -> float:
	var scale_w = (paper_container.size.x - paper_padding * 2) / document_data.paper_size_mm.x
	var scale_h = (paper_container.size.y - paper_padding * 2) / document_data.paper_size_mm.y
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

	margins_overlay.draw_rect(rect, Color.from_rgba8(0, 0, 0, int(255 * 0.3)), false, 1, true)


var assets_on_hold: Array[AssetData]


func add_asset_to_sheet(
	asset_datas: Array[AssetData], add_asset_action: AddAssetAction = AddAssetAction.ADD, select_on_add: bool = false
):
	var duplicated_count: int = 0
	for asset in asset_datas:
		var on_hold: bool = false
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
						duplicate_assets_confirmation_dialog.popup_centered(Vector2i(360, 120))
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
			selected_photo_item = item
			selected_sub_asset_index = 0
			on_photo_item_selected.emit(item, 0)

	document_data.emit_changed()


func reinstantiate_photo_tile_views(scale_px_per_mm: float = _get_px_per_mm_scale()):
	for tile in photo_tiles_container.get_children():
		photo_tiles_container.remove_child(tile)
		tile.queue_free()


	current_page_index = clamp(current_page_index, 0, max(print_layout.total_pages - 1, 0))

	var new_tiles: Array[PhotoTile] = print_layout.get_page_tiles(current_page_index)


	for new_tile in new_tiles:
		var new_tile_view = photo_tile_view_instance.instantiate()

		photo_tiles_container.add_child(new_tile_view)
		new_tile_view.setup(new_tile, scale_px_per_mm, new_tile.photo_item == selected_photo_item, new_tile.sub_asset_index == selected_sub_asset_index, document_data.spacing_mm)
		new_tile_view.on_tile_view_clicked.connect(_on_tile_view_clicked)
		new_tile_view.on_tile_view_right_clicked.connect(_open_photo_tile_context_menu)


func _deselect_all_photo_items(update_properties: bool = true):
	selected_photo_item = null
	for tile_view: PhotoTileView in photo_tiles_container.get_children():
		tile_view.is_selected = false
	if update_properties:
		on_photo_item_selected.emit(null, 0)


func _on_tile_view_clicked(tile: PhotoTileView):
	if tile.photo_item == selected_photo_item:
		for tile_view: PhotoTileView in photo_tiles_container.get_children():
			if tile_view.photo_item == tile.photo_item:
				tile_view.is_selected = false
		selected_photo_item = null
		on_photo_item_selected.emit(null, 0)
	else:
		_deselect_all_photo_items(false)
		for tile_view: PhotoTileView in photo_tiles_container.get_children():
			if tile_view.photo_item == tile.photo_item:
				tile_view.is_selected = true
		selected_photo_item = tile.photo_item
		selected_sub_asset_index = tile.photo_tile.sub_asset_index
		on_photo_item_selected.emit(tile.photo_item, tile.photo_tile.sub_asset_index)
	pass

func _sync_ui():
	if not is_node_ready() or not document_data:
		return

	var scale_px_per_mm = _get_px_per_mm_scale()

	print_layout = ExportEngine._calculate_layout(document_data)

	var new_size: Vector2 = _get_preview_size(scale_px_per_mm)
	paper_sheet.custom_minimum_size = new_size

	reinstantiate_photo_tile_views(scale_px_per_mm)

	margins_overlay.queue_redraw()

	page_spin_box.suffix = "/" + str(print_layout.total_pages)
	advance_page(0)
	page_spin_box.set_value_no_signal(current_page_index + 1)

	# Responsive breakpoints
	# print(paper_container.size.x)
	zoom_presets_option_button.visible = paper_container.size.x > 543
	var show_page_nav: bool = paper_container.size.x > 381
	next_page_button.visible = show_page_nav
	previous_page_button.visible = show_page_nav
	last_page_button.visible = show_page_nav
	first_page_button.visible = show_page_nav

	view_offset = _clamp_offset(view_offset)
	update_scrollbars()

func update_scrollbars():
	var pad_x: float = offset_padding.x
	var pad_y: float = offset_padding.y

	var paper_x: float = paper_sheet.custom_minimum_size.x
	var paper_y: float = paper_sheet.custom_minimum_size.y

	var view_x: float = paper_container.size.x
	var view_y: float = paper_container.size.y

	var clamped_x: float = max(pad_x - (view_x - paper_x)/2,0)
	var clamped_y: float = max(pad_y - (view_y - paper_y)/2,0)

	paper_container_v_scrollbar.page = paper_y
	paper_container_v_scrollbar.min_value = -clamped_y
	paper_container_v_scrollbar.max_value = clamped_y + paper_y
	paper_container_v_scrollbar.set_value_no_signal(-view_offset.y)
	paper_container_v_scrollbar.visible = paper_container_v_scrollbar.max_value - paper_container_v_scrollbar.min_value > paper_container_v_scrollbar.page

	paper_container_h_scrollbar.page = paper_x
	paper_container_h_scrollbar.min_value = -clamped_x
	paper_container_h_scrollbar.max_value = clamped_x + paper_x
	paper_container_h_scrollbar.visible = paper_container_h_scrollbar.max_value - paper_container_h_scrollbar.min_value > paper_container_h_scrollbar.page
	paper_container_h_scrollbar.set_value_no_signal(-view_offset.x)

func _get_clamped() -> Vector2:
	var pad_x: float = offset_padding.x
	var pad_y: float = offset_padding.y

	var paper_x: float = paper_sheet.size.x
	var paper_y: float = paper_sheet.size.y

	var view_x: float = paper_container.size.x
	var view_y: float = paper_container.size.y

	var clamped_x: float = max(pad_x - (view_x - paper_x)/2,0)
	var clamped_y: float = max(pad_y - (view_y - paper_y)/2,0)

	return Vector2(clamped_x, clamped_y)

func _clamp_offset(offset: Vector2) -> Vector2:

	var clamped: Vector2 = _get_clamped()

	return offset.clamp(Vector2(-clamped.x, -clamped.y),Vector2(clamped.x, clamped.y))
