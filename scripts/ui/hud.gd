extends CanvasLayer

## Interfaz de juego (HUD). Muestra vida, armamento centrado, oleada, bajas y puntuación,
## la retícula de apuntado, avisos de oleada y la barra de vida de los jefes / minibosses.
## No conoce la lógica del juego: sólo reacciona a señales y expone métodos de actualización.

@export_group("Health")
@export var health_fill: ColorRect
@export var health_label: Label
@export var bar_max_width: float = 276.0
@export var low_health_threshold: float = 0.3

@export_group("Boss Health")
@export var boss_bar_panel: Control
@export var boss_title_label: Label
@export var boss_health_fill: ColorRect
@export var boss_health_label: Label
@export var boss_bar_max_width: float = 492.0

@export_group("Weapons & Ammo")
@export var ammo_label: Label
@export var reload_label: Label
@export var weapon_slots_panel: Control

@export_group("Progress")
@export var wave_label: Label
@export var score_label: Label
@export var kills_label: Label
@export var level_label: Label

@export_group("Banners")
@export var wave_banner: Label
@export var banner_root: Control
@export var intro_level_label: Label
@export var intro_tagline_label: Label
@export var intro_root: Control

@export_group("Toasts")
## Contenedor del aviso breve (por ejemplo, por qué no se puede recoger algo).
@export var toast_root: Control
@export var toast_label: Label

@export_group("Feedback")
@export var crosshair: Control
@export var damage_vignette: ColorRect
@export var damage_flash_alpha: float = 0.22
@export var hide_system_cursor: bool = true

@export_group("Colors")
@export var health_high_color: Color = Color(0.32, 0.75, 0.36)
@export var health_medium_color: Color = Color(0.9, 0.72, 0.22)
@export var health_low_color: Color = Color(0.85, 0.2, 0.18)

var _last_health: float = -1.0
var _max_health_known: float = 100.0
var _vignette_tween: Tween = null
var _toast_tween: Tween = null
var _boss_tween: Tween = null
var _low_health_pulse: float = 0.0

var _active_slot: int = 0
var _unlocked_slots: Array[bool] = [true, false, false]
var _slot_borders: Array[ColorRect] = []
var _slot_nodes: Array[Control] = []
var _current_boss_node: Node = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_resolve_references()
	_connect_game_manager()
	_prepare_initial_state()
	if hide_system_cursor:
		Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)


func _resolve_references() -> void:
	if health_fill == null:
		health_fill = get_node_or_null("Root/HealthPanel/HealthBarFill") as ColorRect
	if health_label == null:
		health_label = get_node_or_null("Root/HealthPanel/HealthLabel") as Label

	# Boss Bar
	if boss_bar_panel == null:
		boss_bar_panel = get_node_or_null("Root/BossBarPanel") as Control
	if boss_title_label == null:
		boss_title_label = get_node_or_null("Root/BossBarPanel/BossTitleLabel") as Label
	if boss_health_fill == null:
		boss_health_fill = get_node_or_null("Root/BossBarPanel/BossBarFill") as ColorRect
	if boss_health_label == null:
		boss_health_label = get_node_or_null("Root/BossBarPanel/BossHealthLabel") as Label

	# Armamento inferior centrado
	if weapon_slots_panel == null:
		weapon_slots_panel = get_node_or_null("Root/WeaponSlotsPanel") as Control
	if ammo_label == null:
		ammo_label = get_node_or_null("Root/WeaponSlotsPanel/AmmoLabel") as Label
	if reload_label == null:
		reload_label = get_node_or_null("Root/WeaponSlotsPanel/ReloadLabel") as Label

	# Guardar referencias de los 3 slots de armas
	_slot_borders.clear()
	_slot_nodes.clear()
	for i in range(1, 4):
		var slot: Control = get_node_or_null("Root/WeaponSlotsPanel/SlotsContainer/Slot%d" % i) as Control
		if slot != null:
			_slot_nodes.append(slot)
			var border: ColorRect = slot.get_node_or_null("Border") as ColorRect
			if border != null:
				_slot_borders.append(border)

	if wave_label == null:
		wave_label = get_node_or_null("Root/StatsPanel/WaveLabel") as Label
	if score_label == null:
		score_label = get_node_or_null("Root/StatsPanel/ScoreLabel") as Label
	if kills_label == null:
		kills_label = get_node_or_null("Root/StatsPanel/KillsLabel") as Label
	if level_label == null:
		level_label = get_node_or_null("Root/StatsPanel/LevelLabel") as Label
	if wave_banner == null:
		wave_banner = get_node_or_null("Root/BannerRoot/WaveBanner") as Label
	if banner_root == null:
		banner_root = get_node_or_null("Root/BannerRoot") as Control
	if intro_root == null:
		intro_root = get_node_or_null("Root/IntroRoot") as Control
	if intro_level_label == null:
		intro_level_label = get_node_or_null("Root/IntroRoot/IntroLevelLabel") as Label
	if intro_tagline_label == null:
		intro_tagline_label = get_node_or_null("Root/IntroRoot/IntroTaglineLabel") as Label
	if toast_root == null:
		toast_root = get_node_or_null("Root/ToastRoot") as Control
	if toast_label == null:
		toast_label = get_node_or_null("Root/ToastRoot/ToastLabel") as Label
	if toast_root != null:
		toast_root.modulate.a = 0.0
	if crosshair == null:
		crosshair = get_node_or_null("Root/Crosshair") as Control
	if damage_vignette == null:
		damage_vignette = get_node_or_null("Root/DamageVignette") as ColorRect


