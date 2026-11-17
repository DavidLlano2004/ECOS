extends Node
## Reportar un problema: la tecla F8 (en cualquier escena, también en la versión exportada) abre un cuadro
## pequeño sobre el juego (el juego queda en pausa) con un campo de texto de hasta 400 caracteres. Al enviar se
## guarda en user://reportes/ un archivo por reporte, reporte_<fecha>_<id>.json, y una captura del juego en PNG
## con el mismo nombre. No se guarda el nombre ni nada personal. El reporte se guarda SIEMPRE (es local, solo
## para el jugador, aunque no haya aceptado guardar sus respuestas): se le dice dónde está por si quiere compartirlo.
##
## Cada reporte lleva: el texto, la escena actual, la época, la posición del jugador, las habilidades y los
## estados de las emociones, la versión del juego, la duración de la sesión y las últimas 30 líneas del registro
## del juego (si existe).
##
## TECLA: F8 es un atajo del editor de Godot (detiene o pasa por el depurador). Al ejecutar desde el editor
## (compilaciones de depuración) funciona también la tecla Y, que no choca con nada.

const CARPETA := "user://reportes"
const RUTA_REGISTRO := "user://logs/godot.log"
const MAXIMO := 400
const LINEAS_REGISTRO := 30
const ALFABETO := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"

var abierto := false

var _capa: CanvasLayer
var _campo: TextEdit
var _contador: Label
var _captura: Image
var _estaba_en_pausa := false
## Último reporte guardado (rutas), para las pruebas.
var ultimo_reporte := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _input(evento: InputEvent) -> void:
	if not (evento is InputEventKey) or not evento.pressed or evento.echo:
		return
	if abierto:
		if evento.keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			cerrar(false)
		elif evento.keycode in [KEY_ENTER, KEY_KP_ENTER] and evento.ctrl_pressed:
			get_viewport().set_input_as_handled()
			enviar()
		return
	var foco := get_viewport().gui_get_focus_owner()
	var escribiendo := foco is TextEdit or foco is LineEdit
	if evento.keycode == KEY_F8 or (evento.keycode == KEY_Y and OS.is_debug_build() and not escribiendo):
		get_viewport().set_input_as_handled()
		abrir()


## Abre el cuadro de reporte (con una captura del juego tomada justo antes).
func abrir() -> void:
	if abierto or Menus.hay_menu():
		return
	_captura = get_viewport().get_texture().get_image()
	abierto = true
	_estaba_en_pausa = get_tree().paused
	get_tree().paused = true
	_construir()


func _construir() -> void:
	_capa = CanvasLayer.new()
	_capa.layer = 40
	add_child(_capa)
	var raiz := Control.new()
	raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	raiz.theme = EstiloUI.tema()
	_capa.add_child(raiz)
	var velo := ColorRect.new()
	velo.color = Color(0.04, 0.03, 0.08, 0.6)
	velo.set_anchors_preset(Control.PRESET_FULL_RECT)
	raiz.add_child(velo)
	var panel := PanelContainer.new()
	panel.position = Vector2(130, 70)
	panel.size = Vector2(380, 220)
	panel.add_theme_stylebox_override("panel", EstiloUI.caja(Color("1e1b2e", 0.97), EstiloUI.DORADO, 2, 12, 5))
	raiz.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	panel.add_child(v)
	v.add_child(EstiloUI.etiqueta("Reportar un problema", 15, EstiloUI.DORADO))
	v.add_child(EstiloUI.etiqueta("No se guarda tu nombre ni nada personal.", 11, EstiloUI.GRIS))
	var pregunta := EstiloUI.etiqueta("¿Qué pasó? Cuéntanos lo que viste.", 12, EstiloUI.CREMA)
	v.add_child(pregunta)
	_campo = TextEdit.new()
	_campo.custom_minimum_size = Vector2(350, 84)
	_campo.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_campo.add_theme_font_size_override("font_size", 11)
	_campo.text_changed.connect(_al_cambiar_texto)
	v.add_child(_campo)
	_contador = EstiloUI.etiqueta("0 / %d" % MAXIMO, 10, EstiloUI.GRIS)
	_contador.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.add_child(_contador)
	var fila := HBoxContainer.new()
	fila.alignment = BoxContainer.ALIGNMENT_END
	fila.add_theme_constant_override("separation", 8)
	var cancelar := Button.new()
	cancelar.text = "Cancelar"
	cancelar.custom_minimum_size = Vector2(100, 28)
	cancelar.pressed.connect(func() -> void: cerrar(false))
	var mandar := Button.new()
	mandar.text = "Enviar"
	mandar.custom_minimum_size = Vector2(100, 28)
	mandar.pressed.connect(enviar)
	fila.add_child(cancelar)
	fila.add_child(mandar)
	v.add_child(fila)
	_campo.grab_focus.call_deferred()


