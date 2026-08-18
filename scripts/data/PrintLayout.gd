class_name PrintLayout
extends RefCounted

var pages: Array[Array] = []

var total_pages: int:
	get:
		return pages.size()

var unplaced_items: Array[PhotoItemData] = []


func _init():
	ensure_page(0)


func add_tile(tile: PhotoTile):
	ensure_page(tile.page_index)
	pages[tile.page_index].append(tile)


func ensure_page(page_idx: int):
	while pages.size() <= page_idx:
		var new_page: Array[PhotoTile] = []
		pages.append(new_page)


func get_page_tiles(page_idx: int) -> Array[PhotoTile]:
	if pages.size() > 0 and page_idx < pages.size():
		var result: Array[PhotoTile] = []
		result.assign(pages[page_idx])
		return result
	return []


func is_empty():
	return pages.is_empty() or (pages.size() == 1 and pages[0].is_empty())
