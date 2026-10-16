class_name WeaponComponent
extends Node2D

## Componente modular de arma de fuego.
## Gestiona cadencia, cargador, munición de reserva y recarga, e instancia
## proyectiles. Es agnóstico al portador: sirve igual para el jugador,
## un NPC aliado o una torreta.

## Emitida al disparar con éxito.
signal shot_fired(magazine: int, reserve: int)
## Emitida al intentar disparar sin balas en el cargador.
signal dry_fired()
## Emitida al comenzar la recarga.
signal reload_started(duration: float)
## Emitida al terminar la recarga.
signal reload_finished(magazine: int, reserve: int)
## Emitida cada vez que cambia cualquier contador de munición.
signal ammo_changed(magazine: int, reserve: int)

@export_group("Projectile")
## Escena del proyectil a instanciar al disparar.
@export var projectile_scene: PackedScene
## Daño transferido a cada proyectil.
@export var damage: float = 22.0
## Velocidad del proyectil en píxeles por segundo.
@export var projectile_speed: float = 950.0
## Distancia desde el origen del disparo a la boca del cañón.
@export var muzzle_offset: float = 22.0
## Dispersión aleatoria aplicada a cada disparo, en grados.
@export var spread_degrees: float = 3.0

@export_group("Fire Rate & Ammo")
## Nombre legible del arma para la interfaz.
@export var weapon_name: String = "Pistola 9mm"
## Si es falsa, requiere soltar y volver a presionar el botón por cada bala (1 bala por clic).
@export var is_automatic: bool = false
## Si es verdadera, es un arma cuerpo a cuerpo (no gasta munición).
@export var is_melee: bool = false
## Disparos por segundo.
@export var fire_rate: float = 7.0
## Balas por cargador.
@export var magazine_size: int = 12
## Munición de reserva inicial.
@export var reserve_ammo: int = 72
## Tope de munición de reserva acumulable.
@export var max_reserve: int = 300
## Tiempo de recarga en segundos.
@export var reload_time: float = 1.25
## Recarga automáticamente al vaciar el cargador.
@export var auto_reload: bool = true

@export_group("Feedback")
## Nodo opcional (Sprite2D / PointLight2D) destellado al disparar.
@export var muzzle_flash: CanvasItem
## Duración visible del fogonazo en segundos.
@export var muzzle_flash_time: float = 0.05

## Balas disponibles en el cargador en este instante.
var magazine: int = 0

var _cooldown: float = 0.0
var _is_reloading: bool = false
var _reload_timer: float = 0.0
var _trigger_held: bool = false
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	magazine = magazine_size
	_rng.randomize()
	if muzzle_flash != null:
		muzzle_flash.visible = false
	ammo_changed.emit.call_deferred(magazine, reserve_ammo)


func _process(delta: float) -> void:
	if _cooldown > 0.0:
		_cooldown = maxf(0.0, _cooldown - delta)

	if _is_reloading:
		_reload_timer -= delta
		if _reload_timer <= 0.0:
			_finish_reload()


# ------------------------------------------------------------------------------
# Disparo
# ------------------------------------------------------------------------------

## Informa que el usuario ha soltado el gatillo / botón de disparo.
func release_trigger() -> void:
	_trigger_held = false
	if has_node("/root/SoundManager"):
		SoundManager.stop_shoot(weapon_name)


## Intenta efectuar un disparo desde [param origin] hacia [param direction].
## Devuelve true si el disparo se materializó.
func try_fire(origin: Vector2, direction: Vector2) -> bool:
	if not is_automatic and _trigger_held:
		return false
	if direction == Vector2.ZERO:
		return false
	if _is_reloading or _cooldown > 0.0:
		return false

	if is_melee:
		_trigger_held = true
		_cooldown = 1.0 / maxf(0.1, fire_rate)
		var dir_norm_melee: Vector2 = direction.normalized()
		_perform_melee_attack(origin, dir_norm_melee)
		if has_node("/root/SoundManager"):
			SoundManager.play_shoot("knife")
		shot_fired.emit(1, 1)
		return true

	if magazine <= 0:
		if has_node("/root/SoundManager"):
			SoundManager.stop_shoot(weapon_name)
		dry_fired.emit()
		if has_node("/root/SoundManager"):
			SoundManager.play_sound("ui_click", -2.0, 0.1)
		if auto_reload:
			start_reload()
		return false

	_trigger_held = true
	_cooldown = 1.0 / maxf(0.1, fire_rate)
	magazine -= 1
	var dir_norm: Vector2 = direction.normalized()
	_spawn_projectile(origin, dir_norm)
	_play_muzzle_flash(origin, dir_norm)

	if has_node("/root/SoundManager"):
		SoundManager.play_shoot(weapon_name)

	shot_fired.emit(magazine, reserve_ammo)
	ammo_changed.emit(magazine, reserve_ammo)

	if magazine <= 0 and auto_reload:
		start_reload()
	return true



