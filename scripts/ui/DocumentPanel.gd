@tool
class_name DocumentPanel
extends PanelContainer

@onready var tab_container: TabContainer = $TabContainer
@onready var home_panel: Panel = $HomePanel

@export var workspace_instance: PackedScene

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	tab_container.child_entered_tree.connect(_update_view_state)
	tab_container.get_tab_bar().tab_close_pressed.connect(_on_tab_close_pressed)

	home_panel.new_document_requested.connect(open_document)

	_update_view_state(null)
	pass # Replace with function body.


func _update_view_state(_node: Node = null) -> void:
	var workspace_count: int = tab_container.get_child_count();
	if workspace_count > 0:
		tab_container.visible = true
		home_panel.visible = false
	elif workspace_count <= 0:
		tab_container.visible = false
		home_panel.visible = true

func _on_tab_close_pressed(tab_idx: int) -> void:
	var tab_to_close: Node = tab_container.get_child(tab_idx)
	if tab_to_close:
		tab_container.remove_child(tab_to_close)
		tab_to_close.queue_free()
		_update_view_state()

func open_document(data: DocumentData = null) -> void:
	var new_workspace_instance: WorkspaceInstance = workspace_instance.instantiate()

	if data == null:
		data = DocumentData.new()

	new_workspace_instance.setup(data)
	new_workspace_instance.name = "Document %d" % (tab_container.get_child_count() + 1)

	tab_container.add_child(new_workspace_instance)

	tab_container.current_tab = new_workspace_instance.get_index()
