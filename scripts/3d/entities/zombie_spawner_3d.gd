class_name ZombieSpawner3D
extends Node3D

## Spawner 3D de oleadas de zombis estilo SULFUR.
## Gestiona el conteo de enemigos vivos, calcula posiciones radiales verificadas
## para nunca aparecer dentro de muros ni props, y escala por oleadas.
## En la oleada 3 y 4 de CADA nivel genera siempre un Miniboss Mutante.
## En el nivel del Jefe Final (is_boss_level), el Titán Mutante aparece desde el inicio con su barra de vida en HUD.
## Cada nivel dura 5 oleadas para avanzar secuencialmente.

signal wave_started(wave_number: int)
signal zombie_spawned(zombie: Zombie3D)
signal all_waves_completed()

@export var max_alive: int = 25
@export var spawn_interval: float = 2.0
@export var min_spawn_dist: float = 12.0
@export var max_spawn_dist: float = 24.0
@export var total_waves: int = 5
@export var is_boss_level: bool = false

@export var walker_scene: PackedScene = preload("res://scenes/3d/entities/zombie_walker_3d.tscn")
@export var runner_scene: PackedScene = preload("res://scenes/3d/entities/zombie_runner_3d.tscn")
@export var brute_scene: PackedScene = preload("res://scenes/3d/entities/zombie_brute_3d.tscn")
@export var miniboss_scene: PackedScene = preload("res://scenes/3d/entities/zombie_miniboss_3d.tscn")
@export var boss_scene: PackedScene = preload("res://scenes/3d/entities/zombie_boss_3d.tscn")

var current_wave: int = 1
var zombies_to_spawn_this_wave: int = 12
var zombies_spawned_this_wave: int = 0
var is_wave_active: bool = true
var _all_done: bool = false
var _boss_spawned: bool = false
var _miniboss_spawned_this_wave: bool = false
var _active_boss: Zombie3D = null

var _timer: float = 0.0
var _player: Player3D = null


func _ready() -> void:
	_player = get_tree().get_first_node_in_group("player") as Player3D
	if has_node("/root/GameManager") and total_waves > 0:
		GameManager.configure_level(total_waves)

	if is_boss_level:
		# En el mundo del jefe final, el Titán Mutante aparece desde el inicio
		call_deferred("_spawn_boss")

	_start_wave(1)


func _process(delta: float) -> void:
	if not is_wave_active:
		return

	_timer -= delta
	if _timer <= 0.0:
		_timer = spawn_interval
		_try_spawn_zombie()


func _start_wave(wave: int) -> void:
	current_wave = wave
	_miniboss_spawned_this_wave = false
	zombies_to_spawn_this_wave = 8 + wave * 4
	zombies_spawned_this_wave = 0
	is_wave_active = true
	wave_started.emit(current_wave)

	if has_node("/root/GameManager"):
		GameManager.notify_wave_started(current_wave)

	if has_node("/root/SoundManager"):
		SoundManager.play_sound("wave_alert")


func _try_spawn_zombie() -> void:
	# En oleada 3 o 4 de cada nivel sin excepción, generar al Miniboss
	if (current_wave == 3 or current_wave == 4) and not _miniboss_spawned_this_wave:
		_spawn_miniboss()
		return

	if zombies_spawned_this_wave >= zombies_to_spawn_this_wave:
		var alive_enemies: Array[Node] = get_tree().get_nodes_in_group("enemy")
		if is_boss_level:
			# En el nivel de jefe, contar únicamente esbirros para que las oleadas de refuerzo sigan avanzando
			var alive_minions: Array[Node] = []
			for e in alive_enemies:
				if is_instance_valid(e) and e != _active_boss and not e.is_in_group("boss"):
					alive_minions.append(e)
			if alive_minions.is_empty():
				_complete_wave()
		else:
			if alive_enemies.is_empty():
				_complete_wave()
		return

	var current_alive: int = get_tree().get_nodes_in_group("enemy").size()
	if current_alive >= max_alive:
		return

	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Player3D
		if _player == null:
			return

	# Elegir tipo de zombi según avance de oleada
	var scene_to_spawn: PackedScene = walker_scene
	var roll: float = randf()
	if current_wave >= 3 and roll < 0.32:
		scene_to_spawn = brute_scene
	elif current_wave >= 2 and roll < 0.60:
		scene_to_spawn = runner_scene

	if scene_to_spawn == null:
		return

	var z: Zombie3D = scene_to_spawn.instantiate() as Zombie3D
	var spawn_pos: Vector3 = _get_spawn_position()
	z.position = spawn_pos
	get_parent().add_child(z)

	zombies_spawned_this_wave += 1
	zombie_spawned.emit(z)


