class_name Zombie3D
extends CharacterBody3D

## Enemigo Zombi 2.5D estilo SULFUR:
## Malla física 3D con sprite animado bidimensional billboard fijo en Y.
## Incluye animaciones cartoon de cambio de dirección (orientación y ladeo según cámara),
## saltos para superar aceras y obstáculos, telegrafiado/embestida de ataque físico,
## comprobación estricta de distancia 3D y línea de visión (sin golpear a través de muros)
## y secuencia dramática de muerte.

signal died(zombie: Zombie3D, score_value: int)
signal damaged(current: float, max_val: float)

enum State { IDLE, CHASE, ATTACK, DEAD }

@export_group("Identity")
@export var display_name: String = "Caminante 3D"
@export var score_value: int = 15

@export_group("Stats")
@export var max_health: float = 55.0
@export var move_speed: float = 3.5
@export var attack_damage: float = 8.0
@export var attack_range: float = 1.75
@export var attack_cooldown: float = 1.15
@export var attack_windup: float = 0.35
@export var jump_force: float = 5.2
@export var knockback_resistance: float = 0.1
@export var gravity: float = 16.0

@export_group("Presentation")
@export var hit_flash_color: Color = Color(2.5, 0.3, 0.3, 1.0)
@export var sound_groan: String = "zombie_walker"
@export_range(0.0, 1.0) var drop_ammo_chance: float = 0.35
@export_range(0.0, 1.0) var drop_medkit_chance: float = 0.15

var current_health: float = 55.0
var current_state: State = State.CHASE
var player: Player3D = null

# Nodos
@onready var sprite: AnimatedSprite3D = $AnimatedSprite3D
@onready var shadow: MeshInstance3D = $ShadowDisc
@onready var audio_3d: AudioStreamPlayer3D = $AudioStreamPlayer3D

var _attack_timer: float = 0.0
var _is_winding_up: bool = false
var _jump_cooldown: float = 0.0
var _groan_timer: float = 3.0
var _original_modulate: Color = Color.WHITE
var _sprite_base_scale: Vector3 = Vector3.ONE
var _sprite_base_pos_y: float = 0.0
var _was_on_floor: bool = true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	current_health = max_health
	add_to_group("enemy")
	
	floor_snap_length = 0.4
	floor_constant_speed = true
	floor_max_angle = deg_to_rad(48.0)
	
	if sprite != null:
		_original_modulate = sprite.modulate
		_sprite_base_scale = sprite.scale
		_sprite_base_pos_y = sprite.position.y
		sprite.play(&"walking")
	
	_groan_timer = randf_range(2.0, 6.0)
	if player == null:
		player = get_tree().get_first_node_in_group("player") as Player3D


func _physics_process(delta: float) -> void:
	if current_state == State.DEAD:
		_process_dead(delta)
		return

	if _jump_cooldown > 0.0:
		_jump_cooldown -= delta

	var on_floor: bool = is_on_floor()

	# Gravedad
	if not on_floor:
		velocity.y -= gravity * delta
		# Animación en el aire: estiramiento vertical dinámico
		if sprite != null:
			sprite.scale.y = move_toward(sprite.scale.y, _sprite_base_scale.y * 1.25, delta * 3.0)
			sprite.scale.x = move_toward(sprite.scale.x, _sprite_base_scale.x * 0.85, delta * 3.0)
	else:
		# Detectar aterrizaje para compresión física
		if not _was_on_floor:
			_apply_landing_squash()

	_was_on_floor = on_floor

	# Buscar jugador si es nulo
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Player3D
		if player == null:
			move_and_slide()
			return

	if player.is_dead:
		current_state = State.IDLE
		velocity.x = move_toward(velocity.x, 0.0, 10.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 10.0 * delta)
		move_and_slide()
		return

	# Sonidos ocasionales de gemido
	_groan_timer -= delta
	if _groan_timer <= 0.0:
		_groan_timer = randf_range(5.0, 10.0)
		_play_groan()

	var to_player: Vector3 = player.global_position - global_position
	var dist_3d: float = global_position.distance_to(player.global_position)
	var horiz_dist: float = Vector2(to_player.x, to_player.z).length()

	# Máquina de estados
	match current_state:
		State.CHASE:
			_process_chase(delta, to_player, horiz_dist, dist_3d)
		State.ATTACK:
			_process_attack(delta, to_player, dist_3d)
		State.IDLE:
			if dist_3d < 25.0:
				current_state = State.CHASE

	_sync_sprite_footing()
	move_and_slide()

	# Actualizar animación de cambio de dirección respecto a la vista de la cámara
	_process_direction_animation(delta)


