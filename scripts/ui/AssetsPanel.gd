class_name AssetsPanel
extends VBoxContainer

signal add_asset_to_sheet(asset_data: AssetData)
signal request_import_dialog

@export var asset_card_instance: PackedScene

@onready var import_button: Button = %ImportButton

@onready var assets_empty_state_label: Label = %AssetsEmptyStateLabel

@onready var view_option_button: LabeledOptionButton = %ViewOptionButton

@onready var grid_assets_container: GridContainer = %GridAssetsContainer
@onready var list_assets_container: VBoxContainer = %ListAssetsContainer

@onready var grid_scale_slider: LabeledSlider = %GridScaleSlider
@onready var show_file_names_check_button: LabeledCheckButton = %ShowFileNamesCheckButton

@onready var assets_status_footer: PanelHeader = %AssetsStatusFooter

@onready var assets_scroll_container: ScrollContainer = %AssetsScrollContainer

@onready var asset_card_context_menu: PopupMenu = %AssetCardContextMenu
@onready var assets_container_context_menu: PopupMenu = %AssetsContainerContextMenu
@onready var assets_removal_confirmation_dialog: ConfirmationDialog = %AssetsRemovalConfirmationDialog

var document_data: DocumentData
var selected_asset_cards: Array[AssetCard] = []
var last_selected_asset_card: AssetCard = null

var view_mode: String:
	get:
		match view_option_button.selected:
			0:
				return "grid"
			1:
				return "list"
			_:
				return "null"


func setup(data: DocumentData):
	document_data = data
	if not document_data.assets.is_empty():
		for asset in document_data.assets:
			instantiate_asset_card(asset)

func _ready() -> void:
	view_option_button.item_selected.connect(_update_view_mode)

	import_button.pressed.connect(_on_import_button_pressed)

	grid_scale_slider.value_changed.connect(_update_grid_scale)
	show_file_names_check_button.toggled.connect(_update_file_names_visibility)

	assets_scroll_container.gui_input.connect(_on_assets_container_pressed)

	asset_card_context_menu.id_pressed.connect(_on_card_context_menu_pressed)
	assets_container_context_menu.id_pressed.connect(_on_container_context_menu_pressed)

	assets_removal_confirmation_dialog.confirmed.connect(func(): _remove_selected_assets(true))

	resized.connect(_on_resized)

	_update_status_footer()
	_update_view_mode(view_option_button.selected)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.is_pressed:
		if event.keycode == KEY_ESCAPE:
			_deselect_all_asset_cards()
			accept_event()
		elif event.keycode == KEY_A and event.ctrl_pressed:
			_select_all_asset_cards()
			accept_event()


func _on_assets_container_pressed(event: InputEvent):
	if event is InputEventMouseButton and event.is_pressed:
		if event.is_double_click() and event.button_index == MOUSE_BUTTON_LEFT:
			_on_import_button_pressed()
		elif event.button_index == MOUSE_BUTTON_LEFT and not event.ctrl_pressed:
			_deselect_all_asset_cards()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_show_container_context_menu(get_global_mouse_position())


func _on_import_button_pressed() -> void:
	request_import_dialog.emit()


func _update_status_footer():
	var count = (
		"%d assets"
		% (
			grid_assets_container.get_child_count()
			if view_mode == "grid"
			else list_assets_container.get_child_count()
		)
	)
	var selected = ""
	var dimensions = ""
	if selected_asset_cards.size() > 0:
		selected = "* %d selected" % selected_asset_cards.size()
		var last_selected_image = selected_asset_cards.back().asset_data.get_image(0)
		dimensions = (
			"(%dx%d px)" % [last_selected_image.get_width(), last_selected_image.get_height()]
		)
	assets_status_footer.title = count + " " + selected + ("\n" + dimensions if dimensions else "")


func _on_resized():
	var card_width = 32 + 32 * grid_scale_slider.value + 28
	var spacing = grid_assets_container.get_theme_constant("h_separation")
	var container_width = size.x - 20

	var new_columns = floor((container_width + spacing) / (card_width + spacing))

	grid_assets_container.columns = new_columns


func _update_grid_scale(new_scale: int):
	if view_mode != "grid":
		return

	for card: AssetCard in grid_assets_container.get_children():
		card.grid_scale = new_scale

	_on_resized()


func _update_file_names_visibility(toggled_on: bool):
	if view_mode != "grid":
		return

	for card: AssetCard in grid_assets_container.get_children():
		card.show_file_name = toggled_on


