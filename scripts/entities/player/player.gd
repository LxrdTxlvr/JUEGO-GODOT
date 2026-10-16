class_name Player
extends PlayerController

## Jugador de la Fase 1: añade a PlayerController la capa visual (animaciones),
## el arma, el "juice" de cámara y la interfaz pública de recolección.
## La lógica de control sigue viviendo en PlayerController y sigue siendo
## alimentada por la abstracción BaseInputHandler.

## Emitida al intentar recoger un objeto que todavía no se puede usar
## (vida o munición al máximo). La interfaz lo muestra como aviso.
signal pickup_rejected(reason: String)

## Marca de tiempo del último aviso de recogida rechazada, para no repetirlo.
var _last_rejection_ms: int = -10000

@export_group("Player Nodes")
## Sprite animado principal del personaje.
@export var animated_sprite: AnimatedSprite2D
## Componente de arma que dispara los proyectiles.
@export var weapon_component: WeaponComponent
## Cámara que sigue al jugador.
@export var camera: Camera2D
## Sprite de la pistola, hijo de WeaponPivot: rota con el apuntado.
@export var gun_sprite: Sprite2D

@export_group("Gun Feel")
## Reculada de la pistola al disparar, en píxeles.
@export var gun_recoil: float = 3.0
## Tiempo que tarda la pistola en volver a su sitio.
@export var gun_recoil_time: float = 0.09

## Emitida cuando el jugador cambia de arma activa.
signal weapon_switched(slot_index: int, weapon_name: String, magazine: int, reserve: int)
## Emitida cuando se desbloquea una nueva arma en el arsenal.
signal weapon_unlocked(slot_index: int, weapon_name: String)
## Emitida cuando la munición del arma activa cambia.
signal ammo_changed(magazine: int, reserve: int)

@export_group("Player Animation")
@export var idle_animation: StringName = &"idle"
@export var walk_animation: StringName = &"walking"
@export var run_animation: StringName = &"running"
@export var aim_up_animation: StringName = &"aim_up"
@export var aim_down_animation: StringName = &"aim_down"
@export var walk_aim_up_animation: StringName = &"walk_aim_up"
@export var walk_aim_down_animation: StringName = &"walk_aim_down"
## Velocidad a partir de la cual se considera que el jugador camina.
@export var movement_animation_threshold: float = 15.0
## Velocidad a partir de la cual se considera que el jugador corre.
@export var run_animation_threshold: float = 260.0

@export_group("Camera Feel")
## Intensidad del temblor de cámara al disparar.
@export var shoot_shake: float = 1.8
## Intensidad del temblor de cámara al recibir daño.
@export var hurt_shake: float = 7.0
## Velocidad de decaimiento del temblor de cámara.
@export var shake_decay: float = 14.0

@export_group("Death")
## Color con el que se tiñe el sprite al morir.
@export var death_tint: Color = Color(0.55, 0.15, 0.15)

var _shake_strength: float = 0.0
var _is_dead: bool = false
var _was_reloading: bool = false
var _gun_base_offset: Vector2 = Vector2.ZERO
var _step_timer: float = 0.0
const STEP_INTERVAL_WALK: float = 0.36
const STEP_INTERVAL_RUN: float = 0.22

## Arsenal de hasta 3 armas distintas
var weapon_slots: Array[WeaponComponent] = []
var unlocked_weapons: Array[bool] = [true, false, false]
var active_weapon_slot: int = 0


func _ready() -> void:
	super._ready()
	_resolve_player_references()
	_setup_weapon_slots()
	_connect_weapon()
	_connect_visual_signals()


func _resolve_player_references() -> void:
	if animated_sprite == null:
		animated_sprite = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if weapon_component == null:
		weapon_component = get_node_or_null("WeaponPivot/WeaponComponent") as WeaponComponent
	if camera == null:
		camera = get_node_or_null("Camera2D") as Camera2D
	if gun_sprite == null:
		gun_sprite = get_node_or_null("WeaponPivot/Gun") as Sprite2D
	if gun_sprite != null:
		_gun_base_offset = gun_sprite.offset

	# El volteo por apuntado del padre debe aplicarse sobre el sprite animado.
	if visual_sprite == null:
		visual_sprite = animated_sprite

	# El arma recibe la señal de disparo del controlador.
	if weapon_component != null and weapon_component.muzzle_flash == null:
		weapon_component.muzzle_flash = get_node_or_null("WeaponPivot/MuzzleFlash") as CanvasItem