## Sincroniza la posición vertical del sprite respecto a su escala para asegurar que los pies nunca se hundan
func _sync_sprite_footing() -> void:
	if sprite != null and _sprite_base_scale.y > 0.001 and current_state != State.DEAD:
		sprite.position.y = _sprite_base_pos_y * (sprite.scale.y / _sprite_base_scale.y)


func _process_chase(delta: float, to_player: Vector3, horiz_dist: float, dist_3d: float) -> void:
	# Solo pasa a estado de ataque si está cerca en 3D Y con línea de visión
	if dist_3d <= attack_range and absf(to_player.y) <= 1.2 and _has_line_of_sight():
		current_state = State.ATTACK
		_attack_timer = attack_windup
		_is_winding_up = true
		velocity.x = 0.0
		velocity.z = 0.0
		_play_windup_animation()
		return

	var dir: Vector3 = Vector3(to_player.x, 0.0, to_player.z).normalized()
	
	# Salto para superar aceras, escalones y cajas si choca contra pared o jugador está arriba
	if is_on_floor() and _jump_cooldown <= 0.0:
		if is_on_wall() or (to_player.y > 0.35 and horiz_dist < 5.0):
			velocity.y = jump_force
			_jump_cooldown = 1.2
			if sprite != null:
				var tw: Tween = create_tween()
				tw.tween_property(sprite, "scale", Vector3(_sprite_base_scale.x * 0.8, _sprite_base_scale.y * 1.3, 1.0), 0.15)

	# Repulsión entre zombis cercanos
	var separation: Vector3 = _calculate_separation()
	var final_dir: Vector3 = (dir + separation * 0.7).normalized()

	velocity.x = move_toward(velocity.x, final_dir.x * move_speed, 20.0 * delta)
	velocity.z = move_toward(velocity.z, final_dir.z * move_speed, 20.0 * delta)

	if sprite != null and not sprite.is_playing() and current_state != State.ATTACK:
		sprite.play(&"walking")


func _process_attack(delta: float, to_player: Vector3, dist_3d: float) -> void:
	_attack_timer -= delta
	velocity.x = move_toward(velocity.x, 0.0, 15.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 15.0 * delta)

	if _is_winding_up:
		if _attack_timer <= 0.0:
			_is_winding_up = false
			_attack_timer = attack_cooldown
			_execute_strike(to_player, dist_3d)
	else:
		if _attack_timer <= 0.0:
			current_state = State.CHASE
			if sprite != null:
				sprite.scale = _sprite_base_scale
				sprite.modulate = _original_modulate
				sprite.play(&"walking")


func _execute_strike(to_player: Vector3, dist_3d: float) -> void:
	var dir: Vector3 = Vector3(to_player.x, 0.0, to_player.z).normalized()
	
	# Embestida súbita hacia el jugador
	velocity += dir * (move_speed * 1.4)
	
	# Animación de estiramiento ofensivo
	if sprite != null:
		var tw: Tween = create_tween()
		tw.tween_property(sprite, "scale", Vector3(_sprite_base_scale.x * 0.8, _sprite_base_scale.y * 1.35, 1.0), 0.08)
		tw.chain().tween_property(sprite, "scale", _sprite_base_scale, 0.18)

	if has_node("/root/SoundManager"):
		SoundManager.play_sound("zombie_attack")

	# Daño al jugador: SOLO si está dentro de alcance 3D, sin muro de por medio y a altura similar
	var within_reach: bool = dist_3d <= attack_range * 1.15 and absf(to_player.y) <= 1.25
	if within_reach and _has_line_of_sight():
		player.take_damage(attack_damage, global_position)
		_spawn_slash_particle(player.global_position + Vector3(0, 1.0, 0))


