class_name Zombie
extends CharacterBody2D

## Enemigo zombi con máquina de estados (aparecer → perseguir → atacar → morir).
## Reutiliza HealthComponent para la vitalidad y es totalmente configurable por
## el Inspector, de modo que un mismo script da vida a caminantes, corredores y brutos.

## Emitida al morir el zombi, con el valor de puntuación que otorga.
signal died(zombie: Zombie, score_value: int)
## Emitida al recibir daño, útil para barras de vida o efectos.
signal damaged(current_health: float, max_health: float)

enum State { SPAWNING, IDLE, CHASE, ATTACK, DEAD }

const BLOOD_TEXTURE: Texture2D = preload("res://assets/generated/fx_blood_splat.png")
const DECAL_GROUP: StringName = &"decals"

@export_group("Identity")
@export var display_name: String = "Caminante"
## Puntos otorgados al jugador al eliminarlo.
@export var score_value: int = 10

@export_group("Movement")
@export var move_speed: float = 70.0
@export var acceleration: float = 700.0
## Radio dentro del cual otros zombis se repelen para no apilarse.
@export var separation_radius: float = 26.0
@export var separation_force: float = 340.0
## 0 = se empuja con facilidad, 1 = inmune al retroceso.
@export_range(0.0, 1.0, 0.05) var knockback_resistance: float = 0.0

@export_group("Obstacle Avoidance")
## Longitud de los sondeos con los que el zombi rodea muros y estructuras.
@export var avoid_probe_distance: float = 48.0
## Peso del desvío frente al empuje directo hacia el objetivo.
@export_range(0.0, 2.0, 0.05) var avoidance_strength: float = 1.2
## Segundos entre sondeos (evita lanzar rayos en cada frame).
@export var avoidance_interval: float = 0.12

@export_group("Combat")
@export var attack_damage: float = 12.0
## Distancia máxima a la que puede golpear al jugador.
@export var attack_range: float = 46.0
## Segundos de espera entre golpes.
@export var attack_cooldown: float = 1.1
## Antelación del golpe: da margen al jugador para esquivar.
@export var attack_windup: float = 0.3
## Radio a partir del cual un zombi pierde de vista a su objetivo.
@export var detection_radius: float = 1200.0

@export_group("Animation")
@export var walk_animation: StringName = &"walking"
@export var walk_speed_scale: float = 1.0
@export var idle_speed_scale: float = 0.4

@export_group("Presentation")
@export var hit_flash_color: Color = Color(1.0, 0.35, 0.35)
@export var hit_flash_time: float = 0.12
@export var spawn_duration: float = 0.35
@export var death_fade_time: float = 0.5
@export var death_delay: float = 0.4

@export_group("Drops")
## Escenas que puede soltar al morir (botiquín, munición...).
@export var drop_scenes: Array[PackedScene] = []
## Probabilidad base de soltar algo al morir.
@export_range(0.0, 1.0, 0.01) var drop_chance: float = 0.12
## Multiplicador global de esa probabilidad (los escenarios heredan este valor).
@export var drop_rate_multiplier: float = 2.6
## Con esta munición total o menos, el botín se inclina claramente a munición.
@export var prefer_ammo_below: int = 96
## Con esta munición total o menos, soltar munición está garantizado.
@export var guarantee_ammo_below: int = 36
## Distancia máxima a la que se recoloca un botín para que no caiga dentro de un muro.
@export var drop_search_radius: float = 72.0

@export_group("Node References")
@export var health_component: HealthComponent
@export var animated_sprite: AnimatedSprite2D
@export var separation_sensor: Area2D


var _state: int = State.SPAWNING
var _target: Node2D = null
var _velocity_knockback: Vector2 = Vector2.ZERO
var _attack_timer: float = 0.0
var _attack_pending: bool = false
var _attack_windup_elapsed: float = 0.0
var _attack_dir: Vector2 = Vector2.RIGHT
var _slash_effect_timer: float = 0.0
var _slash_effect_points: PackedVector2Array = []
var _sprite_base_scale: Vector2 = Vector2.ONE
var _flash_tween: Tween = null
var _attack_tween: Tween = null
var _avoid_direction: Vector2 = Vector2.ZERO
var _avoid_timer: float = 0.0
var _avoid_side: float = 0.0
var _groan_timer: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _base_move_speed: float = -1.0
var _base_attack_damage: float = -1.0
var _base_walk_speed_scale: float = -1.0
var _base_max_health: float = -1.0

