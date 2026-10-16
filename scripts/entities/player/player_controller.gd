class_name PlayerController
extends CharacterBody2D

## Controlador del Jugador 2D desacoplado de la entrada de hardware.
## Recibe órdenes exclusivamente a través de una instancia de BaseInputHandler
## (DesktopInputHandler para PC o UDPVisionInputHandler para visión artificial futura).

## Señales para desacoplar la lógica de efectos visuales, interfaz y audio
signal player_died()
signal player_damaged(current_hp: float, max_hp: float)
signal player_healed(current_hp: float, max_hp: float)
signal shoot_requested(origin_position: Vector2, direction: Vector2)
signal trigger_released()
signal dodge_performed()

@export_group("Input Injection (Dependency Inversion)")
## Manejador de entradas inyectado. Puede ser cambiado dinámicamente o configurado desde el Inspector.
@export var input_handler: BaseInputHandler

@export_group("Movement Stats")
## Velocidad máxima de desplazamiento en píxeles por segundo.
@export var max_speed: float = 240.0
## Aceleración para arranque suave (píxeles/s²).
@export var acceleration: float = 1800.0
## Fricción al soltar el movimiento (píxeles/s²).
@export var friction: float = 1500.0

@export_group("Dodge / Roll Mechanics")
## Multiplicador de velocidad al esquivar.
@export var dodge_speed_multiplier: float = 2.2
## Duración de la evasión en segundos.
@export var dodge_duration: float = 0.22
## Tiempo de recarga entre evasiones en segundos.
@export var dodge_cooldown: float = 0.8

@export_group("Node References")
## Componente de salud modular. Si no se asigna en inspector, buscará uno en sus hijos.
@export var health_component: HealthComponent
## Pivote visual para rotar el arma o la retícula hacia el objetivo de apuntado.
@export var weapon_pivot: Node2D
## Sprite principal para voltear según la dirección horizontal.
@export var visual_sprite: CanvasItem

# Estado interno
var _is_dodging: bool = false
var _can_dodge: bool = true
var _dodge_direction: Vector2 = Vector2.ZERO
var _current_input: InputPayload = InputPayload.new()


func _ready() -> void:
	_setup_health_component()
	_setup_input_handler()


## Conecta y asegura la existencia del HealthComponent.
func _setup_health_component() -> void:
	if health_component == null:
		health_component = get_node_or_null("HealthComponent") as HealthComponent
	
	if health_component != null:
		health_component.damage_received.connect(_on_health_damaged)
		health_component.healed.connect(_on_health_healed)
		health_component.died.connect(_on_health_died)
	else:
		push_warning("[PlayerController] No se detectó HealthComponent asignado.")


## Conecta el manejador de inputs inyectado.
func _setup_input_handler() -> void:
	if input_handler == null:
		# Intenta encontrar un BaseInputHandler como hijo
		for child in get_children():
			if child is BaseInputHandler:
				input_handler = child
				break
				
	if input_handler != null:
		input_handler.input_dispatched.connect(_on_input_received)
	else:
		push_warning("[PlayerController] No se detectó un BaseInputHandler asignado.")


## Callback cuando el input handler emite una nueva intención de control.
func _on_input_received(payload: InputPayload) -> void:
	_current_input = payload


func _physics_process(delta: float) -> void:
	if health_component != null and health_component.is_dead():
		return

	_handle_dodge_input()
	_apply_movement(delta)
	_apply_aim()
	_handle_combat_actions()
	move_and_slide()


## Gestiona la activación del Dash / Dodge si se recibió la intención.
func _handle_dodge_input() -> void:
	if _current_input.is_dodging and _can_dodge and not _is_dodging:
		var dir: Vector2 = _current_input.movement_vector.normalized()
		if dir == Vector2.ZERO:
			dir = _current_input.aim_direction.normalized()
		_start_dodge(dir)


func _start_dodge(direction: Vector2) -> void:
	_is_dodging = true
	_can_dodge = false
	_dodge_direction = direction
	
	# Otorgar invulnerabilidad durante el dash si existe HealthComponent
	if health_component != null:
		health_component.start_invulnerability(dodge_duration)
		
	dodge_performed.emit()

	# Temporizador de fin de dash
	get_tree().create_timer(dodge_duration).timeout.connect(func() -> void:
		_is_dodging = false
	)
	# Temporizador de cooldown de dash
	get_tree().create_timer(dodge_cooldown).timeout.connect(func() -> void:
		_can_dodge = true
	)


## Procesa la aceleración, desaceleración o velocidad de esquive.
func _apply_movement(delta: float) -> void:
	if _is_dodging:
		velocity = _dodge_direction * (max_speed * dodge_speed_multiplier)
		return

	var target_vector: Vector2 = _current_input.movement_vector.normalized()
	var target_velocity: Vector2 = target_vector * max_speed

	if target_vector != Vector2.ZERO:
		velocity = velocity.move_toward(target_velocity, acceleration * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)


## Orienta el pivote del arma y voltea el sprite según la dirección apuntada.
func _apply_aim() -> void:
	var aim_dir: Vector2 = _current_input.aim_direction
	if aim_dir == Vector2.ZERO:
		return

	if weapon_pivot != null:
		weapon_pivot.rotation = aim_dir.angle()

	# Voltear sprite en el eje horizontal según hacia dónde se apunta
	if visual_sprite != null:
		visual_sprite.scale.x = -1.0 if aim_dir.x < 0.0 else 1.0


## Dispara señales de combate desacopladas (el WeaponComponent responderá a esto).
func _handle_combat_actions() -> void:
	if _current_input.is_shooting and not _is_dodging:
		var spawn_pos: Vector2 = weapon_pivot.global_position if weapon_pivot != null else global_position
		shoot_requested.emit(spawn_pos, _current_input.aim_direction)
	else:
		trigger_released.emit()


# ------------------------------------------------------------------------------
# Manejadores de Salud
# ------------------------------------------------------------------------------
func _on_health_damaged(_amount: float, _source: Node) -> void:
	if health_component != null:
		player_damaged.emit(health_component.current_health, health_component.max_health)


func _on_health_healed(_amount: float) -> void:
	if health_component != null:
		player_healed.emit(health_component.current_health, health_component.max_health)


func _on_health_died() -> void:
	velocity = Vector2.ZERO
	player_died.emit()