## Comprueba si hay línea de visión directa con el jugador (sin muros interpuestos)
func _has_line_of_sight() -> bool:
	if player == null or not is_instance_valid(player):
		return false
	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var from_pos: Vector3 = global_position + Vector3(0, 1.1, 0)
	var to_pos: Vector3 = player.global_position + Vector3(0, 1.0, 0)
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from_pos, to_pos)
	query.collision_mask = 1 # Capa de colisión del mundo (muros, edificios, obstáculos)
	var hit: Dictionary = space_state.intersect_ray(query)
	return hit.is_empty()


## Animación cartoon de giro y ladeo según el movimiento relativo a la cámara
func _process_direction_animation(delta: float) -> void:
	if sprite == null:
		return

	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam == null:
		return

	var cam_right: Vector3 = cam.global_transform.basis.x
	var vel_h: Vector3 = Vector3(velocity.x, 0, velocity.z)
	
	var has_front_anim: bool = sprite.sprite_frames != null and (sprite.sprite_frames.has_animation("walking_front") or sprite.sprite_frames.has_animation("front_walk"))
	var front_anim_name: StringName = &"walking_front" if (sprite.sprite_frames != null and sprite.sprite_frames.has_animation("walking_front")) else &"front_walk"

	var is_attacking_or_windup: bool = (current_state == State.ATTACK or _is_winding_up)
	
	var to_cam: Vector3 = cam.global_position - global_position
	to_cam.y = 0.0
	var dist_to_cam: float = to_cam.length()
	if dist_to_cam > 0.001:
		to_cam /= dist_to_cam

	if has_front_anim:
		var show_front: bool = false
		if is_attacking_or_windup:
			show_front = true
		elif vel_h.length_squared() > 0.05:
			var move_dir: Vector3 = vel_h.normalized()
			# Si el zombi avanza en dirección hacia el jugador/cámara (frontal)
			var dot_to_cam: float = move_dir.dot(to_cam)
			if dot_to_cam > 0.22:
				show_front = true
		elif dist_to_cam < 3.5:
			# Si está muy cerca del jugador parado o merodeando, mirarlo de frente
			show_front = true

		if show_front:
			if sprite.animation != front_anim_name:
				sprite.play(front_anim_name)
			var side_dot: float = to_cam.dot(cam_right)
			sprite.flip_h = (side_dot > 0.15)
		else:
			if sprite.animation != &"walking":
				sprite.play(&"walking")
	else:
		if sprite.animation != &"walking":
			sprite.play(&"walking")

	# Control de volteo horizontal y ladeo dinámico
	if vel_h.length_squared() > 0.1:
		var dot: float = vel_h.normalized().dot(cam_right)
		if sprite.animation == &"walking":
			if dot > 0.15:
				sprite.flip_h = false
			elif dot < -0.15:
				sprite.flip_h = true
		
		# Ladeo dinámico del sprite al cambiar de dirección
		var target_rot_z: float = clampf(-dot * 0.14, -0.18, 0.18)
		sprite.rotation.z = lerpf(sprite.rotation.z, target_rot_z, delta * 9.0)
	else:
		sprite.rotation.z = lerpf(sprite.rotation.z, 0.0, delta * 6.0)


func _play_windup_animation() -> void:
	if sprite == null:
		return
	var tw: Tween = create_tween()
	tw.set_parallel(true)
	# Tensión preparatoria: ensanchamiento horizontal y compresión
	tw.tween_property(sprite, "scale", Vector3(_sprite_base_scale.x * 1.25, _sprite_base_scale.y * 0.85, 1.0), attack_windup * 0.8)
	tw.tween_property(sprite, "modulate", Color(1.4, 0.45, 0.45, 1.0), attack_windup * 0.8)