func _connect_game_manager() -> void:
	if not has_node("/root/GameManager"):
		return
	GameManager.score_changed.connect(_on_score_changed)
	GameManager.kills_changed.connect(_on_kills_changed)
	GameManager.wave_changed.connect(_on_wave_changed)
	_on_score_changed(GameManager.score)
	_on_kills_changed(GameManager.kills)


func _prepare_initial_state() -> void:
	if damage_vignette != null:
		damage_vignette.color.a = 0.0
	if banner_root != null:
		banner_root.modulate.a = 0.0
	if intro_root != null:
		intro_root.modulate.a = 0.0
	if reload_label != null:
		reload_label.visible = false
	if boss_bar_panel != null:
		boss_bar_panel.visible = false
		boss_bar_panel.modulate.a = 0.0
	set_health(100.0, 100.0)
	set_ammo(12, 72)
	_update_slot_visuals()


func _process(delta: float) -> void:
	_update_crosshair()
	_update_low_health_pulse(delta)


func _update_crosshair() -> void:
	if crosshair == null:
		return
	var mouse_position: Vector2 = get_viewport().get_mouse_position()
	crosshair.position = mouse_position - crosshair.size * 0.5


## Parpadeo rojo del borde de pantalla cuando la vida es crítica.
func _update_low_health_pulse(delta: float) -> void:
	if damage_vignette == null:
		return

	var ratio: float = 0.0
	if _max_health_known > 0.0:
		ratio = _last_health / _max_health_known

	if ratio <= 0.0 or ratio > low_health_threshold:
		_low_health_pulse = 0.0
		# Si ya no está en estado crítico y no hay un flash de daño activo, asegurar que vuelve a 0
		if _vignette_tween == null or not _vignette_tween.is_valid():
			damage_vignette.color.a = move_toward(damage_vignette.color.a, 0.0, delta * 2.0)
		return

	# Solo pulsar si no hay un flash de daño de un golpe reciente en curso
	if _vignette_tween == null or not _vignette_tween.is_valid():
		_low_health_pulse += delta * 3.0
		var pulse: float = (sin(_low_health_pulse) * 0.5 + 0.5) * 0.22
		damage_vignette.color.a = pulse


# ------------------------------------------------------------------------------
# API llamada por el Level / Entidades
# ------------------------------------------------------------------------------

## Actualiza la barra y el texto de vida del jugador.
func set_health(current_health: float, max_health: float) -> void:
	_max_health_known = maxf(1.0, max_health)
	var previous: float = _last_health
	_last_health = current_health

	var ratio: float = clampf(current_health / _max_health_known, 0.0, 1.0)
	if health_fill != null:
		health_fill.size.x = bar_max_width * ratio
		health_fill.color = _get_health_color(ratio)

	if health_label != null:
		health_label.text = "%d / %d" % [roundi(current_health), roundi(_max_health_known)]

	if previous >= 0.0 and current_health < previous:
		_flash_damage()
	elif current_health > previous and ratio > low_health_threshold:
		if _vignette_tween != null and _vignette_tween.is_valid():
			_vignette_tween.kill()
		if damage_vignette != null:
			damage_vignette.color.a = 0.0
		_low_health_pulse = 0.0


