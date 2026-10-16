class_name HUD3D
extends CanvasLayer

## Interfaz de usuario estilizada HD para FPS 3D.
## Incluye:
## - Barra de salud con marco metálico desgastado y barra de retardo suave (catchup).
## - Selector de armas con siluetas HD, biseles y animación de escala (1.1x).
## - Viñeta de daño sangriento en los bordes y ColorRect de retroalimentación.
## - Punto de mira (Crosshair) dinámico que se expande con el retroceso y cadencia del subfusil.
## - Tipografía de supervivencia con sombras pronunciadas y rebordes negros.
## - Barra de vida estilizada para Jefe Final y Minibosses.

@onready var crosshair: TextureRect = $Crosshair
@onready var hp_bar: ProgressBar = $BottomBar/HBox/HealthContainer/HPBarBox/HPBar
@onready var hp_bar_catchup: ProgressBar = $BottomBar/HBox/HealthContainer/HPBarBox/HPBarCatchup
@onready var hp_label: Label = $BottomBar/HBox/HealthContainer/HPLabel
@onready var ammo_label: Label = $BottomBar/HBox/AmmoContainer/AmmoLabel
@onready var weapon_label: Label = $BottomBar/HBox/AmmoContainer/WeaponName
@onready var wave_label: Label = $TopBar/WaveLabel
@onready var score_label: Label = $TopBar/ScoreLabel
@onready var hurt_overlay: ColorRect = $HurtOverlay
@onready var hurt_vignette: TextureRect = $HurtVignette
@onready var banner_label: Label = $BannerLabel

# Boss Bar
@onready var boss_panel: Control = $BossBarPanel
@onready var boss_title_label: Label = $BossBarPanel/BossVBox/BossTitleLabel
@onready var boss_bar: ProgressBar = $BossBarPanel/BossVBox/BossBar
@onready var boss_hp_label: Label = $BossBarPanel/BossVBox/BossHealthLabel

# Recuadros de Armas
@onready var weapon_slots_container: HBoxContainer = $WeaponSlotsContainer
@onready var slot_nodes: Array[Control] = [
	$WeaponSlotsContainer/Slot0,
	$WeaponSlotsContainer/Slot1,
	$WeaponSlotsContainer/Slot2
]

var _player: Player3D = null
var _monitored_boss: Zombie3D = null
var _boss_check_timer: float = 0.0

var _style_active: StyleBoxFlat = null
var _style_inactive: StyleBoxFlat = null
var _style_locked: StyleBoxFlat = null

var _hp_catchup_tween: Tween = null
var _crosshair_scale: float = 1.0


func _ready() -> void:
	_init_styles()
	if hurt_overlay != null:
		hurt_overlay.color = Color(0.85, 0.05, 0.05, 0.0)
	if hurt_vignette != null:
		hurt_vignette.modulate.a = 0.0

	if banner_label != null:
		banner_label.modulate.a = 0.0

	if boss_panel != null:
		boss_panel.visible = false

	_player = get_tree().get_first_node_in_group("player") as Player3D
	if _player != null:
		_bind_player(_player)
	else:
		get_tree().node_added.connect(_on_node_added)

	if has_node("/root/GameManager"):
		GameManager.score_changed.connect(_on_score_changed)
		_on_score_changed(GameManager.score)


func _on_node_added(node: Node) -> void:
	if node is Player3D and _player == null:
		_player = node as Player3D
		_bind_player(_player)


func _bind_player(p: Player3D) -> void:
	p.health_changed.connect(_on_health_changed)
	p.ammo_changed.connect(_on_ammo_changed)
	p.weapon_switched.connect(_on_weapon_switched)
	if p.has_signal("weapon_unlocked"):
		p.weapon_unlocked.connect(_on_weapon_unlocked)
	if p.has_signal("weapon_fired"):
		p.weapon_fired.connect(_on_weapon_fired)
	_on_health_changed(p.current_health, p.max_health)
	_refresh_weapon_slots(p.active_slot, p.unlocked_weapons)


