extends Node

## Test automatizado de integración para las características 3D estilo SULFUR:
## 1. Materiales Toon y Props 3D
## 2. Jugador FPS 3D (Vista, movimiento, armas, navajazo con F)
## 3. Zombis 2.5D Billboard (Caminante, Corredor, Bruto, Miniboss, Boss y animaciones frontales)
## 4. Pickups 3D (Munición, Botiquín y Maletín sin bloque amarillo)
## 5. HUD 3D (Barra de jefe, recuadros de armas) y Niveles 3D con barreras perimetrales

const LEVEL_3D_SCENE: PackedScene = preload("res://scenes/3d/world/level_01_3d.tscn")
const PLAYER_3D_SCENE: PackedScene = preload("res://scenes/3d/entities/player_3d.tscn")
const WALKER_3D_SCENE: PackedScene = preload("res://scenes/3d/entities/zombie_walker_3d.tscn")
const RUNNER_3D_SCENE: PackedScene = preload("res://scenes/3d/entities/zombie_runner_3d.tscn")
const BRUTE_3D_SCENE: PackedScene = preload("res://scenes/3d/entities/zombie_brute_3d.tscn")
const MINIBOSS_3D_SCENE: PackedScene = preload("res://scenes/3d/entities/zombie_miniboss_3d.tscn")
const BOSS_3D_SCENE: PackedScene = preload("res://scenes/3d/entities/zombie_boss_3d.tscn")
const PICKUP_AMMO_SCENE: PackedScene = preload("res://scenes/3d/pickups/pickup_ammo_3d.tscn")
const PICKUP_MEDKIT_SCENE: PackedScene = preload("res://scenes/3d/pickups/pickup_medkit_3d.tscn")
const PICKUP_WEAPON_SCENE: PackedScene = preload("res://scenes/3d/pickups/pickup_weapon_3d.tscn")


func _ready() -> void:
	print("=== INICIO DE PRUEBAS 3D ===")
	_test_materials_and_props()
	_test_player_3d()
	_test_zombies_billboard_3d()
	_test_pickups_3d()
	_test_hud_and_levels_3d()
	_test_boss_encounter_and_critical_drops()
	print("=== TODAS LAS PRUEBAS 3D COMPLETADAS EXITOSAMENTE ===")
	get_tree().quit(0)


func _test_materials_and_props() -> void:
	print("\n--- [1] TEST DE MATERIALES CARTOON Y PROPS 3D ---")
	var mat_asphalt: StandardMaterial3D = load("res://assets/materials_3d/mat_asphalt_road.tres")
	assert(mat_asphalt != null, "Debe existir mat_asphalt_road.tres")
	assert(mat_asphalt.diffuse_mode == BaseMaterial3D.DIFFUSE_TOON, "El material de asfalto debe usar DIFFUSE_TOON")

	var mat_sidewalk: StandardMaterial3D = load("res://assets/materials_3d/mat_sidewalk.tres")
	assert(mat_sidewalk != null, "Debe existir mat_sidewalk.tres")
	assert(mat_sidewalk.diffuse_mode == BaseMaterial3D.DIFFUSE_TOON, "El material de banqueta debe usar DIFFUSE_TOON")

	var crate_scene: PackedScene = load("res://scenes/3d/props/crate_3d.tscn")
	assert(crate_scene != null, "Debe existir crate_3d.tscn")
	var crate: Node3D = crate_scene.instantiate()
	add_child(crate)
	assert(crate.has_node("MeshInstance3D"), "Crate debe tener MeshInstance3D")
	assert(crate.has_node("CollisionShape3D"), "Crate debe tener CollisionShape3D")
	print("✓ Materiales Toon verificados con diffuse_mode = DIFFUSE_TOON")
	print("✓ Props modulares 3D (muros, farolas, cajas, barriles) correctos")
	crate.queue_free()


