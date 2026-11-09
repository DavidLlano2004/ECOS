extends Node2D

const PREGUNTAS := [
	{"t": "Cuando sientes rabia, ¿qué sueles hacer?",
	 "o": ["La aguanto", "Exploto", "Intento entender qué pasó"]},
	{"t": "Cuando algo te da miedo, ¿qué haces?",
	 "o": ["Lo evito", "Me obligo a seguir sin pensar", "Busco apoyo"]},
	{"t": "Cuando estás triste, ¿qué haces?",
	 "o": ["Me aíslo", "Hago como si nada", "Me permito sentirlo o lo hablo"]},
]

func _crear_fondo() -> void:
	var capa := CanvasLayer.new()
	capa.layer = -10
	var g := Gradient.new()
	g.colors = PackedColorArray([Color("1b1530"), Color("5a3a6e"), Color("c98a6b")])
	g.offsets = PackedFloat32Array([0.0, 0.6, 1.0])
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill_from = Vector2(0.5, 0.0)
	tex.fill_to = Vector2(0.5, 1.0)
	tex.width = 64
	tex.height = 64
	var rect := TextureRect.new()
	rect.texture = tex
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	capa.add_child(rect)
	add_child(capa)

func _ready() -> void:
	
	_crear_fondo()
	var player := get_tree().get_first_node_in_group("player")
	
	if player:
		player.can_move = false
		


	await Dialogo.preguntar("Este mundo existe en dos tiempos: el Pasado y el Presente. Lo que no se atiende en el pasado se convierte en el mundo en que vives hoy.", ["Continuar"])
	await Dialogo.preguntar("Antes de empezar, quiero conocerte. No hay respuestas correctas.", ["Entiendo"])
	
	

	for p in PREGUNTAS:
		var r: int = await Dialogo.preguntar(p["t"], p["o"])
		GameState.respuestas_inicio.append(r)

	if player:
		player.can_move = true
