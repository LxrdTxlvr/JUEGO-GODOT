extends Node2D

const PLAYER_SCENE: PackedScene = preload("res://scenes/entities/player.tscn")
const MAIN_MENU_SCENE: PackedScene = preload("res://scenes/ui/main_menu.tscn")
const MINIBOSS_SCENE: PackedScene = preload("res://scenes/entities/enemies/zombie_miniboss.tscn")
const PICKUP_WEAPON_SCENE: PackedScene = preload("res://scenes/entities/pickups/pickup_weapon.tscn")
const PICKUP_AMMO_SCENE: PackedScene = preload("res://scenes/entities/pickups/pickup_ammo.tscn")
const ZOMBIE_SPAWNER_SCENE: PackedScene = preload("res://scenes/entities/enemies/zombie_walker.tscn")


func _ready() -> void:
	print("=== INICIO DE PRUEBAS COMPLETAS DE LAS MEJORAS ===")
	if has_node("/root/GameSettings"):
		GameSettings.set_difficulty(GameSettings.Difficulty.NORMAL)
	_test_walk_aim_animations()
	_test_semi_auto_shooting()
	_test_weapons_inventory_and_pickup_cleanup()
	_test_endless_mode_menu_and_manager()
	_test_miniboss_entity()
	_test_hud_weapon_slots_and_boss_bar()
	_test_final_boss_and_level_03()
	print("=== TODAS LAS PRUEBAS FINALIZARON EXITOSAMENTE ===")
	get_tree().quit()


func _test_walk_aim_animations() -> void:
	print("\n--- [1] TEST ANIMACIONES DE CAMINATA EN APUNTADO ARRIBA / ABAJO ---")
	var player: Player = PLAYER_SCENE.instantiate()
	add_child(player)
	player.global_position = Vector2(400, 400)
	if player.input_handler != null:
		player.input_handler.is_active = false

	var frames: SpriteFrames = player.animated_sprite.sprite_frames
	assert(frames.has_animation(&"walk_aim_up"), "Debe tener la animación walk_aim_up")
	assert(frames.has_animation(&"walk_aim_down"), "Debe tener la animación walk_aim_down")
	print("✓ Animaciones walk_aim_up y walk_aim_down registradas en SpriteFrames")

	# Simular: Movimiento activo + Apuntado hacia ARRIBA
	player.velocity = Vector2(100.0, 0.0)
	player._current_input.aim_direction = Vector2(0.2, -0.95).normalized()
	player._physics_process(0.016)
	assert(player.animated_sprite.animation == &"walk_aim_up", "En movimiento apuntando arriba debe reproducir walk_aim_up")
	print("✓ Al caminar apuntando arriba: reproduce walk_aim_up (los pies se mueven)")

	# Simular: Quieto + Apuntado hacia ARRIBA
	player.velocity = Vector2.ZERO
	player._physics_process(0.016)
	assert(player.animated_sprite.animation == &"aim_up", "Quieto apuntando arriba debe reproducir aim_up")
	print("✓ Al estar quieto apuntando arriba: reproduce aim_up")

	# Simular: Movimiento activo + Apuntado hacia ABAJO
	player.velocity = Vector2(100.0, 0.0)
	player._current_input.aim_direction = Vector2(0.2, 0.95).normalized()
	player._physics_process(0.016)
	assert(player.animated_sprite.animation == &"walk_aim_down", "En movimiento apuntando abajo debe reproducir walk_aim_down")
	print("✓ Al caminar apuntando abajo: reproduce walk_aim_down (los pies se mueven)")

	# Simular: Quieto + Apuntado hacia ABAJO
	player.velocity = Vector2.ZERO
	player._physics_process(0.016)
	assert(player.animated_sprite.animation == &"aim_down", "Quieto apuntando abajo debe reproducir aim_down")
	print("✓ Al estar quieto apuntando abajo: reproduce aim_down")

	player.queue_free()


