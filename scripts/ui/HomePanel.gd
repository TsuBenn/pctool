class_name HomePanel
extends Panel

signal new_document_requested()

@onready var new_document_button: Button = %NewDocumentButton

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	new_document_button.pressed.connect(new_document_requested.emit)

