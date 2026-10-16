class_name HealthComponent
extends Node

## Componente modular y reutilizable para la gestión de salud y vitalidad.
## Funciona de manera agnóstica a la vista (aplica idénticamente para 2D, 3D, jugador, zombis o jefes).
## Emite señales para que la UI, efectos de sonido (SFX) o animaciones reaccionen sin acoplamiento.

## Emitida cuando la salud actual cambia (útil para actualizar barras de vida).
signal health_changed(current_health: float, max_health: float)

## Emitida cuando el componente recibe daño efectivo.
signal damage_received(amount: float, source: Node)

## Emitida cuando el componente recupera vida.
signal healed(amount: float)

## Emitida cuando la salud llega a 0 por primera vez.
signal died()

## Emitida al activarse un periodo de invulnerabilidad temporal (I-Frames).
signal invulnerability_started()

## Emitida al expirar el periodo de invulnerabilidad.
signal invulnerability_ended()

@export_group("Stats")
## Vida máxima permitida.
@export var max_health: float = 100.0:
	set(value):
		max_health = maxf(1.0, value)
		if current_health > max_health:
			current_health = max_health
		health_changed.emit(current_health, max_health)

## Vida actual al iniciar o en tiempo de ejecución.
@export var current_health: float = 100.0

@export_group("Defense & Invulnerability")
## Segundos de invulnerabilidad concedidos tras recibir un impacto (0 para desactivar).
@export var invulnerability_duration: float = 0.0

## Si es verdadero, ignora cualquier daño entrante de forma indefinida.
@export var is_invulnerable: bool = false

var _is_dead: bool = false
var _invulnerability_timer: Timer


func _ready() -> void:
	current_health = clampf(current_health, 0.0, max_health)
	_setup_invulnerability_timer()
	# Notificar estado inicial en el siguiente tick del árbol
	health_changed.emit.call_deferred(current_health, max_health)


## Inicializa el temporizador de invulnerabilidad interna si se especificó duración.
func _setup_invulnerability_timer() -> void:
	_invulnerability_timer = Timer.new()
	_invulnerability_timer.one_shot = true
	_invulnerability_timer.timeout.connect(_on_invulnerability_timeout)
	add_child(_invulnerability_timer)


## Aplica una cantidad de daño al componente.
## [param amount]: Cantidad de daño entrante (valores <= 0 serán ignorados).
## [param source]: Nodo causante del daño (proyectil, zombi, trampa, etc.).
func take_damage(amount: float, source: Node = null) -> void:
	if _is_dead or is_invulnerable or amount <= 0.0:
		return

	var previous_health: float = current_health
	current_health = clampf(current_health - amount, 0.0, max_health)
	
	damage_received.emit(amount, source)
	health_changed.emit(current_health, max_health)

	# Iniciar I-Frames si corresponde y el objetivo sigue vivo
	if current_health > 0.0 and invulnerability_duration > 0.0:
		start_invulnerability(invulnerability_duration)

	if current_health <= 0.0 and not _is_dead:
		_is_dead = true
		died.emit()


## Restaura salud sin sobrepasar el límite de max_health.
func heal(amount: float) -> void:
	if _is_dead or amount <= 0.0:
		return

	var actual_heal: float = minf(amount, max_health - current_health)
	if actual_heal <= 0.0:
		return

	current_health += actual_heal
	healed.emit(actual_heal)
	health_changed.emit(current_health, max_health)


## Activa invulnerabilidad temporal durante [param duration] segundos.
func start_invulnerability(duration: float) -> void:
	is_invulnerable = true
	invulnerability_started.emit()
	_invulnerability_timer.start(duration)


func _on_invulnerability_timeout() -> void:
	is_invulnerable = false
	invulnerability_ended.emit()


## Reinicia la salud al máximo y restablece banderas de muerte.
func reset() -> void:
	_is_dead = false
	is_invulnerable = false
	if _invulnerability_timer.is_inside_tree() and not _invulnerability_timer.is_stopped():
		_invulnerability_timer.stop()
	current_health = max_health
	health_changed.emit(current_health, max_health)


## Devuelve la proporción de salud actual en un rango de 0.0 a 1.0.
func get_health_percentage() -> float:
	return current_health / max_health if max_health > 0.0 else 0.0


## Indica si la entidad está muerta.
func is_dead() -> bool:
	return _is_dead