func _setup_weapon_slots() -> void:
	weapon_slots.clear()
	var pivot: Node2D = weapon_pivot if weapon_pivot != null else get_node_or_null("WeaponPivot") as Node2D
	if pivot == null:
		return

	# Slot 0: Pistola 9mm (semiautomática por defecto)
	if weapon_component == null:
		weapon_component = pivot.get_node_or_null("WeaponComponent") as WeaponComponent
	if weapon_component != null:
		weapon_component.weapon_name = "Pistola 9mm"
		weapon_component.is_automatic = false
		weapon_slots.append(weapon_component)

	# Slot 1: Cuchillo táctico (melee)
	var knife: WeaponComponent = pivot.get_node_or_null("WeaponKnife") as WeaponComponent
	if knife == null:
		knife = WeaponComponent.new()
		knife.name = "WeaponKnife"
		knife.weapon_name = "Cuchillo de Combate"
		knife.is_melee = true
		knife.is_automatic = false
		knife.damage = 45.0
		knife.fire_rate = 3.0
		knife.magazine_size = 1
		knife.reserve_ammo = 1
		pivot.add_child(knife)
	weapon_slots.append(knife)

	# Slot 2: Subfusil Automático SMG-9
	var smg: WeaponComponent = pivot.get_node_or_null("WeaponSMG") as WeaponComponent
	if smg == null:
		smg = WeaponComponent.new()
		smg.name = "WeaponSMG"
		smg.weapon_name = "Subfusil SMG-9"
		smg.is_automatic = true
		smg.is_melee = false
		smg.damage = 16.0
		smg.fire_rate = 11.0
		smg.magazine_size = 30
		smg.reserve_ammo = 120
		smg.reload_time = 1.45
		if weapon_component != null:
			smg.projectile_scene = weapon_component.projectile_scene
			smg.muzzle_flash = weapon_component.muzzle_flash
		pivot.add_child(smg)
	weapon_slots.append(smg)

	# Asegurar que el arma activa sea la inicial
	switch_to_weapon_slot(0)


func _connect_weapon() -> void:
	if weapon_component == null:
		push_warning("[Player] Sin WeaponComponent: el jugador no podrá disparar.")
		return
	if not shoot_requested.is_connected(_on_shoot_requested):
		shoot_requested.connect(_on_shoot_requested)
	if not trigger_released.is_connected(_on_trigger_released):
		trigger_released.connect(_on_trigger_released)
	if not weapon_component.shot_fired.is_connected(_on_weapon_fired):
		weapon_component.shot_fired.connect(_on_weapon_fired)


func _connect_visual_signals() -> void:
	dodge_performed.connect(_on_dodge_performed)
	player_died.connect(_on_player_died)
	player_damaged.connect(_on_player_damaged)


func _on_trigger_released() -> void:
	if weapon_component != null:
		weapon_component.release_trigger()
	if has_node("/root/SoundManager"):
		SoundManager.stop_shoot("smg")


