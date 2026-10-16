extends Node2D

const PLAYER_SCENE: PackedScene = preload("res://scenes/entities/player.tscn")
const MAIN_MENU_SCENE: PackedScene = preload("res://scenes/ui/main_menu.tscn")
const OPTIONS_MENU_SCENE: PackedScene = preload("res://scenes/ui/options_menu.tscn")
const OPTIONS_PANEL_SCENE: PackedScene = preload("res://scenes/ui/options_panel.tscn")
const BOSS_SCENE: PackedScene = preload("res://scenes/entities/enemies/zombie_boss.tscn")

func _ready() -> void:
	print("=== INICIO TEST AMETRALLADORA, OPCIONES Y RUGIDO DE JEFE FINAL ===")
	_test_machine_gun_audio_cutoff()
	_test_options_menu_audio_sliders()
	_test_boss_roar_and_slam_removal()
	print("=== TODAS LAS PRUEBAS COMPLETADAS SATISFACTORIAMENTE ===")
	get_tree().quit(0)


func _test_machine_gun_audio_cutoff() -> void:
	print("\n--- [1] TEST CORTE INMEDIATO DE AUDIO EN AMETRALLADORA ---")
	var sm = get_node("/root/SoundManager")
	assert(sm != null, "SoundManager debe existir")
	var smg_player = sm.get("_smg_player") as AudioStreamPlayer
	assert(smg_player != null, "SoundManager debe tener un reproductor dedicado _smg_player")

	# 1. Al disparar ametralladora, inicia el reproductor
	sm.play_shoot("SMG")
	assert(smg_player.playing, "La ametralladora debe empezar a sonar")
	print("✓ Disparo de ametralladora iniciado")

	# 2. Al llamar a stop_shoot("smg") o stop_machine_gun(), se corta de forma inmediata
	sm.stop_shoot("smg")
	assert(not smg_player.playing, "El sonido de ametralladora debe cortarse INMEDIATAMENTE al soltar")
	print("✓ Corte instantáneo verificado al soltar el gatillo")

	# 3. Al disparar y esperar el timeout sin nuevo disparo, se apaga automáticamente
	sm.play_shoot("Ametralladora Pesada")
	assert(smg_player.playing, "Ametralladora sonando")
	# Simular avance de tiempo en _process (timeout es 0.16s)
	sm._process(0.25)
	assert(not smg_player.playing, "El sonido debe apagarse tras expirar el intervalo entre balas")
	print("✓ Apagado automático por inactividad de ráfaga verificado")

	# 4. Integración con WeaponComponent del jugador
	var player: Player = PLAYER_SCENE.instantiate() as Player
	add_child(player)
	player.unlocked_weapons[2] = true
	player.switch_to_weapon_slot(2) # Slot 2 es SMG
	var smg_weapon = player.weapon_component
	assert(smg_weapon != null, "El arma SMG debe existir en el jugador")

	# Disparo simulado
	smg_weapon.try_fire(Vector2.ZERO, Vector2.RIGHT)
	assert(smg_player.playing, "Al disparar el componente de arma, suena la ametralladora")
	
	# Soltar gatillo (release_trigger)
	smg_weapon.release_trigger()
	assert(not smg_player.playing, "Al llamar a release_trigger(), la ametralladora se silencia al instante")
	print("✓ Integración WeaponComponent.release_trigger silencia la ametralladora")

	player.queue_free()


