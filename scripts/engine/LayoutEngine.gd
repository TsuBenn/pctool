class_name LayoutEngine
extends RefCounted

static func calculate_layout(paper: PaperSheet, config: GridConfig, items: Array[AssetItem]) -> Array[Array]:
	var pages: Array[Array] = []
	var current_page: Array[PhotoSlot] = []
	var page_idx: int = 0

	var usable_size: Vector2 = config.get_usable_area_mm(paper)
	var cursor: Vector2 = Vector2.ZERO
	var current_row_height: float = 0.0

	for item in items:
		var tex: Texture2D = item.get("texture")
		var raw_size: Vector2 = item.size_mm
		var qty: int = item.quantity
		var id: String = item.source_id

		for i in range(qty):
			var slot_size = raw_size

			if config.auto_rotate and slot_size.x > usable_size.x and slot_size.y <= usable_size.x:
				slot_size = Vector2(slot_size.y, slot_size.x)

			if cursor.x + slot_size.x > usable_size.x:
				cursor.x = 0.0
				cursor.y += current_row_height + config.gap_mm
				current_row_height = 0.0

			if cursor.y + slot_size.y > usable_size.y:
				pages.append(current_page)
				current_page = []
				page_idx += 1
				cursor = Vector2.ZERO
				current_row_height = 0.0

			var slot = PhotoSlot.new()
			slot.texture = tex
			slot.size_mm = raw_size
			slot.is_rotated = (slot_size != raw_size)
			slot.source_id = id
			slot.page_index = page_idx

			var pos_x = config.margin_mm + config.offset_mm.x + cursor.x
			var pos_y = config.margin_mm + config.offset_mm.y + cursor.y
			slot.position_mm = Vector2(pos_x, pos_y)

			current_page.append(slot)

			cursor.x += slot_size.x + config.gap_mm
			current_row_height = max(current_row_height, slot_size.y)

	if not current_page.is_empty():
		pages.append(current_page)

	return pages