func _apply_landing_squash() -> void:
	if sprite == null:
		return
	var tw: Tween = create_tween()
	tw.tween_property(sprite, "scale", Vector3(_sprite_base_scale.x * 1.25, _sprite_base_scale.y * 0.78, 1.0), 0.08)
	tw.chain().tween_property(sprite, "scale", _sprite_base_scale, 0.15)


func _calculate_separation() -> Vector3:
	var sep: Vector3 = Vector3.ZERO
	var enemies: Array[Node] = get_tree().get_nodes_in_group("enemy")
	for e in enemies:
		if e == self or not (e is Node3D):
			continue
		var diff: Vector3 = global_position - (e as Node3D).global_position
		diff.y = 0.0
		var d: float = diff.length()
		if d > 0.01 and d < 1.4:
			sep += diff.normalized() * (1.4 - d)
	return sep


func take_damage(amount: float, hit_point: Vector3 = Vector3.ZERO, _hit_norm: Vector3 = Vector3.ZERO, dir: Vector3 = Vector3.ZERO) -> void:
	if current_state == State.DEAD:
		return

	current_health = maxf(0.0, current_health - amount)
	damaged.emit(current_health, max_health)

	# Knockback físico
	var kb_strength: float = 4.2 * (1.0 - knockback_resistance)
	velocity += Vector3(dir.x, 0.12, dir.z).normalized() * kb_strength

	# Hit flash cartoon
	if sprite != null:
		sprite.modulate = hit_flash_color
		var tween: Tween = create_tween()
		tween.tween_property(sprite, "modulate", _original_modulate, 0.12)

	_spawn_blood_splat(hit_point if hit_point != Vector3.ZERO else global_position + Vector3(0, 1.0, 0))

	if current_health <= 0.0:
		_die(dir)


func _spawn_blood_splat(pos: Vector3) -> void:
	if not is_inside_tree() or get_parent() == null:
		return
	var p: CPUParticles3D = CPUParticles3D.new()
	p.top_level = true
	p.emitting = true
	p.one_shot = true
	p.explosiveness = 0.95
	p.lifetime = 0.45
	p.amount = 12
	p.spread = 180.0
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 5.0
	p.color = Color(0.85, 0.08, 0.08, 1.0)
	
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = 0.06
	mesh.height = 0.12
	p.mesh = mesh
	
	get_parent().add_child(p)
	p.global_position = pos
	get_tree().create_timer(0.6).timeout.connect(p.queue_free)


func _spawn_slash_particle(pos: Vector3) -> void:
	if not is_inside_tree() or get_parent() == null:
		return
	var p: CPUParticles3D = CPUParticles3D.new()
	p.top_level = true
	p.emitting = true
	p.one_shot = true
	p.explosiveness = 1.0
	p.lifetime = 0.25
	p.amount = 8
	p.spread = 90.0
	p.initial_velocity_min = 1.0
	p.initial_velocity_max = 3.0
	p.color = Color(1.0, 0.2, 0.1, 1.0)
	
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = Vector3(0.04, 0.16, 0.04)
	p.mesh = mesh
	
	get_parent().add_child(p)
	p.global_position = pos
	get_tree().create_timer(0.35).timeout.connect(p.queue_free)