func _init_styles() -> void:
	# Activo: Borde dorado biselado con gradiente oscuro y glow
	_style_active = StyleBoxFlat.new()
	_style_active.bg_color = Color(0.16, 0.20, 0.26, 0.94)
	_style_active.border_color = Color(0.96, 0.82, 0.20, 1.0)
	_style_active.set_border_width_all(2)
	_style_active.set_corner_radius_all(6)
	_style_active.shadow_color = Color(0.96, 0.82, 0.20, 0.35)
	_style_active.shadow_size = 5

	# Inactivo desbloqueado: Acero oscuro elegante
	_style_inactive = StyleBoxFlat.new()
	_style_inactive.bg_color = Color(0.10, 0.11, 0.14, 0.72)
	_style_inactive.border_color = Color(0.38, 0.42, 0.48, 0.55)
	_style_inactive.set_border_width_all(1)
	_style_inactive.set_corner_radius_all(6)

	# Bloqueado: Apagado y deshabilitado
	_style_locked = StyleBoxFlat.new()
	_style_locked.bg_color = Color(0.06, 0.06, 0.08, 0.5)
	_style_locked.border_color = Color(0.18, 0.18, 0.22, 0.35)
	_style_locked.set_border_width_all(1)
	_style_locked.set_corner_radius_all(6)


func _process(delta: float) -> void:
	_boss_check_timer -= delta
	if _boss_check_timer <= 0.0:
		_boss_check_timer = 0.5
		_check_for_boss_or_miniboss()

	# Recuperación dinámica del punto de mira (Crosshair)
	if crosshair != null:
		_crosshair_scale = lerpf(_crosshair_scale, 1.0, delta * 12.0)
		crosshair.scale = Vector2(_crosshair_scale, _crosshair_scale)


func _check_for_boss_or_miniboss() -> void:
	if _monitored_boss != null and is_instance_valid(_monitored_boss) and _monitored_boss.current_health > 0:
		return

	var bosses: Array[Node] = get_tree().get_nodes_in_group("boss")
	for b in bosses:
		if b is Zombie3D and is_instance_valid(b) and (b as Zombie3D).current_health > 0:
			_bind_boss(b as Zombie3D, "TITÁN MUTANTE - JEFE FINAL")
			return

	var minibosses: Array[Node] = get_tree().get_nodes_in_group("miniboss")
	for mb in minibosses:
		if mb is Zombie3D and is_instance_valid(mb) and (mb as Zombie3D).current_health > 0:
			_bind_boss(mb as Zombie3D, "MINIBOSS MUTANTE")
			return


func _bind_boss(boss: Zombie3D, title_text: String) -> void:
	_monitored_boss = boss
	show_boss_bar(title_text, boss.current_health, boss.max_health)
	boss.damaged.connect(func(curr, max_val):
		update_boss_health(curr, max_val)
	)
	boss.died.connect(func(_z, _pts):
		update_boss_health(0.0, boss.max_health)
		_monitored_boss = null
	)


func show_boss_bar(boss_name: String, current_hp: float, max_hp: float) -> void:
	if boss_panel == null:
		return
	boss_title_label.text = boss_name.to_upper()
	boss_bar.max_value = max_hp
	boss_bar.value = current_hp
	boss_hp_label.text = "%d / %d" % [int(current_hp), int(max_hp)]
	boss_panel.visible = true
	var tween: Tween = create_tween()
	boss_panel.modulate.a = 0.0
	tween.tween_property(boss_panel, "modulate:a", 1.0, 0.4)


func update_boss_health(current_hp: float, max_hp: float) -> void:
	if boss_panel == null or not boss_panel.visible:
		return
	boss_bar.max_value = max_hp
	var tween: Tween = create_tween()
	tween.tween_property(boss_bar, "value", current_hp, 0.15)
	boss_hp_label.text = "%d / %d" % [int(current_hp), int(max_hp)]
	if current_hp <= 0.0:
		get_tree().create_timer(1.2).timeout.connect(hide_boss_bar)


func hide_boss_bar() -> void:
	if boss_panel == null or not boss_panel.visible:
		return
	var tween: Tween = create_tween()
	tween.tween_property(boss_panel, "modulate:a", 0.0, 0.4)
	tween.tween_callback(func(): boss_panel.visible = false)


