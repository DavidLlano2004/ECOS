extends Node
## Dueño del diario (TAB) y del menú de pausa (ESC). Decide cuándo se pueden abrir y pausa el juego
## mientras alguno está abierto (get_tree().paused).
##
## Reglas:
##  - Ninguno se abre durante un diálogo (ni el onboarding ni los cuestionarios), ni sin jugador en
##    escena (título, onboarding), ni durante una transición de época.
##  - ESC: la cancelación de conversaciones tiene prioridad (el balloon se la queda); si no hay
##    diálogo, abre la pausa. Con el diario abierto, ESC lo cierra; en la pausa, ESC retrocede o reanuda.

const ESCENA_DIARIO := preload("res://Scenes/UI/Diario.tscn")
const ESCENA_PAUSA := preload("res://Scenes/UI/Pausa.tscn")
const ESCENA_TITULO := "res://Scenes/UI/PantallaTitulo.tscn"

var diario: Diario
var pausa: MenuPausa

## true si el diario se abrió desde el menú de pausa (al cerrarlo se vuelve al menú).
var _diario_desde_pausa := false
## true mientras es este autoload quien mantiene el árbol en pausa.
var _pausando := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	diario = ESCENA_DIARIO.instantiate()
	add_child(diario)
	pausa = ESCENA_PAUSA.instantiate()
	add_child(pausa)
	pausa.reanudar_pedido.connect(cerrar_pausa)
	pausa.diario_pedido.connect(abrir_diario.bind(true))
	pausa.volver_al_titulo_pedido.connect(volver_al_titulo)


## true si hay un menú abierto (diario o pausa).
func hay_menu() -> bool:
	return diario.abierto or pausa.abierta


## ¿Se puede abrir un menú ahora? (jugador en escena, sin diálogo ni transición)
func puede_abrir() -> bool:
	if Dialogo.hay_dialogo() or not Dialogo.pausa_permitida():
		return false
	if Evaluacion.cuestionario_activo:
		return false   # la evaluación no se interrumpe con la pausa ni el diario
	if Habilidades.bloqueado_por("transicion"):
		return false
	return get_tree().get_first_node_in_group("player") != null


func _input(evento: InputEvent) -> void:
	if evento is InputEventKey and evento.echo:
		return
	if evento.is_action_pressed("DIARIO"):
		if diario.abierto:
			get_viewport().set_input_as_handled()
			cerrar_diario()
		elif not pausa.abierta and puede_abrir():
			get_viewport().set_input_as_handled()
			abrir_diario(false)
	elif evento.is_action_pressed("PAUSA"):
		if diario.abierto:
			get_viewport().set_input_as_handled()
			cerrar_diario()
		elif pausa.abierta:
			get_viewport().set_input_as_handled()
			if not pausa.atras():
				cerrar_pausa()
		elif puede_abrir():
			get_viewport().set_input_as_handled()
			abrir_pausa()


# --- Diario ---

func abrir_diario(desde_pausa: bool = false) -> void:
	if diario.abierto or (not desde_pausa and not puede_abrir()):
		return
	_diario_desde_pausa = desde_pausa and pausa.abierta
	if _diario_desde_pausa:
		pausa.ocultar_panel(true)
	diario.abrir()
	_actualizar_pausa()


func cerrar_diario() -> void:
	if not diario.abierto:
		return
	diario.cerrar()
	if _diario_desde_pausa and pausa.abierta:
		pausa.ocultar_panel(false)   # vuelve al menú de pausa
	_diario_desde_pausa = false
	_actualizar_pausa()


# --- Pausa ---

func abrir_pausa() -> void:
	if pausa.abierta or not puede_abrir():
		return
	pausa.abrir()
	_actualizar_pausa()


func cerrar_pausa() -> void:
	if diario.abierto:
		diario.cerrar()
	_diario_desde_pausa = false
	pausa.cerrar()
	_actualizar_pausa()


## Guarda y vuelve a la pantalla de título.
func volver_al_titulo() -> void:
	if Guardado.puede_guardar():
		Guardado.guardar_ahora()
	cerrar_pausa()
	get_tree().paused = false
	get_tree().change_scene_to_file(ESCENA_TITULO)


## El árbol está en pausa exactamente mientras haya un menú abierto.
func _actualizar_pausa() -> void:
	var debe := hay_menu()
	if debe:
		_pausando = true
		get_tree().paused = true
	elif _pausando:
		_pausando = false
		get_tree().paused = false


func _process(_delta: float) -> void:
	# Red de seguridad: si no hay ningún menú abierto, el juego nunca se queda congelado por nosotros
	if _pausando and not hay_menu():
		_pausando = false
		get_tree().paused = false
