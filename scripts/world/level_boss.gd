class_name LevelBoss
extends Level

## Nivel del Escenario Final con el Boss Final (Titán Mutante).
## Controla la aparición del Jefe Final (2400 HP), su barra de vida en HUD,
## y la generación periódica de oleadas de 10 zombis cada 5 minutos.

@export_group("Boss Settings")
@export var boss_scene: PackedScene = preload("res://scenes/entities/enemies/zombie_boss.tscn")
@export var boss_spawn_marker: Marker2D
## Intervalo en segundos entre oleadas de refuerzos (reducido a 45 segundos por requerimiento)
@export var wave_interval_seconds: float = 45.0
@export var zombies_per_wave: int = 10

@export_group("Minion Scenes")
@export var walker_scene: PackedScene = preload("res://scenes/entities/enemies/zombie_walker.tscn")
@export var runner_scene: PackedScene = preload("res://scenes/entities/enemies/zombie_runner.tscn")
@export var brute_scene: PackedScene = preload("res://scenes/entities/enemies/zombie_brute.tscn")

const WEAPON_DROP_SCENE: PackedScene = preload("res://scenes/entities/pickups/pickup_weapon.tscn")

var _active_boss: ZombieBoss = null
var _wave_timer: float = 0.0
var _reinforcement_waves_count: int = 0
var _boss_active: bool = false
var _wave_warned: bool = false
var _minions_since_weapon_drop: int = 0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	super._ready()
	# La primera oleada se activa a los 5 segundos (justo tras el rugido inicial del jefe)
	_wave_timer = 5.0
	_wave_warned = false
	call_deferred("_spawn_final_boss")


func _connect_spawner() -> void:
	# LevelBoss gestiona el flujo del combate directamente sin el spawner de oleadas estándar.
	pass


func _configure_game() -> void:
	if not has_node("/root/GameManager"):
		return
	GameManager.configure_level(1)
	if GameManager.state != GameManager.GameState.PLAYING:
		GameManager.begin_direct_play()


func _show_intro() -> void:
	if hud != null and hud.has_method("set_level_info"):
		hud.call("set_level_info", level_name, 1)
	if hud != null and hud.has_method("show_level_intro"):
		hud.call("show_level_intro", level_name, level_tagline)


func _process(delta: float) -> void:
	if not _boss_active or _active_boss == null or not is_instance_valid(_active_boss):
		return

	_wave_timer -= delta

	# Advertir al jugador 2 segundos antes de la llegada de la oleada
	if _wave_timer <= 2.0 and not _wave_warned:
		_wave_warned = true
		if hud != null and hud.has_method("show_message"):
			hud.call("show_message", "¡PELIGRO! Horda aproximándose")
		_pulse_alarm_ambient()

	if _wave_timer <= 0.0:
		_wave_timer = wave_interval_seconds
		_wave_warned = false
		_spawn_reinforcement_wave()


func _spawn_final_boss() -> void:
	if boss_scene == null:
		push_error("[LevelBoss] No se ha asignado la escena del jefe final.")
		return

	var boss: ZombieBoss = boss_scene.instantiate() as ZombieBoss
	if boss == null:
		return

	var container: Node = get_node_or_null("Entities")
	if container == null:
		container = self
	container.add_child(boss)

	if boss_spawn_marker != null:
		boss.global_position = boss_spawn_marker.global_position
	elif player != null:
		boss.global_position = player.global_position + Vector2(0, -400)
	else:
		boss.global_position = Vector2(960, 500)

	_active_boss = boss
	_boss_active = true

	# Conectar barra de vida y eventos
	if hud != null:
		if hud.has_method("show_boss_bar") and boss.health_component != null:
			hud.call("show_boss_bar", boss.display_name, boss.health_component.current_health, boss.health_component.max_health, boss)
			if not boss.health_component.health_changed.is_connected(Callable(hud, "update_boss_health")):
				boss.health_component.health_changed.connect(Callable(hud, "update_boss_health"))

	boss.died.connect(_on_boss_died)


