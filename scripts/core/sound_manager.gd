extends Node

## Gestor global de efectos de sonido y música (Autoload: SoundManager).
## Administra pools de reproducción global, espacial 2D, reproductor dedicado de pasos,
## reproductor de ráfaga para ametralladora (con corte instantáneo al soltar)
## y reproductor con fundido cruzado para bandas sonoras.

const SOUNDS = {
	# Armas
	"shoot_pistol": preload("res://NEW SNDS/SONIDO ARMA CORTA PISTOLA.mp3"),
	"shoot_smg": preload("res://NEW SNDS/SONIDO ARMA AMETRALLADORA.mp3"),
	"knife_slash": preload("res://assets/audio/sfx_knife_slash.wav"),
	"wall_impact": preload("res://assets/audio/sfx_wall_impact.wav"),
	"flesh_impact": preload("res://assets/audio/sfx_flesh_impact.wav"),
	
	# Jugador y pasos
	"player_hurt": preload("res://assets/audio/sfx_player_hurt.wav"),
	"player_death": preload("res://assets/audio/sfx_player_death.wav"),
	"footstep_walk_1": preload("res://assets/audio/sfx_footstep_walk_1.wav"),
	"footstep_walk_2": preload("res://assets/audio/sfx_footstep_walk_2.wav"),
	"footstep_walk_3": preload("res://assets/audio/sfx_footstep_walk_3.wav"),
	"footstep_walk_4": preload("res://assets/audio/sfx_footstep_walk_4.wav"),
	"footstep_run_1": preload("res://assets/audio/sfx_footstep_run_1.wav"),
	"footstep_run_2": preload("res://assets/audio/sfx_footstep_run_2.wav"),
	"footstep_run_3": preload("res://assets/audio/sfx_footstep_run_3.wav"),
	"footstep_run_4": preload("res://assets/audio/sfx_footstep_run_4.wav"),

	# Zombis y jefes
	"zombie_attack": preload("res://NEW SNDS/ATAQUE ZOMBIES (TODOS).mp3"),
	"zombie_walker": preload("res://NEW SNDS/CAMINANTE SOUND.mp3"),
	"zombie_runner": preload("res://NEW SNDS/CORREDOR SOUND.mp3"),
	"zombie_brute": preload("res://NEW SNDS/DRUTOS SOUND.mp3"),
	"zombie_miniboss": preload("res://NEW SNDS/MINIBOSS SOUND.mp3"),
	"boss_roar": preload("res://NEW SNDS/FINAL BOSS SOUND.mp3"),
	"boss_slam": preload("res://assets/audio/sfx_boss_slam.wav"),
	"zombie_death": preload("res://assets/audio/sfx_zombie_death.wav"),
	"zombie_groan_1": preload("res://assets/audio/sfx_zombie_groan_1.wav"),
	"zombie_groan_2": preload("res://assets/audio/sfx_zombie_groan_2.wav"),

	# Recompensas y alertas
	"pickup_ammo": preload("res://assets/audio/sfx_pickup_ammo.wav"),
	"pickup_health": preload("res://assets/audio/sfx_pickup_health.wav"),
	"pickup_weapon": preload("res://assets/audio/sfx_pickup_weapon.wav"),
	"wave_alert": preload("res://NEW SNDS/SONIDO DE HORDA.mp3"),

	# Interfaz y desenlace
	"ui_click": preload("res://assets/audio/sfx_ui_click.wav"),
	"ui_hover": preload("res://assets/audio/sfx_ui_hover.wav"),
	"victory": preload("res://NEW SNDS/VICTORIA DE NIVEL.mp3"),
	"game_over": preload("res://NEW SNDS/PERDIDA DE NIVEL.mp3"),
}

const MUSIC_TRACKS = {
	"menu": preload("res://NEW SNDS/MENU DE INICIO.mp3"),
	"level_1": preload("res://NEW SNDS/SONIDO DE NIVEL 1.mp3"),
	"level_2": preload("res://NEW SNDS/SONIDO DE NIVEL 2.mp3"),
	"level_final": preload("res://NEW SNDS/SONIDO DE NIVEL FINAL.mp3"),
	"endless": preload("res://NEW SNDS/SONIDO MODO INFINITO.mp3"),
}

const GLOBAL_POOL_SIZE: int = 12
const POOL_2D_SIZE: int = 16

