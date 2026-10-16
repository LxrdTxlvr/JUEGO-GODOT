extends Control

## Panel de opciones reutilizable. Se instancia tanto en la pantalla de opciones
## del menú principal como dentro del menú de pausa.
## Escribe los cambios directamente en el autoload GameSettings, que los
## persiste en disco.

## Emitida cuando el usuario pide cerrar el panel.
signal close_requested()

@export_group("Controls")
@export var volume_slider: HSlider
@export var volume_value_label: Label
@export var music_slider: HSlider
@export var music_value_label: Label
@export var sfx_slider: HSlider
@export var sfx_value_label: Label
@export var footstep_slider: HSlider
@export var footstep_value_label: Label
@export var fullscreen_check: CheckBox
@export var difficulty_button: OptionButton
@export var close_button: Button

## Si es falso, oculta el título y el botón internos: útil cuando el panel se
## incrusta en una pantalla que ya aporta los suyos (p. ej. options_menu).
@export var show_header: bool = true

@export_group("Labels")
@export var title_label: Label
@export var volume_label: Label
@export var music_label: Label
@export var sfx_label: Label
@export var footstep_label: Label
@export var fullscreen_label: Label
@export var difficulty_label: Label
@export var difficulty_hint: Label

var _is_initializing: bool = false


func _ready() -> void:
	_resolve_references()
	_setup_static_texts()
	_sync_from_settings()
	_connect_controls()


func _resolve_references() -> void:
	if volume_slider == null:
		volume_slider = get_node_or_null("Layout/VolumeRow/VolumeSlider") as HSlider
	if volume_value_label == null:
		volume_value_label = get_node_or_null("Layout/VolumeRow/VolumeValue") as Label
	if music_slider == null:
		music_slider = get_node_or_null("Layout/MusicRow/MusicSlider") as HSlider
	if music_value_label == null:
		music_value_label = get_node_or_null("Layout/MusicRow/MusicValue") as Label
	if sfx_slider == null:
		sfx_slider = get_node_or_null("Layout/SfxRow/SfxSlider") as HSlider
	if sfx_value_label == null:
		sfx_value_label = get_node_or_null("Layout/SfxRow/SfxValue") as Label
	if footstep_slider == null:
		footstep_slider = get_node_or_null("Layout/FootstepRow/FootstepSlider") as HSlider
	if footstep_value_label == null:
		footstep_value_label = get_node_or_null("Layout/FootstepRow/FootstepValue") as Label

	if fullscreen_check == null:
		fullscreen_check = get_node_or_null("Layout/FullscreenRow/FullscreenCheck") as CheckBox
	if difficulty_button == null:
		difficulty_button = get_node_or_null("Layout/DifficultyRow/DifficultyButton") as OptionButton
	if close_button == null:
		close_button = get_node_or_null("Layout/CloseButton") as Button
	if title_label == null:
		title_label = get_node_or_null("Layout/TitleLabel") as Label
	if volume_label == null:
		volume_label = get_node_or_null("Layout/VolumeRow/VolumeLabel") as Label
	if music_label == null:
		music_label = get_node_or_null("Layout/MusicRow/MusicLabel") as Label
	if sfx_label == null:
		sfx_label = get_node_or_null("Layout/SfxRow/SfxLabel") as Label
	if footstep_label == null:
		footstep_label = get_node_or_null("Layout/FootstepRow/FootstepLabel") as Label
	if fullscreen_label == null:
		fullscreen_label = get_node_or_null("Layout/FullscreenRow/FullscreenLabel") as Label
	if difficulty_label == null:
		difficulty_label = get_node_or_null("Layout/DifficultyRow/DifficultyLabel") as Label
	if difficulty_hint == null:
		difficulty_hint = get_node_or_null("Layout/DifficultyHint") as Label


func _setup_static_texts() -> void:
	if title_label != null:
		title_label.text = "OPCIONES"
		title_label.visible = show_header
	if volume_label != null:
		volume_label.text = "🔊 Volumen general"
	if music_label != null:
		music_label.text = "🎵 Música de fondo"
	if sfx_label != null:
		sfx_label.text = "💥 Efectos y armas"
	if footstep_label != null:
		footstep_label.text = "👟 Pasos del jugador"
	if fullscreen_label != null:
		fullscreen_label.text = "Pantalla completa"
	if difficulty_label != null:
		difficulty_label.text = "Dificultad"
	if close_button != null:
		close_button.text = "VOLVER"
		close_button.visible = show_header
	if difficulty_hint != null:
		difficulty_hint.text = (
			"La dificultad ajusta la cantidad de zombis, su velocidad y el daño que infligen."
		)