## Caché compartida por todos los zombis: tipo de recogible de cada escena de botín.
static var _drop_type_cache: Dictionary = {}


func _ready() -> void:
	add_to_group("enemies")
	_rng.randomize()
	_resolve_references()
	_apply_difficulty()
	if has_node("/root/GameSettings"):
		var gs: Node = get_node("/root/GameSettings")
		if not gs.is_connected("settings_applied", Callable(self, "_apply_difficulty")):
			gs.connect("settings_applied", Callable(self, "_apply_difficulty"))
	_connect_health()
	_acquire_target()
	_play_spawn_animation()


func _resolve_references() -> void:
	if health_component == null:
		health_component = get_node_or_null("HealthComponent") as HealthComponent
	if animated_sprite == null:
		animated_sprite = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if animated_sprite != null:
		_sprite_base_scale = animated_sprite.scale.abs()
	if separation_sensor == null:
		separation_sensor = get_node_or_null("SeparationSensor") as Area2D


func _apply_difficulty() -> void:
	if _base_move_speed < 0.0:
		_base_move_speed = move_speed
	if _base_attack_damage < 0.0:
		_base_attack_damage = attack_damage
	if _base_walk_speed_scale < 0.0:
		_base_walk_speed_scale = walk_speed_scale
	if health_component != null and _base_max_health < 0.0:
		_base_max_health = health_component.max_health

	var dmg_mult: float = 1.0
	var spd_mult: float = 1.0
	if has_node("/root/GameSettings"):
		dmg_mult = GameSettings.enemy_damage_multiplier
		spd_mult = GameSettings.enemy_speed_multiplier

	# Progresión gradual en Modo Infinito según la oleada alcanzada
	if has_node("/root/GameManager") and GameManager.is_endless_mode:
		dmg_mult *= GameManager.get_endless_damage_multiplier()
		spd_mult *= GameManager.get_endless_speed_multiplier()
		if health_component != null and _base_max_health > 0.0:
			var old_max: float = health_component.max_health
			var ratio: float = health_component.current_health / old_max if old_max > 0.0 else 1.0
			var hp_mult: float = GameManager.get_endless_health_multiplier()
			health_component.max_health = _base_max_health * hp_mult
			health_component.current_health = health_component.max_health * ratio

	attack_damage = _base_attack_damage * dmg_mult
	move_speed = _base_move_speed * spd_mult
	walk_speed_scale = _base_walk_speed_scale * spd_mult


func _connect_health() -> void:
	if health_component == null:
		push_warning("[Zombie] %s sin HealthComponent." % name)
		return
	health_component.damage_received.connect(_on_damage_received)
	health_component.died.connect(_on_died)


func _play_spawn_animation() -> void:
	# Se anima el modulate del propio zombi (no el del sprite) para no dejar
	# el sprite con alfa 0 de forma permanente.
	modulate.a = 0.0
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 1.0, spawn_duration)
	if animated_sprite != null:
		animated_sprite.scale = _sprite_base_scale * 0.6
		tween.tween_property(animated_sprite, "scale", _sprite_base_scale, spawn_duration) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.chain().tween_callback(func() -> void:
		_state = State.CHASE
	)


# ------------------------------------------------------------------------------
# Bucle principal
# ------------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if _state == State.DEAD:
		return

	if _attack_timer > 0.0:
		_attack_timer = maxf(0.0, _attack_timer - delta)

	# Sonidos ambientales de gemidos ocasionales
	_groan_timer -= delta
	if _groan_timer <= 0.0:
		_groan_timer = _rng.randf_range(8.0, 16.0)
		if _state == State.CHASE and has_node("/root/SoundManager"):
			SoundManager.play_zombie_groan(global_position, display_name)

	if _attack_pending:
		_attack_windup_elapsed += delta

	if _state == State.SPAWNING:
		_apply_deceleration(delta)
		return

	if _target == null or not is_instance_valid(_target):
		_acquire_target()

	_update_state(delta)
	_apply_movement(delta)
	move_and_slide()
	_update_animation()