var _global_players: Array[AudioStreamPlayer] = []
var _2d_players: Array[AudioStreamPlayer2D] = []
var _footstep_player: AudioStreamPlayer = null
var _music_player: AudioStreamPlayer = null
var _smg_player: AudioStreamPlayer = null
var _smg_active_timeout: float = 0.0

var _current_music_key: String = ""
var _current_target_music_db: float = -8.0
var _music_tween: Tween = null

var _global_idx: int = 0
var _2d_idx: int = 0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()
	_setup_audio_pools()
	_setup_dedicated_players()


func _process(delta: float) -> void:
	if _smg_active_timeout > 0.0:
		_smg_active_timeout -= delta
		if _smg_active_timeout <= 0.0:
			stop_machine_gun()


func _setup_audio_pools() -> void:
	for i in range(GLOBAL_POOL_SIZE):
		var p: AudioStreamPlayer = AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_global_players.append(p)

	for i in range(POOL_2D_SIZE):
		var p2d: AudioStreamPlayer2D = AudioStreamPlayer2D.new()
		p2d.bus = "Master"
		p2d.max_distance = 1800.0
		p2d.attenuation = 1.2
		add_child(p2d)
		_2d_players.append(p2d)


func _setup_dedicated_players() -> void:
	# Reproductor dedicado para pasos del jugador
	_footstep_player = AudioStreamPlayer.new()
	_footstep_player.bus = "Master"
	add_child(_footstep_player)

	# Reproductor dedicado para música de fondo
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = "Master"
	_music_player.finished.connect(_on_music_finished)
	add_child(_music_player)

	# Reproductor dedicado para la ametralladora (evita repeticiones acumuladas y permite corte instantáneo)
	_smg_player = AudioStreamPlayer.new()
	_smg_player.bus = "Master"
	add_child(_smg_player)


# ------------------------------------------------------------------------------
# Cálculo de Volúmenes por Canal (Sincronizado con GameSettings)
# ------------------------------------------------------------------------------

func _calc_sfx_volume(base_db: float) -> float:
	var sfx_vol: float = 0.85
	if has_node("/root/GameSettings"):
		sfx_vol = GameSettings.sfx_volume
	if sfx_vol <= 0.001:
		return -80.0
	return base_db + linear_to_db(sfx_vol)


func _calc_music_volume(base_db: float) -> float:
	var m_vol: float = 0.8
	if has_node("/root/GameSettings"):
		m_vol = GameSettings.music_volume
	if m_vol <= 0.001:
		return -80.0
	return base_db + linear_to_db(m_vol)


func _calc_footstep_volume(base_db: float) -> float:
	var f_vol: float = 0.8
	if has_node("/root/GameSettings"):
		f_vol = GameSettings.footstep_volume
	if f_vol <= 0.001:
		return -80.0
	return base_db + linear_to_db(f_vol)


## Actualiza en tiempo real los volúmenes de los reproductores continuos
func update_volume_levels() -> void:
	if _music_player != null and _music_player.playing:
		_music_player.volume_db = _calc_music_volume(_current_target_music_db)
	if _smg_player != null and _smg_player.playing:
		_smg_player.volume_db = _calc_sfx_volume(-2.0)


# ------------------------------------------------------------------------------
# Sistema de Música y Bandas Sonoras
# ------------------------------------------------------------------------------

func play_music(track_key: String, fade_duration: float = 1.0, target_volume_db: float = -8.0) -> void:
	if not MUSIC_TRACKS.has(track_key):
		push_warning("[SoundManager] No se encontró la pista musical: %s" % track_key)
		return
	_current_target_music_db = target_volume_db
	var final_db: float = _calc_music_volume(target_volume_db)

	if _current_music_key == track_key and _music_player.playing:
		_music_player.volume_db = final_db
		return

	_current_music_key = track_key
	var stream: AudioStream = MUSIC_TRACKS[track_key]
	if stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true

	if _music_tween != null and _music_tween.is_valid():
		_music_tween.kill()

	if _music_player.playing and fade_duration > 0.05:
		_music_tween = create_tween()
		_music_tween.tween_property(_music_player, "volume_db", -45.0, fade_duration * 0.5)
		_music_tween.tween_callback(func() -> void:
			_music_player.stream = stream
			_music_player.play()
		)
		_music_tween.tween_property(_music_player, "volume_db", final_db, fade_duration * 0.5)
	else:
		_music_player.stream = stream
		_music_player.volume_db = final_db
		_music_player.play()


