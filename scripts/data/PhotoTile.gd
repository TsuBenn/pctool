class_name PhotoTile
extends RefCounted

var photo_item: PhotoItemData

var page_index: int = 0
var rect_mm: Rect2

var copy_index: int = 0
var sub_asset_index: int = 0

func _init(
	item: PhotoItemData = null,
	page_idx: int = 0,
	rect: Rect2 = Rect2(),
	copy_idx: int = 0,
	sub_asset_idx: int = 0
) -> void:
	self.photo_item = item
	self.page_index = page_idx
	self.rect_mm = rect
	self.copy_index = copy_idx
	self.sub_asset_index = sub_asset_idx
