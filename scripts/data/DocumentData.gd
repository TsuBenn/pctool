class_name DocumentData
extends Resource

@export var paper_size_mm: Vector2 = Vector2(210, 297):
	set(new):
		if paper_size_mm != new:
			paper_size_mm = new
			emit_changed()

@export var dpi: int = 300:
	set(new):
		if dpi != new:
			dpi = new
			emit_changed()

@export var is_landscape: bool = false:
	set(new):
		if is_landscape != new:
			is_landscape = new
			if new:
				paper_size_mm = Vector2(max(paper_size_mm.x, paper_size_mm.y), min(paper_size_mm.x, paper_size_mm.y))
			else:
				paper_size_mm = Vector2(min(paper_size_mm.x, paper_size_mm.y), max(paper_size_mm.x, paper_size_mm.y))
			emit_changed()

@export var margins_mm: float = 20.0:
	set(new):
		if margins_mm != new:
			margins_mm = new
			emit_changed()

@export var spacing_mm: float = 5.0:
	set(new):
		if spacing_mm != new:
			spacing_mm = new
			emit_changed()

@export var assets: Array[AssetData] = []:
	set(new):
		if assets != new:
			assets = new
			emit_changed()

@export var photo_items: Array[PhotoItemData] = []:
	set(new):
		if photo_items != new:
			photo_items = new
			emit_changed()

@export var save_path: String = ""

func add_photo_item_no_signal(photo_item: PhotoItemData):
	add_photo_item(photo_item, false)

func remove_photo_item_no_signal(photo_item: PhotoItemData):
	remove_photo_item(photo_item, false)

func clear_photo_items_no_signal():
	clear_photo_items(false)

func add_photo_item(photo_item: PhotoItemData, signal_changed: bool = true):
	photo_items.append(photo_item)
	photo_item.changed.connect(emit_changed)
	if signal_changed:
		emit_changed()

func remove_photo_item(photo_item: PhotoItemData, signal_changed: bool = true):
	photo_items.erase(photo_item)
	if photo_item.changed.is_connected(emit_changed):
		photo_item.changed.disconnect(emit_changed)
	if signal_changed:
		emit_changed()

func clear_photo_items(signal_changed: bool = true):
	for photo_item in photo_items:
		if photo_item.changed.is_connected(emit_changed):
			photo_item.changed.disconnect(emit_changed)
	photo_items.clear()
	if signal_changed:
		emit_changed()


