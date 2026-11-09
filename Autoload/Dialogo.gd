extends CanvasLayer

signal opcion_elegida(indice: int)

const RUTA_FUENTE := "res://Assets/PixelifySans-VariableFont_wght.ttf"
const TAM_FUENTE := 20          
const VELOCIDAD := 0.03         

@onready var panel: Panel = $Panel
@onready var contenedor: VBoxContainer = $Panel/VBoxContainer
@onready var texto: Label = $Panel/VBoxContainer/Texto
@onready var botones: VBoxContainer = $Panel/VBoxContainer/Botones

var escribiendo := false

func _ready() -> void:
	visible = false
	_aplicar_estilo()

func _crear_caja(fondo: Color, borde: Color, grosor: int, margen: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fondo
	s.border_color = borde
	s.set_border_width_all(grosor)
	s.set_corner_radius_all(6)
	s.set_content_margin_all(margen)
	return s

func _aplicar_estilo() -> void:
	# Caja principal
	panel.add_theme_stylebox_override("panel", _crear_caja(Color("1e1b2e", 0.95), Color("f4c77b"), 3, 12))
	
	panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_left = 24
	panel.offset_right = -24
	panel.offset_top = -240      # altura de la caja: 220 px
	panel.offset_bottom = -20

	# Margen interno para que nada pegue con el borde
	contenedor.offset_left = 20
	contenedor.offset_top = 16
	contenedor.offset_right = -20
	contenedor.offset_bottom = -16
	contenedor.add_theme_constant_override("separation", 10)
	botones.add_theme_constant_override("separation", 8)

	# Tema (fuente y botones)
	var tema := Theme.new()
	if ResourceLoader.exists(RUTA_FUENTE):
		var fuente: Font = load(RUTA_FUENTE)
		tema.set_font("font", "Label", fuente)
		tema.set_font("font", "Button", fuente)
	tema.set_font_size("font_size", "Label", TAM_FUENTE)
	tema.set_font_size("font_size", "Button", TAM_FUENTE)
	tema.set_color("font_color", "Label", Color("fff4dc"))
	tema.set_color("font_color", "Button", Color("d9cfe8"))
	tema.set_color("font_hover_color", "Button", Color("f4c77b"))
	tema.set_color("font_focus_color", "Button", Color("f4c77b"))

	tema.set_stylebox("normal", "Button", _crear_caja(Color("2d2845"), Color("2d2845"), 2, 6))
	tema.set_stylebox("hover", "Button", _crear_caja(Color("3a3358"), Color("f4c77b"), 2, 6))
	tema.set_stylebox("pressed", "Button", _crear_caja(Color("4a4170"), Color("f4c77b"), 2, 6))
	tema.set_stylebox("focus", "Button", _crear_caja(Color("3a3358"), Color("f4c77b"), 2, 6))
	panel.theme = tema

func _input(event: InputEvent) -> void:
	# Con E se completa el texto al instante
	if escribiendo and event.is_action_pressed("INTERACTUAR"):
		escribiendo = false
		get_viewport().set_input_as_handled()

func preguntar(mensaje: String, opciones: Array) -> int:
	# Limpiar botones anteriores
	for b in botones.get_children():
		botones.remove_child(b)
		b.queue_free()

	texto.text = mensaje
	texto.visible_characters = 0
	botones.visible = false

	# Aparece con fundido
	panel.modulate.a = 0.0
	visible = true
	var t := create_tween()
	t.tween_property(panel, "modulate:a", 1.0, 0.2)
	await t.finished

	# Efecto máquina de escribir
	escribiendo = true
	for i in mensaje.length():
		if not escribiendo:
			break
		texto.visible_characters = i + 1
		await get_tree().create_timer(VELOCIDAD).timeout
	texto.visible_characters = -1
	escribiendo = false

	# Mostrar botones
	for i in opciones.size():
		var boton := Button.new()
		boton.text = opciones[i]
		boton.pressed.connect(func(): opcion_elegida.emit(i))
		botones.add_child(boton)
	botones.visible = true
	botones.get_child(0).grab_focus()

	var elegida: int = await opcion_elegida

	# Se va con fundido
	var t2 := create_tween()
	t2.tween_property(panel, "modulate:a", 0.0, 0.15)
	await t2.finished
	visible = false
	return elegida
