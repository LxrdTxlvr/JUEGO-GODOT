class_name ZombieSpawner
extends Node2D

## Director de oleadas. Genera enemigos progresivamente alrededor del jugador,
## fuera de su campo de visión, y avisa a la interfaz mediante señales.
## El spawner no conoce ni al jugador ni al HUD: sólo emite eventos.

## Emitida al comenzar una oleada.
signal wave_started(wave_number: int, total_waves: int)
## Emitida al eliminar a todos los enemigos de una oleada.
signal wave_cleared(wave_number: int)
## Emitida al superar la última oleada del escenario.
signal all_waves_cleared()
## Emitida al aparecer un miniboss especial.
signal miniboss_spawned(miniboss: Zombie)

const MINIBOSS_SCENE: PackedScene = preload("res://scenes/entities/enemies/zombie_miniboss.tscn")

@export_group("Waves")
## Número total de oleadas del escenario.
@export var total_waves: int = 5
## Enemigos de la primera oleada.
@export var base_enemies_per_wave: int = 5
## Enemigos extra acumulados por cada oleada adicional.
@export var enemies_growth_per_wave: float = 2.5
## Segundos entre enemigos dentro de una misma oleada.
@export var spawn_interval: float = 0.7
## Segundos de respiro entre oleadas.
@export var time_between_waves: float = 7.0
## Retardo inicial antes de la primera oleada.
@export var start_delay: float = 2.5
## Máximo de enemigos vivos simultáneamente.
@export var max_alive: int = 45
## Si es falso, hace falta llamar a start() manualmente.
@export var auto_start: bool = true

@export_group("Spawning")
## Escenas de zombi que pueden aparecer (repartidas por peso).
@export var zombie_scenes: Array[PackedScene] = []
## Oleada mínima en la que aparece cada escena (alineado con zombie_scenes).
@export var zombie_unlock_waves: Array[int] = []
## Peso relativo de cada escena en el sorteo (alineado con zombie_scenes).
@export var zombie_weights: Array[float] = []
## Distancia mínima de aparición respecto al jugador.
@export var spawn_min_distance: float = 480.0
## Distancia máxima de aparición respecto al jugador.
@export var spawn_max_distance: float = 760.0
## Intentos de recolocación para no aparecer dentro de un muro.
@export var spawn_placement_attempts: int = 14
## Rectángulo jugable del escenario. Los enemigos nunca aparecen fuera de él:
## eso es lo que hacía que algunos se quedaran atascados en las orillas.
@export var spawn_bounds: Rect2 = Rect2(0, 0, 1920, 1280)
## Margen interior respecto a los muros perimetrales.
@export var bounds_margin: float = 110.0
## Nodo contenedor de los enemigos (por defecto, el padre del spawner).
@export var enemy_container: Node

var _running: bool = false
var _current_wave: int = 1
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	if enemy_container == null:
		enemy_container = get_parent()
	if auto_start:
		start()


## Arranca la secuencia completa de oleadas.
func start() -> void:
	if _running:
		return
	_running = true
	_run_waves()


func _run_waves() -> void:
	await get_tree().create_timer(start_delay, false, false, true).timeout
	if not is_inside_tree():
		return

	var is_endless: bool = false
	if has_node("/root/GameManager"):
		is_endless = GameManager.is_endless_mode

	var wave_number: int = 1
	while _running:
		await _run_single_wave(wave_number, is_endless)
		if not is_inside_tree():
			return
		wave_cleared.emit(wave_number)

		if not is_endless and wave_number >= total_waves:
			break

		await get_tree().create_timer(time_between_waves, false, false, true).timeout
		if not is_inside_tree():
			return
		wave_number += 1

	_running = false
	all_waves_cleared.emit()


func _run_single_wave(wave_number: int, is_endless: bool = false) -> void:
	_current_wave = wave_number
	var displayed_total: int = 999 if is_endless else total_waves
	wave_started.emit(wave_number, displayed_total)
	if has_node("/root/SoundManager"):
		SoundManager.play_wave_alert()
	if has_node("/root/GameManager"):
		GameManager.notify_wave_started(wave_number)


	var count: int = _calculate_enemy_count(wave_number)

	for _i: int in range(count):
		if not is_inside_tree():
			return
		# Espera a que el campo se despeje si hay demasiados enemigos vivos.
		while count_alive_enemies() >= max_alive:
			await get_tree().create_timer(spawn_interval, false, false, true).timeout
			if not is_inside_tree():
				return
		spawn_one()
		await get_tree().create_timer(spawn_interval, false, false, true).timeout

	# Comprobar si corresponde Miniboss en esta oleada
	if is_miniboss_wave(wave_number, is_endless) and is_inside_tree():
		spawn_miniboss()

	# La oleada no termina hasta que cae el último enemigo (incluidos los rezagados y el miniboss).
	while count_alive_enemies() > 0:
		await get_tree().create_timer(0.4, false, false, true).timeout
		if not is_inside_tree():
			return


## Determina si la oleada actual debe incluir la aparición de un Miniboss.
## En modo estándar: en la última oleada del escenario.
## En modo infinito:
## - Hasta la oleada 10: cada 5 oleadas (5, 10).
## - Después de la oleada 10 y hasta la 19: cada 3 oleadas más (13, 16, 19).
## - A partir de la oleada 20: en cada oleada.
func is_miniboss_wave(wave_number: int, is_endless: bool) -> bool:
	if is_endless:
		if wave_number >= 20:
			return true
		elif wave_number > 10:
			return (wave_number - 10) % 3 == 0
		else:
			return wave_number > 0 and (wave_number % 5 == 0)
	else:
		return wave_number == total_waves


