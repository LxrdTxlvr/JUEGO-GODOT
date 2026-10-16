extends Node2D

## Test de navegación: un zombi con un muro de por medio debe RODEARLO hasta
## alcanzar al jugador, en lugar de quedarse empujando contra él.
## Si no hubiera evasión de obstáculos, se quedaría clavado junto al muro.

const WALKER_SCENE: PackedScene = preload("res://scenes/entities/enemies/zombie_walker.tscn")
const PLAYER_SCENE: PackedScene = preload("res://scenes/entities/player.tscn")

const PLAYER_POS: Vector2 = Vector2(400.0, 400.0)
const ZOMBIE_POS: Vector2 = Vector2(760.0, 400.0)
const WALL_CENTER: Vector2 = Vector2(580.0, 400.0)
const WALL_SIZE: Vector2 = Vector2(32.0, 220.0)
const SIMULATION_FRAMES: int = 840


func _ready() -> void:
	_run()


func _run() -> void:
	print("=== TEST DE NAVEGACIÓN ALREDEDOR DE UN MURO ===")

	# El muro va en la capa 1 ("world"), igual que los del escenario.
	var wall: StaticBody2D = StaticBody2D.new()
	wall.collision_layer = 1
	wall.collision_mask = 0
	wall.position = WALL_CENTER
	var wall_shape: CollisionShape2D = CollisionShape2D.new()
	var rectangle: RectangleShape2D = RectangleShape2D.new()
	rectangle.size = WALL_SIZE
	wall_shape.shape = rectangle
	wall.add_child(wall_shape)
	add_child(wall)

	var player: Player = PLAYER_SCENE.instantiate()
	add_child(player)
	player.global_position = PLAYER_POS
	if player.input_handler != null:
		player.input_handler.is_active = false
	await _wait_frames(4)

	var zombie: Zombie = WALKER_SCENE.instantiate()
	add_child(zombie)
	zombie.global_position = ZOMBIE_POS
	await _wait_frames(4)

	var start_distance: float = zombie.global_position.distance_to(player.global_position)
	var closest: float = start_distance
	var x_at_wall: float = 0.0

	print("muro en ", WALL_CENTER, " tamaño ", WALL_SIZE)
	print("jugador en ", PLAYER_POS, " | zombi en ", ZOMBIE_POS,
		" | distancia inicial = ", start_distance)

	for frame: int in range(SIMULATION_FRAMES):
		var distance: float = zombie.global_position.distance_to(player.global_position)
		closest = minf(closest, distance)
		# Guardar a qué altura pasa el zombi cuando cruza la línea del muro.
		if x_at_wall == 0.0 and absf(zombie.global_position.x - WALL_CENTER.x) < 30.0:
			x_at_wall = zombie.global_position.y
		if distance <= zombie.attack_range:
			print("¡Alcanzó al jugador en el frame ", frame, "!")
			break
		await get_tree().physics_frame

	var final_distance: float = zombie.global_position.distance_to(player.global_position)
	print("distancia mínima alcanzada = ", closest)
	print("distancia final            = ", final_distance)
	if x_at_wall != 0.0:
		var detour: float = absf(x_at_wall - ZOMBIE_POS.y)
		print("cruzó la línea del muro a la altura y=", x_at_wall,
			"  (desvío de ", detour, " px respecto a la línea recta)")
	else:
		print("nunca llegó a la línea del muro")

	print("¿logró rodear el muro y acercarse? ", final_distance < 120.0 or closest <= zombie.attack_range)
	print("=== FIN DEL TEST DE NAVEGACIÓN ===")

	await _wait_frames(5)
	get_tree().quit()


func _wait_frames(count: int) -> void:
	for _i: int in range(count):
		await get_tree().physics_frame