func _update_view_mode(selected: int) -> void:
	match selected:
		0:
			grid_scale_slider.visible = true
			show_file_names_check_button.visible = true
			for card: AssetCard in list_assets_container.get_children():
				grid_assets_container.visible = true
				list_assets_container.visible = false
				card.reparent(grid_assets_container)
				card.grid_scale = int(grid_scale_slider.value)
				card.show_file_name = show_file_names_check_button.button_pressed
				card.view_mode = AssetCard.ViewMode.GRID
		1:
			grid_scale_slider.visible = false
			show_file_names_check_button.visible = false
			for card: AssetCard in grid_assets_container.get_children():
				grid_assets_container.visible = false
				list_assets_container.visible = true
				card.reparent(list_assets_container)
				card.view_mode = AssetCard.ViewMode.LIST


func _deselect_all_asset_cards():
	for selected_card in selected_asset_cards:
		selected_card.is_selected = false
	selected_asset_cards.clear()
	last_selected_asset_card = null

func _select_all_asset_cards():
	_deselect_all_asset_cards()
	match view_mode:
		"grid":
			for card in grid_assets_container.get_children():
				selected_asset_cards.append(card)
				card.is_selected = true
				last_selected_asset_card = card
		"list":
			for card in list_assets_container.get_children():
				selected_asset_cards.append(card)
				card.is_selected = true
				last_selected_asset_card = card
	_update_status_footer()

func _on_card_clicked(card: AssetCard, ctrl_pressed: bool, shift_pressed: bool):
	if not ctrl_pressed and not shift_pressed:
		_deselect_all_asset_cards()
		selected_asset_cards.append(card)
		last_selected_asset_card = card
		card.is_selected = true

	if ctrl_pressed and not shift_pressed:
		if card in selected_asset_cards:
			selected_asset_cards.erase(card)
			card.is_selected = false
			if selected_asset_cards.size() > 0:
				last_selected_asset_card = selected_asset_cards.back()
			else:
				last_selected_asset_card = null
		else:
			selected_asset_cards.append(card)
			last_selected_asset_card = card
			card.is_selected = true
	elif shift_pressed and not ctrl_pressed and selected_asset_cards.size() > 0:
		var last_selected = last_selected_asset_card.get_index()
		var selected = card.get_index()

		var lower = min(last_selected, selected)
		var upper = max(last_selected, selected)

		for i in range(lower, upper + 1):
			if i == last_selected:
				continue
			match view_mode:
				"grid":
					var current_card = grid_assets_container.get_child(i)
					if current_card and not current_card in selected_asset_cards:
						selected_asset_cards.append(current_card)
						current_card.is_selected = true
				"list":
					var current_card = list_assets_container.get_child(i)
					if current_card and not current_card in selected_asset_cards:
						selected_asset_cards.append(current_card)
						current_card.is_selected = true

	_update_status_footer()
	pass


func _on_card_double_clicked(card: AssetCard):
	_deselect_all_asset_cards()
	selected_asset_cards.append(card)
	last_selected_asset_card = card
	card.is_selected = true
	var result: Array[AssetData] = []
	result.assign([card.asset_data])
	add_asset_to_sheet.emit(result)


enum CardContextMenuAction {
	ADD_TO_SHEET,
	GROUP_SELECTED,
	DUPLICATE,
	RENAME,
	OPEN_LOCATION,
	REMOVE,
}

enum ContainerContextMenuAction { IMPORT, SELECT_ALL, VIEW_AS }


func _show_card_context_menu(card: AssetCard, global_mouse_pos: Vector2i):
	if not card in selected_asset_cards:
		_deselect_all_asset_cards()
		selected_asset_cards.append(card)
		card.is_selected = true

	asset_card_context_menu.set_item_disabled(
		asset_card_context_menu.get_item_index(CardContextMenuAction.GROUP_SELECTED),
		selected_asset_cards.size() < 2
	)

	asset_card_context_menu.position = global_mouse_pos
	asset_card_context_menu.exclusive = true
	asset_card_context_menu.popup()


func _show_container_context_menu(global_mouse_pos: Vector2i):
	_deselect_all_asset_cards()

	assets_container_context_menu.set_item_text(
		3,
		"View as List" if view_mode == "grid" else "View as Grid"
	)

	assets_container_context_menu.position = global_mouse_pos
	assets_container_context_menu.exclusive = true
	assets_container_context_menu.popup()


