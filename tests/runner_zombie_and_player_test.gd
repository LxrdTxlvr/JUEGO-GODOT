extends Node2D

const RUNNER_SCENE: PackedScene = preload("res://scenes/entities/enemies/zombie_runner.tscn")
const PLAYER_SCENE: PackedScene = preload("res://scenes/entities/player.tscn")


func _ready() -> void:
	print("=== INICIO DE TEST DE ZOMBIE CORREDOR Y JUGADOR ===")
	_test_player()
	await _test_runner_zombie()
	print("=== FIN DE TEST DE ZOMBIE CORREDOR Y JUGADOR ===")
	get_tree().quit()


func _test_player() -> void:
	print("\n--- [1] VERIFICACIÓN DEL JUGADOR ---")
	var player: Player = PLAYER_SCENE.instantiate()
	add_child(player)
	player.global_position = Vector2(300.0, 300.0)
	if player.input_handler != null:
		player.input_handler.is_active = false

	var frames: SpriteFrames = player.animated_sprite.sprite_frames
	assert(frames != null, "SpriteFrames no debe ser nulo")
	assert(frames.has_animation(&"idle"), "Debe existir animación idle")
	assert(frames.has_animation(&"walking"), "Debe existir animación walking")
	assert(frames.has_animation(&"running"), "Debe existir animación running")
	print("✓ Animaciones encontradas: idle, walking, running")

	# Test dodge / sprint: verify no 360 spin
	player._start_dodge(Vector2.RIGHT)
	assert(player._is_dodging, "El jugador debe estar en estado de esquiva")
	player._physics_process(0.016)
	assert(is_zero_approx(player.animated_sprite.rotation), "El sprite del jugador no debe rotar 360° al correr/evadir")
	print("✓ Rotación del jugador en esquiva/carrera = ", player.animated_sprite.rotation, " (erguido, sin giro)")

	assert(player.animated_sprite.animation == &"running", "El jugador debe reproducir la animación running al correr")
	print("✓ Animación reproducida en carrera = ", player.animated_sprite.animation)

	player.queue_free()


func _test_runner_zombie() -> void:
	print("\n--- [2] VERIFICACIÓN DEL ZOMBIE CORREDOR ---")
	var player: Player = PLAYER_SCENE.instantiate()
	add_child(player)
	player.global_position = Vector2(100.0, 100.0)
	if player.input_handler != null:
		player.input_handler.is_active = false

	var runner: Zombie = RUNNER_SCENE.instantiate()
	add_child(runner)
	# Colocar al corredor a 400 píxeles del jugador (mucho más allá de los 150 px del bug anterior)
	runner.global_position = Vector2(500.0, 100.0)

	print("✓ Radio de detección del corredor = ", runner.detection_radius, " (esperado 1200.0)")
	assert(runner.detection_radius >= 1000.0, "El radio de detección debe ser al menos 1000 px")
	print("✓ Animación de movimiento asignada = ", runner.walk_animation, " (esperado running)")
	assert(runner.walk_animation == &"running", "walk_animation debe ser running")

	# Simular frames de spawn y movimiento
	for frame in range(35):
		await get_tree().physics_frame

	var dist_before: float = runner.global_position.distance_to(player.global_position)
	print("Distancia inicial tras spawn: ", dist_before)

	for frame in range(30):
		await get_tree().physics_frame

	var dist_after: float = runner.global_position.distance_to(player.global_position)
	print("Distancia tras 30 frames de persecución: ", dist_after)

	assert(dist_after < dist_before, "El zombi corredor debe perseguir activamente al jugador a más de 150 px")
	print("✓ El zombi corredor se desplazó activamente hacia el jugador a velocidad alta")
	print("✓ Animación actual del zombi corredor = ", runner.animated_sprite.animation)
	assert(runner.animated_sprite.animation == &"running", "El zombi debe estar reproduciendo la animación running")

	runner.queue_free()
	player.queue_free()