func set_wave(wave: int) -> void:
	if wave_label != null:
		wave_label.text = "OLEADA %d" % wave
		var tween: Tween = create_tween()
		wave_label.scale = Vector2(1.25, 1.25)
		tween.tween_property(wave_label, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	show_banner("¡OLEADA %d!" % wave, Color(0.95, 0.75, 0.1, 1.0))


func show_wave_cleared(wave: int) -> void:
	show_banner("¡OLEADA %d SUPERADA!" % wave, Color(0.3, 0.95, 0.45, 1.0))


func show_victory_banner() -> void:
	show_banner("¡VICTORIA! ¡TODAS LAS OLEADAS SUPERADAS!", Color(0.3, 0.95, 0.45, 1.0), 3.5)


func show_banner(text: String, color: Color, duration: float = 2.0) -> void:
	if banner_label == null:
		return
	banner_label.text = text
	banner_label.add_theme_color_override("font_color", color)
	banner_label.modulate.a = 0.0
	var tween: Tween = create_tween().set_parallel(false)
	tween.tween_property(banner_label, "modulate:a", 1.0, 0.25).set_trans(Tween.TRANS_CUBIC)
	tween.tween_interval(duration)
	tween.tween_property(banner_label, "modulate:a", 0.0, 0.4).set_trans(Tween.TRANS_CUBIC)


func _on_health_changed(current: float, max_val: float) -> void:
	var prev_val: float = hp_bar.value if hp_bar != null else current
	
	if hp_bar != null:
		hp_bar.max_value = max_val
		hp_bar.value = current
	if hp_label != null:
		hp_label.text = "%d / %d" % [int(current), int(max_val)]

	# Barra secundaria detrás (Catchup) que baja medio segundo después de recibir daño
	if hp_bar_catchup != null:
		hp_bar_catchup.max_value = max_val
		if current < prev_val:
			# Daño recibido: retrasar y luego interpolar suavemente
			if _hp_catchup_tween != null and _hp_catchup_tween.is_valid():
				_hp_catchup_tween.kill()
			_hp_catchup_tween = create_tween()
			_hp_catchup_tween.tween_interval(0.50) # Medio segundo de retardo
			_hp_catchup_tween.tween_property(hp_bar_catchup, "value", current, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		else:
			# Curación: sincronizar de inmediato
			hp_bar_catchup.value = current

	# Feedback de daño: viñeta sangrienta y flash de pantalla
	if current < prev_val:
		if hurt_vignette != null:
			var tw_v: Tween = create_tween()
			hurt_vignette.modulate.a = 0.85
			tw_v.tween_property(hurt_vignette, "modulate:a", 0.0, 0.55).set_trans(Tween.TRANS_CUBIC)

		if hurt_overlay != null:
			var tw_o: Tween = create_tween()
			hurt_overlay.color = Color(0.85, 0.05, 0.05, 0.4)
			tw_o.tween_property(hurt_overlay, "color:a", 0.0, 0.28)


func _on_ammo_changed(mag: int, reserve: int) -> void:
	if ammo_label != null:
		ammo_label.text = "%02d / %03d" % [mag, reserve]


func _on_weapon_switched(slot: int, weapon_name: String) -> void:
	if weapon_label != null:
		weapon_label.text = weapon_name.to_upper()
	if _player != null:
		_refresh_weapon_slots(slot, _player.unlocked_weapons)


func _on_weapon_unlocked(slot: int, _weapon_name: String) -> void:
	if _player != null:
		_refresh_weapon_slots(slot, _player.unlocked_weapons)


func _on_weapon_fired(slot: int) -> void:
	# Expansión dinámica del punto de mira al disparar
	match slot:
		1: # SMG: acumula expansión rápida
			_crosshair_scale = minf(_crosshair_scale + 0.22, 1.75)
		2: # Escopeta: salto fuerte
			_crosshair_scale = 1.65
		_: # Pistola
			_crosshair_scale = 1.40


func _refresh_weapon_slots(active_slot: int, unlocked: Array[bool]) -> void:
	for i in range(slot_nodes.size()):
		var slot: Control = slot_nodes[i]
		if slot == null:
			continue
		var is_unlocked: bool = i < unlocked.size() and unlocked[i]
		var is_active: bool = (i == active_slot)

		var icon: TextureRect = slot.get_node_or_null("Icon") as TextureRect
		var num_lbl: Label = slot.get_node_or_null("NumLabel") as Label

		var tw: Tween = create_tween()
		if is_unlocked:
			if is_active:
				slot.add_theme_stylebox_override("panel", _style_active)
				# Animación de escala 1.1x en el arma equipada actualmente
				tw.tween_property(slot, "scale", Vector2(1.12, 1.12), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
				if icon != null:
					icon.modulate = Color(1.0, 1.0, 1.0, 1.0)
				if num_lbl != null:
					num_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2, 1.0))
			else:
				slot.add_theme_stylebox_override("panel", _style_inactive)
				tw.tween_property(slot, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_QUAD)
				if icon != null:
					icon.modulate = Color(0.72, 0.72, 0.75, 0.75)
				if num_lbl != null:
					num_lbl.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75, 0.85))
		else:
			slot.add_theme_stylebox_override("panel", _style_locked)
			tw.tween_property(slot, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_QUAD)
			if icon != null:
				icon.modulate = Color(0.22, 0.22, 0.25, 0.35)
			if num_lbl != null:
				num_lbl.add_theme_color_override("font_color", Color(0.45, 0.45, 0.45, 0.5))


func _on_score_changed(new_score: int) -> void:
	if score_label != null:
		score_label.text = "PUNTOS: %d" % new_score