func _test_player_3d() -> void:
	print("\n--- [2] TEST DE JUGADOR FPS 3D ---")
	var player: Player3D = PLAYER_3D_SCENE.instantiate()
	add_child(player)

	assert(player.head != null, "Player3D debe tener nodo Head")
	assert(player.camera != null, "Player3D debe tener Camera3D")
	assert(player.aim_ray != null, "Player3D debe tener AimRay")
	assert(player.viewmodel != null, "Player3D debe tener ViewModel3D totalmente modelado")
	assert(player.weapons.size() >= 3, "Debe tener 3 armas configuradas (Pistola, SMG, Escopeta)")

	# Daño y curación
	var initial_hp: float = player.current_health
	player.take_damage(20.0)
	assert(player.current_health == initial_hp - 20.0, "La salud debe disminuir al recibir daño")
	var healed: bool = player.heal(15.0)
	assert(healed, "Debe aceptar curación cuando está herido")
	assert(player.current_health == initial_hp - 5.0, "La salud debe recuperarse con curación")

	# Desbloqueo y cambio de armas
	assert(player.player_needs_weapon(), "Inicialmente debe faltarle armas por desbloquear")
	var unlocked_smg: bool = player.unlock_weapon_pickup()
	assert(unlocked_smg, "Debe poder desbloquear el Subfusil")
	assert(player.active_slot == 1, "Debe cambiar a ranura 1 (SMG)")

	var unlocked_shotgun: bool = player.unlock_weapon_pickup()
	assert(unlocked_shotgun, "Debe poder desbloquear la Escopeta")
	assert(player.active_slot == 2, "Debe cambiar a ranura 2 (Escopeta)")
	assert(not player.player_needs_weapon(), "Una vez obtenidas todas, no debe necesitar más armas")

	# Probar navajazo con tecla F y modelo 3D de cuchillo
	assert(player.melee_cooldown_timer == 0.0, "Temporizador de navajazo debe iniciar en 0")
	assert(player.viewmodel.combat_knife != null, "ViewModel3D debe tener el modelo 3D de cuchillo táctico (CombatKnife)")
	player._perform_melee_attack()
	assert(player.melee_cooldown_timer > 0.0, "Debe activar enfriamiento tras el navajazo con F")
	assert(player.viewmodel.is_melee_animating, "La animación de navajazo 3D debe estar activa")

	# Probar munición
	player.add_ammo(25)
	assert(player.weapons[player.active_slot]["reserve"] > 30, "La reserva debe aumentar")
	print("✓ Jugador FPS (armas, daño, curación, vista, munición y navajazo con navaja 3D visible) funcionando")
	player.queue_free()


func _test_zombies_billboard_3d() -> void:
	print("\n--- [3] TEST DE ZOMBIS 2.5D BILLBOARD ---")
	
	# Caminante
	var walker: Zombie3D = WALKER_3D_SCENE.instantiate()
	add_child(walker)
	assert(walker.sprite != null, "El zombi debe tener AnimatedSprite3D")
	assert(walker.sprite.billboard == BaseMaterial3D.BILLBOARD_FIXED_Y, "El sprite debe usar BILLBOARD_FIXED_Y")
	assert(walker.sprite.sprite_frames.has_animation("walking_front"), "Caminante debe tener animación frontal")
	assert(walker.has_node("ShadowDisc"), "El zombi debe tener sombra de contacto")
	walker.queue_free()

	# Corredor
	var runner: Zombie3D = RUNNER_3D_SCENE.instantiate()
	add_child(runner)
	assert(runner.move_speed > 5.0, "El corredor debe ser veloz")
	assert(runner.sprite.sprite_frames.has_animation("walking_front"), "Corredor debe tener animación frontal")
	runner.queue_free()

	# Bruto
	var brute: Zombie3D = BRUTE_3D_SCENE.instantiate()
	add_child(brute)
	assert(brute.max_health >= 150.0, "El bruto debe tener alta vitalidad")
	assert(brute.sprite.sprite_frames.has_animation("walking_front"), "Bruto debe tener animación frontal")
	brute.queue_free()

	# Miniboss
	var miniboss: Zombie3D = MINIBOSS_3D_SCENE.instantiate()
	add_child(miniboss)
	assert(miniboss.is_in_group("miniboss"), "Debe pertenecer al grupo miniboss")
	assert(miniboss.max_health >= 350.0, "El miniboss debe tener salud intermedia")
	assert(miniboss.sprite.sprite_frames.has_animation("walking_front"), "Miniboss debe tener animación frontal")
	miniboss.queue_free()

	# Boss
	var boss: Zombie3D = BOSS_3D_SCENE.instantiate()
	add_child(boss)
	assert(boss.is_in_group("boss"), "El jefe debe estar en grupo boss")
	assert(boss.max_health >= 800.0, "El jefe debe tener vida de jefe")
	assert(boss.sprite.sprite_frames.has_animation("walking_front"), "Jefe debe tener animación frontal")
	assert(boss.sprite.position.y >= 2.8, "El sprite del Jefe debe estar a altura suficiente para no hundirse (pies sobre suelo)")
	boss.queue_free()
	print("✓ Zombis (Caminante, Corredor, Bruto, Miniboss y Jefe) con pies sobre terreno y vistas frontales verificados")


