extends Node

## Gestor global del juego (Autoload).
## Centraliza el estado de la partida, las transiciones de escena, la puntuación,
## las oleadas y la pausa. Ningún nodo de la escena necesita conocerse entre sí:
## todos se comunican a través de las señales de este singleton.

## Emitida cada vez que cambia el estado global de la partida.
signal state_changed(new_state: int)
## Emitida al variar la puntuación acumulada.
signal score_changed(new_score: int)
## Emitida al variar el número de bajas confirmadas.
signal kills_changed(total_kills: int)
## Emitida al comenzar o cambiar de oleada.
signal wave_changed(current_wave: int, total_waves: int)
## Emitida cuando la partida termina (muerte, victoria o salida).
signal run_finished(stats: Dictionary)

enum GameState { BOOT, MAIN_MENU, PLAYING, PAUSED, GAME_OVER }

const MAIN_MENU_SCENE: String = "res://scenes/ui/main_menu.tscn"
const GAME_OVER_SCENE: String = "res://scenes/ui/game_over.tscn"

## Escenarios disponibles en la Fase 1, en orden de progresión.
const LEVELS: Array[String] = [
	"res://scenes/world/level_01.tscn",
	"res://scenes/world/level_02.tscn",
	"res://scenes/world/level_03.tscn",
]

## Escenarios disponibles en 3D (estilo SULFUR)
const LEVELS_3D: Array[String] = [
	"res://scenes/3d/world/level_01_3d.tscn",
	"res://scenes/3d/world/level_02_3d.tscn",
	"res://scenes/3d/world/level_03_3d.tscn",
]

## Segundos de cámara lenta dramática antes de saltar a la pantalla de fin de partida.
const DEATH_SLOWMO_TIME_SCALE: float = 0.35
const DEATH_SLOWMO_DURATION: float = 1.8

var state: int = GameState.BOOT
var score: int = 0
var kills: int = 0
var wave: int = 0
var total_waves: int = 5
var current_level_index: int = 0
var survival_time: float = 0.0
## Indica si la partida actual se juega en modo oleadas infinitas.
var is_endless_mode: bool = false
## Indica si la partida actual se juega en modo 3D (SULFUR).
var is_3d_mode: bool = false
## Estadísticas de la última partida, consumidas por la pantalla de Game Over.
var last_stats: Dictionary = {}

var _is_run_active: bool = false
var _pause_was_pressed: bool = false


func _ready() -> void:
	# El gestor debe seguir respondiendo a la pausa aunque el árbol esté congelado.
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(delta: float) -> void:
	if state == GameState.PLAYING:
		survival_time += delta
	_check_pause_input()


## Pausa leída por sondeo, igual que el resto de acciones del juego.
## Al correr con PROCESS_MODE_ALWAYS sigue funcionando con el árbol congelado.
## Se detecta el flanco de subida sobre el estado de la acción (en lugar de
## is_action_just_pressed) para no depender del frame exacto del evento.
func _check_pause_input() -> void:
	var is_pressed: bool = Input.is_action_pressed("pause")
	if is_pressed and not _pause_was_pressed:
		if state == GameState.PLAYING:
			pause_game()
		elif state == GameState.PAUSED:
			resume_game()
	_pause_was_pressed = is_pressed


# ------------------------------------------------------------------------------
# Flujo de escenas
# ------------------------------------------------------------------------------

## Inicia una partida nueva en el escenario indicado (índice dentro de LEVELS).
func start_run(level_index: int = 0) -> void:
	score = 0
	kills = 0
	wave = 0
	survival_time = 0.0
	is_endless_mode = false
	is_3d_mode = false
	current_level_index = clampi(level_index, 0, LEVELS.size() - 1)
	_is_run_active = true
	_reset_time_scale()
	get_tree().paused = false
	score_changed.emit(score)
	kills_changed.emit(kills)
	_change_scene(LEVELS[current_level_index])
	_set_state(GameState.PLAYING)


## Inicia una partida en versión 3D (estilo SULFUR)
func start_run_3d(level_index: int = 0) -> void:
	score = 0
	kills = 0
	wave = 0
	survival_time = 0.0
	is_endless_mode = false
	is_3d_mode = true
	current_level_index = clampi(level_index, 0, LEVELS_3D.size() - 1)
	_is_run_active = true
	_reset_time_scale()
	get_tree().paused = false
	score_changed.emit(score)
	kills_changed.emit(kills)
	_change_scene(LEVELS_3D[current_level_index])
	_set_state(GameState.PLAYING)


## Inicia una partida especial en Modo Oleadas Infinitas sobre el escenario indicado.
func start_endless_run(level_index: int = 0) -> void:
	score = 0
	kills = 0
	wave = 0
	survival_time = 0.0
	is_endless_mode = true
	total_waves = 999
	current_level_index = clampi(level_index, 0, LEVELS.size() - 1)
	_is_run_active = true
	_reset_time_scale()
	get_tree().paused = false
	score_changed.emit(score)
	kills_changed.emit(kills)
	_change_scene(LEVELS[current_level_index])
	_set_state(GameState.PLAYING)


