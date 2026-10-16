class_name ViewModel3D
extends Node3D

## Controlador de vista en primera persona 3D (FPS Viewmodel).
## Gestiona los brazos del superviviente y modelos tridimensionales completos
## para Pistola 9mm, Subfusil Rápido y Escopeta de Combate.
## Orientados frontalmente hacia el centro de la pantalla (punto de mira),
## con retroceso físico de corredera, amortiguación de salto y recarga.

@export var default_position: Vector3 = Vector3(0.15, -0.20, -0.38)
@export var default_rotation: Vector3 = Vector3.ZERO

# Nodos de armas 3D
@onready var pistol_node: Node3D = $Pistol
@onready var smg_node: Node3D = $SMG
@onready var shotgun_node: Node3D = $Shotgun
@onready var pistol_slide: Node3D = $Pistol/Slide
@onready var smg_bolt: Node3D = $SMG/Bolt
@onready var shotgun_pump: Node3D = $Shotgun/Pump
@onready var muzzle_flash: Node3D = $MuzzleFlash
@onready var muzzle_light: OmniLight3D = $MuzzleLight
@onready var combat_knife: Node3D = $CombatKnife

# Nodos de brazos
@onready var right_arm: Node3D = $RightArm
@onready var left_arm: Node3D = $LeftArm

var current_weapon_index: int = 0
var is_melee_animating: bool = false
var _recoil_pos: Vector3 = Vector3.ZERO
var _recoil_rot: Vector3 = Vector3.ZERO
var _jump_offset: Vector3 = Vector3.ZERO
var _jump_rot: Vector3 = Vector3.ZERO
var _mouse_sway: Vector2 = Vector2.ZERO
var _walk_bob: Vector3 = Vector3.ZERO


func _ready() -> void:
	position = default_position
	rotation = default_rotation
	if muzzle_flash != null:
		muzzle_flash.visible = false
	if muzzle_light != null:
		muzzle_light.visible = false
	if combat_knife != null:
		combat_knife.visible = false
	set_weapon(0)


func set_weapon(slot_index: int) -> void:
	current_weapon_index = slot_index
	if pistol_node != null:
		pistol_node.visible = (slot_index == 0)
	if smg_node != null:
		smg_node.visible = (slot_index == 1)
	if shotgun_node != null:
		shotgun_node.visible = (slot_index == 2)
	
	# Reposicionar punto de destello según arma activa
	if muzzle_flash != null and muzzle_light != null:
		match slot_index:
			0:
				muzzle_flash.position = Vector3(0.0, 0.045, -0.16)
				muzzle_light.position = Vector3(0.0, 0.045, -0.16)
			1:
				muzzle_flash.position = Vector3(0.0, 0.02, -0.25)
				muzzle_light.position = Vector3(0.0, 0.02, -0.25)
			2:
				muzzle_flash.position = Vector3(0.0, 0.03, -0.30)
				muzzle_light.position = Vector3(0.0, 0.03, -0.30)


func play_shoot_effect(recoil_p: Vector3, recoil_r: Vector3) -> void:
	_recoil_pos = recoil_p
	_recoil_rot = recoil_r

	# Movimiento físico de la corredera / cerrojo hacia atrás (+Z)
	if current_weapon_index == 0 and pistol_slide != null:
		var tw: Tween = create_tween()
		tw.tween_property(pistol_slide, "position:z", 0.035, 0.04).set_trans(Tween.TRANS_QUAD)
		tw.tween_property(pistol_slide, "position:z", 0.0, 0.08).set_trans(Tween.TRANS_BACK)
	elif current_weapon_index == 1 and smg_bolt != null:
		var tw: Tween = create_tween()
		tw.tween_property(smg_bolt, "position:z", 0.04, 0.03).set_trans(Tween.TRANS_QUAD)
		tw.tween_property(smg_bolt, "position:z", 0.0, 0.06).set_trans(Tween.TRANS_BACK)
	elif current_weapon_index == 2 and shotgun_pump != null:
		var tw: Tween = create_tween()
		tw.tween_property(shotgun_pump, "position:z", 0.07, 0.08).set_trans(Tween.TRANS_QUAD)
		tw.tween_property(shotgun_pump, "position:z", 0.0, 0.12).set_trans(Tween.TRANS_BACK)

	# Destello del cañón y luz
	if muzzle_flash != null:
		muzzle_flash.visible = true
		muzzle_flash.rotation.z = randf() * TAU
	if muzzle_light != null:
		muzzle_light.visible = true

	get_tree().create_timer(0.05).timeout.connect(func():
		if muzzle_flash != null and is_instance_valid(muzzle_flash):
			muzzle_flash.visible = false
		if muzzle_light != null and is_instance_valid(muzzle_light):
			muzzle_light.visible = false
	)


func apply_jump_takeoff() -> void:
	_jump_offset = Vector3(0.0, -0.06, -0.02)
	_jump_rot = Vector3(0.12, 0.0, 0.0)


