class_name EfectoPausa
extends CanvasLayer
## Efecto en pantalla de la habilidad Pausa: leve desaturación azulada y viñeta que se cierra un
## poco (shader), y un reloj tenue que gira en el borde derecho de la pantalla. Aparece y se
## desvanece con suavidad y se borra solo. Lo crea HabilidadPausa (cuelga del autoload Habilidades).

const RUTA_SHADER := "res://Shaders/pausa.gdshader"
const RADIO_RELOJ := 16.0
const COLOR_RELOJ := Color(0.7, 0.85, 1.0)

var _material: ShaderMaterial
var _reloj: Control
var _tween: Tween
var _fuerza := 0.0:
	set(valor):
		_fuerza = valor
		if _material != null:
			_material.set_shader_parameter("fuerza", valor)
		if _reloj != null:
			_reloj.modulate.a = valor * 0.45  # el reloj es tenue


func _ready() -> void:
	layer = 3  # sobre el mundo, bajo la viñeta (4), el HUD (5) y los diálogos
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_material = ShaderMaterial.new()
	_material.shader = load(RUTA_SHADER)
	rect.material = _material
	add_child(rect)

	_reloj = Control.new()
	_reloj.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	_reloj.position = Vector2(-RADIO_RELOJ - 10.0, 0.0)
	_reloj.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reloj.draw.connect(_dibujar_reloj)
	add_child(_reloj)
	_fuerza = 0.0


func _process(_delta: float) -> void:
	_reloj.queue_redraw()


## Entra con suavidad.
func aparecer() -> void:
	_animar(1.0, 0.25)


## Sale con suavidad y se borra.
func desaparecer() -> void:
	_animar(0.0, 0.8)
	_tween.tween_callback(queue_free)


func _animar(destino: float, segundos: float) -> void:
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "_fuerza", destino, segundos)


## Esfera de reloj con marcas y una manecilla que gira (en tiempo real, no se ralentiza).
func _dibujar_reloj() -> void:
	var centro := Vector2.ZERO
	_reloj.draw_arc(centro, RADIO_RELOJ, 0.0, TAU, 40, COLOR_RELOJ, 2.0, true)
	for i in 12:
		var direccion := Vector2.from_angle(TAU * i / 12.0 - PI / 2.0)
		_reloj.draw_line(centro + direccion * (RADIO_RELOJ - 4.0), centro + direccion * (RADIO_RELOJ - 1.5), COLOR_RELOJ, 1.0)
	var segundos := Time.get_ticks_msec() / 1000.0
	var minutero := Vector2.from_angle(segundos * TAU / 3.0 - PI / 2.0)  # una vuelta cada 3 s
	var horario := Vector2.from_angle(segundos * TAU / 36.0 - PI / 2.0)
	_reloj.draw_line(centro, centro + minutero * (RADIO_RELOJ - 4.0), COLOR_RELOJ, 1.5, true)
	_reloj.draw_line(centro, centro + horario * (RADIO_RELOJ - 8.0), COLOR_RELOJ, 2.0, true)
	_reloj.draw_circle(centro, 1.8, COLOR_RELOJ)