func stop_music(fade_duration: float = 0.8) -> void:
	_current_music_key = ""
	if not _music_player.playing:
		return
	if _music_tween != null and _music_tween.is_valid():
		_music_tween.kill()

	if fade_duration > 0.05:
		_music_tween = create_tween()
		_music_tween.tween_property(_music_player, "volume_db", -45.0, fade_duration)
		_music_tween.tween_callback(func() -> void:
			_music_player.stop()
		)
	else:
		_music_player.stop()


func _on_music_finished() -> void:
	if _current_music_key != "" and MUSIC_TRACKS.has(_current_music_key):
		_music_player.play()


# ------------------------------------------------------------------------------
# Reproducción de SFX Global y 2D
# ------------------------------------------------------------------------------

func play_sound(sound_key: String, volume_db: float = 0.0, pitch_var: float = 0.05) -> void:
	if not SOUNDS.has(sound_key):
		return
	var final_db: float = _calc_sfx_volume(volume_db)
	if final_db <= -79.0:
		return

	var stream: AudioStream = SOUNDS[sound_key]
	var player: AudioStreamPlayer = _global_players[_global_idx]
	_global_idx = (_global_idx + 1) % GLOBAL_POOL_SIZE

	player.stop()
	player.stream = stream
	player.volume_db = final_db
	player.pitch_scale = 1.0 + _rng.randf_range(-pitch_var, pitch_var)
	player.play()


func play_sound_2d(sound_key: String, pos: Vector2, volume_db: float = 0.0, pitch_var: float = 0.08) -> void:
	if not SOUNDS.has(sound_key):
		return
	var final_db: float = _calc_sfx_volume(volume_db)
	if final_db <= -79.0:
		return

	var stream: AudioStream = SOUNDS[sound_key]
	var player: AudioStreamPlayer2D = _2d_players[_2d_idx]
	_2d_idx = (_2d_idx + 1) % POOL_2D_SIZE

	player.stop()
	player.global_position = pos
	player.stream = stream
	player.volume_db = final_db
	player.pitch_scale = 1.0 + _rng.randf_range(-pitch_var, pitch_var)
	player.play()


# ------------------------------------------------------------------------------
# Control Específico de Ametralladora (Corte Inmediato al Dejar de Disparar)
# ------------------------------------------------------------------------------

## Reproduce o mantiene la ráfaga continua de ametralladora sin duplicar instancias
func play_machine_gun() -> void:
	_smg_active_timeout = 0.16
	if _smg_player == null:
		return
	var final_db: float = _calc_sfx_volume(-2.0)
	if final_db <= -79.0:
		if _smg_player.playing:
			_smg_player.stop()
		return

	_smg_player.volume_db = final_db
	if not _smg_player.playing:
		_smg_player.stream = SOUNDS["shoot_smg"]
		_smg_player.pitch_scale = 1.0 + _rng.randf_range(-0.03, 0.03)
		_smg_player.play()


## Detiene de forma inmediata el sonido de ametralladora
func stop_machine_gun() -> void:
	_smg_active_timeout = 0.0
	if _smg_player != null and _smg_player.playing:
		_smg_player.stop()


## Llamada genérica para detener disparos si corresponde al arma indicada
func stop_shoot(weapon_name: String = "") -> void:
	var w_lower: String = weapon_name.to_lower()
	if weapon_name == "" or "smg" in w_lower or "subfusil" in w_lower or "ametralladora" in w_lower:
		stop_machine_gun()


# ------------------------------------------------------------------------------
# API Específica de Sonidos
# ------------------------------------------------------------------------------

## Pasos normales de caminata del sobreviviente
func play_player_step_walk() -> void:
	var step_keys: Array[String] = ["footstep_walk_1", "footstep_walk_2", "footstep_walk_3", "footstep_walk_4"]
	var selected_key: String = step_keys[_rng.randi_range(0, step_keys.size() - 1)]
	if _footstep_player != null and SOUNDS.has(selected_key):
		var final_db: float = _calc_footstep_volume(-6.5)
		if final_db <= -79.0:
			return
		_footstep_player.stream = SOUNDS[selected_key]
		_footstep_player.volume_db = final_db
		_footstep_player.pitch_scale = 1.0 + _rng.randf_range(-0.06, 0.06)
		_footstep_player.play()


