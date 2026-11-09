extends Node2D
## Arena de pruebas para ver las 7 emociones antes de tener el mapa.
## Se juega con F6 (escena actual). NO es la escena principal y NO lanza el onboarding.
##
## Teclas de depuración (solo en compilaciones de depuración):
##   F3 = mostrar u ocultar el panel de estado
##   F4 = reiniciar la partida (GameState.nueva_partida()) y recargar la escena

## Tamaño de la arena (los límites de la cámara y los muros usan este rectángulo).
const ARENA := Rect2(0, 0, 1600, 900)
const RUTA_FUENTE := "res://Assets/PixelifySans-VariableFont_wght.ttf"

@onready var jugador: Node2D = $Mundo/Player
@onready var capa_depuracion: CanvasLayer = $Depuracion
@onready var etiqueta: Label = %Estado

## Textura de luz circular suave, para los destellos.
var _textura_luz: GradientTexture2D


func _ready() -> void:
	jugador.establecer_limites(ARENA)
	_preparar_textura_luz()

	# Cada criatura avisa cuando es integrada: destello de luz y temblor de cámara
	for emocion in get_tree().get_nodes_in_group("emociones"):
		emocion.integrada.connect(_on_emocion_integrada.bind(emocion))
	GameState.emocion_resuelta.connect(func(_id: String, _resultado: String) -> void: _actualizar_panel())

	_aplicar_estilo_panel()
	capa_depuracion.visible = OS.is_debug_build()
	_actualizar_panel()


func _unhandled_input(evento: InputEvent) -> void:
	if not OS.is_debug_build():
		return
	if evento is InputEventKey and evento.pressed and not evento.echo:
		match evento.keycode:
			KEY_F3:
				capa_depuracion.visible = not capa_depuracion.visible
			KEY_F4:
				GameState.nueva_partida()
				get_tree().reload_current_scene()


# --- Panel de depuración ---

func _actualizar_panel() -> void:
	var lineas: Array[String] = ["PRUEBA DE EMOCIONES   [F3] panel   [F4] reiniciar", ""]
	var habilidades: Array[String] = []
	for id in GameState.ids_emociones():
		var datos := GameState.obtener_datos(id)
		lineas.append("%s: %s" % [datos.nombre, GameState.estado.get(id, "pendiente")])
		if GameState.tiene_habilidad(datos.habilidad_id):
			habilidades.append(datos.habilidad_nombre)
	lineas.append("")
	lineas.append("Habilidades: %s" % (", ".join(habilidades) if not habilidades.is_empty() else "ninguna"))
	lineas.append("Integradas: %d / %d   Final: %s" % [
		GameState.cantidad_integradas(), GameState.ids_emociones().size(), GameState.calcular_final()])
	etiqueta.text = "\n".join(lineas)


func _aplicar_estilo_panel() -> void:
	if ResourceLoader.exists(RUTA_FUENTE):
		etiqueta.add_theme_font_override("font", load(RUTA_FUENTE))
	etiqueta.add_theme_font_size_override("font_size", 12)
	etiqueta.add_theme_color_override("font_color", Color("fff4dc"))
	etiqueta.add_theme_color_override("font_outline_color", Color("1e1b2e"))
	etiqueta.add_theme_constant_override("outline_size", 4)


# --- Efectos al integrar una emoción ---

func _on_emocion_integrada(_id: String, emocion: Node2D) -> void:
	_destello(emocion.global_position + Vector2(0, -24), emocion.datos.color)
	_temblor_camara(3.0, 0.4)


func _preparar_textura_luz() -> void:
	var degradado := Gradient.new()
	degradado.set_color(0, Color.WHITE)
	degradado.set_color(1, Color(1, 1, 1, 0))
	_textura_luz = GradientTexture2D.new()
	_textura_luz.gradient = degradado
	_textura_luz.fill = GradientTexture2D.FILL_RADIAL
	_textura_luz.fill_from = Vector2(0.5, 0.5)
	_textura_luz.fill_to = Vector2(1.0, 0.5)
	_textura_luz.width = 256
	_textura_luz.height = 256


## Destello de luz del color de la emoción que se desvanece.
func _destello(posicion: Vector2, color: Color) -> void:
	var luz := PointLight2D.new()
	luz.texture = _textura_luz
	luz.texture_scale = 1.6
	luz.color = color
	luz.energy = 1.6
	luz.global_position = posicion
	add_child(luz)
	var t := create_tween()
	t.tween_property(luz, "energy", 0.0, 1.2).set_ease(Tween.EASE_OUT)
	t.tween_callback(luz.queue_free)


## Temblor corto de la cámara del jugador.
func _temblor_camara(fuerza: float, segundos: float) -> void:
	var camara: Camera2D = jugador.camara
	var t := create_tween()
	t.tween_method(func(restante: float) -> void:
		camara.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * fuerza * restante,
		1.0, 0.0, segundos)
	t.tween_callback(func() -> void: camara.offset = Vector2.ZERO)