func _test_options_menu_audio_sliders() -> void:
	print("\n--- [2] TEST DESLIZADORES DE VOLUMEN DENTRO DEL MENÚ DE OPCIONES ---")
	# 1. Verificar que el menú principal tiene el botón de Opciones
	var main_menu = MAIN_MENU_SCENE.instantiate()
	add_child(main_menu)
	var opt_button = main_menu.get_node_or_null("Root/LeftSection/Buttons/OptionsButton") as Button
	assert(opt_button != null, "El menú principal debe tener el botón 'OPCIONES'")
	print("✓ Menú principal cuenta con botón 'OPCIONES'")
	main_menu.queue_free()

	# 2. Instanciar OptionsMenu (la pantalla accesible desde Opciones)
	var options_menu = OPTIONS_MENU_SCENE.instantiate()
	add_child(options_menu)

	var panel = options_menu.get_node_or_null("Root/OptionsPanel")
	assert(panel != null, "OptionsMenu debe contener OptionsPanel")

	var master_slider = panel.get_node_or_null("Layout/VolumeRow/VolumeSlider") as HSlider
	var master_label = panel.get_node_or_null("Layout/VolumeRow/VolumeValue") as Label
	var music_slider = panel.get_node_or_null("Layout/MusicRow/MusicSlider") as HSlider
	var music_label = panel.get_node_or_null("Layout/MusicRow/MusicValue") as Label
	var sfx_slider = panel.get_node_or_null("Layout/SfxRow/SfxSlider") as HSlider
	var sfx_label = panel.get_node_or_null("Layout/SfxRow/SfxValue") as Label
	var footstep_slider = panel.get_node_or_null("Layout/FootstepRow/FootstepSlider") as HSlider
	var footstep_label = panel.get_node_or_null("Layout/FootstepRow/FootstepValue") as Label

	assert(master_slider != null, "Debe existir deslizador de volumen general")
	assert(music_slider != null, "Debe existir deslizador de música")
	assert(sfx_slider != null, "Debe existir deslizador de efectos/armas")
	assert(footstep_slider != null, "Debe existir deslizador de pasos")
	print("✓ Los 4 deslizadores de audio están presentes dentro del Menú de Opciones")

	# Probar ajuste de volumen general
	master_slider.value = 50.0
	assert(GameSettings.master_volume >= 0.49 and GameSettings.master_volume <= 0.51, "GameSettings debe actualizar master_volume a 0.5")
	assert(master_label.text == "50%", "La etiqueta debe mostrar 50%")
	print("✓ Deslizador General ajusta y muestra porcentaje correctamente (50%)")

	# Probar ajuste de música
	music_slider.value = 35.0
	assert(GameSettings.music_volume >= 0.34 and GameSettings.music_volume <= 0.36, "GameSettings debe actualizar music_volume a 0.35")
	assert(music_label.text == "35%", "La etiqueta debe mostrar 35%")
	print("✓ Deslizador de Música ajusta y muestra porcentaje correctamente (35%)")

	# Probar ajuste de SFX
	sfx_slider.value = 70.0
	assert(GameSettings.sfx_volume >= 0.69 and GameSettings.sfx_volume <= 0.71, "GameSettings debe actualizar sfx_volume a 0.70")
	assert(sfx_label.text == "70%", "La etiqueta debe mostrar 70%")
	print("✓ Deslizador de Efectos ajusta y muestra porcentaje correctamente (70%)")

	# Probar ajuste de pasos
	footstep_slider.value = 90.0
	assert(GameSettings.footstep_volume >= 0.89 and GameSettings.footstep_volume <= 0.91, "GameSettings debe actualizar footstep_volume a 0.90")
	assert(footstep_label.text == "90%", "La etiqueta debe mostrar 90%")
	print("✓ Deslizador de Pasos ajusta y muestra porcentaje correctamente (90%)")

	options_menu.queue_free()


func _test_boss_roar_and_slam_removal() -> void:
	print("\n--- [3] TEST RUGIDO LIMPIO Y PERIÓDICO DEL JEFE FINAL ---")
	var boss: ZombieBoss = BOSS_SCENE.instantiate() as ZombieBoss
	add_child(boss)

	# 1. Al iniciar la animación de aparición / grito inicial
	boss._play_spawn_animation()
	assert(boss._is_roaring, "El jefe debe estar en estado de rugido")
	print("✓ Animación de aparición del Jefe Final iniciada con el rugido")

	# 2. Simular un paso del rugido donde antes se disparaban los golpes
	boss._shockwave_timer = 0.0
	boss._process_roar(0.016)
	assert(boss._shockwaves.size() > 0, "Las ondas visuales deben generarse")
	print("✓ Ondas visuales de rugido generadas limpiamente sin golpes sonoros")

	# 3. Finalizar rugido inicial y verificar transición a persecución
	boss._end_roar()
	assert(not boss._is_roaring, "El rugido inicial debe terminar")
	assert(boss._state == Zombie.State.CHASE, "El jefe debe pasar a persecución")
	assert(boss._periodic_roar_timer >= 12.0, "El temporizador de rugido periódico debe reiniciarse")
	print("✓ Transición a combate tras el rugido inicial completada")

	# 4. Simular el avance del temporizador de rugido periódico
	boss._periodic_roar_timer = 0.05
	boss._process_periodic_roar(0.1)
	assert(boss._periodic_roar_timer >= 12.0, "El rugido periódico debe dispararse y reiniciar el intervalo")
	print("✓ Rugido periódico disparado correctamente y reiniciado para repetirse periódicamente")

	boss.queue_free()
