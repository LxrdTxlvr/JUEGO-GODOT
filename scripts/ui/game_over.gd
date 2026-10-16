extends Control

## Pantalla de resultado. Se muestra al morir o al superar todas las oleadas.
## Lee las estadísticas de la partida desde GameManager.

@export_group("Labels")
@export var title_label: Label
@export var subtitle_label: Label
@export var level_label: Label
@export var score_label: Label
@export var kills_label: Label
@export var wave_label: Label
@export var time_label: Label
@export var difficulty_label: Label

@export_group("Buttons")
@export var retry_button: Button
@export var next_level_button: Button
@export var main_menu_button: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = false
	Engine.time_scale = 1.0
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	_resolve_references()
	_connect_buttons()
	_fill_stats()


func _resolve_references() -> void:
	if title_label == null:
		title_label = get_node_or_null("Root/Panel/TitleLabel") as Label
	if subtitle_label == null:
		subtitle_label = get_node_or_null("Root/Panel/SubtitleLabel") as Label
	if level_label == null:
		level_label = get_node_or_null("Root/Panel/Stats/LevelLabel") as Label
	if score_label == null:
		score_label = get_node_or_null("Root/Panel/Stats/ScoreLabel") as Label
	if kills_label == null:
		kills_label = get_node_or_null("Root/Panel/Stats/KillsLabel") as Label
	if wave_label == null:
		wave_label = get_node_or_null("Root/Panel/Stats/WaveLabel") as Label
	if time_label == null:
		time_label = get_node_or_null("Root/Panel/Stats/TimeLabel") as Label
	if difficulty_label == null:
		difficulty_label = get_node_or_null("Root/Panel/DifficultyLabel") as Label
	if retry_button == null:
		retry_button = get_node_or_null("Root/Panel/Buttons/RetryButton") as Button
	if next_level_button == null:
		next_level_button = get_node_or_null("Root/Panel/Buttons/NextLevelButton") as Button
	if main_menu_button == null:
		main_menu_button = get_node_or_null("Root/Panel/Buttons/MainMenuButton") as Button


func _connect_buttons() -> void:
	if retry_button != null:
		retry_button.pressed.connect(_on_retry_pressed)
		retry_button.grab_focus()
	if next_level_button != null:
		next_level_button.pressed.connect(_on_next_level_pressed)
	if main_menu_button != null:
		main_menu_button.text = "MENÚ PRINCIPAL"
		main_menu_button.pressed.connect(_on_main_menu_pressed)


func _fill_stats() -> void:
	var stats: Dictionary = {}
	if has_node("/root/GameManager"):
		stats = GameManager.last_stats

	var victory: bool = bool(stats.get("victory", false))
	var level_number: int = int(stats.get("level_number", 1))
	var is_endless: bool = bool(stats.get("is_endless", false))
	var reached_wave: int = int(stats.get("wave", 0))
	var total_waves: int = int(stats.get("total_waves", 0))

	if has_node("/root/SoundManager"):
		if victory:
			SoundManager.play_victory()
		else:
			SoundManager.play_defeat()


	var is_3d: bool = bool(stats.get("is_3d", false))

	# 1. TÍTULOS Y SUBTÍTULOS POR ESCENARIO Y MODO DE JUEGO
	if title_label != null:
		if is_endless:
			title_label.text = "HAS CAÍDO" if not victory else "¡SUPERVIVENCIA ÉPICA!"
		elif victory:
			if level_number == 1:
				title_label.text = "¡NIVEL 1 SUPERADO!"
			elif level_number == 2:
				title_label.text = "¡NIVEL 2 SUPERADO!"
			elif level_number == 3:
				title_label.text = "¡VICTORIA TOTAL!"
			else:
				title_label.text = "¡HAS SOBREVIVIDO!"
		else:
			if level_number == 3:
				title_label.text = "HAS SIDO ANIQUILADO"
			else:
				title_label.text = "HAS CAÍDO"

		title_label.add_theme_color_override(
			"font_color",
			Color(0.35, 0.95, 0.55) if victory else Color(0.95, 0.22, 0.18)
		)

	if subtitle_label != null:
		if is_endless:
			subtitle_label.text = "Resististe con valentía hasta el final. ¡Supera tu récord en la próxima partida!"
		elif victory:
			if level_number == 1:
				subtitle_label.text = "Has despejado las calles. El acceso a la Zona Industrial ha sido asegurado."
			elif level_number == 2:
				subtitle_label.text = "Has asegurado la Zona Industrial. El camino al Núcleo del Titán está abierto."
			elif level_number == 3:
				subtitle_label.text = "¡Has destruido al Titán Mutante y erradicado la infección zombi!"
			else:
				subtitle_label.text = "Has despejado todas las oleadas de este escenario."
		else:
			if level_number == 1:
				subtitle_label.text = "La horda de las calles te superó. Reagrúpate y vuelve a intentarlo."
			elif level_number == 2:
				subtitle_label.text = "La infestación en la fábrica fue implacable. Inténtalo de nuevo."
			elif level_number == 3:
				subtitle_label.text = "El Titán Final acabó contigo. ¡Aprende sus patrones y vuelve a desafiarlo!"
			else:
				subtitle_label.text = "La horda te alcanzó. Inténtalo de nuevo."

	# 2. IDENTIFICADOR DEL ESCENARIO
	if level_label != null:
		var prefix: String = "[3D Edition] " if is_3d else ""
		if is_endless:
			level_label.text = prefix + "Modo Infinito · Supervivencia"
		elif level_number == 1:
			level_label.text = prefix + "Nivel 1 · Calles Devastadas"
		elif level_number == 2:
			level_label.text = prefix + "Nivel 2 · Zona Industrial"
		elif level_number == 3:
			level_label.text = prefix + "Nivel 3 · Núcleo del Titán (Jefe Final)"
		else:
			level_label.text = prefix + ("Nivel %d" % level_number)

	# 3. ESTADÍSTICAS NUMÉRICAS
	if score_label != null:
		score_label.text = "Puntuación: %d" % int(stats.get("score", 0))
	if kills_label != null:
		kills_label.text = "Zombis eliminados: %d" % int(stats.get("kills", 0))

	# 4. CONTADOR DE OLEADAS SEGÚN MODO
	if wave_label != null:
		if is_endless:
			wave_label.text = "Oleadas resistidas: %d" % reached_wave
		elif level_number == 3:
			if victory:
				wave_label.text = "Enfrentamiento: Titán Mutante Derrotado"
			else:
				wave_label.text = "Enfrentamiento: Titán Mutante"
		else:
			if victory:
				wave_label.text = "Oleadas superadas: %d / %d" % [total_waves, total_waves]
			else:
				wave_label.text = "Oleada alcanzada: %d / %d" % [reached_wave, total_waves]

	if time_label != null:
		time_label.text = "Tiempo sobrevivido: %s" % _format_time(float(stats.get("time", 0.0)))
	if difficulty_label != null:
		var difficulty_name: String = "Normal"
		if has_node("/root/GameSettings"):
			difficulty_name = GameSettings.get_difficulty_name()
		difficulty_label.text = "Dificultad: %s" % difficulty_name

	# 5. BOTONES DE ACCIÓN (TEXTOS Y VISIBILIDAD)
	var has_next: bool = false
	if has_node("/root/GameManager"):
		var total_levels_count: int = GameManager.LEVELS_3D.size() if is_3d else GameManager.LEVELS.size()
		has_next = GameManager.current_level_index + 1 < total_levels_count

	if next_level_button != null:
		next_level_button.visible = victory and not is_endless and has_next
		if level_number == 2:
			next_level_button.text = "ENFRENTAR AL JEFE FINAL"
		else:
			next_level_button.text = "SIGUIENTE NIVEL"

	if retry_button != null:
		if is_endless:
			retry_button.text = "REINTENTAR MODO INFINITO"
		elif level_number == 3:
			retry_button.text = "REINTENTAR JEFE FINAL"
		else:
			retry_button.text = "REINTENTAR NIVEL %d" % level_number

	# 6. ESTILIZADO VISUAL DEL MARCO
	_apply_visual_styling(victory)