# ------------------------------------------------------------------------------
# Barra de Vida de Jefes (Miniboss y Boss Final)
# ------------------------------------------------------------------------------

## Muestra la barra de jefe en el centro superior.
func show_boss_bar(boss_name: String, current_hp: float, max_hp: float, boss_node: Node = null) -> void:
	if boss_bar_panel == null:
		return
	_current_boss_node = boss_node
	if boss_title_label != null:
		boss_title_label.text = boss_name.to_upper()
	update_boss_health(current_hp, max_hp)
	boss_bar_panel.visible = true
	if _boss_tween != null and _boss_tween.is_valid():
		_boss_tween.kill()
	_boss_tween = create_tween()
	_boss_tween.tween_property(boss_bar_panel, "modulate:a", 1.0, 0.4)


## Actualiza la barra de vida del jefe activo.
func update_boss_health(current_hp: float, max_hp: float) -> void:
	if boss_bar_panel == null:
		return
	var safe_max: float = maxf(1.0, max_hp)
	var ratio: float = clampf(current_hp / safe_max, 0.0, 1.0)
	if boss_health_fill != null:
		boss_health_fill.size.x = boss_bar_max_width * ratio
	if boss_health_label != null:
		boss_health_label.text = "%d / %d" % [maxi(0, roundi(current_hp)), roundi(safe_max)]
	if current_hp <= 0.0:
		hide_boss_bar(1.0)


## Oculta la barra de jefe (por muerte o fin del combate).
func hide_boss_bar(delay: float = 0.0) -> void:
	if boss_bar_panel == null or not boss_bar_panel.visible:
		return
	if _boss_tween != null and _boss_tween.is_valid():
		_boss_tween.kill()
	_boss_tween = create_tween()
	if delay > 0.0:
		_boss_tween.tween_interval(delay)
	_boss_tween.tween_property(boss_bar_panel, "modulate:a", 0.0, 0.6)
	_boss_tween.chain().tween_callback(func() -> void:
		boss_bar_panel.visible = false
		_current_boss_node = null
	)


# ------------------------------------------------------------------------------
# Armamento Inferior Centrado
# ------------------------------------------------------------------------------

## Actualiza la información del arma activa sin mostrar su nombre textual.
## Muestra el recuadro correspondiente resaltado y los números [1], [2], [3] debajo.
func set_weapon_info(slot_index: int, weapon_name: String, magazine: int, reserve: int) -> void:
	_active_slot = slot_index
	if slot_index >= 0 and slot_index < _unlocked_slots.size():
		_unlocked_slots[slot_index] = true
	_update_slot_visuals()

	if ammo_label == null:
		return
	# No se muestra el nombre del arma por requerimiento de diseño
	if weapon_name.contains("Cuchillo") or slot_index == 1:
		ammo_label.text = "∞"
		ammo_label.modulate = Color(0.9, 0.85, 0.4)
	else:
		ammo_label.text = "%d | %d" % [magazine, reserve]
		ammo_label.modulate = Color(0.85, 0.25, 0.2) if magazine <= 3 else Color.WHITE


## Actualiza la lista de armas desbloqueadas para mostrar/atenuar sus recuadros.
func set_unlocked_weapons(unlocked: Array) -> void:
	for i in range(mini(unlocked.size(), _unlocked_slots.size())):
		_unlocked_slots[i] = bool(unlocked[i])
	_update_slot_visuals()


## Desbloquea visualmente una ranura de arma.
func unlock_slot(slot_index: int) -> void:
	if slot_index >= 0 and slot_index < _unlocked_slots.size():
		_unlocked_slots[slot_index] = true
		_update_slot_visuals()


