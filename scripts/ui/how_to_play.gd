extends Control

## Pantalla "Cómo jugar": explica los controles y las reglas de supervivencia.

@export var title_label: Label
@export var back_button: Button
## Contenedor vertical donde se generan las filas de controles.
@export var controls_container: VBoxContainer
@export var rules_label: RichTextLabel

## Pares acción / tecla mostrados en pantalla.
const CONTROL_ROWS: Array[Array] = [
	["Mover", "W A S D  o  Flechas"],
	["Apuntar", "Ratón"],
	["Disparar", "Clic izquierdo"],
	["Navajazo / Cuchillo", "F"],
	["Cambiar Armas", "1, 2, 3  o  Rueda del ratón"],
	["Saltar (en 3D)", "Espacio"],
	["Esquivar / Sprint", "Clic derecho  o  Shift"],
	["Recargar", "R"],
	["Pausa", "Esc  o  P"],
]

const RULES_TEXT: String = (
	"[b]Objetivo[/b]\n"
	+ "Sobrevive a todas las oleadas de zombis de cada escenario.\n\n"
	+ "[b]Caminantes[/b]: lentos y numerosos. Fáciles de derribar.\n"
	+ "[b]Corredores[/b]: rápidos y frágiles. No dejes que te rodeen.\n"
	+ "[b]Brutos[/b]: enormes, lentos y muy resistentes. Hacen mucho daño.\n\n"
	+ "[b]Municipio limitado[/b]: los botiquines y las cajas de munición los "
	+ "sueltan los zombis al morir. Recógelos pasando por encima.\n\n"
	+ "[b]La esquiva te da invulnerabilidad[/b], no solo velocidad: "
	+ "cruza a través de un grupo para salir del cerco."
)


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_resolve_references()
	_build_controls()
	_fill_rules()


func _resolve_references() -> void:
	if title_label == null:
		title_label = get_node_or_null("Root/TitleLabel") as Label
	if back_button == null:
		back_button = get_node_or_null("Root/BackButton") as Button
	if controls_container == null:
		controls_container = get_node_or_null("Root/Panel/ControlsContainer") as VBoxContainer
	if rules_label == null:
		rules_label = get_node_or_null("Root/Panel/RulesLabel") as RichTextLabel

	if title_label != null:
		title_label.text = "CÓMO JUGAR"
	if back_button != null:
		back_button.text = "VOLVER"
		back_button.pressed.connect(_on_back_pressed)


## Genera una fila por cada control, con la acción y las teclas disponibles.
func _build_controls() -> void:
	if controls_container == null:
		return
	for row: Array in CONTROL_ROWS:
		var line: HBoxContainer = HBoxContainer.new()
		line.add_theme_constant_override("separation", 16)

		var action_label: Label = Label.new()
		action_label.text = str(row[0])
		action_label.custom_minimum_size = Vector2(300.0, 0.0)

		var key_label: Label = Label.new()
		key_label.text = str(row[1])
		key_label.add_theme_color_override("font_color", Color(0.98, 0.82, 0.45))

		line.add_child(action_label)
		line.add_child(key_label)
		controls_container.add_child(line)


func _fill_rules() -> void:
	if rules_label != null:
		rules_label.bbcode_enabled = true
		rules_label.text = RULES_TEXT


func _on_back_pressed() -> void:
	if has_node("/root/GameManager"):
		GameManager.go_to_main_menu()
	else:
		get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