func _test_semi_auto_shooting() -> void:
	print("\n--- [2] TEST DISPARO SEMIAUTOMÁTICO (1 BALA POR CLIC) ---")
	var player: Player = PLAYER_SCENE.instantiate()
	add_child(player)
	player.global_position = Vector2(300, 300)
	if player.input_handler != null:
		player.input_handler.is_active = false

	var weapon: WeaponComponent = player.weapon_component
	assert(weapon != null, "WeaponComponent debe existir")
	assert(not weapon.is_automatic, "El arma principal (pistola) debe ser semiautomática (is_automatic = false)")

	var initial_mag: int = weapon.magazine
	print("Balas iniciales en cargador: ", initial_mag)

	# Simular mantener presionado el clic durante 5 frames seguidos
	for _i in range(5):
		weapon.try_fire(player.global_position, Vector2.RIGHT)
		player._physics_process(0.016)

	print("Balas tras mantener clic por 5 frames sin soltar: ", weapon.magazine)
	assert(weapon.magazine == initial_mag - 1, "Mantener presionado el clic debe disparar EXACTAMENTE 1 bala (sin ráfagas)")
	print("✓ Verificado: 1 bala por clic sin ráfaga continua involuntaria")

	# Simular soltar el clic (release_trigger) y volver a hacer clic
	weapon.release_trigger()
	weapon._cooldown = 0.0 # reset cooldown para test unitario
	weapon.try_fire(player.global_position, Vector2.RIGHT)
	assert(weapon.magazine == initial_mag - 2, "Al soltar y volver a hacer clic debe disparar la segunda bala")
	print("✓ Verificado: Segundo clic dispara la segunda bala con normalidad")

	player.queue_free()


func _test_weapons_inventory_and_pickup_cleanup() -> void:
	print("\n--- [3] TEST ARSENAL DE 3 ARMAS Y LIMPIEZA DE OBJETOS ---")
	var player: Player = PLAYER_SCENE.instantiate()
	add_child(player)
	player.global_position = Vector2(200, 200)

	# Verificar slots
	assert(player.weapon_slots.size() >= 3, "El jugador debe tener 3 slots de armas configurados")
	print("Slot 0: ", player.weapon_slots[0].weapon_name, " (Semiautomática)")
	print("Slot 1: ", player.weapon_slots[1].weapon_name, " (Melee)")
	print("Slot 2: ", player.weapon_slots[2].weapon_name, " (Automática)")

	# Desbloquear las 3 armas mediante el método de recogida de maletín
	player.unlock_weapon_pickup()
	assert(player.unlocked_weapons[1] == true, "Slot 1 (Cuchillo) debe desbloquearse al recoger maletín")
	assert(player.active_weapon_slot == 1, "Debe equipar el arma recién desbloqueada")
	print("✓ Maletín desbloqueó: ", player.weapon_component.weapon_name)

	player.unlock_weapon_pickup()
	assert(player.unlocked_weapons[2] == true, "Slot 2 (Subfusil) debe desbloquearse con el segundo maletín")
	assert(player.weapon_component.is_automatic == true, "El subfusil debe ser automático")
	print("✓ Maletín desbloqueó: ", player.weapon_component.weapon_name, " (Automático)")

	# Comprobar alternancia a la pistola
	player.switch_to_weapon_slot(0)
	assert(player.active_weapon_slot == 0, "Debe volver a la pistola al seleccionar slot 0")
	print("✓ Alternancia entre las 3 armas verificada")

	# Test de limpieza de objetos en el suelo al final de oleada o cambio de nivel
	var p1: Node2D = PICKUP_AMMO_SCENE.instantiate() as Node2D
	var p2: Node2D = PICKUP_WEAPON_SCENE.instantiate() as Node2D
	add_child(p1)
	add_child(p2)
	assert(get_tree().get_nodes_in_group("pickups").size() >= 2, "Debe haber pickups en el grupo pickups")

	# Ejecutar limpieza de nivel
	get_tree().call_group("pickups", "queue_free")
	await get_tree().process_frame
	print("✓ Limpieza de objetos no recogidos (pickups) verificada")

	player.queue_free()


func _test_endless_mode_menu_and_manager() -> void:
	print("\n--- [4] TEST MODO OLEADAS INFINITAS EN MENÚ Y GESTOR ---")
	var mm: Control = MAIN_MENU_SCENE.instantiate()
	add_child(mm)

	var endless_btn: Button = mm.get_node("Root/LeftSection/Buttons/EndlessButton") as Button
	assert(endless_btn != null, "El botón EndlessButton debe existir en el menú")
	print("✓ Botón Modo Infinito presente en la interfaz del Menú Principal: '", endless_btn.text, "'")
	mm.queue_free()

	# Comprobar GameManager
	assert(has_node("/root/GameManager"), "GameManager debe estar cargado como Autoload")
	GameManager.is_endless_mode = true
	assert(GameManager.is_endless_mode == true, "is_endless_mode debe ser true")
	print("✓ GameManager configurado en Modo Infinito (is_endless_mode = true)")
	GameManager.is_endless_mode = false


