extends Node2D

## Test automatizado de velocidad de zombis según dificultad seleccionada.

const WALKER_SCENE: PackedScene = preload("res://scenes/entities/enemies/zombie_walker.tscn")
const RUNNER_SCENE: PackedScene = preload("res://scenes/entities/enemies/zombie_runner.tscn")
const BRUTE_SCENE: PackedScene = preload("res://scenes/entities/enemies/zombie_brute.tscn")
const MINIBOSS_SCENE: PackedScene = preload("res://scenes/entities/enemies/zombie_miniboss.tscn")
const BOSS_SCENE: PackedScene = preload("res://scenes/entities/enemies/zombie_boss.tscn")


func _ready() -> void:
	print("=== INICIO DE TEST: VELOCIDAD DE ZOMBIS POR DIFICULTAD ===")
	_run_tests()
	print("=== FIN DE TEST: VELOCIDAD DE ZOMBIS POR DIFICULTAD ===")
	get_tree().quit()


func _run_tests() -> void:
	assert(has_node("/root/GameSettings"), "GameSettings autoload debe existir")

	# Guardar dificultad original para restaurarla al final
	var original_difficulty: int = GameSettings.difficulty

	print("\n--- [1] COMPROBACIÓN DE MULTIPLICADORES DE DIFICULTAD ---")
	GameSettings.set_difficulty(GameSettings.Difficulty.FACIL)
	assert(is_equal_approx(GameSettings.enemy_speed_multiplier, 0.85), "Fácil debe ser 0.85x")
	assert(is_equal_approx(GameSettings.enemy_damage_multiplier, 0.7), "Fácil daño debe ser 0.7x")
	print("✓ Fácil -> Multiplicador de velocidad = ", GameSettings.enemy_speed_multiplier, " | daño = ", GameSettings.enemy_damage_multiplier)

	GameSettings.set_difficulty(GameSettings.Difficulty.NORMAL)
	assert(is_equal_approx(GameSettings.enemy_speed_multiplier, 1.0), "Normal debe ser 1.0x")
	assert(is_equal_approx(GameSettings.enemy_damage_multiplier, 1.0), "Normal daño debe ser 1.0x")
	print("✓ Normal -> Multiplicador de velocidad = ", GameSettings.enemy_speed_multiplier, " | daño = ", GameSettings.enemy_damage_multiplier)

	GameSettings.set_difficulty(GameSettings.Difficulty.DIFICIL)
	assert(is_equal_approx(GameSettings.enemy_speed_multiplier, 1.35), "Difícil debe ser 1.35x (+5% de aumento)")
	assert(is_equal_approx(GameSettings.enemy_damage_multiplier, 1.55), "Difícil daño debe ser 1.55x (+5% de aumento)")
	print("✓ Difícil -> Multiplicador de velocidad = ", GameSettings.enemy_speed_multiplier, " | daño = ", GameSettings.enemy_damage_multiplier)

	print("\n--- [2] COMPROBACIÓN EN TODOS LOS TIPOS DE ZOMBIS EN DIFICULTAD DIFÍCIL ---")
	var scenes: Array[Dictionary] = [
		{"name": "Walker", "scene": WALKER_SCENE, "base_speed": 72.0},
		{"name": "Runner", "scene": RUNNER_SCENE, "base_speed": 148.0},
		{"name": "Brute", "scene": BRUTE_SCENE, "base_speed": 48.0},
		{"name": "Miniboss", "scene": MINIBOSS_SCENE, "base_speed": 75.0},
		{"name": "Boss", "scene": BOSS_SCENE, "base_speed": 60.0},
	]

	for entry in scenes:
		var zombie: Zombie = entry["scene"].instantiate() as Zombie
		add_child(zombie)
		var expected_speed: float = entry["base_speed"] * 1.35
		print("Zombie: ", entry["name"], " | Base: ", entry["base_speed"], " | Actual: ", zombie.move_speed, " | Esperado: ", expected_speed)
		assert(is_equal_approx(zombie.move_speed, expected_speed), "La velocidad en Difícil debe ser 1.35x la base")
		zombie.queue_free()

	print("\n--- [3] COMPROBACIÓN EN DIFICULTAD FÁCIL ---")
	GameSettings.set_difficulty(GameSettings.Difficulty.FACIL)
	for entry in scenes:
		var zombie: Zombie = entry["scene"].instantiate() as Zombie
		add_child(zombie)
		var expected_speed: float = entry["base_speed"] * 0.85
		print("Zombie: ", entry["name"], " | Base: ", entry["base_speed"], " | Actual: ", zombie.move_speed, " | Esperado: ", expected_speed)
		assert(is_equal_approx(zombie.move_speed, expected_speed), "La velocidad en Fácil debe ser 0.85x la base")
		zombie.queue_free()

	print("\n--- [4] COMPROBACIÓN DE CAMBIO DINÁMICO DE DIFICULTAD EN VIVO ---")
	GameSettings.set_difficulty(GameSettings.Difficulty.NORMAL)
	var dynamic_zombie: Zombie = RUNNER_SCENE.instantiate() as Zombie
	add_child(dynamic_zombie)
	assert(is_equal_approx(dynamic_zombie.move_speed, 148.0), "Debe iniciar a 148.0 en Normal")
	print("✓ Runner creado en Normal: velocidad = ", dynamic_zombie.move_speed)

	# Cambiar a Difícil mientras el zombi sigue activo en el árbol
	GameSettings.set_difficulty(GameSettings.Difficulty.DIFICIL)
	assert(is_equal_approx(dynamic_zombie.move_speed, 148.0 * 1.35), "Debe actualizarse dinámicamente a 199.8 en Difícil")
	print("✓ Runner actualizado dinámicamente a Difícil: velocidad = ", dynamic_zombie.move_speed)

	# Cambiar a Fácil
	GameSettings.set_difficulty(GameSettings.Difficulty.FACIL)
	assert(is_equal_approx(dynamic_zombie.move_speed, 148.0 * 0.85), "Debe actualizarse dinámicamente a 125.8 en Fácil")
	print("✓ Runner actualizado dinámicamente a Fácil: velocidad = ", dynamic_zombie.move_speed)
	dynamic_zombie.queue_free()

	print("\n--- [5] COMPROBACIÓN DE PROGRESIÓN GRADUAL EN MODO INFINITO ---")
	GameSettings.set_difficulty(GameSettings.Difficulty.NORMAL)
	GameManager.is_endless_mode = true

	# Oleada 1 (base)
	GameManager.wave = 1
	var z_w1: Zombie = WALKER_SCENE.instantiate() as Zombie
	add_child(z_w1)
	assert(is_equal_approx(z_w1.move_speed, 72.0), "En oleada 1 infinita debe ser velocidad base")
	print("✓ Modo Infinito Oleada 1: velocidad = ", z_w1.move_speed, " | daño = ", z_w1.attack_damage)
	z_w1.queue_free()

	# Oleada 5 (+14% velocidad, +20% daño, +16% vida)
	GameManager.wave = 5
	var z_w5: Zombie = WALKER_SCENE.instantiate() as Zombie
	add_child(z_w5)
	assert(is_equal_approx(z_w5.move_speed, 72.0 * 1.14), "En oleada 5 infinita debe tener +14% velocidad")
	assert(is_equal_approx(z_w5.attack_damage, 7.0 * 1.20), "En oleada 5 infinita debe tener +20% daño")
	print("✓ Modo Infinito Oleada 5: velocidad = ", z_w5.move_speed, " (+14%) | daño = ", z_w5.attack_damage, " (+20%)")
	z_w5.queue_free()

	# Oleada 10 (+31.5% velocidad, +45% daño, +36% vida)
	GameManager.wave = 10
	var z_w10: Zombie = WALKER_SCENE.instantiate() as Zombie
	add_child(z_w10)
	assert(is_equal_approx(z_w10.move_speed, 72.0 * 1.315), "En oleada 10 infinita debe tener +31.5% velocidad")
	assert(is_equal_approx(z_w10.attack_damage, 7.0 * 1.45), "En oleada 10 infinita debe tener +45% daño")
	print("✓ Modo Infinito Oleada 10: velocidad = ", z_w10.move_speed, " (+31.5%) | daño = ", z_w10.attack_damage, " (+45%)")
	z_w10.queue_free()

	GameManager.is_endless_mode = false

	# Restaurar dificultad inicial
	GameSettings.set_difficulty(original_difficulty)
	print("\n✓ Todos los tests de velocidad y dificultad progresiva pasaron exitosamente.")
