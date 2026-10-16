class_name InputPayload
extends RefCounted

## Estructura de datos (DTO) agnóstica al hardware que encapsula las intenciones del jugador.
## Permite desacoplar completamente la lógica del personaje (PlayerController) de la fuente de entrada
## (Teclado/Mouse, Gamepad, o Sockets UDP con Visión Artificial).

## Vector de movimiento deseado normalizado (X: [-1.0, 1.0], Y: [-1.0, 1.0]).
var movement_vector: Vector2 = Vector2.ZERO

## Vector unitario que indica hacia dónde apunta el jugador.
var aim_direction: Vector2 = Vector2.RIGHT

## Coordenada espacial hacia donde se apunta (útil para retículas o posicionamiento 2D/3D).
var aim_target_position: Vector2 = Vector2.ZERO

## Estado de disparo (True mientras se mantenga presionada la intención de disparar).
var is_shooting: bool = false

## Intención de evasión/esquive (Dash/Roll). Activo durante un pulso/frame.
var is_dodging: bool = false

## Intención de recargar arma.
var is_reloading: bool = false

## Índice del jugador (0 para Jugador 1, 1 para Jugador 2 en soporte cooperativo futuro).
var player_index: int = 0

## Marca de tiempo en milisegundos para sincronización y predicción en red/sockets.
var timestamp_ms: int = 0


func _init(
	p_movement_vector: Vector2 = Vector2.ZERO,
	p_aim_direction: Vector2 = Vector2.RIGHT,
	p_aim_target_position: Vector2 = Vector2.ZERO,
	p_is_shooting: bool = false,
	p_is_dodging: bool = false,
	p_is_reloading: bool = false,
	p_player_index: int = 0
) -> void:
	movement_vector = p_movement_vector
	aim_direction = p_aim_direction
	aim_target_position = p_aim_target_position
	is_shooting = p_is_shooting
	is_dodging = p_is_dodging
	is_reloading = p_is_reloading
	player_index = p_player_index
	timestamp_ms = Time.get_ticks_msec()


## Devuelve una copia clonada para evitar mutaciones no deseadas entre sistemas.
func duplicate_payload() -> InputPayload:
	var copy: InputPayload = InputPayload.new(
		movement_vector,
		aim_direction,
		aim_target_position,
		is_shooting,
		is_dodging,
		is_reloading,
		player_index
	)
	copy.timestamp_ms = timestamp_ms
	return copy
