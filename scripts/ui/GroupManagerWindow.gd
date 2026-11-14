class_name GroupManagerWindow
extends Window

var group_asset: GroupAssetData:
	set(new):
		if group_asset and group_asset.changed.is_connected(_sync_ui):
			group_asset.changed.disconnect(_sync_ui)
		group_asset = new
		if group_asset and not group_asset.changed.is_connected(_sync_ui):
			group_asset.changed.connect(_sync_ui)

var selected_assets: Array[AssetData] = []

@onready var asset_list: ItemList = %AssetList

@onready var selected_asset_label: Label = %SelectedAssetLabel
@onready var selected_asset_type_label: Label = %SelectedAssetTypeLabel

@onready var slice_group_box: GroupBox = %SliceGroupBox
@onready var start_drag_box: DragBox = %StartDragBox
@onready var end_drag_box: DragBox = %EndDragBox

func request_open(group: GroupAssetData):
	asset_list.clear()
	group_asset = group
	for entry in group.children:
		var asset: AssetData = entry[0]
		var index: int = entry[1]
		asset_list.add_item(asset.display_name, PreviewTextureEngine.request(asset, index, 128, true))
	popup_centered(get_parent().get_window().size * 0.8)

var _selection_dirty: bool = false

func _on_multi_selected(_i: int, _s: bool):
	if not _selection_dirty:
		_selection_dirty = true
		_process_multi_selection.call_deferred()

func _process_multi_selection():
	var selected_items = asset_list.get_selected_items()
	if selected_items.size() != 1:
		selected_asset_label.text = "-"
		selected_asset_type_label.text = "-"
		slice_group_box.visible = false
	else:
		selected_assets.assign((selected_items as Array).map(func(i): return group_asset.children[i][0]))
		var selected_asset = selected_assets.back()
		selected_asset_label.text = selected_asset.display_name
		slice_group_box.visible = false
		if selected_asset is PdfAssetSlice:
			slice_group_box.visible = true
			start_drag_box.set_value_no_signal(selected_asset.start)
			start_drag_box.max_value = selected_asset.get_count()
			end_drag_box.set_value_no_signal(selected_asset.end)
		selected_asset_type_label.text = (func():
			if selected_asset is ImageAssetData:
				return "Image"
			elif selected_asset is PdfAssetData:
				return "PDF"
			elif selected_asset is PdfAssetSlice:
				return "PDF Slice"
		).call()

	_selection_dirty = false

func _sync_ui():
	pass

func _ready() -> void:
	close_requested.connect(
		func():
			# cancel()
			group_asset = null
			selected_assets.clear()
			hide()
	)
	asset_list.empty_clicked.connect(
		func(_i, mouse):
			if mouse == MOUSE_BUTTON_LEFT:
				asset_list.deselect_all()
	)
	asset_list.multi_selected.connect(_on_multi_selected)
	get_parent().get_window().size_changed.connect(
		func():
			if visible:
				popup_centered(get_parent().get_window().size * 0.8)
	)

