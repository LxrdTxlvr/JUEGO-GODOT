extends Node2D

const PLAYER_SCENE: PackedScene = preload("res://scenes/entities/player.tscn")
const WALKER_SCENE: PackedScene = preload("res://scenes/entities/enemies/zombie_walker.tscn")
const RUNNER_SCENE: PackedScene = preload("res://scenes/entities/enemies/zombie_runner.tscn")
const BRUTE_SCENE: PackedScene = preload("res://scenes/entities/enemies/zombie_brute.tscn")
const MINIBOSS_SCENE: PackedScene = preload("res://scenes/entities/enemies/zombie_miniboss.tscn")

func _ready() -> void:
	print("=== INICIO DE VALIDACIÓN DE PASOS Y NUEVOS SONIDOS ===")
	_test_sound_manager_catalog()
	await _test_player_footsteps()
	_test_music_switching()
	_test_zombie_groans()
	print("=== TODAS LAS COMPROBACIONES DE AUDIO HAN SIDO EXITOSAS ===")
	get_tree().quit(0)


func _test_sound_manager_catalog() -> void:
	print("\n--- [1] CATÁLOGO DE AUDIO EN SOUNDMANAGER ---")
	assert(has_node("/root/SoundManager"), "SoundManager debe existir")
	var sm = get_node("/root/SoundManager")

	# Pasos creados
	assert(sm.SOUNDS.has("footstep_walk_1"), "Debe tener footstep_walk_1")
	assert(sm.SOUNDS.has("footstep_walk_2"), "Debe tener footstep_walk_2")
	assert(sm.SOUNDS.has("footstep_walk_3"), "Debe tener footstep_walk_3")
	assert(sm.SOUNDS.has("footstep_walk_4"), "Debe tener footstep_walk_4")
	assert(sm.SOUNDS.has("footstep_run_1"), "Debe tener footstep_run_1")
	assert(sm.SOUNDS.has("footstep_run_2"), "Debe tener footstep_run_2")
	assert(sm.SOUNDS.has("footstep_run_3"), "Debe tener footstep_run_3")
	assert(sm.SOUNDS.has("footstep_run_4"), "Debe tener footstep_run_4")
	print("✓ 8 variaciones de pasos (4 caminar + 4 correr) verificadas")

	# Sonidos de armas actualizados
	assert(sm.SOUNDS.has("shoot_pistol"), "Debe tener shoot_pistol de NEW SNDS")
	assert(sm.SOUNDS.has("shoot_smg"), "Debe tener shoot_smg de NEW SNDS")
	print("✓ Sonidos de armas (Pistola y Ametralladora) actualizados desde NEW SNDS")

	# Sonidos de zombis
	assert(sm.SOUNDS.has("zombie_walker"), "Debe tener zombie_walker")
	assert(sm.SOUNDS.has("zombie_runner"), "Debe tener zombie_runner")
	assert(sm.SOUNDS.has("zombie_brute"), "Debe tener zombie_brute")
	assert(sm.SOUNDS.has("zombie_miniboss"), "Debe tener zombie_miniboss")
	assert(sm.SOUNDS.has("boss_roar"), "Debe tener boss_roar")
	assert(sm.SOUNDS.has("zombie_attack"), "Debe tener zombie_attack")
	assert(sm.SOUNDS.has("wave_alert"), "Debe tener wave_alert")
	print("✓ Sonidos específicos por tipo de enemigo vinculados exitosamente")

	# Música
	assert(sm.MUSIC_TRACKS.has("menu"), "Debe tener música menu")
	assert(sm.MUSIC_TRACKS.has("level_1"), "Debe tener música level_1")
	assert(sm.MUSIC_TRACKS.has("level_2"), "Debe tener música level_2")
	assert(sm.MUSIC_TRACKS.has("level_final"), "Debe tener música level_final")
	assert(sm.MUSIC_TRACKS.has("endless"), "Debe tener música endless")
	print("✓ 5 pistas musicales registradas (Menú, Nivel 1, Nivel 2, Final y Modo Infinito)")


func _test_player_footsteps() -> void:
	print("\n--- [2] TEST SISTEMA DE PASOS DEL JUGADOR ---")
	var player: Player = PLAYER_SCENE.instantiate() as Player
	add_child(player)
	player.global_position = Vector2(500, 500)

	var sm = get_node("/root/SoundManager")
	var footstep_player = sm.get("_footstep_player") as AudioStreamPlayer
	assert(footstep_player != null, "SoundManager debe tener reproductor de pasos dedicado")

	# 1. Jugador quieto -> no reproduce pasos
	player.velocity = Vector2.ZERO
	player._update_footsteps(0.5)
	assert(not footstep_player.playing, "Estando quieto no debe sonar ningún paso")
	print("✓ Jugador quieto: sin pasos")

	# 2. Jugador caminando -> reproduce paso al cumplir intervalo
	player.velocity = Vector2(100, 0)
	player._step_timer = 0.0
	player._update_footsteps(player.STEP_INTERVAL_WALK + 0.05)
	assert(footstep_player.playing, "Al caminar debe disparar sonido de paso")
	print("✓ Paso de caminata reproducido exitosamente")

	# 3. Jugador corriendo -> reproduce paso al cumplir intervalo de correr
	footstep_player.stop()
	player.velocity = Vector2(300, 0)
	player._step_timer = 0.0
	player._update_footsteps(player.STEP_INTERVAL_RUN + 0.05)
	assert(footstep_player.playing, "Al correr debe disparar sonido de paso de carrera")
	print("✓ Paso de carrera/sprint reproducido exitosamente")

	player.queue_free()


func _test_music_switching() -> void:
	print("\n--- [3] TEST REPRODUCTOR DE MÚSICA Y TRANSICIONES ---")
	var sm = get_node("/root/SoundManager")
	var music_player = sm.get("_music_player") as AudioStreamPlayer
	assert(music_player != null, "Debe existir un AudioStreamPlayer dedicado para música")

	# Menú
	sm.play_music("menu", 0.0, -10.0)
	assert(music_player.playing, "La música de menú debe reproducirse")
	assert(sm.get("_current_music_key") == "menu", "Clave actual debe ser 'menu'")
	print("✓ Pista musical 'menu' activa")

	# Cambio a nivel 1
	sm.play_music("level_1", 0.0, -10.0)
	assert(music_player.playing, "La música de nivel 1 debe reproducirse")
	assert(sm.get("_current_music_key") == "level_1", "Clave actual debe ser 'level_1'")
	print("✓ Pista musical 'level_1' activa")

	# Stop
	sm.stop_music(0.0)
	assert(not music_player.playing, "stop_music debe detener el reproductor")
	print("✓ Detención de música verificada")


func _test_zombie_groans() -> void:
	print("\n--- [4] TEST SONIDOS POR TIPO DE ZOMBI ---")
	var sm = get_node("/root/SoundManager")

	# Llamadas sin error
	sm.play_zombie_groan(Vector2.ZERO, "Caminante")
	sm.play_zombie_groan(Vector2.ZERO, "Corredor")
	sm.play_zombie_groan(Vector2.ZERO, "Bruto")
	sm.play_zombie_groan(Vector2.ZERO, "Miniboss")
	sm.play_boss_roar(Vector2.ZERO)
	sm.play_zombie_attack(Vector2.ZERO)
	print("✓ Gemidos y rugidos por tipo disparados correctamente en el pool 2D")
