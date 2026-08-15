@tool
extends TabContainer

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	get_tab_bar().tab_close_display_policy = get_tab_bar().CLOSE_BUTTON_SHOW_ACTIVE_ONLY
