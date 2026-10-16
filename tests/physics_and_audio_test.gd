extends Node2D

## Test de validación para las físicas de zombis en muros, colisión de balas con paredes y SoundManager.

const BULLET_SCENE: PackedScene = preload("res://scenes/entities/projectiles/bullet.tscn")
const WALKER_SCENE: PackedScene = preload("res://scenes/entities/enemies/zombie_walker.tscn")
const PLAYER_SCENE: PackedScene = preload("res://scenes/entities/player.tscn")


func _ready() -> void:
	print("=== INICIO TEST DE FÍSICAS Y SISTEMA DE AUDIO ===")
	_test_sound_manager()
	await _test_bullet_wall_collision()
	await _test_zombie_wall_sliding()


func _test_sound_manager() -> void:
	print("\n--- [1] TEST SOUND MANAGER ---")
	assert(has_node("/root/SoundManager"), "SoundManager autoload debe estar presente")
	var sm = get_node("/root/SoundManager")
	assert(sm.SOUNDS.size() >= 25, "Deben existir al menos 25 efectos de sonido cargados")
	assert(sm.SOUNDS.has("shoot_pistol"), "Debe tener sonido de disparo pistola")
	assert(sm.SOUNDS.has("shoot_smg"), "Debe tener sonido de subfusil/ametralladora")
	assert(sm.SOUNDS.has("footstep_walk_1"), "Debe tener sonido de paso normal")
	assert(sm.SOUNDS.has("footstep_run_1"), "Debe tener sonido de paso al correr")
	assert(sm.SOUNDS.has("zombie_walker"), "Debe tener sonido de zombi caminante")
	assert(sm.SOUNDS.has("zombie_runner"), "Debe tener sonido de zombi corredor")
	assert(sm.SOUNDS.has("zombie_brute"), "Debe tener sonido de zombi bruto")
	assert(sm.SOUNDS.has("zombie_miniboss"), "Debe tener sonido de miniboss mutante")
	assert(sm.SOUNDS.has("boss_roar"), "Debe tener sonido de rugido del jefe")
	assert(sm.MUSIC_TRACKS.size() == 5, "Deben existir 5 pistas musicales registradas")
	assert(sm.MUSIC_TRACKS.has("menu"), "Debe existir música de menú")
	assert(sm.MUSIC_TRACKS.has("level_1"), "Debe existir música de nivel 1")
	assert(sm.MUSIC_TRACKS.has("level_2"), "Debe existir música de nivel 2")
	assert(sm.MUSIC_TRACKS.has("level_final"), "Debe existir música de nivel final")
	assert(sm.MUSIC_TRACKS.has("endless"), "Debe existir música de modo infinito")
	print("✓ SoundManager verificado correctamente con todos los sonidos y bandas sonoras listos.")


func _test_bullet_wall_collision() -> void:
	print("\n--- [2] TEST COLISIÓN DE BALA CON MURO ---")
	# Crear muro estático en capa 1
	var wall: StaticBody2D = StaticBody2D.new()
	wall.collision_layer = 1
	wall.collision_mask = 0
	wall.position = Vector2(200.0, 100.0)
	var col_shape: CollisionShape2D = CollisionShape2D.new()
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = Vector2(32.0, 120.0)
	col_shape.shape = rect
	wall.add_child(col_shape)
	add_child(wall)

	# Instanciar bala apuntando hacia el muro desde Vector2(100, 100)
	var bullet: Projectile = BULLET_SCENE.instantiate() as Projectile
	add_child(bullet)
	bullet.global_position = Vector2(100.0, 100.0)
	bullet.setup(Vector2.RIGHT, 20.0, 950.0)

	var hit_detected: Array[bool] = [false]
	bullet.impact.connect(func(body: Node) -> void:
		hit_detected[0] = true
		print("✓ Impacto de bala registrado contra: ", body.name if body != null else "muro")
	)

	# Avanzar frames de física
	for _i in range(12):
		await get_tree().physics_frame

	assert(hit_detected[0], "La bala debe impactar contra el muro y no atravesarlo")
	wall.queue_free()
	print("✓ Bala colisiona y se destruye contra el muro exitosamente.")


func _test_zombie_wall_sliding() -> void:
	print("\n--- [3] TEST ZOMBI SIN TRABARSE EN MURO ---")
	# Muro intermedio
	var wall: StaticBody2D = StaticBody2D.new()
	wall.collision_layer = 1
	wall.position = Vector2(400.0, 300.0)
	var col_shape: CollisionShape2D = CollisionShape2D.new()
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = Vector2(32.0, 180.0)
	col_shape.shape = rect
	wall.add_child(col_shape)
	add_child(wall)

	# Jugador pegado al otro lado del muro
	var player: Player = PLAYER_SCENE.instantiate() as Player
	add_child(player)
	player.global_position = Vector2(370.0, 300.0) # A solo 30px del centro del muro (detrás de él)
	if player.input_handler != null:
		player.input_handler.is_active = false

	# Zombi al frente del muro
	var zombie: Zombie = WALKER_SCENE.instantiate() as Zombie
	add_child(zombie)
	zombie.global_position = Vector2(440.0, 300.0) # A 40px del muro, distancia total al jugador ~70px

	for _i in range(30):
		await get_tree().physics_frame

	# Comprobar que no se congele en ataque sin visión
	assert(zombie._state != Zombie.State.ATTACK, "El zombi no debe entrar en estado de ataque sin línea de visión")
	assert(zombie._state == Zombie.State.CHASE, "El zombi debe mantenerse en persecución para rodear el muro")
	print("✓ Estado del zombi tras muro: ", zombie._state, " (Persiguiendo y buscando ruta)")

	wall.queue_free()
	player.queue_free()
	zombie.queue_free()
	print("=== TODOS LOS TESTS COMPLETADOS SATISFACTORIAMENTE ===")
	get_tree().quit(0)