func _update_state(_delta: float) -> void:
	if _target == null:
		_state = State.IDLE
		return

	if _attack_pending:
		_state = State.ATTACK
		return

	var distance: float = global_position.distance_to(_target.global_position)
	if distance > detection_radius:
		_state = State.IDLE
		return

	if distance <= attack_range:
		# Solo pasar a estado de ataque si TIENE línea de visión directa.
		# Si hay un muro entre el zombi y el jugador, debe seguir en CHASE
		# para rodear el muro y no quedarse trabado contra la pared.
		if _has_line_of_sight():
			_state = State.ATTACK
			_try_attack()
		else:
			_state = State.CHASE
	else:
		_state = State.CHASE


func _acquire_target() -> void:
	_target = get_tree().get_first_node_in_group("player") as Node2D


# -----------------------------------------------------

func _apply_movement(delta: float) -> void:
	var desired: Vector2 = Vector2.ZERO

	if _avoid_timer > 0.0:
		_avoid_timer = maxf(0.0, _avoid_timer - delta)

	if _attack_pending:
		desired = Vector2.ZERO
	elif _state == State.CHASE and _target != null:
		var to_target: Vector2 = (_target.global_position - global_position).normalized()
		
		# Deslizamiento inteligente y tracción si el zombi está tocando un muro
		if is_on_wall():
			var wall_norm: Vector2 = get_wall_normal()
			# Si intenta avanzar hacia el muro:
			if to_target.dot(wall_norm) < 0.2:
				var slide_dir: Vector2 = to_target.slide(wall_norm).normalized()
				if slide_dir == Vector2.ZERO or slide_dir.length_squared() < 0.01:
					if _avoid_side == 0.0:
						_avoid_side = 1.0 if _rng.randf() > 0.5 else -1.0
					slide_dir = wall_norm.orthogonal() * _avoid_side
				_avoid_direction = slide_dir
				_avoid_timer = 0.22

		var avoid_vec: Vector2 = _get_avoidance_vector(to_target)
		var steering: Vector2
		if is_on_wall() and _avoid_direction != Vector2.ZERO:
			steering = _avoid_direction * 1.8 + to_target * 0.2
		elif avoid_vec != Vector2.ZERO:
			steering = to_target * 0.35 + avoid_vec * avoidance_strength
		else:
			steering = to_target

		desired = steering.normalized() * move_speed
		desired += _get_separation_vector() * separation_force

	var combined: Vector2 = desired + _velocity_knockback
	velocity = velocity.move_toward(combined, acceleration * delta)

	# Preservar velocidad tangente si se roza un muro para no trabarse
	if is_on_wall():
		var w_norm: Vector2 = get_wall_normal()
		if velocity.dot(w_norm) < 0.0:
			velocity = velocity.slide(w_norm)

	_velocity_knockback = _velocity_knockback.move_toward(Vector2.ZERO, acceleration * 1.5 * delta)

	if not _attack_pending and _state == State.CHASE and _target != null:
		var facing: float = signf(_target.global_position.x - global_position.x)
		if facing != 0.0 and animated_sprite != null:
			animated_sprite.scale.x = _sprite_base_scale.x * facing


func _apply_deceleration(delta: float) -> void:
	velocity = velocity.move_toward(Vector2.ZERO, acceleration * delta)
	move_and_slide()