func _on_card_context_menu_pressed(id: int):
	match id:
		CardContextMenuAction.ADD_TO_SHEET:
			var asset_datas: Array[AssetData] = []
			asset_datas.assign(selected_asset_cards.map(func(asset_card): return asset_card.asset_data))
			add_asset_to_sheet.emit(asset_datas)
		CardContextMenuAction.GROUP_SELECTED:
			Global.notice("Feature Not Implemented", "Assets grouping has not been implemented!")
			pass
		CardContextMenuAction.DUPLICATE:
			Global.notice("Feature Not Implemented", "Assets Duplication has not been implemented!")
			pass
		CardContextMenuAction.RENAME:
			Global.notice("Feature Not Implemented", "Assets Renaming has not been implemented!")
			pass
		CardContextMenuAction.OPEN_LOCATION:
			Global.notice("Feature Not Implemented", "Opening Assets Location has not been implemented!")
			pass
		CardContextMenuAction.REMOVE:
			_remove_selected_assets()
	pass


func _on_container_context_menu_pressed(id: int):
	match id:
		ContainerContextMenuAction.IMPORT:
			request_import_dialog.emit()
		ContainerContextMenuAction.SELECT_ALL:
			match view_mode:
				"grid":
					for card: AssetCard in grid_assets_container.get_children():
						if not card in selected_asset_cards:
							selected_asset_cards.append(card)
						card.is_selected = true
				"list":
					for card: AssetCard in list_assets_container.get_children():
						if not card in selected_asset_cards:
							selected_asset_cards.append(card)
						card.is_selected = true
		ContainerContextMenuAction.VIEW_AS:
			match view_mode:
				"grid":
					view_option_button.selected = 1
					_update_view_mode(1)
				"list":
					view_option_button.selected = 0
					_update_view_mode(0)

func _remove_selected_assets(force_remove: bool = false) -> void:
	if selected_asset_cards.is_empty():
		return

	# 1. Collect targets
	var assets_to_delete: Array[AssetData] = []
	for card in selected_asset_cards:
		if card.asset_data:
			assets_to_delete.append(card.asset_data)

	# 2. Check how many are currently placed on the canvas
	var placed_items_to_remove: Array[PhotoItemData] = []
	for item in document_data.photo_items:
		if item.asset in assets_to_delete:
			placed_items_to_remove.append(item)

	# 3. If any are placed on the canvas and we're not force-removing, show prompt
	if not placed_items_to_remove.is_empty() and not force_remove:
		var count: int = placed_items_to_remove.size()
		assets_removal_confirmation_dialog.dialog_text = (
			"%s currently placed on the print sheet.\nRemoving will also clear its copies from the canvas. Continue?"
			% ("This asset is" if count == 1 else "There are %d items" % count)
		)
		assets_removal_confirmation_dialog.popup_centered(Vector2i(480, 160))
		return

	# 4. EXECUTE REMOVAL: Clean up canvas items first
	for item in placed_items_to_remove:
		document_data.remove_photo_item(item, false) # false = don't emit yet

	# 5. Clean up asset data
	for asset in assets_to_delete:
		document_data.assets.erase(asset)

	# 6. Clean up UI cards (iterate over duplicate to avoid iteration bugs)
	for card in selected_asset_cards.duplicate():
		var container = card.get_parent()
		if container:
			container.remove_child(card)
		card.queue_free()

	selected_asset_cards.clear()
	last_selected_asset_card = null

	# 7. Notify Canvas to redraw & update UI state
	document_data.emit_changed()
	_update_status_footer()

	# Show empty placeholder if no cards remain
	var total_cards = grid_assets_container.get_child_count() + list_assets_container.get_child_count()
	assets_empty_state_label.visible = (total_cards == 0)

func instantiate_asset_card(asset_data: AssetData) -> void:
	var new_asset_card: AssetCard = asset_card_instance.instantiate()

	if not new_asset_card:
		return

	assets_empty_state_label.visible = false

	match view_mode:
		"grid":
			new_asset_card.view_mode = AssetCard.ViewMode.GRID
			new_asset_card.grid_scale = int(grid_scale_slider.value)
			new_asset_card.show_file_name = show_file_names_check_button.button_pressed
			grid_assets_container.add_child(new_asset_card)
			grid_assets_container.visible = true
			list_assets_container.visible = false
		"list":
			new_asset_card.view_mode = AssetCard.ViewMode.LIST
			list_assets_container.add_child(new_asset_card)
			grid_assets_container.visible = false
			list_assets_container.visible = true

	_update_status_footer()
	new_asset_card.setup(asset_data)

	new_asset_card.card_clicked.connect(_on_card_clicked)
	new_asset_card.card_double_clicked.connect(_on_card_double_clicked)
	new_asset_card.context_menu_requested.connect(_show_card_context_menu)