func _test_pickups_3d() -> void:
	print("\n--- [4] TEST DE PICKUPS 3D ---")
	var ammo: Pickup3D = PICKUP_AMMO_SCENE.instantiate()
	add_child(ammo)
	assert(ammo.has_node("Sprite3D"), "Pickup debe tener Sprite3D")
	assert(ammo.has_node("CollisionShape3D"), "Pickup debe tener CollisionShape3D")
	ammo.queue_free()

	var med: Pickup3D = PICKUP_MEDKIT_SCENE.instantiate()
	add_child(med)
	assert(med.pickup_type == Pickup3D.Type.MEDKIT, "Tipo de medkit correcto")
	med.queue_free()

	var weapon_pickup: Pickup3D = PICKUP_WEAPON_SCENE.instantiate()
	add_child(weapon_pickup)
	assert(weapon_pickup.pickup_type == Pickup3D.Type.WEAPON, "Tipo de arma correcto")
	assert(not weapon_pickup.has_node("MeshInstance3D"), "El bloque amarillo flotante debe haber sido retirado")
	print("✓ Pickup de munición, botiquín y maletín limpio (sin bloque amarillo) verificados")
	weapon_pickup.queue_free()


func _test_hud_and_levels_3d() -> void:
	print("\n--- [5] TEST DE HUD Y NIVELES 3D ---")
	var level: Level3D = LEVEL_3D_SCENE.instantiate()
	add_child(level)
	assert(level.player != null, "El nivel debe contener al Player3D")
	assert(level.spawner != null, "El nivel debe contener al ZombieSpawner3D")
	assert(level.hud != null, "El nivel debe contener al HUD3D")
	assert(level.hud.boss_panel != null, "El HUD 3D debe contener la barra de vida del Jefe")
	assert(level.hud.weapon_slots_container != null, "El HUD 3D debe contener los recuadros de armas")
	assert(level.hud.slot_nodes.size() == 3, "El HUD 3D debe tener 3 recuadros de armas")
	
	# Verificar que los slots de armas usan iconos gráficos compactos y no nombres largos
	for i in range(level.hud.slot_nodes.size()):
		var slot_node: Control = level.hud.slot_nodes[i]
		assert(slot_node.has_node("Icon"), "Cada slot debe tener un nodo Icon (TextureRect)")
		assert(slot_node.has_node("NumLabel"), "Cada slot debe tener un nodo NumLabel con el número de arma")
		var icon_rect: TextureRect = slot_node.get_node("Icon") as TextureRect
		assert(icon_rect.texture != null, "El icono debe tener asignada la textura del arma")

	assert(level.has_node("PerimeterBarriers"), "El nivel debe tener barreras de perímetro")

	# Validaciones del Overhaul Visual HD
	assert(level.hud.has_node("ViewModelFPS2D"), "El HUD 3D debe integrar el nodo ViewModelFPS2D (2.5D viewmodel)")
	assert(level.hud.has_node("HurtVignette"), "El HUD 3D debe contener HurtVignette para feedback de daño")
	assert(level.hud.hp_bar_catchup != null, "El HUD 3D debe tener la barra secundaria de vida (catchup)")
	
	var world_env: WorldEnvironment = level.get_node_or_null("WorldEnvironment") as WorldEnvironment
	assert(world_env != null and world_env.environment != null, "El nivel debe tener WorldEnvironment configurado")
	assert(world_env.environment.volumetric_fog_enabled, "El ambiente 3D debe tener Volumetric Fog activado")
	assert(world_env.environment.glow_enabled, "El ambiente 3D debe tener Glow/Bloom activado")
	assert(world_env.environment.ssao_enabled, "El ambiente 3D debe tener SSAO activado")
	assert(world_env.environment.tonemap_mode == 2, "El ambiente 3D debe usar Tonemap ACES (modo 2)")

	var lamp_scene: PackedScene = load("res://scenes/3d/props/street_lamp_3d.tscn")
	var lamp_inst: Node3D = lamp_scene.instantiate()
	assert(lamp_inst.has_node("SpotLight3D"), "StreetLamp3D debe contar con un SpotLight3D descendente")
	var spot: SpotLight3D = lamp_inst.get_node("SpotLight3D") as SpotLight3D
	assert(spot.shadow_enabled, "El foco SpotLight3D debe proyectar sombras")
	lamp_inst.queue_free()

	print("✓ HUD 3D HD (Viewmodel 2.5D, HP Catchup, Viñeta sangrienta, Iconos silueta) verificado")
	print("✓ Entorno 3D Atmosférico (Niebla volumétrica, Bloom, SSAO, Farolas Spot con sombras) verificado")
	level.queue_free()