## Sondeo multi-ángulo contra muros y obstáculos para rodear estructuras fluidamente.
func _get_avoidance_vector(direction: Vector2) -> Vector2:
	if _avoid_timer > 0.0:
		return _avoid_direction

	_avoid_timer = avoidance_interval

	if direction == Vector2.ZERO:
		_avoid_direction = Vector2.ZERO
		return _avoid_direction

	var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	if space == null:
		_avoid_direction = Vector2.ZERO
		return _avoid_direction

	# Si el frente está despejado, no desviar
	var front_dist: float = _probe_distance(space, direction)
	if front_dist >= avoid_probe_distance * 0.9:
		_avoid_side = 0.0
		_avoid_direction = Vector2.ZERO
		return _avoid_direction

	var left_side: Vector2 = direction.rotated(-PI * 0.5)
	var right_side: Vector2 = direction.rotated(PI * 0.5)
	var diag_left: Vector2 = direction.rotated(-PI * 0.25)
	var diag_right: Vector2 = direction.rotated(PI * 0.25)

	var score_l: float = _probe_distance(space, left_side) + _probe_distance(space, diag_left) * 0.8
	var score_r: float = _probe_distance(space, right_side) + _probe_distance(space, diag_right) * 0.8

	if _avoid_side == 0.0:
		_avoid_side = -1.0 if score_l >= score_r else 1.0
	else:
		var current_dist: float = _probe_distance(space, direction.rotated(_avoid_side * PI * 0.5))
		if current_dist < 22.0 and (score_l if _avoid_side > 0.0 else score_r) > 32.0:
			_avoid_side = -_avoid_side

	var best_side: Vector2 = direction.rotated(_avoid_side * PI * 0.5)
	_avoid_direction = best_side
	return _avoid_direction


func _probe_distance(space: PhysicsDirectSpaceState2D, dir: Vector2) -> float:
	var from: Vector2 = global_position
	var to: Vector2 = from + dir * avoid_probe_distance
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(from, to)
	query.collision_mask = 1  # Capa 1: colisiones del mapa / muros
	query.exclude = [get_rid()]

	var hit: Dictionary = space.intersect_ray(query)
	if hit.is_empty():
		return avoid_probe_distance
	return from.distance_to(hit.position)



## Calcula una fuerza de repulsión suave contra los zombis vecinos.
func _get_separation_vector() -> Vector2:
	if separation_sensor == null or not separation_sensor.monitoring:
		return Vector2.ZERO

	var push: Vector2 = Vector2.ZERO
	var neighbors: Array[Area2D] = separation_sensor.get_overlapping_areas()
	for area in neighbors:
		var other: Node2D = area.get_parent() as Node2D
		if other == null or other == self:
			continue
		var diff: Vector2 = global_position - other.global_position
		var dist: float = diff.length()
		if dist > 0.001 and dist < separation_radius:
			push += (diff / dist) * (1.0 - dist / separation_radius)

	return push.normalized() if push.length() > 1.0 else push


func _update_animation() -> void:
	if animated_sprite == null or animated_sprite.sprite_frames == null:
		return
	if not animated_sprite.sprite_frames.has_animation(walk_animation):
		return

	if animated_sprite.animation != walk_animation:
		animated_sprite.play(walk_animation)

	if _attack_pending:
		animated_sprite.speed_scale = 0.0
		return

	var is_moving: bool = velocity.length() > 12.0
	animated_sprite.speed_scale = walk_speed_scale if is_moving else idle_speed_scale


# ------------------------------------------------------------------------------
# Ataque
# ------------------------------------------------------------------------------

func _try_attack() -> void:
	if _attack_timer > 0.0 or _attack_pending or _target == null:
		return
	if not _has_line_of_sight():
		return

	_attack_pending = true
	_attack_windup_elapsed = 0.0
	_attack_dir = (_target.global_position - global_position).normalized()
	if _attack_dir == Vector2.ZERO:
		_attack_dir = Vector2.RIGHT

	var facing: float = 1.0 if _attack_dir.x >= 0 else -1.0
	if animated_sprite != null:
		animated_sprite.scale.x = _sprite_base_scale.x * facing

	# Animación de anticipación / telegrafiado físico:
	# El zombi se echa hacia atrás con deformación física de preparación (sin alterar color)
	if _attack_tween != null and _attack_tween.is_valid():
		_attack_tween.kill()

	_attack_tween = create_tween()
	# Postura de retroceso/tensión preparatoria (squash vertical y estiramiento horizontal)
	var windup_scale = Vector2(_sprite_base_scale.x * facing * 1.25, _sprite_base_scale.y * 0.8)
	_attack_tween.tween_property(animated_sprite, "scale", windup_scale, attack_windup * 0.85).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	queue_redraw()

	# Temporizador del telegrafiado para que el jugador tenga tiempo de esquivar
	var windup_timer: SceneTreeTimer = get_tree().create_timer(
		attack_windup, false, false, true
	)
	windup_timer.timeout.connect(_on_attack_landed)


