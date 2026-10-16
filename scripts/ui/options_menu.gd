extends Control

## Pantalla completa de opciones, accesible desde el menú principal.

@export var options_panel: Control
@export var back_button: Button
@export var title_label: Label
@export var hint_label: Label


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_resolve_references()
	if title_label != null:
		title_label.text = "OPCIONES"
	if hint_label != null:
		hint_label.text = "Los cambios se guardan automáticamente."
	if back_button != null:
		back_button.pressed.connect(_on_back_pressed)
	if options_panel != null:
		options_panel.close_requested.connect(_on_back_pressed)


func _resolve_references() -> void:
	if options_panel == null:
		options_panel = get_node_or_null("Root/OptionsPanel") as Control
	if back_button == null:
		back_button = get_node_or_null("Root/BackButton") as Button
	if title_label == null:
		title_label = get_node_or_null("Root/TitleLabel") as Label
	if hint_label == null:
		hint_label = get_node_or_null("Root/HintLabel") as Label


func _on_back_pressed() -> void:
	if has_node("/root/GameManager"):
		GameManager.go_to_main_menu()
	else:
		get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
