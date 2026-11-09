class_name GloboCierre
extends Node2D
## Globo pequeño con una frase breve sobre un personaje (por ejemplo, la despedida de una emoción
## cuando el jugador cancela la conversación). No es la caja de diálogo: aparece, se queda un par
## de segundos y se desvanece solo.

const RUTA_FUENTE := "res://Assets/PixelifySans-VariableFont_wght.ttf"
const SEGUNDOS_VISIBLE := 2.2


## Muestra `texto` sobre `padre` (a `altura` px de su origen, negativa = hacia arriba).
static func mostrar(padre: Node2D, texto: String, altura: float = -72.0) -> void:
	if texto == "" or not is_instance_valid(padre):
		return
	var viejo := padre.get_node_or_null("GloboCierre")
	if viejo != null:
		viejo.queue_free()
	var globo := GloboCierre.new()
	globo.name = "GloboCierre"
	globo.z_index = 50
	globo.z_as_relative = false
	globo.position = Vector2(0, altura)
	padre.add_child(globo)
	globo._construir(texto)


func _construir(texto: String) -> void:
	var panel := PanelContainer.new()
	var caja := StyleBoxFlat.new()
	caja.bg_color = Color("1e1b2e", 0.92)
	caja.border_color = Color("f4c77b")
	caja.set_border_width_all(1)
	caja.set_corner_radius_all(3)
	caja.content_margin_left = 5
	caja.content_margin_right = 5
	caja.content_margin_top = 2
	caja.content_margin_bottom = 2
	panel.add_theme_stylebox_override("panel", caja)
	var etiqueta := Label.new()
	etiqueta.text = texto
	if ResourceLoader.exists(RUTA_FUENTE):
		etiqueta.add_theme_font_override("font", load(RUTA_FUENTE))
	etiqueta.add_theme_font_size_override("font_size", 10)
	etiqueta.add_theme_color_override("font_color", Color("fff4dc"))
	panel.add_child(etiqueta)
	add_child(panel)
	# Centrado sobre el punto (el tamaño mínimo se conoce al instante)
	var tamano := panel.get_combined_minimum_size()
	panel.position = Vector2(-tamano.x / 2.0, -tamano.y)
	modulate.a = 0.0
	var t := create_tween()
	t.tween_property(self, "modulate:a", 1.0, 0.25)
	t.tween_interval(SEGUNDOS_VISIBLE)
	t.tween_property(self, "modulate:a", 0.0, 0.4)
	t.tween_callback(queue_free)
