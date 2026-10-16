extends CanvasLayer

## Menú de pausa. Se instancia dentro de cada escenario y se muestra u oculta
## reaccionando al estado global de GameManager, sin detener nada por su cuenta.

@export_group("Panels")
@export var main_panel: Control
@export var options_overlay: Control
@export var options_panel: Control

@export_group("Buttons")
@export var resume_button: Button
@export var options_button: Button
@export var main_menu_button: Button
@export var quit_button: Button

@export_group("Labels")
@export var title_label: Label
@export var hint_label: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_resolve_references()
	_setup_texts()
	_connect_buttons()
	_connect_game_manager()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		if options_overlay != null and options_overlay.visible:
			_on_options_closed()
		else:
			_on_resume_pressed()


func _resolve_references() -> void:
	if main_panel == null:
		main_panel = get_node_or_null("Root/MainPanel") as Control
	if options_overlay == null:
		options_overlay = get_node_or_null("Root/OptionsOverlay") as Control
	if options_panel == null:
		options_panel = get_node_or_null("Root/OptionsOverlay/OptionsPanel") as Control
	if resume_button == null:
		resume_button = get_node_or_null("Root/MainPanel/Layout/ResumeButton") as Button
	if options_button == null:
		options_button = get_node_or_null("Root/MainPanel/Layout/OptionsButton") as Button
	if main_menu_button == null:
		main_menu_button = get_node_or_null("Root/MainPanel/Layout/MainMenuButton") as Button
	if quit_button == null:
		quit_button = get_node_or_null("Root/MainPanel/Layout/QuitButton") as Button
	if title_label == null:
		title_label = get_node_or_null("Root/MainPanel/Layout/TitleLabel") as Label
	if hint_label == null:
		hint_label = get_node_or_null("Root/MainPanel/Layout/HintLabel") as Label


func _setup_texts() -> void:
	if title_label != null:
		title_label.text = "PAUSA"
	if resume_button != null:
		resume_button.text = "CONTINUAR"
	if options_button != null:
		options_button.text = "OPCIONES"
	if main_menu_button != null:
		main_menu_button.text = "MENÚ PRINCIPAL"
	if quit_button != null:
		quit_button.text = "SALIR DEL JUEGO"
	if hint_label != null:
		hint_label.text = "Pulsa Esc para continuar la partida."


func _connect_buttons() -> void:
	var buttons = [resume_button, options_button, main_menu_button, quit_button]
	for b in buttons:
		if b != null:
			b.pressed.connect(func() -> void:
				if has_node("/root/SoundManager"):
					SoundManager.play_ui_click()
			)
	if resume_button != null:
		resume_button.pressed.connect(_on_resume_pressed)
	if options_button != null:
		options_button.pressed.connect(_on_options_pressed)
	if main_menu_button != null:
		main_menu_button.pressed.connect(_on_main_menu_pressed)
	if quit_button != null:
		quit_button.pressed.connect(_on_quit_pressed)
	if options_panel != null:
		options_panel.close_requested.connect(_on_options_closed)



func _connect_game_manager() -> void:
	if not has_node("/root/GameManager"):
		return
	GameManager.state_changed.connect(_on_state_changed)
	_on_state_changed(GameManager.state)


# ------------------------------------------------------------------------------
# Manejadores
# ------------------------------------------------------------------------------

func _on_state_changed(new_state: int) -> void:
	var should_show: bool = false
	if has_node("/root/GameManager"):
		should_show = new_state == GameManager.GameState.PAUSED

	visible = should_show
	if should_show:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		if options_overlay != null:
			options_overlay.visible = false
		if main_panel != null:
			main_panel.visible = true
		if resume_button != null:
			resume_button.grab_focus()
	else:
		if has_node("/root/GameManager") and GameManager.is_3d_mode and new_state == GameManager.GameState.PLAYING:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_resume_pressed() -> void:
	if has_node("/root/GameManager"):
		GameManager.resume_game()


func _on_options_pressed() -> void:
	if options_overlay != null:
		options_overlay.visible = true
	if main_panel != null:
		main_panel.visible = false


func _on_options_closed() -> void:
	if options_overlay != null:
		options_overlay.visible = false
	if main_panel != null:
		main_panel.visible = true
	if options_button != null:
		options_button.grab_focus()


func _on_main_menu_pressed() -> void:
	if has_node("/root/GameManager"):
		GameManager.go_to_main_menu()


func _on_quit_pressed() -> void:
	if has_node("/root/GameManager"):
		GameManager.quit_game()
	else:
		get_tree().quit()
