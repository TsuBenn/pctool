extends Node

# Fired when OS files are dragged onto the window
signal files_dropped(paths: PackedStringArray, drop_position: Vector2)

# Fired when an asset quantity or size changes in the sidebar
signal asset_list_updated()

# Fired when the layout engine finishes calculating new pages
signal layout_recalculated(pages: Array)

# Fired when the user switches pages (e.g., Page 1 of 3)
signal page_changed(new_page_index: int)
