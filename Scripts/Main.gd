extends Node2D

## Diálogo del inicio (el guía y las 5 preguntas). Las respuestas se guardan
## solas en GameState.respuestas_inicio desde el propio .dialogue.
const ONBOARDING := preload("res://Dialogos/onboarding.dialogue")
const FONDO := preload("res://Assets/UI/fondo_titulo.png")

## Fondo del onboarding: la ilustración del título, desenfocada, más oscura y fría,
## para que el Guía y las emociones destaquen.
func _crear_fondo() -> void:
	var capa := CanvasLayer.new()
	capa.layer = -10
	var rect := TextureRect.new()
	rect.texture = FONDO
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED  # cubre la pantalla sin deformar
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	var material := ShaderMaterial.new()
	material.shader = load("res://Shaders/desenfoque_oscuro.gdshader")
	rect.material = material
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
