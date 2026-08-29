extends Control
class_name Main

# MOUSE POINTERS
@export var pointer: Texture2D
@export var hand_point: Texture2D
@export var hand_grab: Texture2D
@export var hand: Texture2D
@export var text: Texture2D
@export var omni_dir: Texture2D
@export var diag_bottom_top_dir: Texture2D
@export var diag_top_bottom_dir: Texture2D
@export var hori_dir: Texture2D
@export var verti_dir: Texture2D
@export var hour_glass: Texture2D
@export var forbidden: Texture2D
@export var crosshair: Texture2D
@export var can_drop: Texture2D
@export var help: Texture2D

@onready var image_import_dialog: FileDialog = %ImageImportDialog
@onready var open_document_dialog: FileDialog = %OpenDocumentDialog
@onready var notice_dialog: AcceptDialog = %NoticeDialog
@onready var export_dialog: FileDialog = %ExportDialog

@onready var about_window: Window = %AboutWindow

@onready var workspace_tab_container: TabContainer = %WorkspaceTabContainer
@onready var document_panel: DocumentPanel = %DocumentPanel

var current_workspace: WorkspaceInstance:
	get:
		var workspace = workspace_tab_container.get_current_tab_control()
		if workspace:
			return workspace
		else:
			return null

@onready var file_menu: MenuButton = %FileMenu
@onready var edit_menu: MenuButton = %EditMenu
@onready var view_menu: MenuButton = %ViewMenu
@onready var help_menu: MenuButton = %HelpMenu

enum {
		FILE_NEW,
		FILE_OPEN,
		FILE_OPEN_RECENT,
		FILE_SAVE,
		FILE_SAVE_AS,
		FILE_IMPORT_ASSETS,
		FILE_EXPORT_PDF,
		FILE_EXPORT_IMAGE,
	}

enum {
		VIEW_FIT,
		VIEW_CENTER,
		VIEW_ZOOM_IN,
		VIEW_ZOOM_OUT,
	}

enum {
		HELP_ABOUT
	}

var export_mode: int = ExportEngine.EXPORT_PNG

@onready var update_checker: UpdateChecker = %UpdateChecker

func _ready() -> void:


	update_checker.check_for_updates()

	get_window().min_size = Vector2i(800, 600)

	file_menu.about_to_popup.connect(_file_menu_setup)
	file_menu.id_pressed.connect(_on_file_menu_pressed)

	view_menu.about_to_popup.connect(_view_menu_setup)
	view_menu.id_pressed.connect(_on_view_menu_pressed)

	help_menu.id_pressed.connect(
		func(id):
			match id:
				HELP_ABOUT:
					about_window.popup_centered()
	)

	document_panel.import_assets_requested.connect(func(): image_import_dialog.popup_centered(Vector2i(600,400)))
	document_panel.open_document_requested.connect(func(): open_document_dialog.popup_centered(Vector2i(600,400)))

	export_dialog.file_selected.connect(_export_file)
	open_document_dialog.files_selected.connect(_open_documents)
	image_import_dialog.files_selected.connect(_on_file_dropped)

	get_window().files_dropped.connect(_on_file_dropped)

	get_window().title = Global.app_title_prefix

	Global.on_noticed.connect(_show_notice_dialog)

	get_tree().node_added.connect(_on_node_added)
	_apply_nearest_filter(get_tree().root)
	_apply_custom_cursor()

func _export_file(file_path: String):
	if current_workspace:
		ExportEngine.export_document(current_workspace.document_data, file_path, export_mode)

func _open_documents(files: PackedStringArray):
	for file in files:
		var doc : DocumentData = DocumentManager.open_document(file)
		if not doc == null:
			doc.save_path = file
			document_panel.open_document(doc)

func _on_file_dropped(files: PackedStringArray) -> void:
	var image_files: PackedStringArray = []
	var document_files: PackedStringArray = []

	for file in files:
		if not FileAccess.file_exists(file):
			Global.notice("File Not Found", 'File from path "%s" does not exists!' % file)
			return

		var ext = file.get_extension().to_lower()

		if ["png", "jpg", "jpeg", "webp"].has(ext):
			image_files.append(file)
			continue
		elif ext == DocumentManager.EXTENSION:
			document_files.append(file)
			continue

		Global.notice("File Unsupported", 'Unsupported file format "%s" of path %s' % [file.get_extension(),file])
		return


	if not image_files.is_empty():
		if current_workspace:
			current_workspace._on_image_files_selected(image_files)
			return
		else:
			document_panel.open_document(null, files)
	if not document_files.is_empty():
		_open_documents(document_files)


func _file_menu_setup():
	var popup = file_menu.get_popup()
	if current_workspace == null:
		popup.set_item_disabled(popup.get_item_index(FILE_SAVE), true)
		popup.set_item_disabled(popup.get_item_index(FILE_SAVE_AS), true)
		popup.set_item_disabled(popup.get_item_index(FILE_IMPORT_ASSETS), true)
		popup.set_item_disabled(popup.get_item_index(FILE_EXPORT_PDF), true)
		popup.set_item_disabled(popup.get_item_index(FILE_EXPORT_IMAGE), true)
	else:
		popup.set_item_disabled(popup.get_item_index(FILE_SAVE), false)
		popup.set_item_disabled(popup.get_item_index(FILE_SAVE_AS), false)
		popup.set_item_disabled(popup.get_item_index(FILE_IMPORT_ASSETS), false)
		popup.set_item_disabled(popup.get_item_index(FILE_EXPORT_PDF), false)
		popup.set_item_disabled(popup.get_item_index(FILE_EXPORT_IMAGE), false)

