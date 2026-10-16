extends Node2D

## Test determinista de los sistemas de la Fase 1:
##  - recogida de pickups (botiquín / munición)
##  - progresión de oleadas y señal de escenario superado
##  - muerte del jugador y paso a estado de fin de partida
## Ejecutar con F6 sobre esta escena y leer la consola.

const WALKER_SCENE: PackedScene = preload("res://scenes/entities/enemies/zombie_walker.tscn")
const PLAYER_SCENE: PackedScene = preload("res://scenes/entities/player.tscn")
const MEDKIT_SCENE: PackedScene = preload("res://scenes/entities/pickups/pickup_medkit.tscn")
const AMMO_SCENE: PackedScene = preload("res://scenes/entities/pickups/pickup_ammo.tscn")

var _wave_starts: Array[int] = []
var _waves_cleared: Array[int] = []
var _all_cleared: bool = false
var _death_reported: bool = false


func _ready() -> void:
	_run()


func _run() -> void:
	print("=== TEST DE SISTEMAS ===")
	await _test_waves()
	await _test_pickups()
	await _test_player_death()
	print("=== FIN DEL TEST DE SISTEMAS ===")
	await _wait_frames(5)
	get_tree().quit()


# ------------------------------------------------------------------------------
# 1. Oleadas
# ------------------------------------------------------------------------------
func _test_waves() -> void:
	print("\n--- [A] PROGRESIÓN DE OLEADAS ---")

	# El spawner necesita un jugador en escena para colocar los enemigos.
	var player: Player = PLAYER_SCENE.instantiate()
	add_child(player)
	player.global_position = Vector2(600.0, 600.0)
	if player.input_handler != null:
		player.input_handler.is_active = false
	await _wait_frames(3)

	var spawner: ZombieSpawner = ZombieSpawner.new()
	spawner.total_waves = 2
	spawner.base_enemies_per_wave = 2
	spawner.enemies_growth_per_wave = 0.0
	spawner.spawn_interval = 0.05
	spawner.time_between_waves = 0.3
	spawner.start_delay = 0.05
	spawner.max_alive = 8
	spawner.spawn_min_distance = 90.0
	spawner.spawn_max_distance = 140.0
	spawner.zombie_scenes = [WALKER_SCENE]
	spawner.enemy_container = self
	spawner.auto_start = false

	spawner.wave_started.connect(func(wave_number: int, _total: int) -> void:
		_wave_starts.append(wave_number)
	)
	spawner.wave_cleared.connect(func(wave_number: int) -> void:
		_waves_cleared.append(wave_number)
	)
	spawner.all_waves_cleared.connect(func() -> void:
		_all_cleared = true
	)

	add_child(spawner)
	await _wait_frames(2)
	spawner.start()

	# Matar al instante todo lo que aparezca, durante un máximo de 15 s simulados.
	for _i: int in range(900):
		for node: Node in get_tree().get_nodes_in_group("enemies"):
			var zombie: Zombie = node as Zombie
			if zombie != null and zombie.is_alive():
				zombie.take_damage(1000.0, null)
		if _all_cleared:
			break
		await get_tree().physics_frame

	print("[A] oleadas iniciadas      = ", _wave_starts, "  (esperado [1, 2])")
	print("[A] oleadas superadas      = ", _waves_cleared, "  (esperado [1, 2])")
	print("[A] ¿escenario completado? = ", _all_cleared)
	print("[A] GameManager.wave       = ", GameManager.wave, "  (esperado 2)")
	print("[A] BAJAS totales          = ", GameManager.kills)

	# Limpieza
	spawner.queue_free()
	player.queue_free()
	await _wait_frames(3)


# ------------------------------------------------------------------------------
# 2. Pickups
# ------------------------------------------------------------------------------
func _test_pickups() -> void:
	print("\n--- [B] RECOGIDA DE OBJETOS ---")

	var player: Player = PLAYER_SCENE.instantiate()
	add_child(player)
	player.global_position = Vector2(600.0, 900.0)
	if player.input_handler != null:
		player.input_handler.is_active = false
	await _wait_frames(3)

	# --- Botiquín: primero hay que estar herido para poder curarse ---
	player.take_damage(50.0, null)
	await _wait_frames(3)
	var hurt_hp: float = player.health_component.current_health

	var medkit: Pickup = MEDKIT_SCENE.instantiate()
	var medkit_amount: float = medkit.heal_amount
	medkit.global_position = player.global_position
	add_child(medkit)
	await _wait_frames(6)
	print("[B] botiquín: vida ", hurt_hp, " -> ", player.health_component.current_health,
		"  (debe subir ~", medkit_amount, ")")
	print("[B] ¿botiquín recogido?  ", not is_instance_valid(medkit))

	# --- Munición ---
	var ammo_before: int = player.weapon_component.reserve_ammo
	var ammo_pickup: Pickup = AMMO_SCENE.instantiate()
	var ammo_amount: int = ammo_pickup.ammo_amount
	ammo_pickup.global_position = player.global_position
	add_child(ammo_pickup)
	await _wait_frames(6)
	print("[B] munición: reserva ", ammo_before, " -> ", player.weapon_component.reserve_ammo,
		"  (debe subir ~", ammo_amount, ")")
	print("[B] ¿munición recogida?  ", not is_instance_valid(ammo_pickup))

	player.queue_free()
	await _wait_frames(3)


# ------------------------------------------------------------------------------
# 3. Muerte del jugador
# ------------------------------------------------------------------------------
func _test_player_death() -> void:
	print("\n--- [C] MUERTE DEL JUGADOR ---")

	var player: Player = PLAYER_SCENE.instantiate()
	add_child(player)
	player.global_position = Vector2(600.0, 1200.0)
	if player.input_handler != null:
		player.input_handler.is_active = false
	await _wait_frames(3)

	var death_reported: bool = false
	# Reproduce el cableado que hace Level.
	player.player_died.connect(func() -> void:
		death_reported = true
		GameManager.finish_run(false)
	)

	GameManager.add_score(123)
	player.take_damage(9999.0, null)
	await _wait_frames(4)

	print("[C] ¿se emitió player_died?      ", death_reported)
	print("[C] vida del jugador             = ", player.health_component.current_health)
	print("[C] GameManager.state            = ", GameManager.state,
		"  (GAME_OVER = ", GameManager.GameState.GAME_OVER, ")")
	print("[C] ¿estado final de partida?    ", GameManager.state == GameManager.GameState.GAME_OVER)
	print("[C] last_stats                   = ", GameManager.last_stats)

	Engine.time_scale = 1.0


func _wait_frames(count: int) -> void:
	for _i: int in range(count):
		await get_tree().physics_frame
