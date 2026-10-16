class_name Level3D
extends Node3D

## Nivel 3D prototipo estilo SULFUR.
## Gestiona el entorno cartoon 3D, iluminación, atmósfera de niebla,
## conexión del HUD con el spawner, menú de pausa, música de fondo
## y las transiciones a Game Over / Victoria.

@export var level_title: String = "Manzana Cero - 3D Edition"
@export var music_track: String = "level_1"

## Escena del menú de pausa compartida con el modo 2D.
const PAUSE_MENU_SCENE: String = "res://scenes/ui/pause_menu.tscn"

@onready var player: Player3D = $Player3D
@onready var spawner: ZombieSpawner3D = $ZombieSpawner3D
@onready var hud: HUD3D = $HUD3D


func _ready() -> void:
	# Si se lanza el nivel directamente (F6) sin pasar por GameManager
	if has_node("/root/GameManager"):
		if GameManager.state == GameManager.GameState.BOOT or \
		   GameManager.state == GameManager.GameState.MAIN_MENU:
			GameManager.is_3d_mode = true
			GameManager.begin_direct_play()
		else:
			GameManager.state = GameManager.GameState.PLAYING
	else:
		# Sin autoload: simplemente capturar ratón y jugar
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	# Música
	if has_node("/root/SoundManager") and not music_track.is_empty():
		SoundManager.play_music(music_track)

	# HUD ↔ Spawner
	if spawner != null and hud != null:
		spawner.wave_started.connect(hud.set_wave)
		spawner.all_waves_completed.connect(hud.show_victory_banner)
		hud.set_wave(spawner.current_wave)

	# Muerte del jugador
	if player != null:
		player.player_died.connect(_on_player_died)

	# Instanciar menú de pausa (lo gestiona el script pause_menu.gd con GameManager)
	_add_pause_menu()


func _add_pause_menu() -> void:
	if not ResourceLoader.exists(PAUSE_MENU_SCENE):
		return
	var pm_res: PackedScene = load(PAUSE_MENU_SCENE)
	if pm_res == null:
		return
	var pm: CanvasLayer = pm_res.instantiate()
	add_child(pm)


func _on_player_died() -> void:
	if has_node("/root/SoundManager"):
		SoundManager.play_sound("game_over")
	# Liberar el ratón
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# Notificar a GameManager → disparará slow-mo y cambiará a pantalla de resultado
	if has_node("/root/GameManager"):
		GameManager.finish_run(false)

