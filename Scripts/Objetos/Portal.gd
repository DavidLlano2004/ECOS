class_name Portal
extends Node2D
## Portal entre el Pasado y el Presente. El portal principal está en el hub; las grietas son
## portales pequeños (escala 0.5) en la entrada de cada zona, para no tener que volver siempre al hub.
##
## Se interactúa con E (o con Q estando dentro de su zona). El portal no sabe nada del mundo:
## solo avisa con la señal `viaje_pedido` y Mundo (que lo crea) hace el viaje con Mundo.viajar().
## Hay un portal en cada época, en el mismo sitio: el dorado del Pasado y el azul del Presente.

## El jugador quiere viajar.
signal viaje_pedido

const COLOR_PASADO := Color(1.0, 0.78, 0.4)
const COLOR_PRESENTE := Color(0.55, 0.75, 1.0)
## Punto de apoyo del dibujo (96x96, centrado y casi en el borde de abajo).
const APOYO := Vector2(48, 94)
## A qué distancia (px, a escala 1) el portal se "despierta".
const DISTANCIA_ACTIVO := 70.0

@export var escala: float = 1.0
@export var es_grieta: bool = false

@onready var _sprite: AnimatedSprite2D = $Sprite
@onready var _zona: Area2D = $Zona
@onready var _forma: CollisionShape2D = $Zona/Forma
@onready var _luz: PointLight2D = $Luz
@onready var _espiral: CPUParticles2D = $Espiral

var _color := COLOR_PASADO
var _tiempo := 0.0
var _cerca := false


func _ready() -> void:
	add_to_group("portales")
	_color = COLOR_PRESENTE if _epoca() == "presente" else COLOR_PASADO
	if es_grieta:
		escala = minf(escala, 0.5)

	# Dibujo apoyado por la base en la posición del nodo
	_sprite.centered = false
	_sprite.offset = -APOYO
	_sprite.scale = Vector2(escala, escala)
	_sprite.play(&"dormido")

	# Zona de interacción (capa 2 = interactuable)
	var circulo := CircleShape2D.new()
	circulo.radius = 34.0 * escala
	_forma.shape = circulo
	_zona.position = Vector2(0, -12.0 * escala)

	# Luz dorada (Pasado) o azul (Presente)
	_luz.color = _color
	_luz.position = Vector2(0, -46.0 * escala)
	_luz.texture_scale = 1.5 * escala
	_luz.energy = 0.8

	# Partículas en espiral que entran hacia el centro del portal
	_espiral.position = Vector2(0, -46.0 * escala)
	_espiral.emission_sphere_radius = 38.0 * escala
	_espiral.scale_amount_min = 1.0
	_espiral.scale_amount_max = 2.0 if not es_grieta else 1.5
	_espiral.amount = 26 if not es_grieta else 14
	_espiral.texture = _textura_punto()
	var degradado := Gradient.new()
	degradado.offsets = PackedFloat32Array([0.0, 0.25, 1.0])
	degradado.colors = PackedColorArray([
		Color(_color, 0.0), Color(_color.lightened(0.3), 0.9), Color(_color, 0.0)])
	_espiral.color_ramp = degradado
	_espiral.emitting = true


func _process(delta: float) -> void:
	_tiempo += delta
	var jugador := get_tree().get_first_node_in_group("player") as Node2D
	_cerca = jugador != null and jugador.global_position.distance_to(global_position) < DISTANCIA_ACTIVO * maxf(escala, 0.6)
	var animacion := &"activo" if _cerca else &"dormido"
	if _sprite.animation != animacion:
		_sprite.play(animacion)
	# La luz respira suavemente y brilla más cuando el portal está despierto
	var base := 1.1 if _cerca else 0.7
	_luz.energy = lerpf(_luz.energy, base + sin(_tiempo * 2.4) * 0.12, minf(1.0, delta * 5.0))


## El jugador pulsó E (o Q) cerca del portal.
func interactuar() -> void:
	viaje_pedido.emit()


## "pasado" o "presente", según el ancestro del nodo (si no hay ninguno, "pasado").
func _epoca() -> String:
	var nodo := get_parent()
	while nodo != null:
		if nodo.name == &"Presente":
			return "presente"
		if nodo.name == &"Pasado":
			return "pasado"
		nodo = nodo.get_parent()
	return "pasado"


## Cuadradito blanco de 2x2 para las partículas.
func _textura_punto() -> Texture2D:
	var imagen := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	imagen.fill(Color.WHITE)
	return ImageTexture.create_from_image(imagen)