## Calcula cuántos enemigos trae la oleada indicada, según dificultad.
func _calculate_enemy_count(wave_number: int) -> int:
	var base: float = float(base_enemies_per_wave)
	var growth: float = enemies_growth_per_wave * float(wave_number - 1)
	var difficulty: float = 1.0
	if has_node("/root/GameSettings"):
		difficulty = GameSettings.get_difficulty_multiplier()
	return maxi(1, roundi((base + growth) * difficulty))


## Instancia un enemigo aleatorio de la lista en una posición válida.
func spawn_one() -> Zombie:
	if zombie_scenes.is_empty():
		push_warning("[ZombieSpawner] No hay escenas de zombi configuradas.")
		return null

	var scene: PackedScene = _pick_zombie_scene()
	if scene == null:
		return null

	var zombie: Zombie = scene.instantiate() as Zombie
	if zombie == null:
		push_warning("[ZombieSpawner] La escena no es un Zombie válido.")
		return null

	var parent: Node = enemy_container if enemy_container != null else get_parent()
	parent.add_child(zombie)
	zombie.died.connect(_on_zombie_died)
	zombie.global_position = find_spawn_position()
	return zombie


## Instancia un Miniboss especial al final del escenario o cada 5 oleadas en modo infinito.
func spawn_miniboss() -> Zombie:
	var boss: Zombie = MINIBOSS_SCENE.instantiate() as Zombie
	if boss == null:
		return null

	var parent: Node = enemy_container if enemy_container != null else get_parent()
	parent.add_child(boss)
	boss.died.connect(_on_zombie_died)
	boss.global_position = find_spawn_position()
	miniboss_spawned.emit(boss)
	if has_node("/root/SoundManager"):
		SoundManager.play_zombie_groan(boss.global_position, "Miniboss")

	# Mostrar aviso dramático en la interfaz HUD
	var hud: Node = get_tree().get_first_node_in_group("hud")
	if hud != null and hud.has_method("show_wave_banner"):
		hud.call("show_wave_banner", "¡ALERTA: MINIBOSS MUTANTE DETECTADO!")

	return boss


## Registra la baja en la puntuación global y la comunica a la interfaz.
func _on_zombie_died(_zombie: Zombie, score_value: int) -> void:
	if has_node("/root/GameManager"):
		GameManager.register_kill(score_value)


## Elige una escena de zombi según su oleada de desbloqueo y su peso relativo.
func _pick_zombie_scene() -> PackedScene:
	var eligible: Array[int] = []
	var weights: Array[float] = []
	var total_weight: float = 0.0

	for index: int in range(zombie_scenes.size()):
		if zombie_scenes[index] == null:
			continue
		var unlock_wave: int = 1
		if index < zombie_unlock_waves.size():
			unlock_wave = zombie_unlock_waves[index]
		if _current_wave < unlock_wave:
			continue
		var weight: float = 1.0
		if index < zombie_weights.size():
			weight = zombie_weights[index]
		if weight <= 0.0:
			continue
		eligible.append(index)
		weights.append(weight)
		total_weight += weight

	if eligible.is_empty():
		return null

	var roll: float = _rng.randf() * total_weight
	for slot: int in range(eligible.size()):
		roll -= weights[slot]
		if roll <= 0.0:
			return zombie_scenes[eligible[slot]]
	return zombie_scenes[eligible[eligible.size() - 1]]


## Busca un punto libre alrededor del jugador, evitando muros y estructuras,
## y siempre dentro del rectángulo jugable del escenario.
func find_spawn_position() -> Vector2:
	var player: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return global_position

	var inner: Rect2 = spawn_bounds.grow(-bounds_margin)
	for _attempt: int in range(spawn_placement_attempts):
		var angle: float = _rng.randf() * TAU
		var distance: float = _rng.randf_range(spawn_min_distance, spawn_max_distance)
		var candidate: Vector2 = player.global_position + Vector2.RIGHT.rotated(angle) * distance
		if not inner.has_point(candidate):
			continue
		if _is_position_free(candidate):
			return candidate

	# Reserva: un punto libre dentro del escenario, lo más lejos posible del jugador.
	return _find_fallback_position(inner, player.global_position)


## Reserva cuando el anillo alrededor del jugador no cabe en el escenario
## (por ejemplo, si está arrinconado): se sortea dentro de los límites.
func _find_fallback_position(inner: Rect2, player_position: Vector2) -> Vector2:
	var best: Vector2 = player_position.clamp(inner.position, inner.end)
	var best_distance: float = -1.0
	for _attempt: int in range(24):
		var candidate: Vector2 = Vector2(
			_rng.randf_range(inner.position.x, inner.end.x),
			_rng.randf_range(inner.position.y, inner.end.y)
		)
		if not _is_position_free(candidate):
			continue
		var distance: float = candidate.distance_to(player_position)
		if distance > best_distance:
			best = candidate
			best_distance = distance
	return best


func _is_position_free(point: Vector2) -> bool:
	var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var query: PhysicsPointQueryParameters2D = PhysicsPointQueryParameters2D.new()
	query.position = point
	query.collision_mask = 1  # Capa "world"
	query.collide_with_bodies = true
	query.collide_with_areas = false
	return space.intersect_point(query).is_empty()


## Cuenta los enemigos vivos en la escena (incluye rezagados de oleadas previas).
func count_alive_enemies() -> int:
	var alive: int = 0
	for node: Node in get_tree().get_nodes_in_group("enemies"):
		var zombie: Zombie = node as Zombie
		if zombie != null and zombie.is_alive():
			alive += 1
	return alive