func _apply_visual_styling(victory: bool) -> void:
	var panel: Panel = get_node_or_null("Root/Panel") as Panel
	if panel != null:
		var sb: StyleBoxFlat = StyleBoxFlat.new()
		sb.set_corner_radius_all(14)
		sb.border_width_left = 2
		sb.border_width_top = 2
		sb.border_width_right = 2
		sb.border_width_bottom = 2
		if victory:
			sb.bg_color = Color(0.04, 0.08, 0.05, 0.95)
			sb.border_color = Color(0.35, 0.88, 0.52, 0.85)
			sb.shadow_color = Color(0.12, 0.55, 0.28, 0.28)
		else:
			sb.bg_color = Color(0.06, 0.02, 0.02, 0.95)
			sb.border_color = Color(0.88, 0.22, 0.2, 0.85)
			sb.shadow_color = Color(0.65, 0.1, 0.1, 0.28)
		sb.shadow_size = 20
		panel.add_theme_stylebox_override("panel", sb)

	var root: Control = get_node_or_null("Root") as Control
	if root != null:
		root.modulate.a = 0.0
		root.scale = Vector2(0.96, 0.96)
		root.pivot_offset = get_viewport_rect().size * 0.5
		var tween: Tween = create_tween().set_parallel(true)
		tween.tween_property(root, "modulate:a", 1.0, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(root, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _format_time(seconds: float) -> String:
	var total_seconds: int = int(seconds)
	var minutes: int = total_seconds / 60
	var remaining: int = total_seconds % 60
	return "%02d:%02d" % [minutes, remaining]


# ------------------------------------------------------------------------------
# Manejadores
# ------------------------------------------------------------------------------

func _on_retry_pressed() -> void:
	if has_node("/root/SoundManager"):
		SoundManager.play_ui_click()
	if has_node("/root/GameManager"):
		var stats: Dictionary = GameManager.last_stats
		var is_endless: bool = bool(stats.get("is_endless", false))
		var is_3d: bool = bool(stats.get("is_3d", GameManager.is_3d_mode))
		var level_idx: int = int(stats.get("level_index", GameManager.current_level_index))
		if is_endless:
			GameManager.start_endless_run(level_idx)
		elif is_3d:
			GameManager.start_run_3d(level_idx)
		else:
			GameManager.start_run(level_idx)


func _on_next_level_pressed() -> void:
	if has_node("/root/SoundManager"):
		SoundManager.play_ui_click()
	if has_node("/root/GameManager"):
		GameManager.advance_to_next_level()


func _on_main_menu_pressed() -> void:
	if has_node("/root/SoundManager"):
		SoundManager.play_ui_click()
	if has_node("/root/GameManager"):
		GameManager.go_to_main_menu()
	else:
		get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
