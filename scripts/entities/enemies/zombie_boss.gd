class_name ZombieBoss
extends Zombie

## Jefe Final Titán.
## Posee 2400 HP (el doble que el Miniboss), tamaño colosal (2.6x),
## apariencia grotesca y aterradora, y una potente animación de rugido/grito
## que sacude toda la pantalla mediante ondas de choque e hiper-vibración.

signal boss_screamed()

@export var roar_duration: float = 2.6
@export var roar_shake_intensity: float = 22.0

@export_group("Periodic Roar")
@export var periodic_roar_enabled: bool = true
## Rango de segundos entre rugidos periódicos del Jefe Final durante el combate
@export var periodic_roar_interval_min: float = 14.0
@export var periodic_roar_interval_max: float = 18.0
@export var periodic_roar_shake_intensity: float = 10.0

var _is_roaring: bool = false
var _roar_timer: float = 0.0
var _shockwave_timer: float = 0.0
var _periodic_roar_timer: float = 0.0
var _shockwaves: Array[Dictionary] = []
var _base_scale: Vector2 = Vector2(2.6, 2.6)


func _ready() -> void:
	super._ready()
	add_to_group("boss")
	add_to_group("miniboss")
	display_name = "Titán Mutante Final"
	scale = _base_scale
	_reset_periodic_roar_timer()


func _process(delta: float) -> void:
	if _shockwaves.size() > 0:
		var kept: Array[Dictionary] = []
		for sw in _shockwaves:
			sw.radius += delta * 320.0
			sw.alpha = maxf(0.0, sw.alpha - delta * 1.5)
			if sw.alpha > 0.01:
				kept.append(sw)
		_shockwaves = kept
		queue_redraw()

	if _is_roaring:
		_process_roar(delta)
	elif _state != State.DEAD and (health_component == null or health_component.current_health > 0.0):
		_process_periodic_roar(delta)


func _draw() -> void:
	super._draw()
	for sw in _shockwaves:
		var col: Color = sw.color
		col.a = sw.alpha
		draw_arc(Vector2.ZERO, sw.radius, 0.0, TAU, 48, col, 5.0, true)


func _on_attack_landed() -> void:
	super._on_attack_landed()
	_spawn_shockwave(true)


func _play_spawn_animation() -> void:
	modulate.a = 0.0
	_is_roaring = true
	_roar_timer = roar_duration
	_state = State.SPAWNING

	# Solo reproduce el rugido del jefe final (sin ningún sonido de golpe)
	if has_node("/root/SoundManager"):
		SoundManager.play_boss_roar(global_position)

	# Aparecer gradualmente con tinte carmesí
	var tween: Tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.4)

	# Notificar a la interfaz del rugido y activación de la barra de vida
	var hud: Node = get_tree().get_first_node_in_group("hud")
	if hud != null:
		if hud.has_method("show_boss_bar") and health_component != null:
			hud.call("show_boss_bar", display_name, health_component.current_health, health_component.max_health, self)
		if hud.has_method("show_wave_banner"):
			hud.call("show_wave_banner", "¡¡¡ALERTA MÁXIMA: EL TITÁN FINAL HA DESPERTADO!!!")


func _process_roar(delta: float) -> void:
	_roar_timer -= delta
	_shockwave_timer -= delta

	# Sacudir la cámara continuamente durante el rugido
	if _target == null or not is_instance_valid(_target):
		_acquire_target()

	if _target != null and _target.has_method("add_camera_shake"):
		_target.call("add_camera_shake", roar_shake_intensity)

	# Sacudir el sprite del jefe y pulsar su escala
	if animated_sprite != null:
		animated_sprite.offset = Vector2(
			_rng.randf_range(-7.0, 7.0),
			_rng.randf_range(-7.0, 7.0)
		)
		var pulse: float = 1.0 + sin(_roar_timer * 18.0) * 0.12
		scale = _base_scale * pulse

	# Emitir ondas de choque visuales cada 0.35s SIN sonido de golpes
	if _shockwave_timer <= 0.0:
		_shockwave_timer = 0.35
		_spawn_shockwave(false)

	if _roar_timer <= 0.0:
		_end_roar()


func _spawn_shockwave(play_sound: bool = false) -> void:
	if play_sound and has_node("/root/SoundManager"):
		SoundManager.play_boss_slam(global_position)

	_shockwaves.append({
		"radius": 30.0,
		"alpha": 0.9,
		"color": Color(1.0, 0.25, 0.25) if _rng.randf() > 0.5 else Color(0.98, 0.8, 0.2)
	})


func _end_roar() -> void:
	_is_roaring = false
	scale = _base_scale
	if animated_sprite != null:
		animated_sprite.offset = Vector2.ZERO
	_state = State.CHASE
	_reset_periodic_roar_timer()
	boss_screamed.emit()


func _reset_periodic_roar_timer() -> void:
	_periodic_roar_timer = _rng.randf_range(periodic_roar_interval_min, periodic_roar_interval_max)


func _process_periodic_roar(delta: float) -> void:
	if not periodic_roar_enabled:
		return
	_periodic_roar_timer -= delta
	if _periodic_roar_timer <= 0.0:
		_reset_periodic_roar_timer()
		_trigger_periodic_roar()


func _trigger_periodic_roar() -> void:
	if _state == State.DEAD or (health_component != null and health_component.current_health <= 0.0):
		return

	# Solo reproduce el sonido del rugido periódicamente durante la batalla
	if has_node("/root/SoundManager"):
		SoundManager.play_boss_roar(global_position)

	# Temblor de cámara aterrador durante el rugido periódico
	if _target == null or not is_instance_valid(_target):
		_acquire_target()
	if _target != null and _target.has_method("add_camera_shake"):
		_target.call("add_camera_shake", periodic_roar_shake_intensity)

	# Breve pulso visual en el titán
	var tween: Tween = create_tween()
	tween.tween_property(self, "scale", _base_scale * 1.15, 0.18).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(self, "scale", _base_scale, 0.25).set_trans(Tween.TRANS_QUAD)


func _on_damage_received(amount: float, source: Node) -> void:
	super._on_damage_received(amount, source)
	# Cada impacto sobre el Titán genera un temblor menor en la cámara
	if _target != null and _target.has_method("add_camera_shake"):
		_target.call("add_camera_shake", 4.0)


func _die() -> void:
	# Gran temblor final al morir
	if _target != null and _target.has_method("add_camera_shake"):
		_target.call("add_camera_shake", 18.0)

	# Ocultar la barra de jefe en HUD
	var hud: Node = get_tree().get_first_node_in_group("hud")
	if hud != null and hud.has_method("hide_boss_bar"):
		hud.call("hide_boss_bar", 1.2)

	super._die()
