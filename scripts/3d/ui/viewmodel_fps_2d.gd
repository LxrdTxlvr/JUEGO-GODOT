class_name ViewModelFPS2D
extends Control

## Viewmodel 2.5D en primera persona con sprites HD estilizados.
## Gestiona reposo, disparo con fogonazo, recarga y navajazo procedural
## con weapon sway de ratón y bobbing sinusoidal/cosenoidal al caminar.

@export var base_position: Vector2 = Vector2(-512, -512)
@export var sway_intensity: float = 22.0
@export var bob_intensity: float = 14.0

@onready var weapon_anchor: Control = $WeaponAnchor
@onready var weapon_rect: TextureRect = $WeaponAnchor/WeaponRect
@onready var knife_anchor: Control = $KnifeAnchor
@onready var knife_rect: TextureRect = $KnifeAnchor/KnifeRect

var textures_idle: Array[Texture2D] = []
var textures_fire: Array[Texture2D] = []
var textures_reload: Array[Texture2D] = []
var texture_knife: Texture2D = null

var _player: Player3D = null
var _current_slot: int = 0
var _is_reloading: bool = false
var _is_slashing: bool = false
var _fire_reset_timer: float = 0.0

# Valores procedurales suavizados
var _sway_offset: Vector2 = Vector2.ZERO
var _sway_rotation: float = 0.0
var _recoil_offset: Vector2 = Vector2.ZERO
var _recoil_rotation: float = 0.0
var _step_cycle: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_load_hd_textures()
	
	if knife_anchor != null:
		knife_anchor.visible = false
	
	# Buscar al jugador
	_player = get_tree().get_first_node_in_group("player") as Player3D
	if _player != null:
		_bind_player(_player)
	else:
		# Intento diferido si el player aún no entra en grupo
		get_tree().node_added.connect(_on_node_added)

	_apply_frame("idle")


func _load_hd_textures() -> void:
	textures_idle = [
		load("res://assets/generated/viewmodel_pistol_idle_hd.png"),
		load("res://assets/generated/viewmodel_smg_idle_hd.png"),
		load("res://assets/generated/viewmodel_shotgun_idle_hd.png")
	]
	textures_fire = [
		load("res://assets/generated/viewmodel_pistol_fire_hd.png"),
		load("res://assets/generated/viewmodel_smg_fire_hd.png"),
		load("res://assets/generated/viewmodel_shotgun_fire_hd.png")
	]
	textures_reload = [
		load("res://assets/generated/viewmodel_pistol_reload_hd.png"),
		load("res://assets/generated/viewmodel_smg_reload_hd.png"),
		load("res://assets/generated/viewmodel_shotgun_reload_hd.png")
	]
	texture_knife = load("res://assets/generated/viewmodel_knife_slash_hd.png")
	if knife_rect != null and texture_knife != null:
		knife_rect.texture = texture_knife


func _on_node_added(node: Node) -> void:
	if node is Player3D and _player == null:
		_player = node as Player3D
		_bind_player(_player)


func _bind_player(p: Player3D) -> void:
	if p.has_signal("weapon_switched") and not p.weapon_switched.is_connected(_on_weapon_switched):
		p.weapon_switched.connect(_on_weapon_switched)
	if p.has_signal("weapon_fired") and not p.weapon_fired.is_connected(_on_weapon_fired):
		p.weapon_fired.connect(_on_weapon_fired)
	if p.has_signal("weapon_reloaded") and not p.weapon_reloaded.is_connected(_on_weapon_reloaded):
		p.weapon_reloaded.connect(_on_weapon_reloaded)
	if p.has_signal("melee_attacked") and not p.melee_attacked.is_connected(_on_melee_attacked):
		p.melee_attacked.connect(_on_melee_attacked)
	_current_slot = p.active_slot
	_apply_frame("idle")


func _process(delta: float) -> void:
	if _fire_reset_timer > 0.0:
		_fire_reset_timer -= delta
		if _fire_reset_timer <= 0.0 and not _is_reloading and not _is_slashing:
			_apply_frame("idle")

	# Suavizado de retroceso
	_recoil_offset = _recoil_offset.lerp(Vector2.ZERO, delta * 14.0)
	_recoil_rotation = lerpf(_recoil_rotation, 0.0, delta * 14.0)

	# Suavizado de sway de ratón
	_sway_offset = _sway_offset.lerp(Vector2.ZERO, delta * 8.0)
	_sway_rotation = lerpf(_sway_rotation, 0.0, delta * 8.0)

	# Bobbing procedural basado en el movimiento del jugador
	var bob_x: float = 0.0
	var bob_y: float = 0.0

	if _player != null and is_instance_valid(_player):
		var vel_h: Vector2 = Vector2(_player.velocity.x, _player.velocity.z)
		var is_moving: bool = vel_h.length_squared() > 0.1 and _player.is_on_floor()
		if is_moving:
			var speed_factor: float = 12.0 if Input.is_action_pressed("dodge") else 8.5
			_step_cycle += delta * speed_factor
			var amp_mult: float = 1.35 if Input.is_action_pressed("dodge") else 1.0
			bob_x = sin(_step_cycle * 0.5) * (bob_intensity * amp_mult)
			bob_y = cos(_step_cycle) * (bob_intensity * 0.65 * amp_mult)
		else:
			_step_cycle = 0.0

	# Aplicar posición y rotación procedural al ancla del arma
	if weapon_anchor != null:
		var target_pos: Vector2 = base_position + _sway_offset + _recoil_offset + Vector2(bob_x, bob_y)
		weapon_anchor.position = weapon_anchor.position.lerp(target_pos, delta * 20.0)
		weapon_anchor.rotation = lerpf(weapon_anchor.rotation, _sway_rotation + _recoil_rotation, delta * 18.0)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var mx: float = clampf(-event.relative.x * 0.15, -sway_intensity, sway_intensity)
		var my: float = clampf(-event.relative.y * 0.12, -sway_intensity * 0.8, sway_intensity * 0.8)
		_sway_offset = Vector2(mx, my)
		_sway_rotation = deg_to_rad(clampf(-event.relative.x * 0.08, -6.0, 6.0))


