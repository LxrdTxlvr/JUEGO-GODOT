extends Node

## Ajustes persistentes del usuario (Autoload).
## Guarda y restaura volumen, pantalla completa y dificultad en user://settings.cfg
## para que las opciones sobrevivan entre sesiones.

signal settings_applied()

const SETTINGS_PATH: String = "user://settings.cfg"
const CONFIG_SECTION: String = "settings"

enum Difficulty { FACIL, NORMAL, DIFICIL }

const DIFFICULTY_NAMES: Array[String] = ["Fácil", "Normal", "Difícil"]
const DIFFICULTY_MULTIPLIERS: Array[float] = [0.7, 1.0, 1.55]
const DIFFICULTY_SPEED_MULTIPLIERS: Array[float] = [0.85, 1.0, 1.35]

var master_volume: float = 0.8
var music_volume: float = 0.8
var sfx_volume: float = 0.85
var footstep_volume: float = 0.8

var fullscreen: bool = false
var difficulty: int = Difficulty.NORMAL
## Multiplicador global de daño enemigo derivado de la dificultad.
var enemy_damage_multiplier: float = 1.0
## Multiplicador global de velocidad enemiga derivado de la dificultad.
var enemy_speed_multiplier: float = 1.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_settings()
	apply_all()


## Carga los ajustes desde disco; si no existe el archivo, mantiene los valores por defecto.
func load_settings() -> void:
	var config: ConfigFile = ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return
	master_volume = clampf(
		float(config.get_value(CONFIG_SECTION, "master_volume", master_volume)), 0.0, 1.0
	)
	music_volume = clampf(
		float(config.get_value(CONFIG_SECTION, "music_volume", music_volume)), 0.0, 1.0
	)
	sfx_volume = clampf(
		float(config.get_value(CONFIG_SECTION, "sfx_volume", sfx_volume)), 0.0, 1.0
	)
	footstep_volume = clampf(
		float(config.get_value(CONFIG_SECTION, "footstep_volume", footstep_volume)), 0.0, 1.0
	)
	fullscreen = bool(config.get_value(CONFIG_SECTION, "fullscreen", fullscreen))
	difficulty = clampi(
		int(config.get_value(CONFIG_SECTION, "difficulty", difficulty)),
		Difficulty.FACIL,
		Difficulty.DIFICIL
	)


## Escribe los ajustes actuales en disco.
func save_settings() -> void:
	var config: ConfigFile = ConfigFile.new()
	config.set_value(CONFIG_SECTION, "master_volume", master_volume)
	config.set_value(CONFIG_SECTION, "music_volume", music_volume)
	config.set_value(CONFIG_SECTION, "sfx_volume", sfx_volume)
	config.set_value(CONFIG_SECTION, "footstep_volume", footstep_volume)
	config.set_value(CONFIG_SECTION, "fullscreen", fullscreen)
	config.set_value(CONFIG_SECTION, "difficulty", difficulty)
	var error: int = config.save(SETTINGS_PATH)
	if error != OK:
		push_warning("[GameSettings] No se pudieron guardar los ajustes (código %d)." % error)


## Aplica todos los ajustes al motor.
func apply_all() -> void:
	apply_volume()
	apply_fullscreen()
	apply_difficulty()
	settings_applied.emit()


func apply_volume() -> void:
	var bus_index: int = AudioServer.get_bus_index("Master")
	if bus_index >= 0:
		if master_volume <= 0.001:
			AudioServer.set_bus_mute(bus_index, true)
		else:
			AudioServer.set_bus_mute(bus_index, false)
			AudioServer.set_bus_volume_db(bus_index, linear_to_db(master_volume))
	
	if has_node("/root/SoundManager"):
		var sm = get_node("/root/SoundManager")
		if sm.has_method("update_volume_levels"):
			sm.call("update_volume_levels")


func apply_fullscreen() -> void:
	var mode: int = (
		DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN if fullscreen
		else DisplayServer.WINDOW_MODE_WINDOWED
	)
	DisplayServer.window_set_mode(mode)


func apply_difficulty() -> void:
	var index: int = clampi(difficulty, Difficulty.FACIL, Difficulty.DIFICIL)
	enemy_damage_multiplier = DIFFICULTY_MULTIPLIERS[index]
	enemy_speed_multiplier = DIFFICULTY_SPEED_MULTIPLIERS[index]


## Multiplicador de cantidad de enemigos por oleada según la dificultad.
func get_difficulty_multiplier() -> float:
	return DIFFICULTY_MULTIPLIERS[clampi(
		difficulty, Difficulty.FACIL, Difficulty.DIFICIL
	)]


## Multiplicador de velocidad de los zombis según la dificultad.
func get_difficulty_speed_multiplier() -> float:
	return DIFFICULTY_SPEED_MULTIPLIERS[clampi(
		difficulty, Difficulty.FACIL, Difficulty.DIFICIL
	)]


func get_difficulty_name() -> String:
	return DIFFICULTY_NAMES[clampi(difficulty, Difficulty.FACIL, Difficulty.DIFICIL)]


func set_master_volume(value: float) -> void:
	master_volume = clampf(value, 0.0, 1.0)
	apply_volume()
	save_settings()


func set_volume(value: float) -> void:
	set_master_volume(value)


func set_music_volume(value: float) -> void:
	music_volume = clampf(value, 0.0, 1.0)
	apply_volume()
	save_settings()


func set_sfx_volume(value: float) -> void:
	sfx_volume = clampf(value, 0.0, 1.0)
	apply_volume()
	save_settings()


func set_footstep_volume(value: float) -> void:
	footstep_volume = clampf(value, 0.0, 1.0)
	apply_volume()
	save_settings()


func set_fullscreen(enabled: bool) -> void:
	fullscreen = enabled
	apply_fullscreen()
	save_settings()


func set_difficulty(value: int) -> void:
	difficulty = clampi(value, Difficulty.FACIL, Difficulty.DIFICIL)
	apply_difficulty()
	save_settings()
	settings_applied.emit()