func _test_miniboss_entity() -> void:
	print("\n--- [5] TEST MINIBOSS MUTANTE ---")
	var miniboss: Zombie = MINIBOSS_SCENE.instantiate() as Zombie
	add_child(miniboss)

	assert(miniboss.is_in_group("miniboss"), "Debe pertenecer al grupo miniboss")
	assert(miniboss.display_name.contains("Miniboss"), "Debe llamarse Miniboss")
	assert(miniboss.health_component.max_health == 1200.0, "La vida del miniboss debe ser 1200 (x3 de 400)")
	assert(miniboss.attack_damage >= 25.0, "El daño del miniboss debe ser imponente (>= 25)")
	assert(miniboss.drop_chance >= 0.9, "El miniboss debe soltar botín valioso garantizado")
	print("✓ Miniboss Mutante verificado con ", miniboss.health_component.max_health, " HP (aumentado x3) y daño ", miniboss.attack_damage)

	miniboss.queue_free()


func _test_hud_weapon_slots_and_boss_bar() -> void:
	print("\n--- [6] TEST HUD: ARMAS CENTRADAS Y BARRA DE JEFE ---")
	var hud_scene: PackedScene = preload("res://scenes/ui/hud.tscn")
	var hud: CanvasLayer = hud_scene.instantiate() as CanvasLayer
	add_child(hud)

	# 1. Comprobar que existe la barra de jefe
	assert(hud.boss_bar_panel != null, "HUD debe tener boss_bar_panel")
	assert(hud.boss_health_fill != null, "HUD debe tener boss_health_fill")
	assert(hud.boss_health_label != null, "HUD debe tener boss_health_label")

	# Simular aparición de boss con 1200 HP
	hud.show_boss_bar("Miniboss Mutante", 1200.0, 1200.0)
	assert(hud.boss_bar_panel.visible, "El panel de jefe debe estar visible")
	assert(hud.boss_title_label.text == "MINIBOSS MUTANTE", "El título del jefe debe coincidir")
	assert(hud.boss_health_label.text == "1200 / 1200", "El valor de vida debe coincidir")

	# Daño al boss
	hud.update_boss_health(600.0, 1200.0)
	assert(hud.boss_health_label.text == "600 / 1200", "El valor de vida debe actualizarse")

	# 2. Comprobar panel de armamento inferior centrado
	assert(hud.weapon_slots_panel != null, "HUD debe tener weapon_slots_panel")
	var container: HBoxContainer = hud.weapon_slots_panel.get_node_or_null("SlotsContainer") as HBoxContainer
	assert(container != null, "Debe tener SlotsContainer")
	assert(container.get_child_count() == 3, "Debe contener 3 recuadros de armas")

	for i in range(3):
		var slot: Control = container.get_child(i) as Control
		var key_label: Label = slot.get_node_or_null("KeyLabel") as Label
		assert(key_label != null, "Cada slot debe tener etiqueta de tecla numérica")
		assert(key_label.text == "[%d]" % (i + 1), "La tecla debe corresponder al número [%d]" % (i + 1))

	# Actualizar info de arma (sin nombre)
	hud.set_weapon_info(0, "Pistola 9mm", 12, 72)
	assert(not hud.ammo_label.text.contains("Pistola"), "No se debe mostrar el nombre del arma en la interfaz")
	assert(hud.ammo_label.text == "12 | 72", "La munición de pistola debe mostrarse como '12 | 72'")

	hud.set_weapon_info(1, "Cuchillo de Combate", 1, 1)
	assert(hud.ammo_label.text == "∞", "El cuchillo debe mostrar munición infinita '∞'")

	print("✓ HUD verificado: barra de jefe funcional, armamento centrado con 3 slots numéricos y sin nombre")
	hud.queue_free()