## Genera una oleada de 10 zombis aleatorios cada 45 segundos (y a los 6s al inicio)
func _spawn_reinforcement_wave() -> void:
	_reinforcement_waves_count += 1
	if hud != null:
		if hud.has_method("show_wave_banner"):
			hud.call("show_wave_banner", "¡¡OLEADA DE REFUERZOS #%d!!" % _reinforcement_waves_count)
		if "wave_label" in hud and hud.wave_label != null:
			hud.wave_label.text = "OLEADA %d" % _reinforcement_waves_count

	var container: Node = get_node_or_null("Entities")
	if container == null:
		container = self

	var minion_scenes: Array[PackedScene] = [walker_scene, runner_scene, brute_scene]

	for i in range(zombies_per_wave):
		var picked_scene: PackedScene = minion_scenes[_rng.randi_range(0, minion_scenes.size() - 1)]
		if picked_scene == null:
			continue
		var minion: Zombie = picked_scene.instantiate() as Zombie
		if minion == null:
			continue
		container.add_child(minion)

		# Posicionar alrededor del jugador o centro del mapa asegurando que esté dentro de la arena
		var angle: float = _rng.randf_range(0, TAU)
		var dist: float = _rng.randf_range(300.0, 550.0)
		var base_pos: Vector2 = player.global_position if (player != null and is_instance_valid(player)) else Vector2(960, 640)
		var spawn_pos: Vector2 = base_pos + Vector2(cos(angle), sin(angle)) * dist
		
		# Limitar estrictamente dentro de los límites de la arena jugable
		var min_x: float = 120.0
		var max_x: float = 1800.0
		var min_y: float = 120.0
		var max_y: float = 1160.0
		if camera_bounds != Rect2():
			min_x = camera_bounds.position.x + 120.0
			max_x = camera_bounds.end.x - 120.0
			min_y = camera_bounds.position.y + 120.0
			max_y = camera_bounds.end.y - 120.0

		spawn_pos.x = clampf(spawn_pos.x, min_x, max_x)
		spawn_pos.y = clampf(spawn_pos.y, min_y, max_y)

		minion.global_position = spawn_pos
		minion.died.connect(_on_minion_died)


func _on_minion_died(minion: Zombie, score_val: int) -> void:
	if has_node("/root/GameManager"):
		GameManager.register_kill(score_val)

	# Si el jugador todavía no tiene las 3 armas desbloqueadas, garantizar loot de arma
	if player != null and is_instance_valid(player) and "unlocked_weapons" in player:
		var has_locked_weapons: bool = false
		for unlocked in player.unlocked_weapons:
			if not unlocked:
				has_locked_weapons = true
				break
		if has_locked_weapons:
			_minions_since_weapon_drop += 1
			# Cada 2 zombis de refuerzo muertos garantizamos un drop de arma si no hay varios en el suelo
			if _minions_since_weapon_drop >= 2:
				_minions_since_weapon_drop = 0
				call_deferred("_spawn_weapon_at", minion.global_position)


func _spawn_weapon_at(pos: Vector2) -> void:
	var weapon_pickup: Node2D = WEAPON_DROP_SCENE.instantiate() as Node2D
	if weapon_pickup == null:
		return
	var container: Node = get_node_or_null("Entities")
	if container == null:
		container = self
	container.add_child(weapon_pickup)
	weapon_pickup.global_position = pos


func _pulse_alarm_ambient() -> void:
	var cm: CanvasModulate = get_node_or_null("CanvasModulate") as CanvasModulate
	if cm != null:
		var normal_col: Color = Color(0.82, 0.85, 0.92, 1.0)
		var alert_col: Color = Color(0.95, 0.55, 0.55, 1.0)
		var tween: Tween = create_tween()
		tween.tween_property(cm, "color", alert_col, 0.3)
		tween.tween_property(cm, "color", normal_col, 0.8)


func _on_boss_died(_boss: Zombie, score_val: int) -> void:
	_boss_active = false
	if has_node("/root/GameManager"):
		GameManager.register_kill(score_val)

	if hud != null and hud.has_method("hide_boss_bar"):
		hud.call("hide_boss_bar", 1.5)

	if hud != null and hud.has_method("show_wave_banner"):
		hud.call("show_wave_banner", "¡¡¡EL TITÁN FINAL HA SIDO DESTRUIDO!!!")

	# Espera dramática antes de la pantalla de victoria
	await get_tree().create_timer(3.0, false, false, true).timeout
	if not is_inside_tree():
		return

	level_completed.emit()
	get_tree().call_group("pickups", "queue_free")
	if has_node("/root/GameManager"):
		GameManager.finish_run(true)
