class_name FondoEvaluacion
extends RefCounted
## El fondo común de las pantallas de evaluación (consentimiento, cuestionarios y resultados): la ilustración
## del onboarding (la misma de la pantalla de título, Assets/UI/fondo_titulo.png, que es el fondo del onboarding),
## oscurecida, y el Guía a un lado. Se construye por código dentro de una CanvasLayer (viewport de 640x360).

const FONDO := "res://Assets/UI/fondo_onboarding.png"
const FRAMES_GUIA := preload("res://Resources/Personajes/frames_guia.tres")
const POSICION_GUIA := Vector2(78, 262)


## Añade el fondo y devuelve el sprite del Guía (animaciones "idle" y "hablar").
static func crear(capa: CanvasLayer) -> AnimatedSprite2D:
	if ResourceLoader.exists(FONDO):
		var fondo := TextureRect.new()
		fondo.texture = load(FONDO)
		fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
		fondo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		fondo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		fondo.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		fondo.mouse_filter = Control.MOUSE_FILTER_STOP   # nada de debajo recibe clics
		capa.add_child(fondo)
	var velo := ColorRect.new()
	velo.color = Color(0.06, 0.04, 0.12, 0.45)
	velo.set_anchors_preset(Control.PRESET_FULL_RECT)
	velo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	capa.add_child(velo)
	var guia := AnimatedSprite2D.new()
	guia.sprite_frames = FRAMES_GUIA
	guia.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	guia.scale = Vector2(2.5, 2.5)
	guia.position = POSICION_GUIA
	guia.play(&"idle")
	capa.add_child(guia)
	# El Guía flota suavemente
	var flote := guia.create_tween().set_loops()
	flote.tween_property(guia, "position:y", POSICION_GUIA.y - 5.0, 1.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	flote.tween_property(guia, "position:y", POSICION_GUIA.y, 1.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return guia
