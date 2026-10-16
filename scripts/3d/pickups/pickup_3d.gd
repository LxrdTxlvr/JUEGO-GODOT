class_name Pickup3D
extends Area3D

## Objeto recolectable en el mundo 3D estilo SULFUR.
## Soporta Munición, Botiquines y Maletines/Cofres de Armas Nuevas.
## Flota con vaivén vertical, rota con billboard y emite un destello al recogerse.

enum Type { AMMO, MEDKIT, WEAPON }

@export var pickup_type: Type = Type.AMMO
@export var amount: int = 30
@export var bob_amplitude: float = 0.08
@export var bob_speed: float = 3.5

@onready var sprite: Sprite3D = get_node_or_null("Sprite3D") as Sprite3D
var _base_y: float = 0.0
var _time: float = 0.0


func _ready() -> void:
	_base_y = position.y
	_time = randf() * TAU
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	_time += delta * bob_speed
	position.y = _base_y + sin(_time) * bob_amplitude
	rotate_y(delta * 0.8)


func _on_body_entered(body: Node3D) -> void:
	if not (body is Player3D):
		return

	var player: Player3D = body as Player3D
	var accepted: bool = false

	match pickup_type:
		Type.AMMO:
			accepted = player.add_ammo(amount)
		Type.MEDKIT:
			accepted = player.heal(float(amount))
		Type.WEAPON:
			if player.has_method("unlock_weapon_pickup"):
				accepted = player.unlock_weapon_pickup()
			else:
				accepted = player.add_ammo(60)

	if accepted:
		_collected_effect()


func _collected_effect() -> void:
	set_deferred("monitoring", false)
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	if sprite != null:
		tween.tween_property(sprite, "scale", sprite.scale * 1.5, 0.15)
		tween.tween_property(sprite, "modulate:a", 0.0, 0.15)
	else:
		tween.tween_property(self, "scale", scale * 1.3, 0.15)
	tween.chain().tween_callback(queue_free)
