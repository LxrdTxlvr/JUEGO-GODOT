extends Node2D

const PLAYER_SCENE: PackedScene = preload("res://scenes/entities/player.tscn")
const MAIN_MENU_SCENE: PackedScene = preload("res://scenes/ui/main_menu.tscn")
const GAME_OVER_SCENE: PackedScene = preload("res://scenes/ui/game_over.tscn")


func _ready() -> void:
	print("=== INICIO DE TEST DE APUNTADO, DISPARO Y MENÚS ===")
	_test_game_over_panel()
	_test_main_menu_showcase()
	_test_player_aiming_and_shooting()
	print("=== FIN DE TEST DE APUNTADO, DISPARO Y MENÚS ===")
	get_tree().quit()


func _test_game_over_panel() -> void:
	print("\n--- [1] VERIFICACIÓN DEL MENÚ FINAL (GAME OVER / VICTORIA) ---")
	var go: Control = GAME_OVER_SCENE.instantiate()
	add_child(go)

	var panel: Panel = go.get_node("Root/Panel") as Panel
	assert(panel != null, "Panel de fin de juego debe existir")
	var panel_width: float = panel.offset_right - panel.offset_left
	var panel_height: float = panel.offset_bottom - panel.offset_top
	print("Tamaño del panel: ", panel_width, "x", panel_height, " (ampliado para albergar 3 botones)")
	assert(panel_width >= 900.0, "El panel debe tener al menos 900 px de ancho para evitar desbordamiento")

	var buttons_box: HBoxContainer = go.get_node("Root/Panel/Buttons") as HBoxContainer
	assert(buttons_box != null, "Contenedor de botones debe existir")
	var btn_width: float = buttons_box.offset_right - buttons_box.offset_left
	print("Ancho del área de botones: ", btn_width)
	assert(btn_width >= 850.0, "El contenedor de botones debe abarcar suficiente ancho")
	assert(buttons_box.offset_bottom <= panel_height - 30.0, "Los botones no deben sobrepasar el borde inferior del panel")
	print("✓ Menú final verificado: los botones no se salen del marco.")
	go.queue_free()


func _test_main_menu_showcase() -> void:
	print("\n--- [2] VERIFICACIÓN DEL MENÚ PRINCIPAL (ESTILO METAL SLUG) ---")
	var mm: Control = MAIN_MENU_SCENE.instantiate()
	add_child(mm)

	var showcase: Panel = mm.get_node("Root/CharacterShowcase") as Panel
	assert(showcase != null, "El panel de CharacterShowcase debe existir")
	var char_sprite: AnimatedSprite2D = showcase.get_node("CharacterSprite") as AnimatedSprite2D
	assert(char_sprite != null, "El sprite del personaje debe existir en el menú")
	assert(char_sprite.scale.x >= 4.0, "El personaje debe mostrarse en escala arcade prominente (>= 4x)")
	assert(char_sprite.sprite_frames.has_animation(&"idle"), "Debe tener animación idle")
	print("✓ Personaje tipo Metal Slug presente con escala: ", char_sprite.scale)

	var left_sec: Control = mm.get_node("Root/LeftSection") as Control
	assert(left_sec != null, "La sección izquierda de botones debe existir")
	var btn1: Button = left_sec.get_node("Buttons/Level1Button") as Button
	assert(btn1 != null, "Botón escenario 1 presente")
	print("✓ Menú principal reorganizado estilo arcade verificado.")
	mm.queue_free()


func _test_player_aiming_and_shooting() -> void:
	print("\n--- [3] VERIFICACIÓN DE APUNTADO Y DISPARO ---")
	var player: Player = PLAYER_SCENE.instantiate()
	add_child(player)
	player.global_position = Vector2(400.0, 400.0)
	if player.input_handler != null:
		player.input_handler.is_active = false

	var frames: SpriteFrames = player.animated_sprite.sprite_frames
	assert(frames.has_animation(&"aim_up"), "Debe existir animación aim_up")
	assert(frames.has_animation(&"aim_down"), "Debe existir animación aim_down")
	print("✓ Animaciones de apuntado vertical presentes: aim_up, aim_down")

	# 1. Probar apuntado hacia ARRIBA
	player._current_input.aim_direction = Vector2(0.2, -0.95).normalized()
	player._physics_process(0.016)
	assert(player.animated_sprite.animation == &"aim_up", "Al apuntar arriba debe reproducir aim_up")
	var muzzle_up: Vector2 = player.get_muzzle_position()
	print("Posición del cañón apuntando arriba: ", muzzle_up, " (global_position.y = ", player.global_position.y, ")")
	assert(muzzle_up.y < player.global_position.y - 20.0, "La boca del cañón al apuntar arriba debe estar en la parte superior")
	print("✓ Apuntado hacia arriba verificado con éxito")

	# 2. Probar apuntado hacia ABAJO
	player._current_input.aim_direction = Vector2(0.2, 0.95).normalized()
	player._physics_process(0.016)
	assert(player.animated_sprite.animation == &"aim_down", "Al apuntar abajo debe reproducir aim_down")
	var muzzle_down: Vector2 = player.get_muzzle_position()
	print("Posición del cañón apuntando abajo: ", muzzle_down, " (global_position.y = ", player.global_position.y, ")")
	assert(muzzle_down.y > player.global_position.y, "La boca del cañón al apuntar abajo debe apuntar hacia abajo")
	print("✓ Apuntado hacia abajo verificado con éxito")

	# 3. Probar apuntado HORIZONTAL DERECHA
	player._current_input.aim_direction = Vector2(1.0, 0.0)
	player._physics_process(0.016)
	assert(player.animated_sprite.animation == &"idle", "Al apuntar horizontal quieto debe reproducir idle")
	var muzzle_right: Vector2 = player.get_muzzle_position()
	assert(muzzle_right.x > player.global_position.x + 15.0, "El cañón debe estar al frente derecho")
	print("✓ Apuntado horizontal derecho verificado con éxito")

	# 4. Probar apuntado HORIZONTAL IZQUIERDA
	player._current_input.aim_direction = Vector2(-1.0, 0.0)
	player._physics_process(0.016)
	var muzzle_left: Vector2 = player.get_muzzle_position()
	assert(muzzle_left.x < player.global_position.x - 15.0, "El cañón debe estar al frente izquierdo")
	print("✓ Apuntado horizontal izquierdo verificado con éxito")

	# 5. Probar disparo y rotación del fogonazo
	var flash: Sprite2D = player.weapon_component.muzzle_flash as Sprite2D
	assert(flash != null, "MuzzleFlash debe existir")
	player._on_shoot_requested(Vector2.ZERO, Vector2(0.0, -1.0)) # Disparo hacia arriba
	assert(flash.visible, "El fogonazo debe encenderse al disparar")
	print("Rotación global del fogonazo disparando hacia arriba (-90°): ", rad_to_deg(flash.global_rotation), "°")
	assert(is_equal_approx(flash.global_rotation, -PI * 0.5), "El fogonazo debe rotar apuntando hacia arriba")
	print("✓ Fogonazo y disparo rotan exactamente en la dirección apuntada")

	player.queue_free()
