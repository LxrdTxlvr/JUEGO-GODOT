class_name DesktopInputHandler
extends BaseInputHandler

## Implementación concreta de BaseInputHandler para Teclado y Ratón en PC.
## Lee las acciones mapeadas en InputMap y calcula el apuntado respecto al cursor del ratón.
## En la siguiente fase, esta clase puede intercambiarse por un UDPVisionInputHandler sin tocar el PlayerController.

## Nodo de referencia para calcular el vector de apuntado relativo (generalmente el PlayerController).
@export var actor_reference: Node2D

## Nombres de acciones configuradas en el InputMap del proyecto.
@export_group("Input Map Action Names")
@export var action_move_left: StringName = &"move_left"
@export var action_move_right: StringName = &"move_right"
@export var action_move_up: StringName = &"move_up"
@export var action_move_down: StringName = &"move_down"
@export var action_shoot: StringName = &"shoot"
@export var action_dodge: StringName = &"dodge"
@export var action_reload: StringName = &"reload"


func _ready() -> void:
	super._ready()
	# Si no se asignó explícitamente el actor, intenta vincularse al padre si es Node2D
	if actor_reference == null and get_parent() is Node2D:
		actor_reference = get_parent() as Node2D


func _physics_process(_delta: float) -> void:
	if not is_active:
		return
	poll_input()
	dispatch()


## Lee los dispositivos de entrada locales y actualiza el payload agnóstico.
func poll_input() -> void:
	# 1. Movimiento en 8 direcciones normalizado
	var raw_vector: Vector2 = Input.get_vector(
		action_move_left,
		action_move_right,
		action_move_up,
		action_move_down
	)
	current_payload.movement_vector = raw_vector

	# 2. Apuntado hacia el cursor en coordenadas de mundo
	if actor_reference != null:
		var world_mouse: Vector2 = actor_reference.get_global_mouse_position()
		current_payload.aim_target_position = world_mouse
		var dir: Vector2 = (world_mouse - actor_reference.global_position).normalized()
		if dir != Vector2.ZERO:
			current_payload.aim_direction = dir
	else:
		var mouse_pos: Vector2 = Vector2.ZERO
		var viewport: Viewport = get_viewport()
		if viewport != null:
			mouse_pos = viewport.get_mouse_position()
			var canvas_transform: Transform2D = viewport.get_canvas_transform()
			mouse_pos = canvas_transform.affine_inverse() * mouse_pos
		current_payload.aim_target_position = mouse_pos
		current_payload.aim_direction = Vector2.RIGHT

	# 3. Acciones de combate
	current_payload.is_shooting = Input.is_action_pressed(action_shoot)
	current_payload.is_dodging = Input.is_action_just_pressed(action_dodge)
	current_payload.is_reloading = Input.is_action_just_pressed(action_reload)
	current_payload.timestamp_ms = Time.get_ticks_msec()
