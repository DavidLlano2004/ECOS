class_name Consentimiento
extends CanvasLayer
## Pantalla de consentimiento, antes del primer cuestionario (capa 12). Con "Acepto y continúo" las respuestas
## se guardan de forma anónima en este computador (Evaluacion.consentimiento_guardar = true); con "Jugar sin
## guardar mis respuestas" las preguntas se hacen igual y se muestra el resultado, pero no se escribe nada en
## archivos. No se puede cancelar: hay que elegir una de las dos.
##
## Uso:   await Consentimiento.mostrar(get_tree())

const ESCENA := "res://Scenes/UI/Consentimiento.tscn"
const TEXTO := "ECOS es un juego educativo sobre emociones. Antes y después de jugar te haremos algunas preguntas para saber qué aprendiste. Tus respuestas se guardan de forma anónima en este computador y solo se usan para evaluar el juego. No es un test psicológico ni da diagnósticos. Puedes dejar de jugar cuando quieras."

signal decidido(acepta: bool)

var _raiz: Control
var _decidido := false


static func mostrar(arbol: SceneTree) -> void:
	var escena := (load(ESCENA) as PackedScene).instantiate() as Consentimiento
	arbol.root.add_child.call_deferred(escena)   # (diferido: la raíz puede estar ocupada montando la escena)
	await escena.tree_exited


func _ready() -> void:
	layer = 12
	process_mode = Node.PROCESS_MODE_ALWAYS
	Evaluacion.cuestionario_activo = true
	FondoEvaluacion.crear(self)
	_raiz = Control.new()
	_raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	_raiz.theme = EstiloUI.tema()
	_raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.modulate.a = 0.0
	add_child(_raiz)

	var panel := PanelContainer.new()
	panel.position = Vector2(168, 52)
	panel.size = Vector2(452, 256)
	panel.add_theme_stylebox_override("panel", EstiloUI.caja(Color("1e1b2e", 0.96), EstiloUI.DORADO, 2, 16, 5))
	_raiz.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)
	v.add_child(EstiloUI.etiqueta("Antes de empezar", 16, EstiloUI.DORADO))
	var texto := EstiloUI.etiqueta(TEXTO, 12, EstiloUI.CREMA)
	texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	texto.custom_minimum_size = Vector2(410, 110)
	v.add_child(texto)
	var acepto := _boton("Acepto y continúo", true)
	var sin_guardar := _boton("Jugar sin guardar mis respuestas", false)
	v.add_child(acepto)
	v.add_child(sin_guardar)
	create_tween().tween_property(_raiz, "modulate:a", 1.0, 0.5)
	Sonido.efecto("dialogo_abrir")
	await get_tree().process_frame
	acepto.grab_focus()


# ESC, TAB y la habilidad no hacen nada aquí
func _input(evento: InputEvent) -> void:
	for accion in ["PAUSA", "DIARIO", "HABILIDAD", "ui_cancel"]:
		if evento.is_action_pressed(accion):
			get_viewport().set_input_as_handled()
			return


func _boton(texto: String, acepta: bool) -> Button:
	var b := Button.new()
	b.text = texto
	b.custom_minimum_size = Vector2(410, 32)
	b.pressed.connect(_decidir.bind(acepta))
	b.focus_entered.connect(func() -> void: Sonido.efecto("ui_mover"))
	return b


func _decidir(acepta: bool) -> void:
	if _decidido:
		return
	_decidido = true
	Sonido.efecto("ui_elegir")
	Evaluacion.consentimiento_dado = true
	Evaluacion.consentimiento_guardar = acepta
	decidido.emit(acepta)
	var t := create_tween()
	t.tween_property(_raiz, "modulate:a", 0.0, 0.4)
	await t.finished
	Evaluacion.cuestionario_activo = false
	queue_free()
