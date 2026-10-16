class_name Projectile
extends Area2D

## Proyectil genérico de área (balas, flechas, ácido...).
## Viaja en línea recta, aplica daño a cualquier cuerpo con el método
## take_damage() y se destruye al impactar o al agotar su tiempo de vida.

## Emitida al destruirse el proyectil, indicando qué golpeó (null si expiró).
signal impact(body: Node)

@export var speed: float = 950.0
@export var damage: float = 20.0
## Segundos antes de autodestruirse.
@export var lifetime: float = 1.6
## Número de enemigos que puede atravesar antes de detenerse.
@export var pierce: int = 0
## Fuerza de empuje aplicada al objetivo golpeado.
@export var knockback_force: float = 120.0

## Dirección normalizada de vuelo.
var direction: Vector2 = Vector2.RIGHT

var _remaining_life: float = 0.0
var _spent: bool = false


func _ready() -> void:
	_remaining_life = lifetime
	body_entered.connect(_on_body_entered)
	rotation = direction.angle()


## Inicializa el proyectil. Llamado por el WeaponComponent justo tras instanciarlo.
func setup(p_direction: Vector2, p_damage: float, p_speed: float) -> void:
	direction = p_direction.normalized() if p_direction != Vector2.ZERO else Vector2.RIGHT
	damage = p_damage
	speed = p_speed
	rotation = direction.angle()


func _physics_process(delta: float) -> void:
	if _spent:
		return

	var old_pos: Vector2 = global_position
	var step: Vector2 = direction * speed * delta
	var new_pos: Vector2 = old_pos + step

	# Detección continua mediante raycast para evitar traspasar muros o enemigos a alta velocidad
	var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	if space != null:
		var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(old_pos, new_pos)
		query.collision_mask = collision_mask
		query.collide_with_areas = false
		query.collide_with_bodies = true
		query.exclude = [get_rid()]
		var hit: Dictionary = space.intersect_ray(query)
		if not hit.is_empty():
			global_position = hit.position
			_on_impact_hit(hit.collider, hit.normal)
			return

	global_position = new_pos
	_remaining_life -= delta
	if _remaining_life <= 0.0:
		_expire()


func _on_impact_hit(body: Object, normal: Vector2 = Vector2.ZERO) -> void:
	if _spent:
		return

	var is_wall: bool = false
	if body != null and body.has_method("take_damage"):
		body.call("take_damage", damage, self)
		if body.has_method("apply_knockback"):
			body.call("apply_knockback", direction * knockback_force)

		if has_node("/root/SoundManager"):
			SoundManager.play_flesh_impact(global_position)

		if pierce > 0:
			pierce -= 1
			return
	else:
		is_wall = true
		if has_node("/root/SoundManager"):
			SoundManager.play_wall_impact(global_position)

	_spent = true
	impact.emit(body as Node)
	_spawn_impact_fx(is_wall, normal)
	queue_free()


func _on_body_entered(body: Node2D) -> void:
	if _spent:
		return
	_on_impact_hit(body, -direction)


func _spawn_impact_fx(is_wall: bool, normal: Vector2) -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	var root: Node = tree.current_scene
	if root == null:
		return

	var particles: CPUParticles2D = CPUParticles2D.new()
	particles.emitting = true
	particles.one_shot = true
	particles.explosiveness = 0.95
	particles.amount = 8 if is_wall else 6
	particles.lifetime = 0.18
	particles.global_position = global_position
	
	var emit_dir: Vector2 = normal if normal != Vector2.ZERO else -direction
	particles.direction = emit_dir
	particles.spread = 45.0
	particles.initial_velocity_min = 60.0
	particles.initial_velocity_max = 140.0
	particles.scale_amount_min = 1.5
	particles.scale_amount_max = 3.0
	
	if is_wall:
		# Chispas doradas al chocar contra muro
		particles.color = Color(1.0, 0.85, 0.3, 1.0)
	else:
		# Salpicadura orgánica al impactar enemigo
		particles.color = Color(0.85, 0.12, 0.12, 1.0)
		
	root.add_child(particles)
	tree.create_timer(0.25).timeout.connect(particles.queue_free)


func _expire() -> void:
	if _spent:
		return
	_spent = true
	impact.emit(null)
	queue_free()