func _on_attack_landed() -> void:
	if _state == State.DEAD or not _attack_pending:
		return
	_attack_pending = false
	_attack_windup_elapsed = 0.0

	if _target == null or not is_instance_valid(_target):
		_reset_after_attack()
		return

	# Embestida súbita hacia el objetivo al asestar el golpe
	var facing: float = 1.0 if _attack_dir.x >= 0 else -1.0
	var lunge_force: float = move_speed * 1.8 + 80.0
	_velocity_knockback += _attack_dir * lunge_force

	# Animación física del golpe (estiramiento ofensivo, sin tintes de color en el zombi)
	if _attack_tween != null and _attack_tween.is_valid():
		_attack_tween.kill()
	_attack_tween = create_tween()
	var strike_scale = Vector2(_sprite_base_scale.x * facing * 0.8, _sprite_base_scale.y * 1.3)
	if animated_sprite != null:
		_attack_tween.tween_property(animated_sprite, "scale", strike_scale, 0.07).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_attack_tween.chain().tween_property(animated_sprite, "scale", Vector2(_sprite_base_scale.x * facing, _sprite_base_scale.y), 0.15)

	if has_node("/root/SoundManager"):
		SoundManager.play_zombie_attack(global_position)

	# Daño al jugador SOLO si sigue dentro del rango de impacto y no esquivó
	var distance: float = global_position.distance_to(_target.global_position)
	if distance <= attack_range * 1.1 and _has_line_of_sight():
		if _target.has_method("take_damage"):
			_target.call("take_damage", attack_damage, self)
		if _target.has_method("add_camera_shake"):
			var shake: float = 3.5
			if is_in_group("boss"):
				shake = 10.0
			elif is_in_group("miniboss"):
				shake = 6.5
			_target.call("add_camera_shake", shake)

	_attack_timer = attack_cooldown
	queue_redraw()


func _reset_after_attack() -> void:
	if animated_sprite != null:
		var facing: float = signf(animated_sprite.scale.x)
		if facing == 0.0:
			facing = 1.0
		animated_sprite.scale = Vector2(_sprite_base_scale.x * facing, _sprite_base_scale.y)
		animated_sprite.modulate = Color.WHITE
	_attack_pending = false
	_attack_timer = attack_cooldown
	queue_redraw()


func _draw() -> void:
	pass



## Comprueba que no haya un muro entre el zombi y su objetivo.
func _has_line_of_sight() -> bool:
	if _target == null:
		return false
	var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(
		global_position, _target.global_position
	)
	query.collision_mask = 1  # Capa "world"
	query.exclude = [get_rid()]
	var result: Dictionary = space.intersect_ray(query)
	return result.is_empty()


# ------------------------------------------------------------------------------
# Daño y muerte
# ------------------------------------------------------------------------------

## Entrada de daño estándar (usada por proyectiles, explosiones o cuerpo a cuerpo).
func take_damage(amount: float, source: Node = null) -> void:
	if _state == State.DEAD or health_component == null:
		return
	health_component.take_damage(amount, source)


## Aplica un empuje instantáneo, reducido por la resistencia al retroceso.
func apply_knockback(force: Vector2) -> void:
	if _state == State.DEAD:
		return
	_velocity_knockback += force * (1.0 - knockback_resistance)


func heal(amount: float) -> bool:
	if health_component == null:
		return false
	health_component.heal(amount)
	return true


func _on_damage_received(_amount: float, _source: Node) -> void:
	_play_hit_flash()
	_spawn_blood(0.55)
	if health_component != null:
		damaged.emit(health_component.current_health, health_component.max_health)


