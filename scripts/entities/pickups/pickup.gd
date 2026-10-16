class_name Pickup
extends Area2D

## Objeto recolectable del mundo (botiquín, munición, llaves...).
## Se recoge al entrar en contacto con el cuerpo del jugador y aplica su
## efecto llamando a los métodos públicos del portador, sin acoplarse a su
## estructura interna de nodos.

enum PickupType { MEDKIT, AMMO, WEAPON }

## Emitida cuando el objeto es recogido.
signal collected(pickup_type: int, amount: float)

@export var pickup_type: int = PickupType.MEDKIT
## Vida restaurada si es un botiquín.
@export var heal_amount: float = 35.0
## Balas entregadas si es munición.
@export var ammo_amount: int = 24
## Grupo al que debe pertenecer el cuerpo para poder recogerlo.
@export var collector_group: StringName = &"player"

@export_group("Recogida")
## Radio de recogida efectivo en píxeles (0 = respetar el del escenario).
## Un radio generoso evita que el jugador tenga que pisar el objeto con precisión.
@export var collect_radius: float = 32.0

@export_group("Presentation")
## Amplitud del vaivén vertical (0 para desactivar).
@export var bob_amplitude: float = 3.0
@export var bob_speed: float = 3.0
## Segundos antes de desaparecer; 0 = permanente.
@export var lifetime: float = 0.0

var _elapsed: float = 0.0
var _base_y: float = 0.0
var _base_y_ready: bool = false
var _collected: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	add_to_group("pickups")
	_apply_collect_radius()


## Aplica el radio de recogida en tiempo de ejecución para no depender de que el
## escenario tenga exactamente ese valor en su CollisionShape2D.
func _apply_collect_radius() -> void:
	if collect_radius <= 0.0:
		return
	var shape_node: CollisionShape2D = get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node == null or not (shape_node.shape is CircleShape2D):
		return
	# Se duplica el recurso para no mutar el compartido entre instancias.
	var circle: CircleShape2D = (shape_node.shape as CircleShape2D).duplicate() as CircleShape2D
	circle.radius = collect_radius
	shape_node.shape = circle


func _process(delta: float) -> void:
	# La altura base se captura en el primer frame, no en _ready: quien instancia
	# el objeto suele recolocarlo justo después de añadirlo al árbol.
	if not _base_y_ready:
		_base_y = position.y
		_base_y_ready = true

	_elapsed += delta

	if bob_amplitude > 0.0:
		position.y = _base_y + sin(_elapsed * bob_speed) * bob_amplitude

	if lifetime > 0.0 and _elapsed >= lifetime:
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	if _collected or not body.is_in_group(collector_group):
		return

	var applied: float = _apply_effect(body)
	if applied <= 0.0:
		# No se consume: se avisa de por qué no se puede usar todavía.
		_notify_rejected(body)
		return

	_collected = true
	if has_node("/root/SoundManager"):
		var type_name: String = "ammo"
		if pickup_type == PickupType.MEDKIT:
			type_name = "health"
		elif pickup_type == PickupType.WEAPON:
			type_name = "weapon"
		SoundManager.play_pickup(type_name)

	collected.emit(pickup_type, applied)
	queue_free()



## Informa al portador de por qué no se ha podido usar el objeto, para que la
## interfaz pueda explicárselo al jugador en vez de parecer que está roto.
func _notify_rejected(collector: Node) -> void:
	if not collector.has_method("on_pickup_rejected"):
		return
	var reason: String = "NO SE PUEDE USAR"
	match pickup_type:
		PickupType.MEDKIT:
			reason = "SALUD AL MÁXIMO"
		PickupType.AMMO:
			reason = "MUNICIÓN AL MÁXIMO"
		PickupType.WEAPON:
			reason = "ARSENAL AL MÁXIMO"
	collector.call("on_pickup_rejected", reason)


## Aplica el efecto sobre el portador. Devuelve la cantidad realmente aplicada.
func _apply_effect(collector: Node) -> float:
	match pickup_type:
		PickupType.MEDKIT:
			if collector.has_method("heal"):
				var healed: bool = bool(collector.call("heal", heal_amount))
				return heal_amount if healed else 0.0
		PickupType.AMMO:
			if collector.has_method("add_ammo"):
				var added: int = int(collector.call("add_ammo", ammo_amount))
				return float(added)
		PickupType.WEAPON:
			if collector.has_method("unlock_weapon_pickup"):
				collector.call("unlock_weapon_pickup")
				return 1.0
			elif collector.has_method("add_ammo"):
				return float(collector.call("add_ammo", ammo_amount))
	return 0.0
