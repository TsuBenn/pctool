@tool
class_name AssetCard
extends PanelContainer

signal card_clicked(card: AssetCard, ctrl_pressed: bool)
signal context_menu_requested(card: AssetCard, global_mouse_pose: Vector2)

enum ViewMode {Grid, List}

var asset_data: AssetData

@export var file_icon: Texture2D

var is_selected: bool = false:
	set(new_val):
		is_selected = new_val
		if selected_highlight.is_node_ready():
			selected_highlight.visible = new_val

var view_mode: ViewMode = ViewMode.Grid:
	set(new_mode):
		view_mode = new_mode
		update_view_mode(new_mode)

var grid_scale: int = 1:
	set(new_scale):
		grid_scale = new_scale
		if view_mode == ViewMode.Grid and is_node_ready():
			var thumbnail_size: int = 16 + 16*grid_scale
			texture_rect.custom_minimum_size = Vector2i(thumbnail_size, thumbnail_size)
			texture_rect.custom_maximum_size = Vector2i(thumbnail_size, thumbnail_size)

var show_file_name: bool = true:
	set(new_val):
		show_file_name = new_val
		if view_mode == ViewMode.Grid and is_node_ready():
			label.visible = new_val
			margin_container.add_theme_constant_override("margin_bottom", 3 if show_file_name else 6)

@onready var box_container: BoxContainer = %BoxContainer
@onready var margin_container: MarginContainer = %MarginContainer
@onready var texture_rect: TextureRect = %TextureRect
@onready var label: Label = %Label
@onready var panel_container: PanelContainer = %PanelContainer

@onready var selected_highlight: Panel = %SelectedHighlight

@onready var button: Button = %Button

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	update_view_mode(view_mode)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.is_pressed():
		if event.button_index == MOUSE_BUTTON_LEFT:
			card_clicked.emit(self, event.ctrl_pressed, event.shift_pressed)
			accept_event()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			context_menu_requested.emit(self, Vector2i(get_global_mouse_position()))
			accept_event()

func setup(asset: AssetData):
	asset_data = asset
	label.text = asset.display_name.get_basename()
	tooltip_text = asset.display_name
	update_view_mode(view_mode)

func update_view_mode(mode: ViewMode):
	if not is_node_ready():
		return
	match mode:
		ViewMode.Grid:
			var thumbnail_size: int = 16 + 16*grid_scale
			box_container.vertical = true
			if asset_data:
				texture_rect.texture = asset_data.get_preview_texture(0)
			texture_rect.custom_minimum_size = Vector2i(thumbnail_size, thumbnail_size)
			texture_rect.custom_maximum_size = Vector2i(thumbnail_size, thumbnail_size)
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			label.visible = show_file_name
			# label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			# label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
			label.autowrap_mode = TextServer.AUTOWRAP_OFF
			label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS_FORCE
			size_flags_horizontal = Control.SIZE_EXPAND_FILL
			panel_container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			panel_container.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
			margin_container.add_theme_constant_override("margin_left", 6)
			margin_container.add_theme_constant_override("margin_right", 6)
			margin_container.add_theme_constant_override("margin_top", 6)
			margin_container.add_theme_constant_override("margin_bottom", 3 if show_file_name else 6)
		ViewMode.List:
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