func _play_hit_flash() -> void:
	if animated_sprite == null:
		return
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	animated_sprite.modulate = hit_flash_color
	_flash_tween = create_tween()
	_flash_tween.tween_property(animated_sprite, "modulate", Color.WHITE, hit_flash_time)


func _on_died() -> void:
	_die()


func _die() -> void:
	if _state == State.DEAD:
		return
	_state = State.DEAD
	_attack_pending = false
	velocity = Vector2.ZERO
	_target = null

	# Desactivar toda interacción física
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
	if separation_sensor != null:
		separation_sensor.set_deferred("monitoring", false)

	_spawn_blood(1.4)
	if has_node("/root/SoundManager"):
		SoundManager.play_zombie_death(global_position)
	# El drop es un Area2D: añadirlo al árbol dentro del sondeo de física
	# (justo aquí, desde body_entered) es ilegal, así que se difiere.
	call_deferred("_spawn_drop")
	died.emit(self, score_value)

	if animated_sprite != null:
		animated_sprite.speed_scale = 0.0

	# Caída y desvanecimiento
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 0.0, death_fade_time).set_delay(death_delay)
	if animated_sprite != null:
		tween.tween_property(animated_sprite, "rotation", deg_to_rad(78.0), death_fade_time) \
			.set_delay(death_delay)
	tween.chain().tween_callback(queue_free)


## Deja una mancha de sangre persistente en el suelo.
func _spawn_blood(scale_factor: float) -> void:
	var parent: Node = get_parent()
	if parent == null:
		return
	var decal: Sprite2D = Sprite2D.new()
	decal.texture = BLOOD_TEXTURE
	decal.global_position = global_position
	decal.rotation = _rng.randf_range(0.0, TAU)
	decal.scale = Vector2.ONE * scale_factor
	decal.modulate = Color(1.0, 1.0, 1.0, 0.75)
	decal.z_index = -1
	decal.add_to_group(DECAL_GROUP)
	parent.add_child(decal)


func _spawn_drop() -> void:
	if drop_scenes.is_empty():
		return
	var parent: Node = get_parent()
	if parent == null:
		return

	var total_ammo: int = _get_player_total_ammo()
	var ammo_critical: bool = total_ammo >= 0 and total_ammo <= guarantee_ammo_below
	var ammo_low: bool = total_ammo >= 0 and total_ammo <= prefer_ammo_below
	var needs_weapon: bool = _player_needs_weapon()

	# Con la munición bajo mínimos o si aún le faltan armas, se garantiza mayor frecuencia
	if not ammo_critical:
		var effective_chance: float = clampf(drop_chance * drop_rate_multiplier, 0.0, 1.0)
		if needs_weapon:
			effective_chance = maxf(effective_chance, 0.55)
		if _rng.randf() > effective_chance:
			return

	var scene: PackedScene = _pick_drop_scene(ammo_low, ammo_critical)
	if scene == null:
		return

	var drop: Node2D = scene.instantiate() as Node2D
	if drop == null:
		return
	parent.add_child(drop)
	drop.global_position = _find_free_drop_position(global_position)


const WEAPON_DROP_SCENE: PackedScene = preload("res://scenes/entities/pickups/pickup_weapon.tscn")

## Comprueba si el jugador aún tiene alguna de las 3 armas por desbloquear.
func _player_needs_weapon() -> bool:
	var player_node: Node = get_tree().get_first_node_in_group("player")
	if player_node != null and "unlocked_weapons" in player_node:
		var unlocked_list: Array = player_node.unlocked_weapons
		for is_unlocked in unlocked_list:
			if not is_unlocked:
				return true
	return false

