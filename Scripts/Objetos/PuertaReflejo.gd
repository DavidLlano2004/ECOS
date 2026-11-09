class_name PuertaReflejo
extends StaticBody2D
## La Puerta del Reflejo: una puerta de piedra con un espejo en el centro, arriba del mapa
## (Zona_Final). Está en las dos épocas; en el Presente el espejo está agrietado.
##
## Al interactuar:
##   - si queda alguna emoción pendiente: dice que aún falta algo por atender (sin decir cuántas);
##   - si todas están resueltas (integrada, atacada o ignorada): muestra el resultado de
##     GameState.calcular_final() como texto simple.
## TEMPORAL: ese texto es provisional; la secuencia final se hace en un paso posterior.

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


## Las líneas que dirá la puerta ahora (según el estado de las emociones).
func lineas_de_dialogo() -> Array:
	if GameState.cantidad_pendientes() > 0:
		return ["El espejo está empañado. Aún falta algo por atender."]
	# TEMPORAL: resultado provisional del final; la secuencia final llegará más adelante
	var final := GameState.calcular_final()
	return ["TEMPORAL - Aquí irá la secuencia final.", "Tu final sería «%s»." % final]


func interactuar() -> void:
	if not puede_interactuar():
		return
	_ocupada = true
	await Dialogo.mostrar_texto("", lineas_de_dialogo())  # se puede salir con ESC; no cambia nada
	_ocupada = false


func _buscar_epoca() -> String:
	var nodo := get_parent()
	while nodo != null:
		if nodo.name == &"Presente":
			return "presente"
		if nodo.name == &"Pasado":
			return "pasado"
		nodo = nodo.get_parent()
	return "pasado"