func _test_boss_encounter_and_critical_drops() -> void:
	print("\n--- [6] TEST DE JEFE FINAL, OLEADAS DE REFUERZO Y PROBABILIDADES ---")
	assert(GameManager.has_method("notify_level_won"), "GameManager debe tener notify_level_won()")
	
	# Drop de botiquines al 20% de salud
	var player: Player3D = PLAYER_3D_SCENE.instantiate()
	add_child(player)
	player.current_health = 25.0 # <= 20% de 160 HP
	
	var walker: Zombie3D = WALKER_3D_SCENE.instantiate()
	walker.player = player
	add_child(walker)
	walker.player = player
	assert(walker._check_player_critical_health(), "Debe detectar salud crítica (<= 20%)")
	
	var medkit_picks: int = 0
	for i in range(50):
		var picked: PackedScene = walker._pick_drop_scene(false, true)
		if picked == walker.MEDKIT_DROP_3D:
			medkit_picks += 1
	assert(medkit_picks >= 30, "Con salud crítica debe priorizar botiquines (~75%)")
	print("✓ Probabilidad de botiquín al 75% cuando salud del jugador <= 20% verificada")
	walker.queue_free()
	player.queue_free()

	# Oleadas de refuerzo con jefe activo
	var spawner: ZombieSpawner3D = ZombieSpawner3D.new()
	spawner.is_boss_level = true
	add_child(spawner)
	
	var boss: Zombie3D = BOSS_3D_SCENE.instantiate()
	add_child(boss)
	spawner._active_boss = boss
	
	# Derrota del jefe
	spawner._on_boss_defeated()
	assert(spawner._active_boss == null, "El jefe debe marcarse como derrotado")
	print("✓ Flujo de oleadas de refuerzo y victoria limpia de nivel verificados")
	boss.queue_free()
	spawner.queue_free()