func _update_slot_visuals() -> void:
	for i in range(_slot_nodes.size()):
		var slot_node: Control = _slot_nodes[i]
		var border: ColorRect = _slot_borders[i] if i < _slot_borders.size() else null
		var is_unlocked: bool = i < _unlocked_slots.size() and _unlocked_slots[i]
		var is_active: bool = (i == _active_slot)

		if slot_node != null:
			slot_node.modulate.a = 1.0 if is_unlocked else 0.35

		if border != null:
			if is_active:
				border.color = Color(0.98, 0.85, 0.32, 1.0) # Borde dorado brillante
			else:
				border.color = Color(0.35, 0.4, 0.45, 0.7) # Borde metálico neutral


## Actualiza los contadores de munición numéricamente.
func set_ammo(magazine: int, reserve: int) -> void:
	if ammo_label == null:
		return
	if _active_slot == 1:
		ammo_label.text = "∞"
		ammo_label.modulate = Color(0.9, 0.85, 0.4)
	else:
		ammo_label.text = "%d | %d" % [magazine, reserve]
		ammo_label.modulate = Color(0.85, 0.25, 0.2) if magazine <= 3 else Color.WHITE


## Muestra u oculta el aviso de recarga.
func set_reloading(is_reloading: bool) -> void:
	if reload_label == null:
		return
	reload_label.visible = is_reloading
	if is_reloading:
		reload_label.text = "RECARGANDO..."


## Fija el nombre del escenario y total de oleadas en la esquina.
func set_level_info(level_name: String, total_waves: int) -> void:
	if level_label != null:
		level_label.text = level_name
	_totals_waves = total_waves
	if wave_label != null:
		wave_label.text = "OLEADA 0 / %d" % total_waves


## Cartel central con el número de oleada.
func show_wave_banner(text: String) -> void:
	if wave_banner == null or banner_root == null:
		return
	wave_banner.text = text
	_animate_banner(banner_root, 2.2)


## Cartel de presentación del escenario al empezar.
func show_level_intro(level_name: String, tagline: String) -> void:
	if intro_root == null:
		return
	if intro_level_label != null:
		intro_level_label.text = level_name
	if intro_tagline_label != null:
		intro_tagline_label.text = tagline
	_animate_banner(intro_root, 3.0)


## Aviso breve y centrado, por ejemplo el motivo de una recogida rechazada.
func show_message(text: String) -> void:
	if toast_root == null or toast_label == null:
		return
	toast_label.text = text
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	toast_root.modulate.a = 0.0
	_toast_tween = create_tween()
	_toast_tween.tween_property(toast_root, "modulate:a", 1.0, 0.12)
	_toast_tween.tween_interval(1.3)
	_toast_tween.tween_property(toast_root, "modulate:a", 0.0, 0.35)


# ------------------------------------------------------------------------------
# Internos
# ------------------------------------------------------------------------------

var _totals_waves: int = 0


func _get_health_color(ratio: float) -> Color:
	if ratio > 0.5:
		return health_high_color
	if ratio > 0.25:
		return health_medium_color
	return health_low_color


func _animate_banner(target: Control, hold_time: float) -> void:
	if target == null:
		return
	var tween: Tween = create_tween()
	tween.tween_property(target, "modulate:a", 1.0, 0.35)
	tween.tween_interval(hold_time)
	tween.tween_property(target, "modulate:a", 0.0, 0.6)


func _flash_damage() -> void:
	if damage_vignette == null:
		return
	if _vignette_tween != null and _vignette_tween.is_valid():
		_vignette_tween.kill()
	damage_vignette.color.a = damage_flash_alpha
	_vignette_tween = create_tween()
	_vignette_tween.tween_property(damage_vignette, "color:a", 0.0, 0.45)


func _on_score_changed(new_score: int) -> void:
	if score_label != null:
		score_label.text = "PUNTOS  %d" % new_score


func _on_kills_changed(total_kills: int) -> void:
	if kills_label != null:
		kills_label.text = "BAJAS  %d" % total_kills


func _on_wave_changed(current_wave: int, total_waves: int) -> void:
	if wave_label != null:
		if has_node("/root/GameManager") and GameManager.is_endless_mode:
			wave_label.text = "OLEADA %d (INFINITO)" % current_wave
		else:
			wave_label.text = "OLEADA %d / %d" % [current_wave, total_waves]


func _exit_tree() -> void:
	if hide_system_cursor:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
