class_name Level
extends Node2D

## Raíz de un escenario de la Fase 1. Actúa como "composition root": conoce a
## los participantes de la escena y los conecta entre sí, pero cada uno sigue
## siendo independiente y reutilizable por separado.

## Emitida al superar todas las oleadas del escenario.
signal level_completed()

@export_group("Level Info")
## Nombre mostrado en el HUD y en la pantalla de resultado.
@export var level_name: String = "Bloque Residencial"
## Texto de ambientación mostrado al empezar.
@export_multiline var level_tagline: String = ""

@export_group("Scene References")
@export var player: Player
@export var spawner: ZombieSpawner
@export var hud: CanvasLayer
## Punto exacto donde aparece el jugador; si está vacío se respeta su posición.
@export var player_start: Node2D

@export_group("Camera Bounds")
## Rectángulo del mundo que la cámara no debe abandonar (coordenadas en píxeles).
@export var camera_bounds: Rect2 = Rect2(0, 0, 1920, 1280)
## Desactiva los límites si el escenario no debe restringir la cámara.
@export var restrict_camera: bool = true


func _ready() -> void:
	_resolve_references()
	_place_player()
	_configure_camera()
	_configure_game()
	_connect_player()
	_connect_spawner()
	_connect_hud()
	_show_intro()
	_start_level_music()


func _resolve_references() -> void:
	if player == null:
		player = get_node_or_null("Entities/Player") as Player
		if player == null:
			player = get_tree().get_first_node_in_group("player") as Player
	if spawner == null:
		spawner = find_child("ZombieSpawner", true, false) as ZombieSpawner
	if hud == null:
		hud = get_node_or_null("HUD") as CanvasLayer
		if hud == null:
			hud = find_child("HUD", true, false) as CanvasLayer


func _place_player() -> void:
	if player_start != null and player != null:
		player.global_position = player_start.global_position


## Encierra la cámara dentro de los límites del escenario.
func _configure_camera() -> void:
	if not restrict_camera or player == null or player.camera == null:
		return
	var camera: Camera2D = player.camera
	camera.limit_left = int(camera_bounds.position.x)
	camera.limit_top = int(camera_bounds.position.y)
	camera.limit_right = int(camera_bounds.position.x + camera_bounds.size.x)
	camera.limit_bottom = int(camera_bounds.position.y + camera_bounds.size.y)


func _configure_game() -> void:
	if not has_node("/root/GameManager"):
		return
	var wave_total: int = spawner.total_waves if spawner != null else 5
	GameManager.configure_level(wave_total)
	# Permite probar un escenario suelto (F6) sin pasar por el menú principal:
	# sin esto la partida se quedaría en estado BOOT y la pausa no respondería.
	if GameManager.state != GameManager.GameState.PLAYING:
		GameManager.begin_direct_play()


func _connect_player() -> void:
	if player == null:
		push_error("[Level] No se encontró al jugador en la escena.")
		return
	player.player_died.connect(_on_player_died)


func _connect_spawner() -> void:
	if spawner == null:
		push_error("[Level] No se encontró el ZombieSpawner en la escena.")
		return
	spawner.all_waves_cleared.connect(_on_all_waves_cleared)
	if spawner.has_signal("miniboss_spawned"):
		spawner.miniboss_spawned.connect(_on_miniboss_spawned)


