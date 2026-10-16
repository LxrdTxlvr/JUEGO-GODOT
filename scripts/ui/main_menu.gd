extends Control

## Pantalla de menú principal con selector interactivo 2D / 3D.
## Permite al usuario elegir en primera instancia entre jugar en 2D o en 3D,
## adaptando instantáneamente los botones de campaña (Escenarios 1, 2, Jefe Final)
## y el modo infinito para lanzar la experiencia seleccionada.

@export_group("Mode Selector")
var mode_2d_button: Button
var mode_3d_button: Button
var campaign_header: Label
var class_info_label: Label

@export_group("Buttons")
@export var level_1_button: Button
@export var level_2_button: Button
@export var level_3_button: Button
@export var endless_button: Button
@export var options_button: Button
@export var how_to_play_button: Button
@export var quit_button: Button

@export_group("Labels")
@export var title_label: Label
@export var subtitle_label: Label
@export var difficulty_label: Label
@export var version_label: Label
@export var hint_label: Label

@export_group("Background")
@export var background: TextureRect
@export var background_zoom: float = 1.08
@export var background_zoom_time: float = 24.0

const GAME_TITLE: String = "Motion Dead"
const GAME_SUBTITLE: String = "Combate y resistencia táctica contra la horda"

var is_3d_selected: bool = false

# Estilos de pestañas
var _tab_active_style: StyleBox
var _tab_inactive_style: StyleBox


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_resolve_references()
	_setup_styles()
	_connect_buttons()
	_setup_texts()
	_set_mode_ui(false) # Por defecto arranca en 2D
	_start_background_drift()
	if has_node("/root/SoundManager"):
		SoundManager.play_music("menu", 1.0, -6.0)


func _resolve_references() -> void:
	mode_2d_button = get_node_or_null("Root/LeftSection/ModeSelectorBox/Mode2DButton") as Button
	mode_3d_button = get_node_or_null("Root/LeftSection/ModeSelectorBox/Mode3DButton") as Button
	campaign_header = get_node_or_null("Root/LeftSection/ScrollContainer/ContentBox/CampaignHeader") as Label
	class_info_label = get_node_or_null("Root/CharacterShowcase/DossierCard/ClassInfo") as Label

	if level_1_button == null:
		level_1_button = get_node_or_null("Root/LeftSection/ScrollContainer/ContentBox/CampaignGroup/Level1Button") as Button
	if level_2_button == null:
		level_2_button = get_node_or_null("Root/LeftSection/ScrollContainer/ContentBox/CampaignGroup/Level2Button") as Button
	if level_3_button == null:
		level_3_button = get_node_or_null("Root/LeftSection/ScrollContainer/ContentBox/CampaignGroup/Level3Button") as Button
	if endless_button == null:
		endless_button = get_node_or_null("Root/LeftSection/ScrollContainer/ContentBox/SpecialGroup/EndlessButton") as Button
	if options_button == null:
		options_button = get_node_or_null("Root/LeftSection/ScrollContainer/ContentBox/SystemRow/OptionsButton") as Button
	if how_to_play_button == null:
		how_to_play_button = get_node_or_null("Root/LeftSection/ScrollContainer/ContentBox/SystemRow/HowToPlayButton") as Button
	if quit_button == null:
		quit_button = get_node_or_null("Root/LeftSection/ScrollContainer/ContentBox/SystemRow/QuitButton") as Button
	if title_label == null:
		title_label = get_node_or_null("Root/LeftSection/TitleBox/TitleLabel") as Label
	if subtitle_label == null:
		subtitle_label = get_node_or_null("Root/LeftSection/TitleBox/SubtitleLabel") as Label
	if difficulty_label == null:
		difficulty_label = get_node_or_null("Root/LeftSection/TitleBox/DiffCard/DiffLabel") as Label
	if version_label == null:
		version_label = get_node_or_null("Root/BottomBar/VersionLabel") as Label
	if hint_label == null:
		hint_label = get_node_or_null("Root/BottomBar/HintLabel") as Label
	if background == null:
		background = get_node_or_null("Background") as TextureRect


func _setup_styles() -> void:
	if mode_2d_button != null:
		_tab_active_style = mode_2d_button.get_theme_stylebox("normal")
	if mode_3d_button != null:
		_tab_inactive_style = mode_3d_button.get_theme_stylebox("normal")


