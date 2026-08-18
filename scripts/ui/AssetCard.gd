@tool
class_name AssetCard
extends PanelContainer

signal card_clicked(card: AssetCard, ctrl_pressed: bool)
signal card_double_clicked(card: AssetCard)
signal context_menu_requested(card: AssetCard, global_mouse_pose: Vector2)

enum ViewMode { GRID, LIST }

var asset_data: AssetData

@export var file_icon: Texture2D
@export var drag_preview: PackedScene

var is_selected: bool = false:
	set(new_val):
		is_selected = new_val
		if selected_highlight.is_node_ready():
			selected_highlight.visible = new_val

var view_mode: ViewMode = ViewMode.GRID:
	set(new_mode):
		view_mode = new_mode
		update_view_mode(new_mode)

var grid_scale: int = 1:
	set(new_scale):
		grid_scale = new_scale
		if view_mode == ViewMode.GRID and is_node_ready():
			var thumbnail_size: int = 16 + 16 * grid_scale
			texture_rect.custom_minimum_size = Vector2i(thumbnail_size, thumbnail_size)
			texture_rect.custom_maximum_size = Vector2i(thumbnail_size, thumbnail_size)

var show_file_name: bool = true:
	set(new_val):
		show_file_name = new_val
		if view_mode == ViewMode.GRID and is_node_ready():
			label.visible = new_val
			margin_container.add_theme_constant_override(
				"margin_bottom", 3 if show_file_name else 6
			)

@onready var box_container: BoxContainer = %BoxContainer
@onready var margin_container: MarginContainer = %MarginContainer
@onready var texture_rect: TextureRect = %TextureRect
@onready var label: Label = %Label
@onready var panel_container: PanelContainer = %PanelContainer

@onready var selected_highlight: Panel = %SelectedHighlight

@onready var button: Button = %Button


func _ready() -> void:
	update_view_mode(view_mode)


var _pressed_while_selected: bool = false

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.is_pressed():
			if event.button_index == MOUSE_BUTTON_LEFT:
				if event.is_double_click():
					card_double_clicked.emit(self)
					accept_event()

				if event.ctrl_pressed or event.shift_pressed:
					card_clicked.emit(self, event.ctrl_pressed, event.shift_pressed)
					accept_event()

				elif not is_selected:
					card_clicked.emit(self, false, false)
					accept_event()

				else:
					_pressed_while_selected = true

			elif event.button_index == MOUSE_BUTTON_RIGHT:
				context_menu_requested.emit(self, Vector2i(get_global_mouse_position()))
				accept_event()
		elif event.is_released():
			if event.button_index == MOUSE_BUTTON_LEFT and _pressed_while_selected:
					card_clicked.emit(self, false, false)
					_pressed_while_selected = false
			accept_event()


func _get_drag_data(at_position: Vector2) -> Variant:
	if asset_data == null:
		return null

	var preview_instance = drag_preview.instantiate()
	var preview_control = Control.new()
	preview_control.add_child(preview_instance)

	preview_instance.display_name = asset_data.display_name
	preview_instance.texture = asset_data.get_preview_texture(0)
	preview_instance.texture_size = Vector2i(16 + 16*grid_scale, 16 + 16*grid_scale)
	var assets_panel: AssetsPanel = find_parent("AssetsPanel")
	var asset_data_group: Array[AssetData] = []
	if assets_panel:
		asset_data_group.assign(assets_panel.selected_asset_cards.map(func(asset_card): return asset_card.asset_data))
		preview_instance.stack_count = assets_panel.selected_asset_cards.size()
	else:
		push_error("AssetCard: Failed to find AssetsPanel!")

	set_drag_preview(preview_control)

	return {"type": "asset_data_group", "assets": asset_data_group}


func setup(asset: AssetData):
	asset_data = asset
	label.text = asset.display_name.get_basename()
	tooltip_text = asset.display_name
	update_view_mode(view_mode)


func update_view_mode(mode: ViewMode):
	if not is_node_ready():
		return
	match mode:
		ViewMode.GRID:
			var thumbnail_size: int = 16 + 16 * grid_scale
			box_container.vertical = true
			if asset_data:
				texture_rect.texture = asset_data.get_preview_texture(0)
			texture_rect.custom_minimum_size = Vector2i(thumbnail_size, thumbnail_size)
			texture_rect.custom_maximum_size = Vector2i(thumbnail_size, thumbnail_size)
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			label.visible = show_file_name
			label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
			# label.autowrap_mode = TextServer.AUTOWRAP_OFF
			# label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS_FORCE
			size_flags_horizontal = Control.SIZE_EXPAND_FILL
			panel_container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			panel_container.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
			margin_container.add_theme_constant_override("margin_left", 6)
			margin_container.add_theme_constant_override("margin_right", 6)
			margin_container.add_theme_constant_override("margin_top", 6)
			margin_container.add_theme_constant_override(
				"margin_bottom", 3 if show_file_name else 6
			)
		ViewMode.LIST:
			box_container.vertical = false
			texture_rect.texture = file_icon
			texture_rect.custom_minimum_size = Vector2i(7, 7)
			texture_rect.custom_maximum_size = Vector2i(7, 7)
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			label.visible = true
			label.autowrap_mode = TextServer.AUTOWRAP_OFF
			label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS_FORCE
			size_flags_horizontal = Control.SIZE_EXPAND_FILL
			panel_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			panel_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
			margin_container.add_theme_constant_override("margin_left", 2)
			margin_container.add_theme_constant_override("margin_right", 2)
			margin_container.add_theme_constant_override("margin_top", 2)
			margin_container.add_theme_constant_override("margin_bottom", 1)