func _spawn_miniboss() -> void:
	_miniboss_spawned_this_wave = true
	if miniboss_scene == null:
		return
	var mb: Zombie3D = miniboss_scene.instantiate() as Zombie3D
	mb.position = _get_spawn_position()
	get_parent().add_child(mb)
	zombies_spawned_this_wave += 1
	zombie_spawned.emit(mb)
	if has_node("/root/SoundManager"):
		SoundManager.play_sound("zombie_miniboss")


func _spawn_boss() -> void:
	if _boss_spawned or boss_scene == null:
		return
	_boss_spawned = true
	var boss: Zombie3D = boss_scene.instantiate() as Zombie3D
	var center: Vector3 = _player.global_position if _player != null else global_position
	# Aparecer a unos 15 metros en el escenario
	boss.position = center + Vector3(0.0, 0.2, -15.0)
	get_parent().add_child(boss)
	_active_boss = boss
	zombie_spawned.emit(boss)

	if has_node("/root/SoundManager"):
		SoundManager.play_sound("boss_roar")

	boss.died.connect(func(_z, _score):
		_on_boss_defeated()
	)


func _on_boss_defeated() -> void:
	_active_boss = null
	if has_node("/root/GameManager"):
		GameManager.notify_level_won()
	all_waves_completed.emit()


func _get_spawn_position() -> Vector3:
	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var center: Vector3 = _player.global_position if _player != null else global_position
	
	for attempt in range(8):
		var angle: float = randf() * TAU
		var dist: float = randf_range(min_spawn_dist, max_spawn_dist)
		var cand_x: float = clampf(center.x + cos(angle) * dist, -24.0, 24.0)
		var cand_z: float = clampf(center.z + sin(angle) * dist, -24.0, 24.0)
		
		var from_pos: Vector3 = Vector3(cand_x, 12.0, cand_z)
		var to_pos: Vector3 = Vector3(cand_x, -1.0, cand_z)
		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from_pos, to_pos)
		query.collision_mask = 1
		var result: Dictionary = space_state.intersect_ray(query)
		
		if not result.is_empty():
			var hit_y: float = result.position.y
			if hit_y <= 0.45 and hit_y >= -0.2:
				return Vector3(cand_x, hit_y + 0.05, cand_z)

	var safe_angle: float = randf() * TAU
	var safe_dist: float = randf_range(10.0, 15.0)
	return Vector3(clampf(center.x + cos(safe_angle) * safe_dist, -12.0, 12.0), 0.1, clampf(center.z + sin(safe_angle) * safe_dist, -12.0, 12.0))


func _complete_wave() -> void:
	is_wave_active = false

	var is_infinite: bool = total_waves <= 0
	if not is_infinite and current_wave >= total_waves:
		# Si es nivel de jefe y el jefe sigue vivo, generar oleadas de refuerzo continuas
		if is_boss_level and _active_boss != null and is_instance_valid(_active_boss) and _active_boss.current_health > 0:
			get_tree().create_timer(4.0).timeout.connect(func():
				if _active_boss != null and is_instance_valid(_active_boss) and _active_boss.current_health > 0:
					_start_wave(current_wave)
			)
			return

		_all_done = true
		all_waves_completed.emit()
		if has_node("/root/GameManager"):
			GameManager.notify_level_won()
	else:
		var timer: SceneTreeTimer = get_tree().create_timer(4.0)
		timer.timeout.connect(func():
			_start_wave(current_wave + 1)
		)
