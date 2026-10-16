class_name Player3D
extends CharacterBody3D

## Controlador en Primera Persona (FPS) estilo SULFUR para entorno 3D.
## Incluye vista de ratón, movimiento suave con inercia, salto, bobbing de cámara,
## brazos y armas totalmente modelados en 3D orientados frontalmente hacia el centro,
## retroceso físico de corredera, amortiguación de salto y aterrizaje,
## y sistema de desbloqueo dinámico de armas idéntico a la versión 2D.

signal health_changed(current: float, max_val: float)
signal ammo_changed(magazine: int, reserve: int)
signal weapon_switched(slot: int, weapon_name: String)
signal weapon_unlocked(slot: int, weapon_name: String)
signal weapon_fired(slot: int)
signal weapon_reloaded(duration: float)
signal melee_attacked()
signal player_died()

@export_group("Movement")
@export var walk_speed: float = 6.0
@export var sprint_speed: float = 9.2
@export var jump_velocity: float = 5.2
@export var acceleration: float = 38.0
@export var deceleration: float = 30.0
@export var gravity: float = 16.0

@export_group("Mouse Look")
@export var mouse_sensitivity: float = 0.0022
@export var max_pitch: float = deg_to_rad(85.0)
@export var min_pitch: float = deg_to_rad(-85.0)

@export_group("Stats")
@export var max_health: float = 160.0
var current_health: float = 160.0
var is_dead: bool = false
var invulnerability_timer: float = 0.0

# Nodos
@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var aim_ray: RayCast3D = $Head/Camera3D/AimRay
@onready var viewmodel: ViewModel3D = $Head/Camera3D/ViewModel3D
@onready var gun_anchor: Node3D = $Head/Camera3D/GunAnchor
@onready var gun_sprite: Node = $Head/Camera3D/GunAnchor/GunSprite

# Sistema de Armas (Pistola, SMG, Escopeta)
var weapons: Array = []
var unlocked_weapons: Array[bool] = [true, false, false]
var active_slot: int = 0
var can_shoot: bool = true
var is_reloading: bool = false
var shoot_timer: float = 0.0
var melee_cooldown_timer: float = 0.0
@export var melee_damage: float = 65.0
@export var melee_range: float = 2.4

# Head Bobbing y Mouse Sway
var _step_cycle: float = 0.0
var _was_on_floor: bool = true
var _mouse_delta: Vector2 = Vector2.ZERO
var _step_sound_timer: float = 0.0

# Screen Shake
var _shake_trauma: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	current_health = max_health
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	floor_snap_length = 0.35
	floor_constant_speed = true
	floor_max_angle = deg_to_rad(46.0)
	
	_setup_weapons()
	_apply_active_weapon()
	health_changed.emit(current_health, max_health)


func _setup_weapons() -> void:
	weapons.clear()
	# 0: Pistola 9mm
	weapons.append({
		"name": "Pistola 9mm",
		"damage": 32.0,
		"fire_rate": 0.22,
		"is_automatic": false,
		"mag_size": 12,
		"current_mag": 12,
		"reserve": 84,
		"sound_shoot": "shoot_pistol",
		"recoil_pos": Vector3(0.0, 0.035, 0.07),
		"recoil_rot": Vector3(0.14, 0.0, 0.02)
	})
	
	# 1: Subfusil Rápido
	weapons.append({
		"name": "Subfusil Rápido",
		"damage": 18.0,
		"fire_rate": 0.10,
		"is_automatic": true,
		"mag_size": 30,
		"current_mag": 30,
		"reserve": 150,
		"sound_shoot": "shoot_smg",
		"recoil_pos": Vector3(0.0, 0.022, 0.045),
		"recoil_rot": Vector3(0.09, 0.0, 0.015)
	})

	# 2: Escopeta de Combate
	weapons.append({
		"name": "Escopeta de Combate",
		"damage": 68.0,
		"fire_rate": 0.55,
		"is_automatic": false,
		"mag_size": 8,
		"current_mag": 8,
		"reserve": 48,
		"sound_shoot": "shoot_pistol",
		"recoil_pos": Vector3(0.0, 0.06, 0.11),
		"recoil_rot": Vector3(0.24, 0.0, 0.04)
	})


func _apply_active_weapon() -> void:
	if weapons.is_empty():
		return
	var w: Dictionary = weapons[active_slot]
	if viewmodel != null:
		viewmodel.set_weapon(active_slot)
	ammo_changed.emit(w["current_mag"], w["reserve"])
	weapon_switched.emit(active_slot, w["name"])