## Pasos acelerados al correr o esquivar del sobreviviente
func play_player_step_run() -> void:
	var step_keys: Array[String] = ["footstep_run_1", "footstep_run_2", "footstep_run_3", "footstep_run_4"]
	var selected_key: String = step_keys[_rng.randi_range(0, step_keys.size() - 1)]
	if _footstep_player != null and SOUNDS.has(selected_key):
		var final_db: float = _calc_footstep_volume(-4.0)
		if final_db <= -79.0:
			return
		_footstep_player.stream = SOUNDS[selected_key]
		_footstep_player.volume_db = final_db
		_footstep_player.pitch_scale = 1.0 + _rng.randf_range(-0.06, 0.06)
		_footstep_player.play()


func play_shoot(weapon_name: String) -> void:
	var w_lower: String = weapon_name.to_lower()
	if "smg" in w_lower or "subfusil" in w_lower or "ametralladora" in w_lower:
		play_machine_gun()
		return
	
	var key: String = "shoot_pistol"
	var vol: float = 0.0
	if "cuchillo" in w_lower or "knife" in w_lower:
		key = "knife_slash"
		vol = 1.0
	play_sound(key, vol, 0.08)


func play_wall_impact(pos: Vector2) -> void:
	play_sound_2d("wall_impact", pos, -1.0, 0.12)


func play_flesh_impact(pos: Vector2) -> void:
	play_sound_2d("flesh_impact", pos, 1.5, 0.1)


func play_player_hurt() -> void:
	play_sound("player_hurt", 2.0, 0.06)


func play_player_death() -> void:
	stop_machine_gun()
	stop_music(0.4)
	play_sound("player_death", 3.0, 0.0)


func play_zombie_groan(pos: Vector2, enemy_type: String = "") -> void:
	var key: String = "zombie_walker"
	var t: String = enemy_type.to_lower()
	if "corredor" in t or "runner" in t:
		key = "zombie_runner"
	elif "bruto" in t or "druto" in t or "brute" in t:
		key = "zombie_brute"
	elif "miniboss" in t or "mutante" in t:
		key = "zombie_miniboss"
	elif "boss" in t or "titán" in t or "titan" in t:
		key = "boss_roar"
	elif "caminante" in t or "walker" in t:
		key = "zombie_walker"
	else:
		var r: float = _rng.randf()
		if r < 0.4:
			key = "zombie_walker"
		elif r < 0.7:
			key = "zombie_groan_1"
		else:
			key = "zombie_groan_2"
	
	play_sound_2d(key, pos, -2.0, 0.10)


func play_zombie_attack(pos: Vector2) -> void:
	play_sound_2d("zombie_attack", pos, 1.5, 0.08)


func play_zombie_death(pos: Vector2) -> void:
	play_sound_2d("zombie_death", pos, 1.0, 0.12)


func play_boss_roar(pos: Vector2) -> void:
	play_sound_2d("boss_roar", pos, 5.0, 0.05)


func play_boss_slam(pos: Vector2) -> void:
	play_sound_2d("boss_slam", pos, 4.0, 0.08)


func play_pickup(pickup_type: String) -> void:
	var key: String = "pickup_ammo"
	var t_lower: String = pickup_type.to_lower()
	if "salud" in t_lower or "vida" in t_lower or "health" in t_lower or "botiquin" in t_lower:
		key = "pickup_health"
	elif "arma" in t_lower or "weapon" in t_lower or "smg" in t_lower:
		key = "pickup_weapon"
	play_sound(key, 1.5, 0.05)


func play_wave_alert() -> void:
	play_sound("wave_alert", 2.0, 0.0)


func play_ui_click() -> void:
	play_sound("ui_click", 0.0, 0.04)


func play_ui_hover() -> void:
	play_sound("ui_hover", -4.0, 0.05)


func play_victory() -> void:
	stop_machine_gun()
	stop_music(0.4)
	play_sound("victory", 3.0, 0.0)


func play_defeat() -> void:
	stop_machine_gun()
	stop_music(0.4)
	play_sound("game_over", 3.0, 0.0)