func _unhandled_input(event: InputEvent) -> void:
	if _is_dead:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_1:
			switch_to_weapon_slot(0)
		elif event.keycode == KEY_2:
			switch_to_weapon_slot(1)
		elif event.keycode == KEY_3:
			switch_to_weapon_slot(2)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			cycle_weapon(-1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			cycle_weapon(1)


## Alterna entre las armas actualmente desbloqueadas.
func cycle_weapon(step: int) -> void:
	if weapon_slots.size() <= 1:
		return
	var count: int = weapon_slots.size()
	var next_slot: int = active_weapon_slot
	for _i in range(count):
		next_slot = posmod(next_slot + step, count)
		if next_slot < unlocked_weapons.size() and unlocked_weapons[next_slot]:
			switch_to_weapon_slot(next_slot)
			break


const WEAPON_TEXTURES: Array[Texture2D] = [
	preload("res://assets/generated/weapon_pistol.png"),
	preload("res://assets/generated/weapon_knife.png"),
	preload("res://assets/generated/weapon_smg.png"),
]

## Cambia al slot de arma indicado si está desbloqueado.
func switch_to_weapon_slot(slot: int) -> bool:
	if slot < 0 or slot >= weapon_slots.size():
		return false
	if slot < unlocked_weapons.size() and not unlocked_weapons[slot]:
		return false

	active_weapon_slot = slot
	if has_node("/root/SoundManager"):
		SoundManager.stop_shoot("smg")
	if gun_sprite != null and slot >= 0 and slot < WEAPON_TEXTURES.size():
		gun_sprite.texture = WEAPON_TEXTURES[slot]

	var old_weapon: WeaponComponent = weapon_component
	if old_weapon != null and old_weapon.shot_fired.is_connected(_on_weapon_fired):
		old_weapon.shot_fired.disconnect(_on_weapon_fired)

	weapon_component = weapon_slots[slot]
	if weapon_component != null:
		if not weapon_component.shot_fired.is_connected(_on_weapon_fired):
			weapon_component.shot_fired.connect(_on_weapon_fired)
		weapon_component.release_trigger()
		weapon_component.ammo_changed.emit(weapon_component.magazine, weapon_component.reserve_ammo)
		weapon_switched.emit(active_weapon_slot, weapon_component.weapon_name, weapon_component.magazine, weapon_component.reserve_ammo)
	return true


## Desbloquea la siguiente arma del arsenal (cuchillo o subfusil).
func unlock_next_weapon() -> String:
	for i in range(1, unlocked_weapons.size()):
		if not unlocked_weapons[i]:
			unlocked_weapons[i] = true
			var w_name: String = weapon_slots[i].weapon_name if i < weapon_slots.size() else "Nueva Arma"
			weapon_unlocked.emit(i, w_name)
			switch_to_weapon_slot(i)
			return w_name
	# Si ya tiene todas las armas, reponer munición
	add_ammo(60)
	return "MUNICIÓN ADICIONAL"


func unlock_weapon_pickup() -> bool:
	unlock_next_weapon()
	return true


# ------------------------------------------------------------------------------
# Ciclo de vida
# ------------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	_update_animation()
	_update_footsteps(delta)
	_update_weapon_orientation()
	_update_camera_shake(delta)


## Devuelve la posición global exacta de la boca del arma según la animación y el apuntado actual.
func get_muzzle_position() -> Vector2:
	var aim_dir: Vector2 = _current_input.aim_direction
	var facing_left: bool = aim_dir.x < 0.0
	var offset: Vector2 = Vector2.ZERO

	if aim_dir.y < -0.55:
		# Apuntando hacia arriba
		offset = Vector2(-8.0 if facing_left else 8.0, -28.0)
	elif aim_dir.y > 0.55:
		# Apuntando hacia abajo
		offset = Vector2(-18.0 if facing_left else 18.0, 5.0)
	else:
		# Apuntando al frente horizontal
		offset = Vector2(-20.0 if facing_left else 20.0, -14.0)

	return global_position + offset


## El cuerpo del personaje sólo se voltea izquierda/derecha (arte lateral), pero
## la pistola rota libremente con el apuntado. Para que el arma y el fogonazo no
## salgan boca abajo al apuntar hacia la izquierda, se voltean verticalmente.
func _update_weapon_orientation() -> void:
	if weapon_pivot == null:
		return
	weapon_pivot.global_position = get_muzzle_position()
	weapon_pivot.rotation = _current_input.aim_direction.angle()
	var facing_left: bool = _current_input.aim_direction.x < 0.0
	if gun_sprite != null:
		gun_sprite.flip_v = facing_left
	var flash: CanvasItem = weapon_component.muzzle_flash if weapon_component != null else null
	if flash is Sprite2D:
		(flash as Sprite2D).flip_v = facing_left


## Reculada del arma, para dar peso al disparo.
func _play_gun_recoil() -> void:
	if gun_sprite == null:
		return
	gun_sprite.offset = _gun_base_offset - Vector2(gun_recoil, 0.0)
	var tween: Tween = create_tween()
	tween.tween_property(gun_sprite, "offset", _gun_base_offset, gun_recoil_time)


func _update_animation() -> void:
	if animated_sprite == null or animated_sprite.sprite_frames == null:
		return

	var is_running: bool = _is_dodging or velocity.length() > run_animation_threshold
	var is_moving: bool = velocity.length() > movement_animation_threshold
	var aim_y: float = _current_input.aim_direction.y
	var is_aiming_up: bool = aim_y < -0.55
	var is_aiming_down: bool = aim_y > 0.55
	var current_animation: StringName = idle_animation

	if is_aiming_up:
		if is_moving and animated_sprite.sprite_frames.has_animation(walk_aim_up_animation):
			current_animation = walk_aim_up_animation
		elif animated_sprite.sprite_frames.has_animation(aim_up_animation):
			current_animation = aim_up_animation
	elif is_aiming_down:
		if is_moving and animated_sprite.sprite_frames.has_animation(walk_aim_down_animation):
			current_animation = walk_aim_down_animation
		elif animated_sprite.sprite_frames.has_animation(aim_down_animation):
			current_animation = aim_down_animation
	elif is_running and animated_sprite.sprite_frames.has_animation(run_animation):
		current_animation = run_animation
	elif is_moving and animated_sprite.sprite_frames.has_animation(walk_animation):
		current_animation = walk_animation

	if not animated_sprite.sprite_frames.has_animation(current_animation):
		return
	if animated_sprite.animation != current_animation:
		animated_sprite.play(current_animation)

	# Sincroniza la velocidad de la animación con la velocidad real de movimiento.
	if current_animation == walk_animation or current_animation == walk_aim_up_animation or current_animation == walk_aim_down_animation:
		var ratio: float = clampf(velocity.length() / maxf(1.0, max_speed), 0.4, 1.6)
		animated_sprite.speed_scale = ratio
	elif current_animation == run_animation:
		var sprint_speed: float = max_speed * dodge_speed_multiplier
		var ratio: float = clampf(velocity.length() / maxf(1.0, sprint_speed), 0.8, 2.0)
		animated_sprite.speed_scale = ratio
	elif is_moving:
		var ratio: float = clampf(velocity.length() / maxf(1.0, max_speed), 0.5, 1.5)
		animated_sprite.speed_scale = ratio
	else:
		animated_sprite.speed_scale = 1.0


## Control del ritmo y reproducción de pasos según la velocidad de movimiento
func _update_footsteps(delta: float) -> void:
	if _is_dead:
		return
	var speed: float = velocity.length()
	if speed < movement_animation_threshold:
		_step_timer = 0.22
		return

	var is_running: bool = _is_dodging or speed > run_animation_threshold
	var interval: float = STEP_INTERVAL_RUN if is_running else STEP_INTERVAL_WALK

	_step_timer += delta
	if _step_timer >= interval:
		_step_timer = 0.0
		if has_node("/root/SoundManager"):
			if is_running:
				SoundManager.play_player_step_run()
			else:
				SoundManager.play_player_step_walk()


func _update_camera_shake(delta: float) -> void:
	if camera == null:
		return
	if _shake_strength <= 0.01:
		if camera.offset != Vector2.ZERO:
			camera.offset = Vector2.ZERO
		_shake_strength = 0.0
		return
	camera.offset = Vector2(
		randf_range(-_shake_strength, _shake_strength),
		randf_range(-_shake_strength, _shake_strength)
	)
	_shake_strength = move_toward(_shake_strength, 0.0, shake_decay * delta)


func add_camera_shake(amount: float) -> void:
	_shake_strength = maxf(_shake_strength, amount)


func _add_camera_shake(amount: float) -> void:
	add_camera_shake(amount)


# ------------------------------------------------------------------------------
# Combate
# ------------------------------------------------------------------------------

func _on_shoot_requested(_origin_position: Vector2, direction: Vector2) -> void:
	if _is_dead or weapon_component == null:
		return
	var muzzle_pos: Vector2 = get_muzzle_position()
	weapon_component.try_fire(muzzle_pos, direction)


func _on_weapon_fired(magazine: int, reserve: int) -> void:
	_add_camera_shake(shoot_shake)
	_play_gun_recoil()
	ammo_changed.emit(magazine, reserve)


## Entrada de daño usada por zombis, trampas y explosiones.
func take_damage(amount: float, source: Node = null) -> void:
	if _is_dead or health_component == null:
		return
	health_component.take_damage(amount, source)
	_add_camera_shake(hurt_shake)


# ------------------------------------------------------------------------------
# Interfaz pública para pickups
# ------------------------------------------------------------------------------

## Aviso de un pickup que aún no se puede usar. Lo llama el propio Pickup;
## el aviso se limita en el tiempo para no inundar la pantalla.
func on_pickup_rejected(reason: String) -> void:
	var now: int = Time.get_ticks_msec()
	if now - _last_rejection_ms < 1600:
		return
	_last_rejection_ms = now
	pickup_rejected.emit(reason)


## Restaura vida. Devuelve true si se curó algo.
func heal(amount: float) -> bool:
	if _is_dead or health_component == null:
		return false
	var previous: float = health_component.current_health
	health_component.heal(amount)
	return health_component.current_health > previous


## Añade munición de reserva. Devuelve la cantidad realmente añadida.
func add_ammo(amount: int) -> int:
	if weapon_component == null:
		return 0
	var added: int = weapon_component.add_ammo(amount)
	ammo_changed.emit(weapon_component.magazine, weapon_component.reserve_ammo)
	return added


func is_dead() -> bool:
	return _is_dead


# ------------------------------------------------------------------------------
# Efectos visuales
# ------------------------------------------------------------------------------

var _damage_flash_tween: Tween = null


func _on_dodge_performed() -> void:
	if animated_sprite == null:
		return
	# Mantener al personaje erguido en carrera/evasión sin rotaciones de 360 grados.
	if is_instance_valid(animated_sprite):
		animated_sprite.rotation = 0.0


## Parpadeo en rojo inmediato y vistoso cuando el jugador recibe daño de cualquier enemigo.
func _on_player_damaged(_current_hp: float, _max_hp: float) -> void:
	if _is_dead or animated_sprite == null:
		return
	if _damage_flash_tween != null and _damage_flash_tween.is_valid():
		_damage_flash_tween.kill()

	if has_node("/root/SoundManager"):
		SoundManager.play_player_hurt()

	_damage_flash_tween = create_tween()
	# Destello en rojo intenso que parpadea dos veces rápidamente y vuelve al color natural
	animated_sprite.modulate = Color(2.6, 0.3, 0.3, 1.0)
	_damage_flash_tween.tween_property(animated_sprite, "modulate", Color(1.0, 0.3, 0.3, 0.8), 0.05)
	_damage_flash_tween.tween_property(animated_sprite, "modulate", Color.WHITE, 0.07)
	_damage_flash_tween.tween_property(animated_sprite, "modulate", Color(2.2, 0.3, 0.3, 1.0), 0.06)
	_damage_flash_tween.tween_property(animated_sprite, "modulate", Color.WHITE, 0.08)


func _on_player_died() -> void:
	_is_dead = true
	if has_node("/root/SoundManager"):
		SoundManager.stop_shoot("smg")
	if _damage_flash_tween != null and _damage_flash_tween.is_valid():
		_damage_flash_tween.kill()

	if has_node("/root/SoundManager"):
		SoundManager.play_player_death()

	if input_handler != null:
		input_handler.is_active = false
	if animated_sprite != null:
		animated_sprite.speed_scale = 0.0
		var tween: Tween = create_tween()
		tween.tween_property(animated_sprite, "modulate", death_tint, 0.3)
		tween.tween_property(animated_sprite, "rotation", deg_to_rad(72.0), 0.35)
	_add_camera_shake(hurt_shake)