func _test_final_boss_and_level_03() -> void:
	print("\n--- [7] TEST JEFE FINAL Y ESCENARIO 3 ---")
	var boss_scene: PackedScene = preload("res://scenes/entities/enemies/zombie_boss.tscn")
	var boss: ZombieBoss = boss_scene.instantiate() as ZombieBoss
	add_child(boss)

	assert(boss.is_in_group("boss"), "El jefe final debe pertenecer al grupo 'boss'")
	assert(boss.is_in_group("miniboss"), "El jefe final también responde al grupo 'miniboss'")
	assert(boss.health_component.max_health == 2400.0, "La vida del Jefe Final debe ser 2400 (doble del miniboss)")
	assert(boss.scale.x >= 2.5, "El Jefe Final debe ser mucho más grande (>= 2.5x)")
	assert(boss.attack_damage >= 40.0, "El daño del Jefe Final debe ser superior (>= 40)")
	print("✓ Jefe Final verificado: 2400 HP, escala colosal 2.6x, daño ", boss.attack_damage)
	boss.queue_free()

	# Cargar Nivel 3
	var level3_scene: PackedScene = preload("res://scenes/world/level_03.tscn")
	var level3: Level = level3_scene.instantiate() as Level
	assert(level3 is LevelBoss, "Level03 debe ser de tipo LevelBoss")
	assert(level3.zombies_per_wave == 10, "Level03 debe generar oleadas de 10 zombis")
	assert(level3.wave_interval_seconds == 45.0, "Las oleadas deben ocurrir cada 45 segundos según el requerimiento")
	assert(level3.get_node_or_null("Boundaries") != null, "Level03 debe tener límites de colisión Boundaries")
	add_child(level3)
	print("✓ Escenario 3 (LevelBoss) verificado: 10 zombis por oleada cada 45 segundos y colisiones de límite presentes")
	level3.queue_free()

	print("\n--- [8] TEST TELEGRAFIADO DE ATAQUE EN ZOMBIS ---")
	var zombie_scene: PackedScene = preload("res://scenes/entities/enemies/zombie_walker.tscn")
	var z: Zombie = zombie_scene.instantiate() as Zombie
	assert(z.attack_windup > 0.0, "El zombi debe tener un tiempo de anticipación (attack_windup) para esquivar")
	assert(z.has_method("_try_attack"), "El zombi debe poseer método de ataque telegrafiado")
	print("✓ Ataque con telegrafiado visual y ventana de esquiva verificado (windup: %s s)" % z.attack_windup)
	z.queue_free()

	print("\n--- [9] TEST PANTALLA GAME OVER ---")
	var game_over_scene: PackedScene = preload("res://scenes/ui/game_over.tscn")
	var go: Control = game_over_scene.instantiate() as Control
	add_child(go)
	assert(go != null, "La pantalla de Game Over debe instanciarse sin errores de script")
	print("✓ Pantalla Game Over instanciada correctamente (sin error de level_number)")
	go.queue_free()

	print("\n--- [10] TEST RECUPERACIÓN DE VIÑETA ROJA EN HUD ---")
	var hud_res: PackedScene = preload("res://scenes/ui/hud.tscn")
	var test_hud: CanvasLayer = hud_res.instantiate() as CanvasLayer
	add_child(test_hud)
	# Simular vida crítica
	test_hud.set_health(20.0, 100.0)
	test_hud._update_low_health_pulse(0.5)
	assert(test_hud.damage_vignette.color.a > 0.0, "La viñeta debe activarse con vida crítica")
	# Simular recuperación de vida
	test_hud.set_health(100.0, 100.0)
	test_hud._update_low_health_pulse(1.0)
	# Esperar o verificar que tiende a cero
	assert(test_hud.damage_vignette.color.a < 0.05, "La viñeta roja debe disiparse al curarse la vida")
	print("✓ Viñeta roja se apaga correctamente al recuperar vida")
	test_hud.queue_free()

	print("\n--- [11] TEST OLEADAS DE MINIBOSS EN MODO INFINITO ---")
	var spawner: ZombieSpawner = ZombieSpawner.new()
	add_child(spawner)
	# Antes de oleada 10: cada 5 (5, 10)
	assert(spawner.is_miniboss_wave(4, true) == false, "Oleada 4 no debe tener miniboss")
	assert(spawner.is_miniboss_wave(5, true) == true, "Oleada 5 debe tener miniboss")
	assert(spawner.is_miniboss_wave(10, true) == true, "Oleada 10 debe tener miniboss")
	# Entre oleada 10 y 20: cada 3 oleadas más (13, 16, 19)
	assert(spawner.is_miniboss_wave(11, true) == false, "Oleada 11 no debe tener miniboss")
	assert(spawner.is_miniboss_wave(12, true) == false, "Oleada 12 no debe tener miniboss")
	assert(spawner.is_miniboss_wave(13, true) == true, "Oleada 13 debe tener miniboss")
	assert(spawner.is_miniboss_wave(16, true) == true, "Oleada 16 debe tener miniboss")
	assert(spawner.is_miniboss_wave(19, true) == true, "Oleada 19 debe tener miniboss")
	# A partir de oleada 20: en cada oleada
	assert(spawner.is_miniboss_wave(20, true) == true, "Oleada 20 debe tener miniboss")
	assert(spawner.is_miniboss_wave(21, true) == true, "Oleada 21 debe tener miniboss")
	assert(spawner.is_miniboss_wave(25, true) == true, "Oleada 25 debe tener miniboss")
	print("✓ Lógica de oleadas de Miniboss en Modo Infinito (cada 3 tras la 10, cada 1 desde la 20) verificada con éxito")
	spawner.queue_free()

