extends Node2D

## Test de la aparición de enemigos en los bordes del escenario.
## Con el jugador arrinconado en cada esquina, TODOS los puntos de aparición
## deben caer dentro del rectángulo jugable (nunca fuera de los muros), que es
## lo que hacía que algunos zombis se quedaran atascados en las orillas.

const WALKER_SCENE: PackedScene = preload("res://scenes/entities/enemies/zombie_walker.tscn")
const PLAYER_SCENE: PackedScene = preload("res://scenes/entities/player.tscn")

const SAMPLES_PER_CORNER: int = 120


func _ready() -> void:
	_run()


func _run() -> void:
	print("=== TEST DE APARICIÓN EN LAS ORILLAS ===")

	var spawner: ZombieSpawner = ZombieSpawner.new()
	spawner.zombie_scenes = [WALKER_SCENE]
	spawner.auto_start = false
	spawner.enemy_container = self
	add_child(spawner)
	await _wait_frames(2)

	var player: Player = PLAYER_SCENE.instantiate()
	add_child(player)
	if player.input_handler != null:
		player.input_handler.is_active = false
	await _wait_frames(2)

	var inner: Rect2 = spawner.spawn_bounds.grow(-spawner.bounds_margin)
	print("rectángulo jugable = ", inner)

	var corners: Array[Vector2] = [
		Vector2(40.0, 40.0),
		Vector2(1880.0, 40.0),
		Vector2(40.0, 1240.0),
		Vector2(1880.0, 1240.0),
		Vector2(960.0, 640.0),
	]

	var total: int = 0
	var outside: int = 0
	var too_close: int = 0

	for corner: Vector2 in corners:
		player.global_position = corner
		for _i: int in range(SAMPLES_PER_CORNER):
			var point: Vector2 = spawner.find_spawn_position()
			total += 1
			if not inner.has_point(point):
				outside += 1
				if outside <= 6:
					print("  FUERA del rectángulo: ", point, "  (jugador en ", corner, ")")
			elif point.distance_to(corner) < 200.0:
				too_close += 1
				if too_close <= 6:
					print("  DEMASIADO CERCA (", point.distance_to(corner), " px): ", point)

	print("puntos generados            = ", total)
	print("fuera del rectángulo        = ", outside, "   (esperado 0)")
	print("a menos de 200 px del jugador = ", too_close, "   (pocos: sólo si está arrinconado)")
	print("=== FIN DEL TEST DE ORILLAS ===")

	await _wait_frames(5)
	get_tree().quit()


func _wait_frames(count: int) -> void:
	for _i: int in range(count):
		await get_tree().physics_frame