func _perform_melee_attack(origin: Vector2, direction: Vector2) -> void:
	var space_state: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = 42.0
	query.shape = circle
	query.transform = Transform2D(0.0, origin + direction * 36.0)
	query.collision_mask = 4 # Capa de enemigos
	query.collide_with_bodies = true

	var results: Array[Dictionary] = space_state.intersect_shape(query, 6)
	for res in results:
		var collider: Object = res.get("collider")
		if collider != null and collider.has_method("take_damage"):
			collider.call("take_damage", damage, self)


func _spawn_projectile(origin: Vector2, direction: Vector2) -> void:
	if projectile_scene == null:
		push_warning("[WeaponComponent] Sin projectile_scene asignado.")
		return

	var projectile: Node2D = projectile_scene.instantiate() as Node2D
	if projectile == null:
		push_warning("[WeaponComponent] projectile_scene no es un Node2D válido.")
		return

	# Dispersión angular
	var spread_radians: float = deg_to_rad(
		_rng.randf_range(-spread_degrees, spread_degrees)
	)
	var final_direction: Vector2 = direction.rotated(spread_radians)

	var container: Node = _get_projectile_container()
	container.add_child(projectile)
	projectile.global_position = origin + final_direction * muzzle_offset

	if projectile.has_method("setup"):
		projectile.call("setup", final_direction, damage, projectile_speed)
	elif projectile is Projectile:
		var typed_projectile: Projectile = projectile as Projectile
		typed_projectile.direction = final_direction
		typed_projectile.damage = damage
		typed_projectile.speed = projectile_speed


## Busca un contenedor con el grupo "projectile_container"; si no existe,
## cuelga el proyectil de la escena actual.
func _get_projectile_container() -> Node:
	var containers: Array[Node] = get_tree().get_nodes_in_group("projectile_container")
	if not containers.is_empty():
		return containers[0]
	return get_tree().current_scene as Node


func _play_muzzle_flash(origin: Vector2 = Vector2.ZERO, direction: Vector2 = Vector2.RIGHT) -> void:
	if muzzle_flash == null:
		return
	muzzle_flash.visible = true
	if muzzle_flash is Node2D:
		var flash_2d: Node2D = muzzle_flash as Node2D
		if origin != Vector2.ZERO:
			flash_2d.global_position = origin + direction * (muzzle_offset * 0.75)
		flash_2d.global_rotation = direction.angle()
		if flash_2d is Sprite2D:
			(flash_2d as Sprite2D).flip_v = direction.x < 0.0
	var timer: SceneTreeTimer = get_tree().create_timer(
		muzzle_flash_time, true, false, true
	)
	timer.timeout.connect(func() -> void:
		if is_instance_valid(muzzle_flash):
			muzzle_flash.visible = false
	)


# ------------------------------------------------------------------------------
# Recarga y munición
# ------------------------------------------------------------------------------

## Comienza la recarga si hay balas disponibles y no está ya recargando.
func start_reload() -> void:
	if _is_reloading or magazine >= magazine_size or reserve_ammo <= 0:
		return
	if has_node("/root/SoundManager"):
		SoundManager.stop_shoot(weapon_name)
	_is_reloading = true
	_reload_timer = reload_time
	reload_started.emit(reload_time)


func _finish_reload() -> void:
	_is_reloading = false
	var needed: int = magazine_size - magazine
	var transferred: int = mini(needed, reserve_ammo)
	magazine += transferred
	reserve_ammo -= transferred
	reload_finished.emit(magazine, reserve_ammo)
	ammo_changed.emit(magazine, reserve_ammo)


## Añade munición de reserva (usado por los pickups). Devuelve lo realmente añadido.
func add_ammo(amount: int) -> int:
	var previous: int = reserve_ammo
	reserve_ammo = clampi(reserve_ammo + amount, 0, max_reserve)
	var added: int = reserve_ammo - previous
	if added > 0:
		ammo_changed.emit(magazine, reserve_ammo)
	return added


func is_reloading() -> bool:
	return _is_reloading


func get_ammo_ratio() -> float:
	var total_capacity: float = float(magazine_size)
	return float(magazine) / total_capacity if total_capacity > 0.0 else 0.0