func _die(dir: Vector3 = Vector3.ZERO) -> void:
	current_state = State.DEAD
	died.emit(self, score_value)
	
	# Desactivar colisiones para no bloquear disparos ni paso
	collision_layer = 0
	collision_mask = 1
	
	if has_node("/root/GameManager"):
		GameManager.add_score(score_value)
		
	if has_node("/root/SoundManager"):
		SoundManager.play_sound("zombie_death")

	# Impulso de caída al morir
	velocity = Vector3(dir.x, 0.4, dir.z).normalized() * 3.2 + Vector3(0, 1.8, 0)

	# Secuencia dramática cartoon de muerte: cae hacia atrás y se aplana al suelo
	if sprite != null:
		var tween: Tween = create_tween().set_parallel(true)
		tween.tween_property(sprite, "rotation:x", deg_to_rad(-80.0), 0.35).set_trans(Tween.TRANS_QUAD)
		tween.tween_property(sprite, "scale:y", _sprite_base_scale.y * 0.15, 0.45)
		tween.tween_property(sprite, "position:y", 0.08, 0.45)
		tween.tween_property(sprite, "modulate:a", 0.0, 0.65).set_delay(0.2)
		tween.chain().tween_callback(_on_death_completed)
	else:
		_on_death_completed()


func _on_death_completed() -> void:
	_maybe_drop_pickup()
	queue_free()


const WEAPON_DROP_3D: PackedScene = preload("res://scenes/3d/pickups/pickup_weapon_3d.tscn")
const AMMO_DROP_3D: PackedScene = preload("res://scenes/3d/pickups/pickup_ammo_3d.tscn")
const MEDKIT_DROP_3D: PackedScene = preload("res://scenes/3d/pickups/pickup_medkit_3d.tscn")


func _maybe_drop_pickup() -> void:
	if get_parent() == null:
		return

	var is_critical: bool = _check_player_critical_health()
	var needs_weapon: bool = _check_player_needs_weapon()

	# Con salud crítica (<= 20%), probabilidad muy alta de drop (75%), si necesita armas 55%, base 35%
	var effective_chance: float = 0.75 if is_critical else (0.55 if needs_weapon else 0.35)
	if randf() > effective_chance:
		return

	var scene_to_drop: PackedScene = _pick_drop_scene(needs_weapon, is_critical)
	if scene_to_drop != null:
		var item: Node3D = scene_to_drop.instantiate() as Node3D
		if item != null:
			var drop_pos: Vector3 = global_position + Vector3(0, 0.45, 0)
			get_parent().add_child(item)
			item.global_position = drop_pos


func _check_player_critical_health() -> bool:
	if player == null or not is_instance_valid(player):
		if is_inside_tree():
			player = get_tree().get_first_node_in_group("player") as Player3D
	if player != null and is_instance_valid(player) and player.max_health > 0:
		return (player.current_health / player.max_health) <= 0.20
	return false


func _check_player_needs_weapon() -> bool:
	if player == null or not is_instance_valid(player):
		if is_inside_tree():
			player = get_tree().get_first_node_in_group("player") as Player3D
	if player != null and is_instance_valid(player) and player.has_method("player_needs_weapon"):
		return player.player_needs_weapon()
	return false


func _pick_drop_scene(needs_weapon: bool, is_critical: bool = false) -> PackedScene:
	# Si la vida está en 20% o menos, prioridad absoluta a la supervivencia (75% botiquín)
	if is_critical:
		if randf() < 0.75:
			return MEDKIT_DROP_3D
		elif needs_weapon and randf() < 0.50:
			return WEAPON_DROP_3D
		else:
			return AMMO_DROP_3D

	# 1. Si al jugador le faltan armas del arsenal: 60% probabilidad de soltar arma
	if needs_weapon and randf() < 0.60:
		return WEAPON_DROP_3D

	# 2. Si ya se obtuvieron todas las armas, NUNCA soltar más estuches de armas.
	# En su lugar, se sueltan únicamente balas (75%) o botiquines (25%).
	if randf() < 0.75:
		return AMMO_DROP_3D
	else:
		return MEDKIT_DROP_3D


func _process_dead(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	velocity.x = move_toward(velocity.x, 0.0, 12.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 12.0 * delta)
	move_and_slide()


func _play_groan() -> void:
	if audio_3d != null and SoundManager.SOUNDS.has(sound_groan):
		audio_3d.stream = SoundManager.SOUNDS[sound_groan]
		audio_3d.pitch_scale = randf_range(0.9, 1.1)
		audio_3d.play()
