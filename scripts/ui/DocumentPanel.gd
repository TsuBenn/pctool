@tool
class_name DocumentPanel
extends PanelContainer

@onready var tab_container: TabContainer = $TabContainer
@onready var home_panel: Panel = $HomePanel

@export var workspace_instance: PackedScene

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	tab_container.child_entered_tree.connect(_update_view_state)
	tab_container.child_exiting_tree.connect(_update_view_state.call_deferred)

	_update_view_state(null)
	pass # Replace with function body.


func _update_view_state(_node: Node = null):
	var workspace_count: int = tab_container.get_child_count();
	if workspace_count > 0:
		tab_container.visible = true
		home_panel.visible = false
	elif workspace_count <= 0:
		tab_container.visible = false
		home_panel.visible = true


func open_document(data: DocumentData):
	var new_workspace_instance: WorkspaceInstance = workspace_instance.instantiate()

	if data == null:
		data = DocumentData.new()

	new_workspace_instance.setup(data)
	new_workspace_instance.name = "document%d" % (tab_container.get_child_count() + 1)

	tab_container.add_child(new_workspace_instance)

	tab_container.current_tab = new_workspace_instance.get_index()
