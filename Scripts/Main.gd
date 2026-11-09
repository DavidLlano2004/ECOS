extends Node2D

## Diálogo del inicio (el guía y las 5 preguntas). Las respuestas se guardan
## solas en GameState.respuestas_inicio desde el propio .dialogue.
const ONBOARDING := preload("res://Dialogos/onboarding.dialogue")

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
	tex.height = 256
	var rect := TextureRect.new()
	rect.texture = tex
	# Filtro lineal: el filtro por defecto del proyecto es Nearest y el degradado se vería en bandas
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	capa.add_child(rect)
	add_child(capa)

func _ready() -> void:
	
	_crear_fondo()
	var player := get_tree().get_first_node_in_group("player")
	
	if player:
		player.bloquear()
		


	await Dialogo.mostrar(ONBOARDING, "start")

	if player:
		player.liberar()
