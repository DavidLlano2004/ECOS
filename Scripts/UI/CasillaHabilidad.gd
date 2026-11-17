class_name CasillaHabilidad
extends Control
## Una casilla de 40x40 del HUD. Se dibuja por código:
## - bloqueada: silueta gris con candado
## - desbloqueada: ícono a color (hoja de íconos si existe; si no, círculo con la inicial)
## - seleccionada: borde dorado y un leve rebote
## - en espera: relleno radial oscuro que se vacía
## También brilla al desbloquearse y tiembla si se intenta usar bloqueada.

const TAMANO := Vector2(40, 40)
const RUTA_FUENTE := "res://Assets/PixelifySans-VariableFont_wght.ttf"
## Hoja opcional: cuadros de 32x32, 4 columnas x 2 filas (impulso, vision, calma, vinculo,
## reparacion, pausa, revelar, candado).
const RUTA_ICONOS := "res://Assets/UI/iconos_habilidades.png"
const ORDEN_ICONOS := ["impulso", "vision", "calma", "vinculo", "reparacion", "pausa", "revelar", "candado"]
const COLOR_FONDO := Color("1e1b2e", 0.95)
const COLOR_BORDE := Color("4a4170")
const COLOR_DORADO := Color("f4c77b")

var habilidad_id: String = ""
var nombre: String = ""
var color: Color = Color.WHITE
var desbloqueada := false:
	set(valor):
		desbloqueada = valor
		queue_redraw()
## Nivel de la habilidad (2 = mejorada por el cofre de memoria): se marca con una estrella pequeña.
var nivel := 1:
	set(valor):
		nivel = valor
		queue_redraw()
var seleccionada := false:
	set(valor):
		if valor == seleccionada:
			return
		seleccionada = valor
		if valor and is_inside_tree():
			_rebotar()
		queue_redraw()
## true mientras la habilidad tiene un efecto en marcha (Visión encendida, Pausa, compañero): el borde late.
var activa := false:
	set(valor):
		if valor == activa:
			return
		activa = valor
		queue_redraw()
## 0 a 1: cuánto falta de la espera (1 = acaba de usarse, 0 = lista).
var espera := 0.0:
	set(valor):
		espera = valor
		queue_redraw()
## Brillo al desbloquear (0 a 1) y desplazamiento horizontal del temblor, en píxeles.
var brillo := 0.0:
	set(valor):
		brillo = valor
		queue_redraw()
var temblor := 0.0:
	set(valor):
		temblor = valor
		queue_redraw()

var _fuente: Font
var _iconos: Texture2D


func _ready() -> void:
	custom_minimum_size = TAMANO
	size = TAMANO
	pivot_offset = TAMANO / 2.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST  # pixel art: sin suavizado
	if ResourceLoader.exists(RUTA_FUENTE):
		_fuente = load(RUTA_FUENTE)
	if ResourceLoader.exists(RUTA_ICONOS):
		_iconos = load(RUTA_ICONOS)


## Brilla una vez (se llama al desbloquear la habilidad).
func brillar() -> void:
	var t := create_tween()
	t.tween_property(self, "brillo", 1.0, 0.15)
	t.tween_property(self, "brillo", 0.0, 0.9)
	_rebotar()


## Tiembla de lado a lado (se llama al intentar usarla bloqueada).
func temblar() -> void:
	var t := create_tween()
	for desplazamiento in [3.0, -3.0, 2.0, -2.0, 0.0]:
		t.tween_property(self, "temblor", desplazamiento, 0.04)


