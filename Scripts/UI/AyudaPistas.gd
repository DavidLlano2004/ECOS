class_name AyudaPistas
extends CanvasLayer
## Ayudas suaves para que nadie se atasque. Las crea Mundo (no hace falta tocar Mundo.tscn).
##
## 1) Aviso discreto: si el jugador pasa más de 25 s a menos de 80 px de una compuerta cerrada sin tener la
##    habilidad que la abre, sale una línea ("Quizás Culpa pueda ayudar con esto.") como mucho una vez cada
##    2 minutos. Se puede desactivar en Opciones (Opciones.avisos_pistas).
## 2) Brújula (tecla G, solo con el HUD visible): una flecha del color de la emoción apunta 4 s hacia el
##    sitio que sugirió la Guía con "¿Qué hago ahora?".

const SEGUNDOS_CERCA := 25.0
const DISTANCIA_AVISO := 80.0
const ENTRE_AVISOS := 120.0
const SEGUNDOS_AVISO := 5.0
const SEGUNDOS_BRUJULA := 4.0
const RADIO_BRUJULA := 74.0

var _cerca := 0.0                    # segundos seguidos cerca de una compuerta cerrada sin la habilidad
var _ultimo_aviso := -INF
var _etiqueta: Label
var _tween_aviso: Tween
var _brujula: Control
var _brujula_restante := 0.0
var _brujula_color := Color.WHITE
var _brujula_destino := Vector2.ZERO


func _ready() -> void:
	layer = 6
	_etiqueta = EstiloUI.etiqueta("", 12, EstiloUI.CREMA)
	_etiqueta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_etiqueta.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_etiqueta.anchor_left = 0.0
	_etiqueta.anchor_right = 1.0
	_etiqueta.offset_top = -70.0
	_etiqueta.offset_bottom = -50.0
	_etiqueta.modulate.a = 0.0
	_etiqueta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_etiqueta)
	_brujula = Control.new()
	_brujula.set_anchors_preset(Control.PRESET_FULL_RECT)
	_brujula.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_brujula.draw.connect(_dibujar_brujula)
	add_child(_brujula)


func _process(delta: float) -> void:
	_revisar_aviso(delta)
	if _brujula_restante > 0.0:
		_brujula_restante -= delta
		_brujula.queue_redraw()


# --- Aviso suave ---

func _revisar_aviso(delta: float) -> void:
	var jugador := get_tree().get_first_node_in_group("player") as Node2D
	var cercana := _compuerta_cercana(jugador)
	if cercana == null:
		_cerca = 0.0
		return
	_cerca += delta
	var ahora := Time.get_ticks_msec() / 1000.0
	if _cerca < SEGUNDOS_CERCA or ahora - _ultimo_aviso < ENTRE_AVISOS:
		return
	if not Opciones.avisos_pistas or not Habilidades.puede_operar():
		return
	_ultimo_aviso = ahora
	_mostrar_aviso(str(Progresion.compuerta(cercana.id).get("aviso", "")))


## La compuerta cerrada, visible y sin la habilidad que está a menos de 80 px (null si no hay).
func _compuerta_cercana(jugador: Node2D) -> Compuerta:
	if jugador == null:
		return null
	for nodo in get_tree().get_nodes_in_group("compuerta"):
		var c := nodo as Compuerta
		if c != null and not c.esta_abierta and c.is_visible_in_tree() and not GameState.tiene_habilidad(c.habilidad_requerida):
			if c.distancia_al_area(jugador.global_position) < DISTANCIA_AVISO:
				return c
	return null


func _mostrar_aviso(texto: String) -> void:
	if texto == "":
		return
	_etiqueta.text = texto
	Sonido.pista()
	if _tween_aviso != null:
		_tween_aviso.kill()
	_tween_aviso = create_tween()
	_tween_aviso.tween_property(_etiqueta, "modulate:a", 0.9, 0.6)
	_tween_aviso.tween_interval(SEGUNDOS_AVISO)
	_tween_aviso.tween_property(_etiqueta, "modulate:a", 0.0, 1.0)


# --- Brújula (G) ---

func _unhandled_input(evento: InputEvent) -> void:
	if evento.is_action_pressed("BRUJULA") and Habilidades.puede_operar():
		get_viewport().set_input_as_handled()
		_encender_brujula()


func _encender_brujula() -> void:
	# Sin haber pedido pista a la Guía no hay nada que señalar
	if GameState.paso_guia.is_empty():
		_mostrar_aviso("Pregúntale a la Guía «¿Qué hago ahora?» y la brújula te señalará el camino.")
		return
	var paso := Progresion.siguiente_paso()
	GameState.paso_guia = paso
	var destino := _destino_de(paso)
	if destino == Vector2.INF:
		return
	_brujula_destino = destino
	var emocion := GameState.obtener_datos(str(paso.get("emocion", "")))
	_brujula_color = emocion.color.lightened(0.25) if emocion != null else EstiloUI.DORADO
	_brujula_restante = SEGUNDOS_BRUJULA
	_brujula.queue_redraw()


## El punto del mundo al que apunta un paso: la compuerta, o el centro de la zona.
func _destino_de(paso: Dictionary) -> Vector2:
	if str(paso.get("compuerta", "")) != "":
		for nodo in get_tree().get_nodes_in_group("compuerta"):
			var c := nodo as Compuerta
			if c != null and c.id == paso["compuerta"] and c.is_visible_in_tree():
				return c.global_position
	var mundo := get_tree().get_first_node_in_group("mundo")
	if mundo != null and str(paso.get("zona", "")) != "":
		return mundo.posicion_zona(str(paso["zona"]))
	return Vector2.INF


func _dibujar_brujula() -> void:
	if _brujula_restante <= 0.0:
		return
	var jugador := get_tree().get_first_node_in_group("player") as Node2D
	if jugador == null:
		return
	var hacia := _brujula_destino - jugador.global_position
	if hacia.length() < 40.0:
		return   # ya estás ahí
	var direccion := hacia.normalized()
	var alpha := clampf(minf(_brujula_restante, SEGUNDOS_BRUJULA - _brujula_restante + 0.0) * 3.0, 0.0, 1.0)
	alpha = minf(alpha, 1.0) if _brujula_restante < SEGUNDOS_BRUJULA - 0.3 else 1.0
	var centro := _brujula.size / 2.0 + Vector2(0, -24)
	var palpitar := 1.0 + sin(Time.get_ticks_msec() / 1000.0 * 6.0) * 0.08
	var punta := centro + direccion * (RADIO_BRUJULA * palpitar)
	var lateral := direccion.orthogonal()
	var puntos := PackedVector2Array([punta + direccion * 10.0, punta - direccion * 8.0 + lateral * 8.0, punta - direccion * 3.0, punta - direccion * 8.0 - lateral * 8.0])
	_brujula.draw_colored_polygon(puntos, Color(_brujula_color, 0.9 * alpha))
	_brujula.draw_polyline(PackedVector2Array([puntos[0], puntos[1], puntos[2], puntos[3], puntos[0]]), Color(0.1, 0.08, 0.16, 0.8 * alpha), 1.5)