## Elige el botín según probabilidades balanceadas:
## - Con munición crítica: munición garantizada.
## - Si el jugador no tiene todas las armas: 60% de probabilidad de soltar arma.
## - De los consumibles comunes: 75% munición / balas y ~25-30% botiquín de salud.
func _pick_drop_scene(prefer_ammo: bool, force_ammo: bool) -> PackedScene:
	if force_ammo:
		var forced: PackedScene = _find_drop_scene_of_type(Pickup.PickupType.AMMO)
		if forced != null:
			return forced

	# Si al jugador le faltan armas del arsenal, priorizar el drop de arma
	if _player_needs_weapon() and _rng.randf() < 0.60:
		var weapon_drop: PackedScene = _find_drop_scene_of_type(Pickup.PickupType.WEAPON)
		if weapon_drop != null:
			return weapon_drop
		return WEAPON_DROP_SCENE

	# 1. Probabilidad habitual de soltar equipamiento de armas (10%)
	if _rng.randf() < 0.10:
		var weapon_drop: PackedScene = _find_drop_scene_of_type(Pickup.PickupType.WEAPON)
		if weapon_drop != null:
			return weapon_drop
		return WEAPON_DROP_SCENE

	# 2. Si la munición está baja o se cumple el 75% de preferencia para balas
	if prefer_ammo or _rng.randf() < 0.75 or not _has_medkit_in_pool():
		var ammo_drop: PackedScene = _find_drop_scene_of_type(Pickup.PickupType.AMMO)
		if ammo_drop != null:
			return ammo_drop

	# 3. Botiquín (30% relativo o fallback)
	var medkit_drop: PackedScene = _find_drop_scene_of_type(Pickup.PickupType.MEDKIT)
	if medkit_drop != null:
		return medkit_drop

	return drop_scenes[_rng.randi_range(0, drop_scenes.size() - 1)]


func _has_medkit_in_pool() -> bool:
	return _find_drop_scene_of_type(Pickup.PickupType.MEDKIT) != null


func _find_drop_scene_of_type(wanted_type: int) -> PackedScene:
	for scene: PackedScene in drop_scenes:
		if _get_drop_scene_type(scene) == wanted_type:
			return scene
	return null


## Lee (y memoriza en la caché estática) el tipo de recogible de una escena de botín.
func _get_drop_scene_type(scene: PackedScene) -> int:
	if scene == null:
		return -1
	if _drop_type_cache.has(scene):
		return int(_drop_type_cache[scene])

	var probe: Node = scene.instantiate()
	var resolved_type: int = -1
	if probe is Pickup:
		resolved_type = (probe as Pickup).pickup_type
	if probe != null:
		probe.free()
	_drop_type_cache[scene] = resolved_type
	return resolved_type


## Munición total del jugador (cargador + reserva), o -1 si no se puede saber.
func _get_player_total_ammo() -> int:
	var target: Node = get_tree().get_first_node_in_group("player")
	if target == null:
		return -1
	var actor: Player = target as Player
	if actor == null or actor.weapon_component == null:
		return -1
	return actor.weapon_component.magazine + actor.weapon_component.reserve_ammo


## Busca un punto libre cerca de [param base] para que el botín no caiga dentro
## de un muro y quede imposible de recoger.
func _find_free_drop_position(base: Vector2) -> Vector2:
	var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	if space == null:
		return base

	var rings: Array[float] = [0.0, drop_search_radius * 0.5, drop_search_radius]
	for radius: float in rings:
		var steps: int = 1 if radius <= 0.0 else 8
		for step: int in range(steps):
			var angle: float = TAU * float(step) / float(steps)
			var candidate: Vector2 = base + Vector2.RIGHT.rotated(angle) * radius
			if _is_drop_point_free(space, candidate):
				return candidate
	return base


func _is_drop_point_free(space: PhysicsDirectSpaceState2D, point: Vector2) -> bool:
	var query: PhysicsPointQueryParameters2D = PhysicsPointQueryParameters2D.new()
	query.position = point
	query.collision_mask = 1  # Capa "world"
	query.collide_with_bodies = true
	query.collide_with_areas = false
	return space.intersect_point(query).is_empty()


# ------------------------------------------------------------------------------
# Consultas
# ------------------------------------------------------------------------------

func is_alive() -> bool:
	return _state != State.DEAD


func get_health_percentage() -> float:
	if health_component == null:
		return 0.0
	return health_component.get_health_percentage()