func _apply_frame(state: String) -> void:
	if weapon_rect == null or _current_slot >= textures_idle.size():
		return
	
	match state:
		"idle":
			weapon_rect.texture = textures_idle[_current_slot]
		"fire":
			weapon_rect.texture = textures_fire[_current_slot]
		"reload":
			weapon_rect.texture = textures_reload[_current_slot]


func _on_weapon_switched(slot: int, _wname: String) -> void:
	_current_slot = slot
	_is_reloading = false
	_fire_reset_timer = 0.0
	_apply_frame("idle")
	
	# Animación de desenfundado/subida
	if weapon_anchor != null:
		var tw: Tween = create_tween()
		weapon_anchor.position.y = base_position.y + 120.0
		tw.tween_property(weapon_anchor, "position:y", base_position.y, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_weapon_fired(slot: int) -> void:
	_current_slot = slot
	_apply_frame("fire")
	_fire_reset_timer = 0.09
	
	# Retroceso dinámico hacia atrás y arriba
	match slot:
		0: # Pistola
			_recoil_offset = Vector2(-8.0, 24.0)
			_recoil_rotation = deg_to_rad(-4.0)
		1: # SMG
			_recoil_offset = Vector2(-5.0, 16.0)
			_recoil_rotation = deg_to_rad(-2.5)
		2: # Escopeta
			_recoil_offset = Vector2(-15.0, 42.0)
			_recoil_rotation = deg_to_rad(-7.5)


func _on_weapon_reloaded(duration: float) -> void:
	if _is_reloading:
		return
	_is_reloading = true
	_apply_frame("reload")
	
	if weapon_anchor != null:
		var tw: Tween = create_tween()
		# Bajar arma
		tw.tween_property(weapon_anchor, "position:y", base_position.y + 160.0, duration * 0.35).set_trans(Tween.TRANS_QUAD)
		tw.tween_interval(duration * 0.35)
		# Subir arma
		tw.tween_callback(func(): _apply_frame("idle"))
		tw.tween_property(weapon_anchor, "position:y", base_position.y, duration * 0.30).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_callback(func(): _is_reloading = false)


func _on_melee_attacked() -> void:
	if _is_slashing:
		return
	_is_slashing = true
	
	# Ocultar temporalmente el arma de fuego
	if weapon_anchor != null:
		var tw_w: Tween = create_tween()
		tw_w.tween_property(weapon_anchor, "position:y", base_position.y + 180.0, 0.08)
	
	# Mostrar y animar corte de cuchillo
	if knife_anchor != null:
		knife_anchor.visible = true
		knife_anchor.position = Vector2(-460, -460)
		knife_anchor.rotation = deg_to_rad(-25.0)
		knife_anchor.scale = Vector2(0.85, 0.85)
		
		var tw_k: Tween = create_tween()
		# Trazado de corte diagonal violento
		tw_k.parallel().tween_property(knife_anchor, "position", Vector2(-540, -512), 0.12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw_k.parallel().tween_property(knife_anchor, "rotation", deg_to_rad(20.0), 0.12)
		tw_k.parallel().tween_property(knife_anchor, "scale", Vector2(1.15, 1.15), 0.12)
		tw_k.tween_interval(0.06)
		# Retracción y desaparición
		tw_k.parallel().tween_property(knife_anchor, "position:y", base_position.y + 150.0, 0.12).set_trans(Tween.TRANS_QUAD)
		tw_k.parallel().tween_property(knife_anchor, "modulate:a", 0.0, 0.12)
		
		tw_k.tween_callback(func():
			knife_anchor.visible = false
			knife_anchor.modulate.a = 1.0
			_is_slashing = false
			# Regresar arma de fuego
			if weapon_anchor != null:
				var tw_back: Tween = create_tween()
				tw_back.tween_property(weapon_anchor, "position:y", base_position.y, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		)
