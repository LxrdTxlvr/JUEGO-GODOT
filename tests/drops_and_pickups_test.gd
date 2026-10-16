extends Node2D

## Test determinista de recogida de objetos y economía de botín.
## Comprueba: radio de recogida, recogida real a distancia, aviso cuando el
## objeto no se puede usar, y que con la munición a cero caiga munición siempre.
## Ejecutar con F6 sobre esta escena y leer la consola.

const WALKER_SCENE: PackedScene = preload("res://scenes/entities/enemies/zombie_walker.tscn")
const PLAYER_SCENE: PackedScene = preload("res://scenes/entities/player.tscn")
const MEDKIT_SCENE: PackedScene = preload("res://scenes/entities/pickups/pickup_medkit.tscn")
const AMMO_SCENE: PackedScene = preload("res://scenes/entities/pickups/pickup_ammo.tscn")

var _rejected_reasons: Array[String] = []


func _ready() -> void:
	_run()


func _run() -> void:
	print("=== TEST DE OBJETOS Y BOTÍN ===")
	await _test_collect()
	await _test_rejection()
	await _test_emergency_ammo()
	print("\n=== FIN DEL TEST DE OBJETOS ===")
	await _wait_frames(5)
	get_tree().quit()


# ------------------------------------------------------------------------------
# A. Radio de recogida y recogida real a distancia
# ------------------------------------------------------------------------------
func _test_collect() -> void:
	print("\n--- [A] RADIO DE RECOGIDA Y RECOGIDA A DISTANCIA ---")
	var player: Player = _make_player(Vector2(600.0, 600.0))
	await _wait_frames(4)

	# Una instancia lejana sólo sirve para leer el radio finalmente aplicado.
	var probe: Pickup = AMMO_SCENE.instantiate()
	add_child(probe)
	probe.global_position = Vector2(9000.0, 9000.0)
	await _wait_frames(2)
	var resolved_radius: float = 0.0
	var shape_node: CollisionShape2D = probe.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node != null and shape_node.shape is CircleShape2D:
		resolved_radius = (shape_node.shape as CircleShape2D).radius
	print("[A] radio de recogida aplicado = ", resolved_radius, "  (esperado 32)")
	probe.queue_free()
	await _wait_frames(2)

	# Recogida real: el objeto está a 34 px del centro del jugador, no encima.
	var reserve_before: int = player.weapon_component.reserve_ammo
	var ammo: Pickup = AMMO_SCENE.instantiate()
	add_child(ammo)
	ammo.global_position = player.global_position + Vector2(34.0, 0.0)
	await _wait_frames(8)
	print("[A] reserva de munición ", reserve_before, " -> ",
		player.weapon_component.reserve_ammo, "  (esperado +36)")
	print("[A] ¿se recogió a 34 px del centro? ", not is_instance_valid(ammo))

	_clear_player(player)


# ------------------------------------------------------------------------------
# B. Aviso cuando el objeto no se puede usar
# ------------------------------------------------------------------------------
func _test_rejection() -> void:
	print("\n--- [B] OBJETO QUE NO SE PUEDE USAR ---")
	var player: Player = _make_player(Vector2(1200.0, 600.0))
	await _wait_frames(4)

	_rejected_reasons.clear()
	player.pickup_rejected.connect(_on_pickup_rejected)

	# Con la vida al máximo el botiquín no debe consumirse, pero sí avisar.
	var medkit: Pickup = MEDKIT_SCENE.instantiate()
	add_child(medkit)
	medkit.global_position = player.global_position
	await _wait_frames(8)
	print("[B] vida del jugador = ", player.health_component.current_health,
		" / ", player.health_component.max_health)
	print("[B] ¿el botiquín sigue en el suelo? ", is_instance_valid(medkit),
		"  (esperado true: no se malgasta)")
	print("[B] avisos recibidos = ", _rejected_reasons)

	if is_instance_valid(medkit):
		medkit.queue_free()
	_clear_player(player)


# ------------------------------------------------------------------------------
# C. Munición de emergencia cuando el jugador se queda a cero
# ------------------------------------------------------------------------------
func _test_emergency_ammo() -> void:
	print("\n--- [C] MUNICIÓN DE EMERGENCIA CON EL CARGADOR A CERO ---")
	var player: Player = _make_player(Vector2(1800.0, 1000.0))
	await _wait_frames(4)

	player.weapon_component.magazine = 0
	player.weapon_component.reserve_ammo = 0
	await _wait_frames(2)
	print("[C] munición del jugador = ", player.weapon_component.magazine,
		" + ", player.weapon_component.reserve_ammo)

	var spawner: ZombieSpawner = ZombieSpawner.new()
	spawner.zombie_scenes = [WALKER_SCENE]
	spawner.auto_start = false
	spawner.enemy_container = self
	add_child(spawner)
	await _wait_frames(2)

	var kills: int = 6
	for _i: int in range(kills):
		var zombie: Zombie = spawner.spawn_one()
		if zombie == null:
			continue
		zombie.global_position = player.global_position + Vector2(320.0, 0.0)
		await _wait_frames(2)
		zombie.take_damage(9999.0, null)
		await _wait_frames(4)

	var ammo_drops: int = 0
	var medkit_drops: int = 0
	for child: Node in get_children():
		var pickup: Pickup = child as Pickup
		if pickup == null:
			continue
		if pickup.pickup_type == Pickup.PickupType.AMMO:
			ammo_drops += 1
		else:
			medkit_drops += 1

	print("[C] bajas = ", kills)
	print("[C] botines de munición = ", ammo_drops, "  (esperado ", kills, ": garantizado)")
	print("[C] botines de botiquín = ", medkit_drops, "  (esperado 0)")

	spawner.queue_free()
	_clear_player(player)


# ------------------------------------------------------------------------------
# Utilidades
# ------------------------------------------------------------------------------
func _make_player(at: Vector2) -> Player:
	var player: Player = PLAYER_SCENE.instantiate()
	add_child(player)
	player.global_position = at
	if player.input_handler != null:
		player.input_handler.is_active = false
	return player


func _clear_player(player: Player) -> void:
	if is_instance_valid(player):
		player.queue_free()
	for node: Node in get_children():
		if node is Zombie:
			node.queue_free()
	await _wait_frames(3)


func _on_pickup_rejected(reason: String) -> void:
	_rejected_reasons.append(reason)


func _wait_frames(count: int) -> void:
	for _i: int in range(count):
		await get_tree().physics_frame
