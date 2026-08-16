class_name AssetsPanel
extends VBoxContainer

@export var asset_card_instance: PackedScene

@onready var import_button: Button = %ImportButton

@onready var assets_empty_state_label: Label= %AssetsEmptyStateLabel

@onready var view_option_button: LabeledOptionButton = %ViewOptionButton

@onready var grid_assets_container: GridContainer = %GridAssetsContainer
@onready var list_assets_container: VBoxContainer = %ListAssetsContainer

@onready var grid_scale_slider: LabeledSlider = %GridScaleSlider
@onready var show_file_names_check_button: LabeledCheckButton = %ShowFileNamesCheckButton

@onready var assets_status_footer: PanelHeader = %AssetsStatusFooter

@onready var assets_scroll_container: ScrollContainer = %AssetsScrollContainer

@onready var asset_card_context_menu: PopupMenu = %AssetCardContextMenu
@onready var assets_container_context_menu: PopupMenu = %AssetsContainerContextMenu

var selected_asset_cards: Array[AssetCard] = []
var last_selected_asset_card: AssetCard = null

var view_mode: String:
	get:
		match view_option_button.selected_index:
			0:
				return "grid"
			1:
				return "list"
			_:
				return "null"

signal request_import_dialog

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	view_option_button.item_selected.connect(_update_view_mode)

	import_button.pressed.connect(_on_import_button_pressed)

	grid_scale_slider.value_changed.connect(_update_grid_scale)
	show_file_names_check_button.toggled.connect(_update_file_names_visibility)

	assets_scroll_container.gui_input.connect(_on_assets_container_pressed)

	resized.connect(_on_resized)

	_update_status_footer()
	_update_view_mode(view_option_button.selected_index)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.is_pressed and event.keycode == KEY_ESCAPE:
		_deselect_all_asset_cards()

func _on_assets_container_pressed(event: InputEvent):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed and not event.ctrl_pressed:
		_deselect_all_asset_cards()

func _on_import_button_pressed() -> void:
	request_import_dialog.emit()

func _update_status_footer():
	var count = "%d assets" % (grid_assets_container.get_child_count() if view_mode == "grid" else list_assets_container.get_child_count())
	var selected = ""
	var dimensions = ""
	if selected_asset_cards.size() > 0:
		selected = "* %d selected" % selected_asset_cards.size()
		var last_selected_image = selected_asset_cards.back().asset_data.get_image(0)
		dimensions = "(%dx%d px)" % [last_selected_image.get_width(),last_selected_image.get_height()]
	assets_status_footer.title = count + " " + selected + ("\n" + dimensions if dimensions else "")

func _on_resized():
	var card_width = 16 + 16*grid_scale_slider.value + 14
	var spacing = grid_assets_container.get_theme_constant("h_separation")
	var container_width = size.x - 10

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

func _update_view_mode(selected_index: int) -> void:
	match selected_index:
		0:
			grid_scale_slider.visible = true
			show_file_names_check_button.visible = true
			for card: AssetCard in list_assets_container.get_children():
				grid_assets_container.visible = true
				list_assets_container.visible = false
				card.reparent(grid_assets_container)
				card.grid_scale = int(grid_scale_slider.value)
				card.show_file_name = show_file_names_check_button.button_pressed
				card.view_mode = AssetCard.ViewMode.Grid
		1:
			grid_scale_slider.visible = false
			show_file_names_check_button.visible = false
			for card: AssetCard in grid_assets_container.get_children():
				grid_assets_container.visible = false
				list_assets_container.visible = true
				card.reparent(list_assets_container)
				card.view_mode = AssetCard.ViewMode.List

func _deselect_all_asset_cards():
	for selected_card in selected_asset_cards:
		selected_card.is_selected = false
	selected_asset_cards.clear()
	last_selected_asset_card = null

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

		var lower = min (last_selected, selected)
		var upper = max (last_selected, selected)

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

func _on_card_context_menu_requested(card: AssetCard, global_mouse_pos: Vector2i):
	asset_card_context_menu.position = global_mouse_pos
	asset_card_context_menu.popup()

func instantiate_asset_card(asset_data: AssetData) -> void:
	var new_asset_card: AssetCard = asset_card_instance.instantiate()

	if not new_asset_card:
		return

	assets_empty_state_label.visible = false

	match view_mode:
		"grid":
			new_asset_card.view_mode = AssetCard.ViewMode.Grid
			new_asset_card.grid_scale = int(grid_scale_slider.value)
			new_asset_card.show_file_name = show_file_names_check_button.button_pressed
			grid_assets_container.add_child(new_asset_card)
			grid_assets_container.visible = true
			list_assets_container.visible = false
		"list":
			new_asset_card.view_mode = AssetCard.ViewMode.List
			list_assets_container.add_child(new_asset_card)
			grid_assets_container.visible = false
			list_assets_container.visible = true

	_update_status_footer()
	new_asset_card.setup(asset_data)

	new_asset_card.card_clicked.connect(_on_card_clicked)
	new_asset_card.context_menu_requested.connect(_on_card_context_menu_requested)