## Marca la partida como en curso cuando se arranca un escenario directamente
## (F6 sobre level_XX.tscn), sin pasar por el menú principal.
func begin_direct_play() -> void:
	_is_run_active = true
	_reset_time_scale()
	get_tree().paused = false
	_set_state(GameState.PLAYING)


## Registra la configuración de oleadas del escenario recién cargado.
func configure_level(level_waves: int) -> void:
	total_waves = maxi(1, level_waves)


## Avanza al siguiente escenario si existe; si no, cierra la partida como victoria.
func advance_to_next_level() -> bool:
	var active_levels: Array[String] = LEVELS_3D if is_3d_mode else LEVELS
	if current_level_index + 1 >= active_levels.size():
		return false
	current_level_index += 1
	_is_run_active = true
	_reset_time_scale()
	get_tree().paused = false
	_change_scene(active_levels[current_level_index])
	_set_state(GameState.PLAYING)
	return true


## Notifica que se ha completado un nivel o se ha vencido al jefe final.
func notify_level_won() -> void:
	var sm: Node = get_node_or_null("/root/SoundManager")
	if sm != null and sm.has_method("play_sound"):
		sm.play_sound("victory")
	# Si hay un nivel siguiente en la campaña, avanzar; de lo contrario, fin de partida con pantalla de victoria
	if not advance_to_next_level():
		finish_run(true)


func go_to_main_menu() -> void:
	_is_run_active = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_reset_time_scale()
	_change_scene(MAIN_MENU_SCENE)
	_set_state(GameState.MAIN_MENU)


func quit_game() -> void:
	get_tree().quit()


# ------------------------------------------------------------------------------
# Pausa
# ------------------------------------------------------------------------------

func pause_game() -> void:
	if state != GameState.PLAYING:
		return
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_set_state(GameState.PAUSED)


func resume_game() -> void:
	if state != GameState.PAUSED:
		return
	get_tree().paused = false
	if is_3d_mode:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_set_state(GameState.PLAYING)


func is_paused() -> bool:
	return state == GameState.PAUSED


# ------------------------------------------------------------------------------
# Progreso
# ------------------------------------------------------------------------------

func add_score(amount: int) -> void:
	if amount == 0:
		return
	score = maxi(0, score + amount)
	score_changed.emit(score)


func register_kill(score_value: int = 0) -> void:
	kills += 1
	kills_changed.emit(kills)
	add_score(score_value)


func notify_wave_started(new_wave: int) -> void:
	wave = new_wave
	wave_changed.emit(wave, total_waves)


## Multiplicador progresivo de daño de zombis en Modo Infinito (+5% por oleada).
func get_endless_damage_multiplier() -> float:
	if not is_endless_mode:
		return 1.0
	var current_w: int = maxi(1, wave)
	return 1.0 + float(current_w - 1) * 0.05


## Multiplicador progresivo de velocidad de zombis en Modo Infinito (+3.5% por oleada, máximo 2.0x).
func get_endless_speed_multiplier() -> float:
	if not is_endless_mode:
		return 1.0
	var current_w: int = maxi(1, wave)
	return minf(2.0, 1.0 + float(current_w - 1) * 0.035)


## Multiplicador progresivo de salud de zombis en Modo Infinito (+4% por oleada).
func get_endless_health_multiplier() -> float:
	if not is_endless_mode:
		return 1.0
	var current_w: int = maxi(1, wave)
	return 1.0 + float(current_w - 1) * 0.04


# ------------------------------------------------------------------------------
# Fin de partida
# ------------------------------------------------------------------------------

## Finaliza la partida actual. [param victory] distingue victoria de derrota.
func finish_run(victory: bool = false) -> void:
	if state == GameState.GAME_OVER:
		return
	_is_run_active = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	last_stats = {
		"victory": victory,
		"score": score,
		"kills": kills,
		"wave": wave,
		"total_waves": total_waves,
		"time": survival_time,
		"level_index": current_level_index,
		"level_number": current_level_index + 1,
		"is_endless": is_endless_mode,
		"is_3d": is_3d_mode,
	}
	_set_state(GameState.GAME_OVER)
	run_finished.emit(last_stats)

	# Breve cámara lenta para saborear (o lamentar) el desenlace.
	if not victory:
		Engine.time_scale = DEATH_SLOWMO_TIME_SCALE
	var timer: SceneTreeTimer = get_tree().create_timer(
		DEATH_SLOWMO_DURATION, true, false, true
	)
	await timer.timeout

	_reset_time_scale()
	_change_scene(GAME_OVER_SCENE)


# ------------------------------------------------------------------------------
# Utilidades internas
# ------------------------------------------------------------------------------

func _set_state(new_state: int) -> void:
	state = new_state
	state_changed.emit(state)


func _reset_time_scale() -> void:
	Engine.time_scale = 1.0


func _change_scene(path: String) -> void:
	if not ResourceLoader.exists(path):
		push_error("[GameManager] No se encontró la escena: %s" % path)
		return
	get_tree().change_scene_to_file.call_deferred(path)