func apply_jump_landing() -> void:
	_jump_offset = Vector3(0.0, -0.08, 0.03)
	_jump_rot = Vector3(-0.06, 0.0, 0.0)


func play_reload_animation(duration: float = 1.0) -> void:
	var tw: Tween = create_tween()
	# Bajar arma y brazos
	tw.tween_property(self, "position:y", default_position.y - 0.32, duration * 0.28).set_trans(Tween.TRANS_QUAD)
	tw.tween_interval(duration * 0.44)
	# Subir arma lista
	tw.tween_property(self, "position:y", default_position.y, duration * 0.28).set_trans(Tween.TRANS_BACK)


func _get_active_gun_node() -> Node3D:
	match current_weapon_index:
		0: return pistol_node
		1: return smg_node
		2: return shotgun_node
		_: return pistol_node


func play_melee_stab() -> void:
	if is_melee_animating:
		return
	is_melee_animating = true

	var active_gun: Node3D = _get_active_gun_node()
	
	# Inicializar posición y rotación de ataque del cuchillo
	if combat_knife != null:
		combat_knife.visible = true
		combat_knife.position = Vector3(0.14, -0.18, -0.20)
		combat_knife.rotation_degrees = Vector3(-25.0, 40.0, -50.0)

	var tw: Tween = create_tween()
	# 1. Bajar el arma de fuego y lanzar el corte de navaja hacia el centro (0.12s)
	if active_gun != null:
		tw.parallel().tween_property(active_gun, "position:y", -0.38, 0.09).set_trans(Tween.TRANS_QUAD)
	if combat_knife != null:
		tw.parallel().tween_property(combat_knife, "position", Vector3(-0.06, 0.02, -0.36), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(combat_knife, "rotation_degrees", Vector3(18.0, -38.0, 45.0), 0.12).set_trans(Tween.TRANS_QUAD)
	if right_arm != null:
		tw.parallel().tween_property(right_arm, "position:z", 0.04, 0.12).set_trans(Tween.TRANS_QUAD)

	# 2. Breve pausa en el punto culminante del impacto (0.04s)
	tw.tween_interval(0.04)

	# 3. Retracción del cuchillo hacia abajo y retorno del arma de fuego (0.14s)
	if combat_knife != null:
		tw.parallel().tween_property(combat_knife, "position", Vector3(0.14, -0.32, -0.16), 0.14).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(combat_knife, "rotation_degrees", Vector3(-45.0, 50.0, -65.0), 0.14)
	if right_arm != null:
		tw.parallel().tween_property(right_arm, "position:z", 0.12, 0.14).set_trans(Tween.TRANS_QUAD)

	tw.tween_callback(func():
		if combat_knife != null:
			combat_knife.visible = false
	)

	# 4. El arma de fuego regresa a la posición de empuñado lista (0.12s)
	if active_gun != null:
		tw.tween_property(active_gun, "position:y", 0.0, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	tw.tween_callback(func():
		is_melee_animating = false
		if active_gun != null:
			active_gun.position.y = 0.0
	)


func update_transform(delta: float, mouse_delta: Vector2, step_cycle: float, is_moving: bool, is_sprinting: bool) -> void:
	# Sway de ratón
	var target_sway_x: float = clampf(-mouse_delta.x * 0.0007, -0.05, 0.05)
	var target_sway_y: float = clampf(mouse_delta.y * 0.0007, -0.04, 0.04)
	_mouse_sway = _mouse_sway.lerp(Vector2(target_sway_x, target_sway_y), delta * 15.0)

	# Bobbing al caminar/correr
	if is_moving:
		var amp: float = 0.018 if is_sprinting else 0.009
		_walk_bob.x = sin(step_cycle * 0.5) * amp
		_walk_bob.y = cos(step_cycle) * amp * 0.6
	else:
		_walk_bob = _walk_bob.lerp(Vector3.ZERO, delta * 10.0)

	# Recuperación suave de retroceso y salto
	_recoil_pos = _recoil_pos.lerp(Vector3.ZERO, delta * 14.0)
	_recoil_rot = _recoil_rot.lerp(Vector3.ZERO, delta * 14.0)
	_jump_offset = _jump_offset.lerp(Vector3.ZERO, delta * 10.0)
	_jump_rot = _jump_rot.lerp(Vector3.ZERO, delta * 10.0)

	var target_pos: Vector3 = default_position + Vector3(_mouse_sway.x, _mouse_sway.y, 0.0) + _walk_bob + _recoil_pos + _jump_offset
	var target_rot: Vector3 = default_rotation + Vector3(-_mouse_sway.y * 1.6, _mouse_sway.x * 1.6, 0.0) + _recoil_rot + _jump_rot

	position = position.lerp(target_pos, delta * 24.0)
	rotation = rotation.lerp(target_rot, delta * 24.0)
