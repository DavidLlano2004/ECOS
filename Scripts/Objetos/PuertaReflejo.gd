class_name PuertaReflejo
extends StaticBody2D
## La Puerta del Reflejo: una puerta de piedra con un espejo en el centro, arriba del mapa
## (Zona_Final). Está en las dos épocas; en el Presente el espejo está agrietado.
##
## Al interactuar:
##   - si queda alguna emoción pendiente: dice que aún falta algo por atender (sin decir cuántas);
##   - si todas están resueltas (integrada, atacada o ignorada): el Guía pregunta "¿Quieres cerrar tu viaje
##     aquí?" y, si se acepta, se cruza el espejo hacia la secuencia final (Scenes/Final/Final.tscn).

const TEXTURAS := {
	"pasado": preload("res://Assets/Mundo/puerta_reflejo_pasado.png"),
	"presente": preload("res://Assets/Mundo/puerta_reflejo_presente.png"),
}
## Punto de apoyo del dibujo (96x112, centrado en la base).
const APOYO := Vector2(48, 110)

@onready var _sprite: Sprite2D = $Sprite
@onready var _forma: CollisionShape2D = $Forma
@onready var _forma_zona: CollisionShape2D = $Zona/Forma
@onready var _luz: PointLight2D = $Luz

var _epoca := "pasado"
var _tiempo := 0.0
var _ocupada := false


func _ready() -> void:
	add_to_group("puerta_reflejo")
	_epoca = _buscar_epoca()
	_sprite.texture = TEXTURAS[_epoca]
	_sprite.centered = false
	_sprite.offset = -APOYO

	# Colisión solo en la base (capa 1 = mundo)
	var base := RectangleShape2D.new()
	base.size = Vector2(60, 14)
	_forma.shape = base
	_forma.position = Vector2(0, -8)

	# Zona de interacción delante de la puerta (capa 2)
	var circulo := CircleShape2D.new()
	circulo.radius = 42.0
	_forma_zona.shape = circulo
	_forma_zona.position = Vector2(0, 8)

	# Resplandor del espejo
	_luz.texture = load("res://Resources/Mundo/luz_calida.tres")
	_luz.position = Vector2(0, -62)
	_luz.texture_scale = 1.3
	_luz.color = Color(0.82, 0.92, 1.0) if _epoca == "pasado" else Color(0.65, 0.75, 1.0)


func _process(delta: float) -> void:
	_tiempo += delta
	var base := 0.75 if _epoca == "pasado" else 0.4
	_luz.energy = base + sin(_tiempo * 1.6) * 0.1


func puede_interactuar() -> bool:
	return not _ocupada and not Dialogo.hay_dialogo()


## Lo que dice la puerta mientras queda alguna emoción pendiente (sin decir cuántas).
const TEXTO_PENDIENTE := "El espejo está empañado. Aún falta algo por atender."
const PREGUNTA := "¿Quieres cerrar tu viaje aquí?"
const OPCION_CRUZAR := "Sí, cruzar el espejo"
const OPCION_NO := "Todavía no"
const ESCENA_FINAL := "res://Scenes/Final/Final.tscn"

## Se emite al cruzar el espejo (justo antes de cambiar a la escena del final); sirve para las pruebas.
signal cruzado


## INTERACTUAR. Con alguna emoción pendiente: dice que aún falta algo. Con todas resueltas (integrada, atacada
## o ignorada) el Guía pregunta si se quiere cerrar el viaje. "Todavía no" (o cancelar con ESC) vuelve al mundo.
## Este diálogo SÍ se puede cancelar.
func interactuar() -> void:
	if not puede_interactuar():
		return
	_ocupada = true
	if GameState.cantidad_pendientes() > 0:
		await Dialogo.mostrar_texto("Puerta del Reflejo", TEXTO_PENDIENTE)
	else:
		var elegida := await Dialogo.mostrar_texto("Guía", PREGUNTA, [OPCION_CRUZAR, OPCION_NO])
		if elegida == 0:
			await _cruzar()
	_ocupada = false


## Cruza el espejo: el jugador se detiene, fundido a blanco y se pasa a la secuencia final.
## La posición queda guardada para poder volver al mundo con todo el estado intacto.
func _cruzar() -> void:
	var jugador := get_tree().get_first_node_in_group("player") as Player
	if jugador != null:
		jugador.bloquear()
		GameState.posicion_jugador = global_position + Vector2(0, 56)
		GameState.tiene_posicion = true
	Sonido.efecto("luz_blanca")
	var capa := CanvasLayer.new()
	capa.layer = 20
	capa.add_to_group("fundido_final")   # la escena del final la quita cuando ya se ve
	var blanco := ColorRect.new()
	blanco.color = Color(1, 1, 1, 0)
	blanco.set_anchors_preset(Control.PRESET_FULL_RECT)
	blanco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	capa.add_child(blanco)
	get_tree().root.add_child(capa)
	var t := capa.create_tween()
	t.tween_property(blanco, "color:a", 1.0, 1.2)
	await t.finished
	cruzado.emit()
	if jugador != null:
		jugador.liberar()
	get_tree().change_scene_to_file(ESCENA_FINAL)


func _buscar_epoca() -> String:
	var nodo := get_parent()
	while nodo != null:
		if nodo.name == &"Presente":
			return "presente"
		if nodo.name == &"Pasado":
			return "pasado"
		nodo = nodo.get_parent()
	return "pasado"