func _connect_buttons() -> void:
	if mode_2d_button != null:
		mode_2d_button.pressed.connect(func():
			if has_node("/root/SoundManager"):
				SoundManager.play_ui_click()
			_set_mode_ui(false)
		)
	if mode_3d_button != null:
		mode_3d_button.pressed.connect(func():
			if has_node("/root/SoundManager"):
				SoundManager.play_ui_click()
			_set_mode_ui(true)
		)

	var play_buttons: Array[Button] = [
		level_1_button, level_2_button, level_3_button,
		endless_button, options_button, how_to_play_button, quit_button
	]
	for btn in play_buttons:
		if btn != null:
			btn.pivot_offset = Vector2(0, btn.custom_minimum_size.y * 0.5)
			btn.mouse_entered.connect(func() -> void:
				if has_node("/root/SoundManager"):
					SoundManager.play_ui_hover()
				var tw: Tween = create_tween()
				tw.tween_property(btn, "scale", Vector2(1.025, 1.025), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			)
			btn.mouse_exited.connect(func() -> void:
				var tw: Tween = create_tween()
				tw.tween_property(btn, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			)
			btn.pressed.connect(func() -> void:
				if has_node("/root/SoundManager"):
					SoundManager.play_ui_click()
			)

	if level_1_button != null:
		level_1_button.pressed.connect(_on_level_pressed.bind(0))
		level_1_button.grab_focus()
	if level_2_button != null:
		level_2_button.pressed.connect(_on_level_pressed.bind(1))
	if level_3_button != null:
		level_3_button.pressed.connect(_on_level_pressed.bind(2))
	if endless_button != null:
		endless_button.pressed.connect(_on_endless_pressed)
	if options_button != null:
		options_button.pressed.connect(_on_options_pressed)
	if how_to_play_button != null:
		how_to_play_button.pressed.connect(_on_how_to_play_pressed)
	if quit_button != null:
		quit_button.pressed.connect(_on_quit_pressed)


## Cambia la interfaz y textos según la selección 2D o 3D
func _set_mode_ui(is_3d: bool) -> void:
	is_3d_selected = is_3d

	if mode_2d_button != null and mode_3d_button != null:
		if _tab_active_style != null and _tab_inactive_style != null:
			mode_2d_button.add_theme_stylebox_override("normal", _tab_inactive_style if is_3d else _tab_active_style)
			mode_3d_button.add_theme_stylebox_override("normal", _tab_active_style if is_3d else _tab_inactive_style)

	if is_3d:
		if campaign_header != null:
			campaign_header.text = "— MISIONES DE CAMPAÑA 3D (FPS SULFUR) —"
		if level_1_button != null:
			level_1_button.text = "🔥  ESCENARIO 1 · Calles Destruidas (3D)"
		if level_2_button != null:
			level_2_button.text = "🔥  ESCENARIO 2 · Refinería Tóxica (3D)"
		if level_3_button != null:
			level_3_button.text = "💀  JEFE FINAL · Núcleo del Titán (3D)"
		if endless_button != null:
			endless_button.text = "∞  MODO INFINITO · Supervivencia 3D"
		if class_info_label != null:
			class_info_label.text = "MODO SELECCIONADO: 3D PRIMERA PERSONA (FPS)"
	else:
		if campaign_header != null:
			campaign_header.text = "— MISIONES DE CAMPAÑA 2D (TOP-DOWN) —"
		if level_1_button != null:
			level_1_button.text = "▶  ESCENARIO 1 · Las Calles (2D)"
		if level_2_button != null:
			level_2_button.text = "▶  ESCENARIO 2 · Zona Industrial (2D)"
		if level_3_button != null:
			level_3_button.text = "💀  JEFE FINAL · Núcleo Titán (2D)"
		if endless_button != null:
			endless_button.text = "∞  MODO INFINITO · Supervivencia 2D"
		if class_info_label != null:
			class_info_label.text = "MODO SELECCIONADO: 2D CLÁSICO (VISTA SUPERIOR)"


func _setup_texts() -> void:
	if title_label != null:
		title_label.text = GAME_TITLE
	if subtitle_label != null:
		subtitle_label.text = GAME_SUBTITLE
	if version_label != null:
		version_label.text = "v0.3 · Godot %s" % Engine.get_version_info().get("string", "4.x")
	if hint_label != null:
		hint_label.text = "💡 Elige arriba entre Modo 2D o Modo 3D y selecciona tu escenario para desplegarte."
	if difficulty_label != null:
		var difficulty_text: String = "Normal"
		if has_node("/root/GameSettings"):
			difficulty_text = GameSettings.get_difficulty_name()
		difficulty_label.text = "  ⚙ DIFICULTAD: %s  " % difficulty_text.to_upper()


func _start_background_drift() -> void:
	if background == null:
		return
	await get_tree().process_frame
	if not is_instance_valid(background):
		return
	background.pivot_offset = background.size * 0.5
	background.scale = Vector2.ONE
	var tween: Tween = create_tween().set_loops()
	tween.tween_property(background, "scale", Vector2.ONE * background_zoom, background_zoom_time) \
		.set_trans(Tween.TRANS_SINE)
	tween.tween_property(background, "scale", Vector2.ONE, background_zoom_time) \
		.set_trans(Tween.TRANS_SINE)


# ------------------------------------------------------------------------------
# Manejadores de botones
# ------------------------------------------------------------------------------

func _on_level_pressed(level_index: int) -> void:
	if has_node("/root/GameManager"):
		if is_3d_selected:
			GameManager.start_run_3d(level_index)
		else:
			GameManager.start_run(level_index)
	else:
		push_error("[MainMenu] GameManager no disponible.")


func _on_endless_pressed() -> void:
	if has_node("/root/GameManager"):
		if is_3d_selected:
			GameManager.start_run_3d(0)
		else:
			GameManager.start_endless_run(0)
	else:
		push_error("[MainMenu] GameManager no disponible.")


func _on_options_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/options_menu.tscn")


func _on_how_to_play_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/how_to_play.tscn")


func _on_quit_pressed() -> void:
	if has_node("/root/GameManager"):
		GameManager.quit_game()
	else:
		get_tree().quit()
