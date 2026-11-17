extends Node
## Guardado de la partida. Autoguarda cada vez que cambia el estado de una emoción, se recoge un
## fragmento de memoria o se viaja de época, y muestra un pequeño ícono de "guardado" 1.5 s abajo a
## la derecha. "Guardar partida" del menú de pausa lo hace a demanda (guardar_ahora()).
##
## Solo autoguarda dentro del mundo (Mundo.tscn): las arenas de prueba y el título no tocan la partida.
## Guarda también dónde está el jugador, para que "Continuar" lo deje en el mismo sitio.

const SEGUNDOS_ICONO := 1.5
const RUTA_FUENTE := "res://Assets/PixelifySans-VariableFont_wght.ttf"

var _capa: CanvasLayer
var _icono: Control
var _tween: Tween
var _pendiente := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_crear_icono()
	GameState.emocion_resuelta.connect(func(_id: String, _resultado: String) -> void: _pedir_autoguardado())
	GameState.fragmento_recogido.connect(func(_id: String) -> void: _pedir_autoguardado())
	GameState.cofre_abierto.connect(func(_id: String) -> void: _pedir_autoguardado())
	GameState.compuerta_abierta.connect(func(_id: String) -> void: _pedir_autoguardado())
	GameState.epoca_cambiada.connect(func(_epoca: String) -> void: _pedir_autoguardado())


## true si ahora se puede guardar: dentro del mundo (Mundo.tscn) y con jugador. En las arenas de prueba y
## en el título no se guarda, para no pisar la partida real con datos de prueba.
func puede_guardar() -> bool:
	return get_tree().current_scene is Mundo and get_tree().get_first_node_in_group("player") != null


func _pedir_autoguardado() -> void:
	if not puede_guardar() or _pendiente:
		return
	_pendiente = true   # varios cambios en el mismo fotograma se guardan una sola vez
	_autoguardar.call_deferred()


func _autoguardar() -> void:
	_pendiente = false
	if puede_guardar():
		guardar_ahora()


## Guarda ya (autoguardado o botón "Guardar partida"). Devuelve true si se pudo guardar.
func guardar_ahora() -> bool:
	var jugador := get_tree().get_first_node_in_group("player") as Node2D
	if jugador != null:
		GameState.posicion_jugador = jugador.global_position
		GameState.tiene_posicion = true
	var bien := GameState.guardar()
	if bien:
		_mostrar_icono()
	else:
		Notificacion.mostrar("No se pudo guardar", "Revisa que haya espacio en el disco e inténtalo otra vez.")
	return bien


# --- Ícono de "guardado" ---

func _crear_icono() -> void:
	_capa = CanvasLayer.new()
	_capa.layer = 11   # sobre la pausa (9) y los diálogos (10)
	_capa.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_capa)
	_icono = Control.new()
	_icono.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icono.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_icono.offset_left = -78.0
	_icono.offset_top = -26.0
	_icono.offset_right = -8.0
	_icono.offset_bottom = -8.0
	_icono.modulate.a = 0.0
	_icono.draw.connect(_dibujar_icono)
	_capa.add_child(_icono)


## Un disquete dorado y la palabra "Guardado".
func _dibujar_icono() -> void:
	var dorado := Color("f4c77b")
	var oscuro := Color("1e1b2e")
	_icono.draw_rect(Rect2(0, 0, 70, 18), Color(oscuro, 0.9))
	_icono.draw_rect(Rect2(0, 0, 70, 18), dorado, false, 1.0)
	# disquete
	_icono.draw_rect(Rect2(4, 3, 12, 12), dorado)
	_icono.draw_rect(Rect2(6, 3, 8, 4), oscuro)
	_icono.draw_rect(Rect2(7, 9, 6, 6), oscuro)
	if ResourceLoader.exists(RUTA_FUENTE):
		_icono.draw_string(load(RUTA_FUENTE), Vector2(20, 13), "Guardado", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("fff4dc"))


func _mostrar_icono() -> void:
	Sonido.efecto("guardar")
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	# 0.2 s entra, 1.0 s se queda, 0.3 s sale: 1.5 s en total
	_tween.tween_property(_icono, "modulate:a", 1.0, 0.2)
	_tween.tween_interval(1.0)
	_tween.tween_property(_icono, "modulate:a", 0.0, 0.3)