func _al_cambiar_texto() -> void:
	if _campo.text.length() > MAXIMO:
		_campo.text = _campo.text.substr(0, MAXIMO)
		_campo.set_caret_column(MAXIMO)
	_contador.text = "%d / %d" % [_campo.text.length(), MAXIMO]


## Guarda el reporte (JSON + captura) y cierra el cuadro con un aviso.
func enviar() -> void:
	if not abierto:
		return
	var texto := _campo.text.strip_edges() if _campo != null else ""
	var ruta := guardar(texto, _captura)
	cerrar(true)
	if ruta != "":
		var detalle := ""
		if OS.has_feature("web"):
			detalle = "Se descargó en tu navegador. Si quieres, compártelo."
		elif not Evaluacion.consentimiento_guardar:
			detalle = "Está en tu computador: %s. Si quieres, compártelo." % ProjectSettings.globalize_path(CARPETA)
		Notificacion.mostrar("Gracias, quedó guardado", detalle)


func cerrar(_enviado: bool) -> void:
	if not abierto:
		return
	abierto = false
	if _capa != null:
		_capa.queue_free()
		_capa = null
	_campo = null
	get_tree().paused = _estaba_en_pausa


## Escribe el reporte en user://reportes/ y devuelve la ruta del JSON ("" si falló). Se puede llamar sin pantalla.
func guardar(texto: String, captura: Image = null) -> String:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CARPETA))
	var id := _codigo()
	var fecha := Time.get_datetime_string_from_system(false)
	var nombre := "reporte_%s_%s" % [fecha.replace(":", "-"), id]
	var jugador := get_tree().get_first_node_in_group("player") as Node2D
	var escena := get_tree().current_scene
	var emociones := {}
	for e in GameState.ids_emociones():
		emociones[e] = GameState.estado.get(e, "pendiente")
	var datos := {
		"id": id,
		"fecha_iso": fecha,
		"texto": texto.substr(0, MAXIMO),
		"escena": escena.scene_file_path if escena != null else "",
		"epoca": GameState.epoca,
		"posicion_jugador": [snappedf(jugador.global_position.x, 0.1), snappedf(jugador.global_position.y, 0.1)] if jugador != null else null,
		"habilidades": GameState.habilidades,
		"estado_emociones": emociones,
		"version_juego": str(ProjectSettings.get_setting("application/config/version", "0")),
		"duracion_sesion_min": snappedf(Time.get_ticks_msec() / 60000.0, 0.1),
		"registro": _ultimas_lineas_del_registro(),
		"captura": "",
	}
	if captura != null:
		var ruta_png := "%s/%s.png" % [CARPETA, nombre]
		if captura.save_png(ruta_png) == OK:
			datos["captura"] = nombre + ".png"
	var ruta_json := "%s/%s.json" % [CARPETA, nombre]
	var archivo := FileAccess.open(ruta_json, FileAccess.WRITE)
	if archivo == null:
		push_warning("Reportes: no se pudo guardar el reporte (error %d)." % FileAccess.get_open_error())
		return ""
	archivo.store_string(JSON.stringify(datos, "  "))
	archivo.close()
	ultimo_reporte = ruta_json
	# En la web no hay carpeta a la vista: el reporte y su captura se descargan en el navegador
	if OS.has_feature("web"):
		Exportacion.descargar(ruta_json, "%s.json" % nombre, "application/json;charset=utf-8")
		if datos["captura"] != "":
			Exportacion.descargar("%s/%s" % [CARPETA, datos["captura"]], datos["captura"], "image/png")
	return ruta_json


func _ultimas_lineas_del_registro() -> Array:
	if not FileAccess.file_exists(RUTA_REGISTRO):
		return []
	var lineas := FileAccess.get_file_as_string(RUTA_REGISTRO).split("\n")
	var desde := maxi(0, lineas.size() - LINEAS_REGISTRO - 1)
	var resultado: Array = []
	for i in range(desde, lineas.size()):
		if lineas[i].strip_edges() != "":
			resultado.append(lineas[i])
	return resultado


func _codigo() -> String:
	var azar := RandomNumberGenerator.new()
	azar.randomize()
	var c := ""
	for i in 6:
		c += ALFABETO[azar.randi() % ALFABETO.length()]
	return c
