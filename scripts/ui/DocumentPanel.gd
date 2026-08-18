@tool
class_name DocumentPanel
extends PanelContainer

@onready var workspace_tab_container: TabContainer = $WorkspaceTabContainer
@onready var home_panel: Panel = $HomePanel

@export var workspace_instance: PackedScene

signal import_assets_requested
signal open_document_requested

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	workspace_tab_container.child_entered_tree.connect(_update_view_state)
	workspace_tab_container.get_tab_bar().tab_close_pressed.connect(_on_tab_close_pressed)

	home_panel.new_document_requested.connect(open_document)
	home_panel.open_document_requested.connect(open_document_requested.emit)
	home_panel.import_assets_requested.connect(import_assets_requested.emit)

	_update_view_state(null)
	pass  # Replace with function body.


func _update_view_state(_node: Node = null) -> void:
	var workspace_count: int = workspace_tab_container.get_child_count()
	if workspace_count > 0:
		workspace_tab_container.visible = true
		home_panel.visible = false
	elif workspace_count <= 0:
		workspace_tab_container.visible = false
		home_panel.visible = true


func _on_tab_close_pressed(tab_idx: int) -> void:
	var tab_to_close: Node = workspace_tab_container.get_child(tab_idx)
	if tab_to_close:
		workspace_tab_container.remove_child(tab_to_close)
		tab_to_close.queue_free()
		_update_view_state()


func open_document(data: DocumentData = null, files: PackedStringArray = []) -> void:

	if data:
		for workspace in workspace_tab_container.get_children():
			if workspace.document_data.save_path == data.save_path:
				workspace_tab_container.current_tab = workspace.get_index()
				return

	var new_workspace_instance: WorkspaceInstance = workspace_instance.instantiate()

	if data == null:
		data = DocumentData.new()
		new_workspace_instance.name = "Document %d" % (workspace_tab_container.get_child_count() + 1)

	new_workspace_instance.setup(data, files)
	if data.save_path:
		new_workspace_instance.name = data.save_path.get_file().get_basename()

	workspace_tab_container.add_child(new_workspace_instance)

	workspace_tab_container.current_tab = new_workspace_instance.get_index()
