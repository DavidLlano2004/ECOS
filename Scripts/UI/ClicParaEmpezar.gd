extends Control
## Pantalla previa mínima, solo en la web: "Haz clic para empezar". Los navegadores bloquean el audio hasta que hay un
## clic o una tecla, así que esta pantalla va ANTES del título y, al hacer clic, desbloquea el audio (el título ya
## arranca con su música). Fuera de la web no se muestra: pasa directo al título.

const ESCENA_TITULO := "res://Scenes/UI/PantallaTitulo.tscn"
const FONDO := "res://Assets/UI/fondo_onboarding.png"

var _listo := false


func _ready() -> void:
	if not OS.has_feature("web"):
		get_tree().change_scene_to_file.call_deferred(ESCENA_TITULO)
		return
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	if ResourceLoader.exists(FONDO):
		var fondo := TextureRect.new()
		fondo.texture = load(FONDO)
		fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
		fondo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		fondo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		fondo.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		fondo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(fondo)
	var caja := VBoxContainer.new()
	caja.set_anchors_preset(Control.PRESET_CENTER)
	caja.grow_horizontal = Control.GROW_DIRECTION_BOTH
	caja.grow_vertical = Control.GROW_DIRECTION_BOTH
	caja.alignment = BoxContainer.ALIGNMENT_CENTER
	caja.add_theme_constant_override("separation", 14)
	caja.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(caja)
	caja.add_child(_etiqueta("ECOS", 40, Color("f4c77b")))
	var clic := _etiqueta("Haz clic para empezar", 16, Color("fff4dc"))
	caja.add_child(clic)
	caja.add_child(_etiqueta("ECOS se juega con teclado y con sonido: sube el volumen.", 10, Color("b8aed0")))
	# La invitación a hacer clic late suavemente
	var latido := clic.create_tween().set_loops()
	latido.tween_property(clic, "modulate:a", 0.45, 0.9).set_trans(Tween.TRANS_SINE)
	latido.tween_property(clic, "modulate:a", 1.0, 0.9).set_trans(Tween.TRANS_SINE)


func _etiqueta(texto: String, tamano: int, color: Color) -> Label:
	var e := EstiloUI.etiqueta(texto, tamano, color)
	e.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	e.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return e


func _input(evento: InputEvent) -> void:
	if _listo or not OS.has_feature("web"):
		return
	var pulsado: bool = (evento is InputEventMouseButton and evento.pressed) or (evento is InputEventKey and evento.pressed and not evento.echo) \
		or (evento is InputEventScreenTouch and evento.pressed)
	if not pulsado:
		return
	_listo = true
	get_viewport().set_input_as_handled()
	Sonido.efecto("ui_aceptar")   # este sonido, en pleno clic, desbloquea el audio del navegador
	get_tree().change_scene_to_file(ESCENA_TITULO)