func _rebotar() -> void:
	var t := create_tween()
	t.tween_property(self, "scale", Vector2(1.12, 1.12), 0.08)
	t.tween_property(self, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _draw() -> void:
	draw_set_transform(Vector2(temblor, 0.0))
	var rect := Rect2(Vector2.ZERO, TAMANO)
	var gris := Color("5a5570")
	var fondo := COLOR_FONDO if desbloqueada else Color("17141f", 0.95)
	draw_rect(rect, fondo)
	# Ícono o silueta
	var centro := TAMANO / 2.0
	if desbloqueada:
		_dibujar_icono(centro, false)
	else:
		_dibujar_icono(centro, true)
	# Espera: sector oscuro que se vacía (empieza lleno y se recorre en sentido horario)
	if desbloqueada and espera > 0.0:
		_dibujar_sector(centro, espera)
	# Brillo al desbloquear
	if brillo > 0.0:
		draw_rect(rect, Color(1, 0.95, 0.8, 0.55 * brillo))
		draw_rect(rect.grow(2.0 * brillo), Color(COLOR_DORADO, brillo), false, 2.0)
	# Habilidad en marcha: un halo del color de la emoción que late
	if activa:
		var pulso := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * 5.0)
		draw_rect(rect.grow(1.0), Color(color, 0.35 + 0.45 * pulso), false, 2.0)
	# Estrella de la mejora (nivel 2)
	if desbloqueada and nivel >= 2:
		_dibujar_estrella(Vector2(TAMANO.x - 8.0, 8.0))
	# Borde
	var borde := COLOR_DORADO if seleccionada else (COLOR_BORDE if desbloqueada else gris.darkened(0.3))
	draw_rect(rect, borde, false, 2.0 if seleccionada else 1.0)


## Estrella pequeña de cinco puntas (la mejora de la habilidad).
func _dibujar_estrella(centro: Vector2) -> void:
	var puntos := PackedVector2Array()
	for i in 10:
		var radio := 6.0 if i % 2 == 0 else 2.6
		var angulo := -PI / 2.0 + i * PI / 5.0
		puntos.append(centro + Vector2(cos(angulo), sin(angulo)) * radio)
	draw_colored_polygon(puntos, Color(COLOR_DORADO.lightened(0.2), 1.0))
	var contorno := puntos.duplicate()
	contorno.append(puntos[0])
	draw_polyline(contorno, Color("1e1b2e"), 1.0)


func _dibujar_icono(centro: Vector2, candado: bool) -> void:
	if _iconos != null:
		var indice := ORDEN_ICONOS.size() - 1 if candado else ORDEN_ICONOS.find(habilidad_id)
		if indice >= 0:
			var origen := Vector2((indice % 4) * 32, floori(indice / 4.0) * 32)
			var destino := Rect2(centro - Vector2(16, 16), Vector2(32, 32))
			draw_texture_rect_region(_iconos, destino, Rect2(origen, Vector2(32, 32)),
				Color(0.35, 0.35, 0.42) if candado else Color.WHITE)
			return
	if candado:
		draw_circle(centro, 13.0, Color("3a3648"))
		_dibujar_candado(centro)
		return
	# Sin hoja de íconos: círculo del color de la emoción con su inicial
	draw_circle(centro, 14.0, color.darkened(0.25))
	draw_circle(centro, 12.0, color)
	if _fuente != null and nombre != "":
		var inicial := nombre.substr(0, 1)
		var medida := _fuente.get_string_size(inicial, HORIZONTAL_ALIGNMENT_LEFT, -1, 18)
		draw_string(_fuente, centro + Vector2(-medida.x / 2.0, 6.0), inicial,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("1e1b2e"))


## Candado sencillo: cuerpo y arco.
func _dibujar_candado(centro: Vector2) -> void:
	var gris := Color("8a8499")
	draw_rect(Rect2(centro + Vector2(-6, -1), Vector2(12, 9)), gris)
	draw_arc(centro + Vector2(0, -2), 4.5, PI, TAU, 12, gris, 2.0)


## Sector oscuro desde las 12 en punto: cubre la parte `fraccion` (0 a 1) de la casilla.
func _dibujar_sector(centro: Vector2, fraccion: float) -> void:
	var puntos := PackedVector2Array([centro])
	var pasos := 24
	var inicio := -PI / 2.0
	var fin := inicio + TAU * fraccion
	for i in pasos + 1:
		var angulo := lerpf(inicio, fin, float(i) / pasos)
		puntos.append(centro + Vector2(cos(angulo), sin(angulo)) * 40.0)
	# Se recorta a la casilla dibujando solo la intersección aproximada con un polígono cuadrado
	var recortado := Geometry2D.intersect_polygons(puntos,
		PackedVector2Array([Vector2.ZERO, Vector2(TAMANO.x, 0), TAMANO, Vector2(0, TAMANO.y)]))
	for poligono in recortado:
		draw_colored_polygon(poligono, Color(0.05, 0.03, 0.1, 0.72))
