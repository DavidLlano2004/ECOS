class_name Resultados
extends CanvasLayer
## Pantalla de resultados al terminar la evaluación final (capa 12): compara el "antes" y el "después" por
## bloque y por emoción. TEMPORAL: es una versión sencilla hasta que llegue la pantalla de resultados definitiva
## (prompt 5.3). Se muestra aunque el jugador no haya aceptado guardar sus respuestas (entonces no hay "antes").
##
## Uso:   await Resultados.mostrar(get_tree())

const ESCENA := "res://Scenes/UI/Resultados.tscn"

signal cerrada

var _raiz: Control


static func mostrar(arbol: SceneTree) -> void:
	var escena := (load(ESCENA) as PackedScene).instantiate() as Resultados
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
	_construir()
	create_tween().tween_property(_raiz, "modulate:a", 1.0, 0.5)


func _input(evento: InputEvent) -> void:
	for accion in ["PAUSA", "DIARIO", "HABILIDAD"]:
		if evento.is_action_pressed(accion):
			get_viewport().set_input_as_handled()
			return


func _construir() -> void:
	var c := Evaluacion.comparar()
	var panel := PanelContainer.new()
	panel.position = Vector2(150, 18)
	panel.size = Vector2(480, 324)
	panel.add_theme_stylebox_override("panel", EstiloUI.caja(Color("1e1b2e", 0.96), EstiloUI.DORADO, 2, 12, 5))
	_raiz.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 5)
	panel.add_child(v)
	v.add_child(EstiloUI.etiqueta("Tu viaje en números", 16, EstiloUI.DORADO))
	if not c["hay_pre"]:
		var aviso := EstiloUI.etiqueta("No tengo tus respuestas del principio (jugaste sin guardarlas), pero estas son las de ahora.", 10, EstiloUI.GRIS)
		aviso.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(aviso)
	var rejilla := GridContainer.new()
	rejilla.columns = 4
	rejilla.add_theme_constant_override("h_separation", 18)
	v.add_child(rejilla)
	for titulo in ["", "Antes", "Después", "Cambio"]:
		rejilla.add_child(EstiloUI.etiqueta(titulo, 11, EstiloUI.GRIS))
	var maximos := {"trivia": 7, "situaciones": 7, "total": 14, "escala": 10}
	var nombres := {"trivia": "Lo que sé (trivia)", "situaciones": "Cómo reacciono", "total": "Total", "escala": "Cómo me siento"}
	for clave in ["trivia", "situaciones", "total", "escala"]:
		var f: Dictionary = c["por_bloque"][clave]
		rejilla.add_child(EstiloUI.etiqueta(nombres[clave], 12, EstiloUI.CREMA))
		rejilla.add_child(EstiloUI.etiqueta("%d/%d" % [f["pre"], maximos[clave]] if c["hay_pre"] else "-", 12, EstiloUI.CREMA))
		rejilla.add_child(EstiloUI.etiqueta("%d/%d" % [f["post"], maximos[clave]], 12, EstiloUI.CREMA))
		rejilla.add_child(_cambio(int(f["dif"]), c["hay_pre"]))
	v.add_child(EstiloUI.etiqueta("Por emoción (de 0 a 2 puntos)", 11, EstiloUI.GRIS))
	var emociones := GridContainer.new()
	emociones.columns = 4
	emociones.add_theme_constant_override("h_separation", 18)
	emociones.add_theme_constant_override("v_separation", 0)
	v.add_child(emociones)
	for id in GameState.ids_emociones():
		var datos := GameState.obtener_datos(id)
		var e: Dictionary = c["por_emocion"][id]
		emociones.add_child(EstiloUI.etiqueta(datos.nombre, 11, datos.color.lightened(0.3)))
		emociones.add_child(EstiloUI.etiqueta(str(int(e["trivia_pre"]) + int(e["situacion_pre"])) if c["hay_pre"] else "-", 11, EstiloUI.CREMA))
		emociones.add_child(EstiloUI.etiqueta(str(int(e["trivia_post"]) + int(e["situacion_post"])), 11, EstiloUI.CREMA))
		emociones.add_child(_cambio(int(e["dif"]), c["hay_pre"]))
	var pie := "Duración del juego: %d min." % int(round(float(c["duracion_segundos"]) / 60.0)) if float(c["duracion_segundos"]) > 0.0 else ""
	if Evaluacion.consentimiento_guardar:
		pie += ("  " if pie != "" else "") + "Tu código anónimo: %s" % Evaluacion.participante_id
	if pie != "":
		v.add_child(EstiloUI.etiqueta(pie, 10, EstiloUI.GRIS))
	var boton := Button.new()
	boton.text = "Volver al título"
	boton.custom_minimum_size = Vector2(160, 28)
	boton.size_flags_horizontal = Control.SIZE_SHRINK_END
	boton.pressed.connect(_cerrar)
	v.add_child(boton)
	boton.grab_focus.call_deferred()


func _cambio(dif: int, hay_pre: bool) -> Label:
	if not hay_pre:
		return EstiloUI.etiqueta("-", 12, EstiloUI.GRIS)
	var texto := "%+d" % dif if dif != 0 else "igual"
	return EstiloUI.etiqueta(texto, 12, Color("8fd19e") if dif > 0 else (EstiloUI.GRIS if dif == 0 else Color("e0a070")))


func _cerrar() -> void:
	Sonido.efecto("ui_elegir")
	cerrada.emit()
	Evaluacion.cuestionario_activo = false
	var t := create_tween()
	t.tween_property(_raiz, "modulate:a", 0.0, 0.4)
	await t.finished
	queue_free()