func _connect_hud() -> void:
	if hud == null or player == null:
		return

	if player != null:
		# Avisos de recogida rechazada (vida o munición al máximo)
		if hud.has_method("show_message"):
			player.pickup_rejected.connect(Callable(hud, "show_message"))

		# Vida del jugador
		if player.health_component != null and hud.has_method("set_health"):
			player.health_component.health_changed.connect(Callable(hud, "set_health"))
			hud.call(
				"set_health",
				player.health_component.current_health,
				player.health_component.max_health
			)

		# Sincronizar estado inicial de ranuras de armas desbloqueadas
		if hud.has_method("set_unlocked_weapons"):
			hud.call("set_unlocked_weapons", player.unlocked_weapons)

		# Munición e información del arma
		var weapon: WeaponComponent = player.weapon_component
		if weapon != null:
			if hud.has_method("set_weapon_info"):
				hud.call("set_weapon_info", player.active_weapon_slot, weapon.weapon_name, weapon.magazine, weapon.reserve_ammo)
			elif hud.has_method("set_ammo"):
				hud.call("set_ammo", weapon.magazine, weapon.reserve_ammo)
			if hud.has_method("set_reloading"):
				weapon.reload_started.connect(_on_reload_started.bind(hud))
				weapon.reload_finished.connect(_on_reload_finished.bind(hud))

		if player.has_signal("ammo_changed") and hud.has_method("set_ammo"):
			player.ammo_changed.connect(Callable(hud, "set_ammo"))

		if player.has_signal("weapon_switched") and hud.has_method("set_weapon_info"):
			player.weapon_switched.connect(Callable(hud, "set_weapon_info"))
		if player.has_signal("weapon_unlocked"):
			player.weapon_unlocked.connect(func(slot: int, _w_name: String) -> void:
				if hud.has_method("unlock_slot"):
					hud.call("unlock_slot", slot)
				if hud.has_method("show_message"):
					hud.call("show_message", "¡NUEVA ARMA DESBLOQUEADA (TECLA %d)!" % [slot + 1])
			)

	# Progreso de oleadas
	if spawner != null and hud.has_method("show_wave_banner"):
		spawner.wave_started.connect(_on_wave_started.bind(hud))


func _show_intro() -> void:
	var wave_total: int = 0
	if spawner != null:
		wave_total = spawner.total_waves
	if hud != null and hud.has_method("set_level_info"):
		hud.call("set_level_info", level_name, wave_total)
	if hud != null and hud.has_method("show_level_intro"):
		hud.call("show_level_intro", level_name, level_tagline)


func _start_level_music() -> void:
	if not has_node("/root/SoundManager"):
		return
	if has_node("/root/GameManager") and GameManager.is_endless_mode:
		SoundManager.play_music("endless", 1.2, -8.0)
	elif "2" in level_name or (has_node("/root/GameManager") and GameManager.current_level_index == 1):
		SoundManager.play_music("level_2", 1.2, -8.0)
	elif "3" in level_name or "Final" in level_name or (has_node("/root/GameManager") and GameManager.current_level_index == 2):
		SoundManager.play_music("level_final", 1.2, -8.0)
	else:
		SoundManager.play_music("level_1", 1.2, -8.0)


# ------------------------------------------------------------------------------
# Manejadores
# ------------------------------------------------------------------------------

func _on_miniboss_spawned(boss: Zombie) -> void:
	if hud != null and hud.has_method("show_boss_bar") and is_instance_valid(boss):
		if boss.health_component != null:
			hud.call("show_boss_bar", boss.display_name, boss.health_component.current_health, boss.health_component.max_health, boss)
			if not boss.health_component.health_changed.is_connected(Callable(hud, "update_boss_health")):
				boss.health_component.health_changed.connect(Callable(hud, "update_boss_health"))
		if not boss.tree_exited.is_connected(Callable(hud, "hide_boss_bar")):
			boss.tree_exited.connect(Callable(hud, "hide_boss_bar"))


func _on_wave_started(wave_number: int, total_waves: int, target_hud: CanvasLayer) -> void:
	if target_hud.has_method("show_wave_banner"):
		target_hud.call("show_wave_banner", "OLEADA %d / %d" % [wave_number, total_waves])


func _on_reload_started(_duration: float, target_hud: CanvasLayer) -> void:
	if target_hud.has_method("set_reloading"):
		target_hud.call("set_reloading", true)


func _on_reload_finished(_magazine: int, _reserve: int, target_hud: CanvasLayer) -> void:
	if target_hud.has_method("set_reloading"):
		target_hud.call("set_reloading", false)


func _on_player_died() -> void:
	if has_node("/root/GameManager"):
		GameManager.finish_run(false)


func _exit_tree() -> void:
	# Limpieza de objetos no recogidos al salir o cambiar de nivel
	get_tree().call_group("pickups", "queue_free")


func _on_all_waves_cleared() -> void:
	level_completed.emit()
	# Los objetos no recogidos desaparecen al final de la última oleada
	get_tree().call_group("pickups", "queue_free")
	# Respiro mínimo para que se aprecie la última muerte antes del resultado.
	await get_tree().create_timer(1.2, false, false, true).timeout
	if not is_inside_tree():
		return
	if has_node("/root/GameManager"):
		GameManager.finish_run(true)
