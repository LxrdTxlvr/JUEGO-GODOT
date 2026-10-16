extends Node2D

## Test de diagnóstico del pipeline de daño de la Fase 1.
## Ejecuta la escena con F6 (o desde el editor) y lee la consola: imprime el
## resultado de cada comprobación por separado para localizar qué eslabón falla.

const WALKER_SCENE: PackedScene = preload("res://scenes/entities/enemies/zombie_walker.tscn")
const PLAYER_SCENE: PackedScene = preload("res://scenes/entities/player.tscn")
const BULLET_SCENE: PackedScene = preload("res://scenes/entities/projectiles/bullet.tscn")


func _ready() -> void:
	_run()


func _run() -> void:
	print("=== TEST PIPELINE DE DAÑO ===")

	# --- Test 1: daño directo sobre el HealthComponent del zombi ---
	var z1: Zombie = WALKER_SCENE.instantiate()
	add_child(z1)
	z1.global_position = Vector2(200.0, 200.0)
	await _wait_frames(3)
	print("[1] zombi: collision_layer=", z1.collision_layer,
		" collision_mask=", z1.collision_mask,
		" health_component=", z1.health_component != null)
	print("[1] vida inicial = ", z1.health_component.current_health)
	z1.take_damage(22.0, null)
	print("[1] tras take_damage(22) = ", z1.health_component.current_health, "  (esperado 38)")
	print("[1] estado muerte = ", not z1.is_alive())

	# --- Test 2: bala real impactando en el zombi (sin jugador en escena,
	#     para que el zombi se quede quieto en IDLE) ---
	var z2: Zombie = WALKER_SCENE.instantiate()
	add_child(z2)
	z2.global_position = Vector2(700.0, 400.0)
	await _wait_frames(4)

	var bullet: Projectile = BULLET_SCENE.instantiate()
	add_child(bullet)
	bullet.global_position = Vector2(560.0, 400.0)
	bullet.setup(Vector2.RIGHT, 22.0, 320.0)
	print("[2] bala: layer=", bullet.collision_layer, " mask=", bullet.collision_mask,
		" monitoring=", bullet.monitoring)
	print("[2] zombi2: layer=", z2.collision_layer, " mask=", z2.collision_mask,
		" vida=", z2.health_component.current_health)
	await _wait_frames(60)
	print("[2] vida del zombi2 tras la bala = ", z2.health_component.current_health,
		"  (esperado 38 si impacta)")

	# --- Test 3: el zombi golpea al jugador ---
	var p: Player = PLAYER_SCENE.instantiate()
	add_child(p)
	p.global_position = Vector2(300.0, 700.0)
	await _wait_frames(4)
	var player_hp_start: float = p.health_component.current_health
	var z3: Zombie = WALKER_SCENE.instantiate()
	add_child(z3)
	z3.global_position = Vector2(330.0, 700.0)
	await _wait_frames(240)
	print("[3] vida del jugador: ", player_hp_start, " -> ", p.health_component.current_health,
		"  (debe bajar si el zombi acierta el golpe)")

	# --- Test 4: muerte del zombi y emisión de la señal ---
	var z4: Zombie = WALKER_SCENE.instantiate()
	add_child(z4)
	z4.global_position = Vector2(900.0, 700.0)
	z4.died.connect(func(_z: Zombie, score: int) -> void:
		print("[4] señal died emitida, score=", score)
	)
	await _wait_frames(4)
	z4.take_damage(1000.0, null)
	await _wait_frames(4)
	print("[4] vida del zombi4 = ", z4.health_component.current_health,
		"  dead=", z4.health_component.is_dead())

	print("=== FIN DEL TEST ===")
	await _wait_frames(30)
	get_tree().quit()


func _wait_frames(count: int) -> void:
	for _i: int in range(count):
		await get_tree().physics_frame
