extends Node2D

## Test determinista del bucle de combate de la Fase 1.
## Comprueba, con el arma y el spawner reales, que disparar mata a un zombi y
## que la baja se contabiliza en GameManager (BAJAS / PUNTOS del HUD).
## Ejecutar con F6 sobre esta escena y leer la consola.

const WALKER_SCENE: PackedScene = preload("res://scenes/entities/enemies/zombie_walker.tscn")
const PLAYER_SCENE: PackedScene = preload("res://scenes/entities/player.tscn")


func _ready() -> void:
	_run()


func _run() -> void:
	print("=== TEST BUCLE DE COMBATE ===")

	# Jugador con la entrada de hardware congelada: en su lugar inyectamos
	# un InputPayload fijo apuntando a la derecha con el gatillo pulsado.
	var player: Player = PLAYER_SCENE.instantiate()
	add_child(player)
	player.global_position = Vector2(400.0, 400.0)
	await _wait_frames(4)

	if player.input_handler == null:
		print("[!] El jugador no tiene input_handler; el test no es válido.")
		get_tree().quit()
		return
	player.input_handler.is_active = false

	if player.weapon_component == null:
		print("[!] El jugador no tiene WeaponComponent.")
		get_tree().quit()
		return

	# Spawner real, sin arranque automático, para probar la conexión de la baja.
	var spawner: ZombieSpawner = ZombieSpawner.new()
	spawner.zombie_scenes = [WALKER_SCENE]
	spawner.auto_start = false
	spawner.enemy_container = self
	add_child(spawner)
	await _wait_frames(2)

	var kills_before: int = GameManager.kills
	var score_before: int = GameManager.score
	var ammo_before: int = player.weapon_component.magazine + player.weapon_component.reserve_ammo

	var zombie: Zombie = spawner.spawn_one()
	await _wait_frames(2)
	if zombie == null:
		print("[!] El spawner no generó ningún zombi.")
		get_tree().quit()
		return
	# Colocarlo justo delante del jugador, a la derecha.
	zombie.global_position = player.global_position + Vector2(230.0, 0.0)
	await _wait_frames(2)

	print("[info] zombi a ", zombie.global_position, " | jugador en ", player.global_position)
	print("[info] vida del zombi al empezar = ", zombie.health_component.current_health)
	print("[info] munición al empezar = ", ammo_before,
		" | BAJAS=", kills_before, " PUNTOS=", score_before)

	var payload_press: InputPayload = InputPayload.new(
		Vector2.ZERO, Vector2.RIGHT, Vector2.ZERO, true, false, false
	)
	var payload_release: InputPayload = InputPayload.new(
		Vector2.ZERO, Vector2.RIGHT, Vector2.ZERO, false, false, false
	)

	var frames_fired: int = 0
	for _i: int in range(240):
		if not zombie.is_alive():
			break
		if _i % 10 == 0:
			player.input_handler.input_dispatched.emit(payload_press)
		else:
			player.input_handler.input_dispatched.emit(payload_release)
		frames_fired += 1
		await get_tree().physics_frame

	var ammo_after: int = player.weapon_component.magazine + player.weapon_component.reserve_ammo
	print("[info] frames disparando = ", frames_fired)
	print("[info] munición gastada = ", ammo_before - ammo_after)
	print("---------------------------------------------")
	print("¿El zombi ha muerto?          ", not zombie.is_alive(),
		"  (vida final = ", zombie.health_component.current_health, ")")
	print("¿Se contabilizó la baja?      ", GameManager.kills > kills_before,
		"  (BAJAS ", kills_before, " -> ", GameManager.kills, ")")
	print("¿Se sumó puntuación?          ", GameManager.score > score_before,
		"  (PUNTOS ", score_before, " -> ", GameManager.score, ")")
	print("---------------------------------------------")

	print("=== FIN DEL TEST ===")
	await _wait_frames(20)
	get_tree().quit()


func _wait_frames(count: int) -> void:
	for _i: int in range(count):
		await get_tree().physics_frame