## Comprueba si el jugador aún tiene alguna de las armas por desbloquear
func player_needs_weapon() -> bool:
	for unlocked in unlocked_weapons:
		if not unlocked:
			return true
	return false


## Desbloquea la siguiente arma del arsenal (igual que la dinámica del juego 2D)
func unlock_weapon_pickup() -> bool:
	for i in range(1, unlocked_weapons.size()):
		if not unlocked_weapons[i]:
			unlocked_weapons[i] = true
			var w_name: String = weapons[i]["name"] if i < weapons.size() else "Nueva Arma"
			weapon_unlocked.emit(i, w_name)
			_switch_weapon(i)
			if has_node("/root/SoundManager"):
				SoundManager.play_pickup("weapon")
			return true
	
	# Si ya tiene todo el arsenal, otorgar munición adicional abundante
	add_ammo(60)
	return true


func _unhandled_input(event: InputEvent) -> void:
	if is_dead:
		return
		
	if event is InputEventMouseButton:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and event.button_index == MOUSE_BUTTON_LEFT:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			get_viewport().set_input_as_handled()
			return
			
		# Rueda para cambio de arma
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_cycle_unlocked_weapon(1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_cycle_unlocked_weapon(-1)
			
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_mouse_delta = event.relative
		rotate_y(-event.relative.x * mouse_sensitivity)
		head.rotate_x(-event.relative.y * mouse_sensitivity)
		head.rotation.x = clampf(head.rotation.x, min_pitch, max_pitch)
		
	elif event is InputEventKey and event.pressed:
		if event.keycode == KEY_1:
			_switch_weapon(0)
		elif event.keycode == KEY_2 and unlocked_weapons.size() > 1 and unlocked_weapons[1]:
			_switch_weapon(1)
		elif event.keycode == KEY_3 and unlocked_weapons.size() > 2 and unlocked_weapons[2]:
			_switch_weapon(2)
		elif event.keycode == KEY_F:
			_perform_melee_attack()
		elif event.is_action_pressed("reload"):
			_start_reload()


func _cycle_unlocked_weapon(dir: int) -> void:
	var next_slot: int = active_slot
	for attempt in range(weapons.size()):
		next_slot = (next_slot + dir + weapons.size()) % weapons.size()
		if next_slot < unlocked_weapons.size() and unlocked_weapons[next_slot]:
			_switch_weapon(next_slot)
			break


func _physics_process(delta: float) -> void:
	if is_dead:
		_process_death_physics(delta)
		return

	if invulnerability_timer > 0.0:
		invulnerability_timer -= delta

	if melee_cooldown_timer > 0.0:
		melee_cooldown_timer -= delta

	var on_floor: bool = is_on_floor()

	# Gravedad
	if not on_floor:
		velocity.y -= gravity * delta
	else:
		# Detectar aterrizaje para amortiguación de salto
		if not _was_on_floor:
			if viewmodel != null:
				viewmodel.apply_jump_landing()
			if has_node("/root/SoundManager"):
				SoundManager.play_sound("footstep_walk_1", -10.0)

		if Input.is_action_just_pressed("jump"):
			velocity.y = jump_velocity
			if viewmodel != null:
				viewmodel.apply_jump_takeoff()

	_was_on_floor = on_floor

	# Movimiento WASD
	var input_dir: Vector2 = Vector2.ZERO
	if Input.is_action_pressed("move_left"):
		input_dir.x -= 1.0
	if Input.is_action_pressed("move_right"):
		input_dir.x += 1.0
	if Input.is_action_pressed("move_up"):
		input_dir.y -= 1.0
	if Input.is_action_pressed("move_down"):
		input_dir.y += 1.0
	input_dir = input_dir.normalized()

	var is_sprinting: bool = Input.is_action_pressed("dodge")
	var target_speed: float = sprint_speed if is_sprinting else walk_speed
	var forward: Vector3 = -global_transform.basis.z
	var right: Vector3 = global_transform.basis.x
	var move_dir: Vector3 = (forward * (-input_dir.y) + right * input_dir.x).normalized()

	var target_vel_h: Vector3 = move_dir * target_speed
	var current_vel_h: Vector3 = Vector3(velocity.x, 0, velocity.z)
	var accel: float = acceleration if move_dir.length_squared() > 0.01 else deceleration
	current_vel_h = current_vel_h.move_toward(target_vel_h, accel * delta)
	velocity.x = current_vel_h.x
	velocity.z = current_vel_h.z

	move_and_slide()

	# Disparo continuo o semi
	_process_shooting(delta)

	# Actualización del viewmodel 3D (bobbing, sway de ratón y retroceso)
	var is_moving: bool = move_dir.length_squared() > 0.01 and on_floor
	if is_moving:
		var freq: float = 12.0 if is_sprinting else 8.5
		_step_cycle += delta * freq
	else:
		_step_cycle = 0.0

	if viewmodel != null:
		viewmodel.update_transform(delta, _mouse_delta, _step_cycle, is_moving, is_sprinting)
	_mouse_delta = _mouse_delta.lerp(Vector2.ZERO, delta * 12.0)

	# Sonidos de pasos
	_process_footsteps(delta, is_moving, is_sprinting)

	# Screen Shake
	if _shake_trauma > 0.0:
		_shake_trauma = maxf(0.0, _shake_trauma - delta * 2.5)
		camera.rotation.z = (randf() * 2.0 - 1.0) * _shake_trauma * 0.04
		camera.h_offset = (randf() * 2.0 - 1.0) * _shake_trauma * 0.03
		camera.v_offset = (randf() * 2.0 - 1.0) * _shake_trauma * 0.03
	else:
		camera.rotation.z = 0.0
		camera.h_offset = 0.0
		camera.v_offset = 0.0


func _process_shooting(delta: float) -> void:
	if shoot_timer > 0.0:
		shoot_timer -= delta

	if is_reloading or melee_cooldown_timer > 0.0 or (viewmodel != null and viewmodel.is_melee_animating):
		if has_node("/root/SoundManager"):
			SoundManager.stop_machine_gun()
		return

	var w: Dictionary = weapons[active_slot]
	var wants_shoot: bool = false
	if w["is_automatic"]:
		wants_shoot = Input.is_action_pressed("shoot")
	else:
		wants_shoot = Input.is_action_just_pressed("shoot")

	# Detener sonido de ametralladora al soltar el gatillo o al vaciarse el cargador
	if w["is_automatic"] and (not wants_shoot or w["current_mag"] <= 0):
		if has_node("/root/SoundManager"):
			SoundManager.stop_machine_gun()

	if wants_shoot and shoot_timer <= 0.0:
		if w["current_mag"] > 0:
			_fire_weapon()
		else:
			_start_reload()


func _fire_weapon() -> void:
	var w: Dictionary = weapons[active_slot]
	w["current_mag"] -= 1
	shoot_timer = w["fire_rate"]
	ammo_changed.emit(w["current_mag"], w["reserve"])
	weapon_fired.emit(active_slot)

	if has_node("/root/SoundManager"):
		if w["is_automatic"]:
			SoundManager.play_machine_gun()
		else:
			SoundManager.play_sound(w["sound_shoot"])

	if viewmodel != null:
		viewmodel.play_shoot_effect(w["recoil_pos"], w["recoil_rot"])

	_shake_trauma = minf(1.0, _shake_trauma + 0.16)

	# Raycast hit
	if aim_ray != null:
		aim_ray.force_raycast_update()
		if aim_ray.is_colliding():
			var collider: Object = aim_ray.get_collider()
			var hit_point: Vector3 = aim_ray.get_collision_point()
			var hit_norm: Vector3 = aim_ray.get_collision_normal()
			var shot_dir: Vector3 = -camera.global_transform.basis.z

			if collider != null and collider.has_method("take_damage"):
				collider.take_damage(w["damage"], hit_point, hit_norm, shot_dir)
				if has_node("/root/SoundManager"):
					SoundManager.play_sound("flesh_impact")
			else:
				if has_node("/root/SoundManager"):
					SoundManager.play_sound("wall_impact")


func _perform_melee_attack() -> void:
	if is_dead or melee_cooldown_timer > 0.0 or is_reloading:
		return
	melee_cooldown_timer = 0.45
	melee_attacked.emit()

	# Sonido de cuchillo / navajazo
	if has_node("/root/SoundManager"):
		SoundManager.play_sound("knife_slash")

	# Animación en viewmodel de estocada frontal
	if viewmodel != null:
		viewmodel.play_melee_stab()

	_shake_trauma = minf(1.0, _shake_trauma + 0.14)

	# Detección de impacto cuerpo a cuerpo en dirección frontal
	var forward: Vector3 = -camera.global_transform.basis.z
	var origin: Vector3 = camera.global_position
	var target: Vector3 = origin + forward * melee_range
	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(origin, target)
	query.collision_mask = 1 | 4 # World y Enemies
	var hit: Dictionary = space_state.intersect_ray(query)

	var hit_enemy: bool = false
	if not hit.is_empty():
		var collider: Object = hit.collider
		if collider != null and collider.has_method("take_damage"):
			collider.take_damage(melee_damage, hit.position, hit.normal, forward)
			hit_enemy = true
			if has_node("/root/SoundManager"):
				SoundManager.play_sound("flesh_impact")
		else:
			if has_node("/root/SoundManager"):
				SoundManager.play_sound("wall_impact")

	# Búsqueda complementaria de zombis en cono frontal a corta distancia
	if not hit_enemy:
		var enemies: Array[Node] = get_tree().get_nodes_in_group("enemy")
		for e in enemies:
			if e is Node3D and is_instance_valid(e) and (e as Node3D).has_method("take_damage"):
				var node3d: Node3D = e as Node3D
				var diff: Vector3 = node3d.global_position - global_position
				diff.y = 0.0
				var dist: float = diff.length()
				if dist <= melee_range and forward.dot(diff.normalized()) > 0.45:
					node3d.take_damage(melee_damage, node3d.global_position + Vector3(0, 0.9, 0), -forward, forward)
					if has_node("/root/SoundManager"):
						SoundManager.play_sound("flesh_impact")
					break


func _start_reload() -> void:
	var w: Dictionary = weapons[active_slot]
	if is_reloading or w["current_mag"] >= w["mag_size"] or w["reserve"] <= 0:
		return

	if has_node("/root/SoundManager"):
		SoundManager.stop_machine_gun()

	is_reloading = true
	weapon_reloaded.emit(0.9)
	if viewmodel != null:
		viewmodel.play_reload_animation(0.9)

	var reload_timer: SceneTreeTimer = get_tree().create_timer(0.9, false, false, true)
	reload_timer.timeout.connect(func():
		var needed: int = w["mag_size"] - w["current_mag"]
		var take_amount: int = mini(needed, w["reserve"])
		w["current_mag"] += take_amount
		w["reserve"] -= take_amount
		is_reloading = false
		ammo_changed.emit(w["current_mag"], w["reserve"])
	)


func _switch_weapon(new_slot: int) -> void:
	if new_slot == active_slot or new_slot >= weapons.size() or is_reloading:
		return
	if new_slot >= unlocked_weapons.size() or not unlocked_weapons[new_slot]:
		return
	
	if has_node("/root/SoundManager"):
		SoundManager.stop_machine_gun()

	active_slot = new_slot
	_apply_active_weapon()
	if has_node("/root/SoundManager"):
		SoundManager.play_sound("ui_hover")


func _process_footsteps(delta: float, is_moving: bool, is_sprinting: bool) -> void:
	if not is_moving:
		_step_sound_timer = 0.0
		return

	_step_sound_timer -= delta
	if _step_sound_timer <= 0.0:
		_step_sound_timer = 0.32 if is_sprinting else 0.48
		if has_node("/root/SoundManager"):
			var idx: int = randi_range(1, 4)
			var snd: String = "footstep_run_%d" % idx if is_sprinting else "footstep_walk_%d" % idx
			SoundManager.play_sound(snd, -12.0)


func take_damage(amount: float, _hit_point: Vector3 = Vector3.ZERO, _hit_norm: Vector3 = Vector3.ZERO, _dir: Vector3 = Vector3.ZERO) -> void:
	if is_dead:
		return

	if invulnerability_timer > 0.0:
		return
	invulnerability_timer = 0.42

	current_health = maxf(0.0, current_health - amount)
	_shake_trauma = minf(1.0, _shake_trauma + 0.35)
	health_changed.emit(current_health, max_health)

	if has_node("/root/SoundManager"):
		SoundManager.play_sound("player_hurt")

	if current_health <= 0.0:
		_die()


func heal(amount: float) -> bool:
	if current_health >= max_health or is_dead:
		return false
	current_health = minf(max_health, current_health + amount)
	health_changed.emit(current_health, max_health)
	if has_node("/root/SoundManager"):
		SoundManager.play_sound("pickup_health")
	return true


func add_ammo(amount: int) -> bool:
	if weapons.is_empty():
		return false
	var w: Dictionary = weapons[active_slot]
	w["reserve"] += amount
	ammo_changed.emit(w["current_mag"], w["reserve"])
	if has_node("/root/SoundManager"):
		SoundManager.play_sound("pickup_ammo")
	return true


func _die() -> void:
	is_dead = true
	if has_node("/root/SoundManager"):
		SoundManager.stop_machine_gun()
		SoundManager.play_sound("player_death")
	player_died.emit()


func _process_death_physics(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	velocity.x = move_toward(velocity.x, 0.0, deceleration * delta)
	velocity.z = move_toward(velocity.z, 0.0, deceleration * delta)
	move_and_slide()

	head.rotation.z = move_toward(head.rotation.z, deg_to_rad(65.0), delta * 2.0)
	head.position.y = move_toward(head.position.y, 0.4, delta * 3.0)