func _view_menu_setup():
	var popup = view_menu.get_popup()
	if current_workspace == null:
		popup.set_item_disabled(popup.get_item_index(VIEW_FIT), true)
		popup.set_item_disabled(popup.get_item_index(VIEW_CENTER), true)
		popup.set_item_disabled(popup.get_item_index(VIEW_ZOOM_IN), true)
		popup.set_item_disabled(popup.get_item_index(VIEW_ZOOM_OUT), true)
	else:
		popup.set_item_disabled(popup.get_item_index(VIEW_FIT), false)
		popup.set_item_disabled(popup.get_item_index(VIEW_CENTER), false)
		popup.set_item_disabled(popup.get_item_index(VIEW_ZOOM_IN), false)
		popup.set_item_disabled(popup.get_item_index(VIEW_ZOOM_OUT), false)

func _on_file_menu_pressed(id: int):
	match id:
		FILE_NEW:
			document_panel.open_document()
		FILE_OPEN:
			open_document_dialog.popup_centered(Vector2i(600,400))
		FILE_SAVE:
			if current_workspace:
				current_workspace.request_save_document()
		FILE_SAVE_AS:
			if current_workspace:
				current_workspace.request_save_document("")
		FILE_IMPORT_ASSETS:
			current_workspace._on_import_dialog_requested()
		FILE_EXPORT_PDF:
			if current_workspace:
				export_mode = ExportEngine.EXPORT_PDF
				export_dialog.title = "Export to PDF"
				export_dialog.get_line_edit().text = current_workspace.name.to_lower().replace(" ", "-") + ".pdf"
				export_dialog.popup_centered(Vector2(600, 400))
		FILE_EXPORT_IMAGE:
			if current_workspace:
				export_mode = ExportEngine.EXPORT_PNG
				export_dialog.title = "Export to PNG(s)"
				export_dialog.get_line_edit().text = current_workspace.name.to_lower().replace(" ", "-") + ".png"
				export_dialog.popup_centered(Vector2(600, 400))

func _on_view_menu_pressed(id: int):
	if current_workspace:
		current_workspace.canvas_panel._on_canvas_context_menu_pressed(id)


func _request_export_document(mode: int = ExportEngine.EXPORT_PNG):
	export_mode = mode
	export_dialog.popup_centered(Vector2(600, 400))

func _show_notice_dialog(title: String, message: String, ok_button_text: String):
	notice_dialog.title = title
	notice_dialog.dialog_text = message
	notice_dialog.ok_button_text = ok_button_text
	notice_dialog.popup_centered(Vector2i(360, 180))


func _on_node_added(node: Node) -> void:
	_apply_nearest_filter(node)


func _apply_custom_cursor():
	var offset = 32
	Input.set_custom_mouse_cursor(pointer, Input.CURSOR_ARROW, Vector2(offset, offset))
	Input.set_custom_mouse_cursor(hand_point, Input.CURSOR_POINTING_HAND, Vector2(offset, offset))
	Input.set_custom_mouse_cursor(hand_grab, Input.CURSOR_DRAG, Vector2(offset, offset))
	# Input.set_custom_mouse_cursor(hand, Input.CURSOR_DRAG, Vector2(offset, offset))
	Input.set_custom_mouse_cursor(text, Input.CURSOR_IBEAM, Vector2(offset, offset))
	Input.set_custom_mouse_cursor(omni_dir, Input.CURSOR_MOVE, Vector2(offset, offset))
	Input.set_custom_mouse_cursor(
		diag_bottom_top_dir, Input.CURSOR_BDIAGSIZE, Vector2(offset, offset)
	)
	Input.set_custom_mouse_cursor(
		diag_top_bottom_dir, Input.CURSOR_FDIAGSIZE, Vector2(offset, offset)
	)
	Input.set_custom_mouse_cursor(hori_dir, Input.CURSOR_HSIZE, Vector2(offset, offset))
	Input.set_custom_mouse_cursor(verti_dir, Input.CURSOR_VSIZE, Vector2(offset, offset))
	Input.set_custom_mouse_cursor(hori_dir, Input.CURSOR_HSPLIT, Vector2(offset, offset))
	Input.set_custom_mouse_cursor(verti_dir, Input.CURSOR_VSPLIT, Vector2(offset, offset))
	Input.set_custom_mouse_cursor(crosshair, Input.CURSOR_CROSS, Vector2(offset, offset))
	Input.set_custom_mouse_cursor(hour_glass, Input.CURSOR_WAIT, Vector2(offset, offset))
	Input.set_custom_mouse_cursor(hour_glass, Input.CURSOR_BUSY, Vector2(offset, offset))
	Input.set_custom_mouse_cursor(can_drop, Input.CURSOR_CAN_DROP, Vector2(offset, offset))
	Input.set_custom_mouse_cursor(help, Input.CURSOR_HELP, Vector2(offset, offset))
	Input.set_custom_mouse_cursor(forbidden, Input.CURSOR_FORBIDDEN, Vector2(offset, offset))


func _apply_nearest_filter(node: Node) -> void:
	if node is Viewport:
		node.canvas_item_default_texture_filter = (
			Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
		)
	elif node is CanvasItem:
		node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
