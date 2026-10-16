class_name BaseInputHandler
extends Node

## Clase base abstracta para cualquier emisor de entradas del jugador.
## Cumple con el Principio de Inversión de Dependencias (SOLID):
## El PlayerController depende de esta abstracción, no de Input de Godot ni de Sockets concretos.

## Señal emitida cada vez que se genera o actualiza un nuevo paquete de intención de entrada.
signal input_dispatched(payload: InputPayload)

## Almacena el estado de entrada más reciente procesado.
var current_payload: InputPayload = InputPayload.new()

## Identificador del jugador asociado a este manejador (0 = P1, 1 = P2).
@export var player_index: int = 0

## Controla si el manejador procesa y despacha entradas activamente.
@export var is_active: bool = true


func _ready() -> void:
	current_payload.player_index = player_index


## Método plantilla para sobrescribir en subclases (ej. Desktop, UDP, Gamepad).
func poll_input() -> void:
	pass


## Despacha el payload actual a los suscriptores.
func dispatch() -> void:
	if not is_active:
		return
	input_dispatched.emit(current_payload)
