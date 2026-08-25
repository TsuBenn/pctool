@tool
class_name PhotoTileView
extends Control

signal on_tile_view_clicked(tile: PhotoTileView)
signal on_tile_view_right_clicked(tile: PhotoTileView)

@onready var image_texture: TextureRect = %ImageTexture
@onready var selection_outline: Panel = %SelectionOutline
@onready var base_selection: Panel = %BaseSelection
@onready var border: ReferenceRect = %Border

var selection_padding: float = 0

var is_selected: bool = false:
	set(new):
		is_selected = new
		if is_node_ready():
			selection_outline.visible = new

var photo_tile: PhotoTile

var photo_item: PhotoItemData:
	get:
		return photo_tile.photo_item

var view_scale: float = 1.0:  # (MM TO PIXEL) * VIEWPORT_SCALE providied by CanvasPanel
	set(new):
		view_scale = new
		_update_tile_rect()


func setup(tile: PhotoTile, scale_px_per_mm: float, selected: bool = false, padding: float = 0):
	view_scale = scale_px_per_mm
	photo_tile = tile
	is_selected = selected
	selection_padding = padding + 1
	if is_node_ready():
		_update_tile_rect()


func _ready() -> void:
	_update_tile_rect()
	pass

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
			on_tile_view_clicked.emit(self)
			accept_event()
		if event.button_index == MOUSE_BUTTON_RIGHT and event.is_pressed():
			on_tile_view_right_clicked.emit(self)
			accept_event()

func _update_image_rect():
	if photo_item and photo_item.asset:
		image_texture.texture = photo_item.asset.get_preview_texture(photo_tile.sub_asset_index)

	var image_rect_mm: Rect2 = photo_item.get_image_rect_mm(photo_tile.sub_asset_index)
	image_texture.size = image_rect_mm.size * view_scale
	image_texture.position = image_rect_mm.position * view_scale
	image_texture.texture_filter = photo_item.filter_mode as TextureFilter
	pass


func _update_tile_rect():
	if not is_node_ready() or photo_tile == null or image_texture == null:
		return
	var tile_rect_mm: Rect2 = photo_tile.rect_mm
	size = tile_rect_mm.size * view_scale
	position = tile_rect_mm.position * view_scale

	var padding: float = selection_padding*view_scale/2

	if padding <= 1:
		base_selection.visible = false
	else:
		base_selection.visible = true
	selection_outline.get_theme_stylebox("panel").expand_margin_top    = padding
	selection_outline.get_theme_stylebox("panel").expand_margin_bottom = padding
	selection_outline.get_theme_stylebox("panel").expand_margin_left   = padding
	selection_outline.get_theme_stylebox("panel").expand_margin_right  = padding

	if photo_item:
		border.visible = photo_item.border_enabled
		border.border_width = snapped(max(photo_item.border_width * view_scale,1/get_window().content_scale_factor),1)

	_update_image_rect()
