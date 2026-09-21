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

@export var margins_mm: float = 5.0:
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
		photo_items = new
		emit_changed()

@export var save_path: String = ""

func _init() -> void:
	if not Global.undo_redo.has(self):
		Global.undo_redo[self] = UndoRedo.new()

func _get_maximum_photo_item_size(photo_item: PhotoItemData, lock_ratio: bool = false) -> Vector2:
	var max_w: float = paper_size_mm.x - margins_mm * 2
	var max_h: float = paper_size_mm.y - margins_mm * 2

	var photo_aspect: float = photo_item.size_mm.aspect()

	if lock_ratio:
		if max_w/max_h < photo_aspect:
			max_h = max_w / photo_aspect
		else :
			max_w = max_h * photo_aspect

	return Vector2(max_w, max_h)

func add_photo_item_no_signal(photo_item: PhotoItemData):
	add_photo_item(photo_item, false)

func remove_photo_item_no_signal(photo_item: PhotoItemData):
	remove_photo_item(photo_item, false)

func clear_photo_items_no_signal():
	clear_photo_items(false)

func add_photo_item(photo_item: PhotoItemData, signal_changed: bool = true, pos: int = -1, commit: bool = true):
	if pos >= 0:
		photo_items.insert(pos, photo_item)
	else:
		photo_items.append(photo_item)
	photo_item.changed.connect(emit_changed)
	photo_item._document_data = self

	if commit:
		Global.undo_redo[self].create_action("Add Photo Item to Canvas")
		Global.undo_redo[self].add_do_method(
			func():
				add_photo_item(photo_item, true, pos, false)
		)
		Global.undo_redo[self].add_undo_method(
			func():
				remove_photo_item(photo_item, true, pos, false)
		)
		Global.undo_redo[self].commit_action(false)

	if signal_changed:
		emit_changed()

func duplicate_photo_item(photo_item: PhotoItemData, signal_changed: bool = true) -> PhotoItemData:
	var copy: PhotoItemData = photo_item.duplicate()
	var copy_framings: Dictionary[int, PhotoItemData.Framing] = photo_item.framings.duplicate(true)
	copy.framings = copy_framings
	add_photo_item(copy, signal_changed)

	return copy

func remove_photo_item(photo_item: PhotoItemData, signal_changed: bool = true, pos: int = -1, commit: bool = true):
	pos = photo_items.find(photo_item)
	photo_items.erase(photo_item)
	if photo_item.changed.is_connected(emit_changed):
		photo_item.changed.disconnect(emit_changed)

	if commit:
		Global.undo_redo[self].create_action("Remove Photo Item from Canvas")
		Global.undo_redo[self].add_do_method(
			func():
				remove_photo_item(photo_item, true, pos, false)
		)
		Global.undo_redo[self].add_undo_method(
			func():
				add_photo_item(photo_item, true, pos, false)
		)
		Global.undo_redo[self].commit_action(false)

	if signal_changed:
		emit_changed()

func clear_photo_items(signal_changed: bool = true):
	for photo_item in photo_items:
		if photo_item._document_data:
			photo_item._document_data = null
		if photo_item.changed.is_connected(emit_changed):
			photo_item.changed.disconnect(emit_changed)
	photo_items.clear()
	if signal_changed:
		emit_changed()

func clear_assets():
	for asset in assets:
		asset.clean()
	assets.clear()

func clean_up():
	clear_photo_items_no_signal()
	clear_assets()
