class_name PdfSlicingWindow
extends Window

signal accept_slicing(pdf_asset: AssetData, start: int, end: int)
signal cancel_slicing()

var pdf_asset: AssetData

@onready var title_label: Label = %Title
@onready var start_drag_box: DragBox = %StartDragBox
@onready var end_drag_box: DragBox = %EndDragBox
@onready var cancel_button: Button = %CancelButton
@onready var create_slice_button: Button = %CreateSliceButton

func request_open(asset: AssetData):
	if asset:
		title_label.text = asset.display_name
		pdf_asset = asset
		if asset is PdfAssetData:
			title = "Slice PDF Asset"
			start_drag_box.value = 0
			start_drag_box.max_value = asset.page_count - 1
			end_drag_box.max_value = asset.page_count - 1
			end_drag_box.value = asset.page_count - 1
		elif asset is PdfAssetSlice:
			title = "Adjust PDF Slice"
			start_drag_box.value = asset.start
			start_drag_box.max_value = asset.pdf_asset.page_count - 1
			end_drag_box.value = asset.end
			end_drag_box.max_value = asset.pdf_asset.page_count - 1
		popup_centered()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.keycode == KEY_ESCAPE:
			cancel_slicing.emit()
			hide()

func _ready() -> void:
	start_drag_box.value_commit.connect(
		func(new):
			if new > end_drag_box.value:
				end_drag_box.set_value_no_signal(new)
	)
	end_drag_box.value_commit.connect(
		func(new):
			if new < start_drag_box.value:
				start_drag_box.set_value_no_signal(new)
	)
	cancel_button.pressed.connect(
		func():
			cancel_slicing.emit()
			hide()
	)
	create_slice_button.pressed.connect(
		func():
			accept_slicing.emit(pdf_asset, start_drag_box.value, end_drag_box.value)
			hide()
	)
	close_requested.connect(
		func():
			cancel_slicing.emit()
			hide()
	)