## Vuelca los valores actuales del autoload en los controles.
func _sync_from_settings() -> void:
	if not has_node("/root/GameSettings"):
		return
	_is_initializing = true

	if volume_slider != null:
		volume_slider.min_value = 0.0
		volume_slider.max_value = 100.0
		volume_slider.step = 1.0
		volume_slider.value = GameSettings.master_volume * 100.0
		_update_volume_label(volume_value_label, volume_slider.value)

	if music_slider != null:
		music_slider.min_value = 0.0
		music_slider.max_value = 100.0
		music_slider.step = 1.0
		music_slider.value = GameSettings.music_volume * 100.0
		_update_volume_label(music_value_label, music_slider.value)

	if sfx_slider != null:
		sfx_slider.min_value = 0.0
		sfx_slider.max_value = 100.0
		sfx_slider.step = 1.0
		sfx_slider.value = GameSettings.sfx_volume * 100.0
		_update_volume_label(sfx_value_label, sfx_slider.value)

	if footstep_slider != null:
		footstep_slider.min_value = 0.0
		footstep_slider.max_value = 100.0
		footstep_slider.step = 1.0
		footstep_slider.value = GameSettings.footstep_volume * 100.0
		_update_volume_label(footstep_value_label, footstep_slider.value)

	if fullscreen_check != null:
		fullscreen_check.button_pressed = GameSettings.fullscreen

	if difficulty_button != null:
		difficulty_button.clear()
		for difficulty_name: String in GameSettings.DIFFICULTY_NAMES:
			difficulty_button.add_item(difficulty_name)
		difficulty_button.selected = GameSettings.difficulty

	_is_initializing = false


func _connect_controls() -> void:
	if volume_slider != null:
		volume_slider.value_changed.connect(_on_volume_changed)
	if music_slider != null:
		music_slider.value_changed.connect(_on_music_changed)
	if sfx_slider != null:
		sfx_slider.value_changed.connect(_on_sfx_changed)
		sfx_slider.drag_ended.connect(_on_sfx_drag_ended)
	if footstep_slider != null:
		footstep_slider.value_changed.connect(_on_footstep_changed)
		footstep_slider.drag_ended.connect(_on_footstep_drag_ended)
	if fullscreen_check != null:
		fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	if difficulty_button != null:
		difficulty_button.item_selected.connect(_on_difficulty_selected)
	if close_button != null:
		close_button.pressed.connect(_on_close_pressed)


# ------------------------------------------------------------------------------
# Manejadores
# ------------------------------------------------------------------------------

func _on_volume_changed(value: float) -> void:
	_update_volume_label(volume_value_label, value)
	if _is_initializing or not has_node("/root/GameSettings"):
		return
	GameSettings.set_master_volume(value / 100.0)


func _on_music_changed(value: float) -> void:
	_update_volume_label(music_value_label, value)
	if _is_initializing or not has_node("/root/GameSettings"):
		return
	GameSettings.set_music_volume(value / 100.0)


func _on_sfx_changed(value: float) -> void:
	_update_volume_label(sfx_value_label, value)
	if _is_initializing or not has_node("/root/GameSettings"):
		return
	GameSettings.set_sfx_volume(value / 100.0)


func _on_sfx_drag_ended(value_changed: bool) -> void:
	if value_changed and has_node("/root/SoundManager"):
		SoundManager.play_ui_click()


func _on_footstep_changed(value: float) -> void:
	_update_volume_label(footstep_value_label, value)
	if _is_initializing or not has_node("/root/GameSettings"):
		return
	GameSettings.set_footstep_volume(value / 100.0)


func _on_footstep_drag_ended(value_changed: bool) -> void:
	if value_changed and has_node("/root/SoundManager"):
		SoundManager.play_player_step_walk()


func _update_volume_label(lbl: Label, value: float) -> void:
	if lbl != null:
		lbl.text = "%d%%" % roundi(value)


func _on_fullscreen_toggled(pressed: bool) -> void:
	if _is_initializing or not has_node("/root/GameSettings"):
		return
	GameSettings.set_fullscreen(pressed)


func _on_difficulty_selected(index: int) -> void:
	if _is_initializing or not has_node("/root/GameSettings"):
		return
	GameSettings.set_difficulty(index)


func _on_close_pressed() -> void:
	close_requested.emit()
