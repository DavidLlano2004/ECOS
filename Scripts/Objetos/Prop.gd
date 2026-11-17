class_name Prop
extends Node2D
## Un objeto decorativo del mundo (árbol, roca, farol, banco...).
##
## Se dibuja con el recorte de su hoja (props_pasado.png o props_presente.png, según la época del
## nodo padre: "Pasado" o "Presente"), apoyado por la base en la posición del nodo (así el y-sort
## lo ordena bien con el jugador). Tiene una colisión pequeña solo en la base.
## Las luces cálidas existen solo en el Pasado: en el Presente las faroles están apagados.

const TAMANO_CUADRO := 128
## Punto de apoyo dentro del cuadro: centrado y a 2 px del borde de abajo.
const APOYO := Vector2(64, 126)
const HOJAS := {
	"pasado": preload("res://Assets/Mundo/props_pasado.png"),
	"presente": preload("res://Assets/Mundo/props_presente.png"),
}

## Cada tipo: "cuadro" (columna, fila en la hoja), "escala" (el jugador mide unos 56 px: lo grande son
## los árboles y los postes; roca, tocón, banco y arbusto son pequeños), "colision" (Rect2 relativo a la
## base, a escala 1; vacío = sin colisión) y "luces" (posiciones de las luces, solo en el Pasado).
const DATOS := {
	"arbol_dorado": {
		"cuadro": Vector2i(0, 0), "escala": 1.3,
		"colision": Rect2(-13, -8, 26, 8),
		"luces": [Vector2(-27, -39), Vector2(27, -38)],
	},
	"cerezo": {"cuadro": Vector2i(1, 0), "escala": 1.2, "colision": Rect2(-10, -8, 20, 8), "luces": []},
	"arbol_redondo": {"cuadro": Vector2i(2, 0), "escala": 1.1, "colision": Rect2(-6, -8, 12, 8), "luces": []},
	"arbusto_flores": {"cuadro": Vector2i(3, 0), "escala": 0.55, "colision": Rect2(), "luces": []},
	"roca": {"cuadro": Vector2i(0, 1), "escala": 0.5, "colision": Rect2(-30, -14, 68, 14), "luces": []},
	"farol_poste": {
		"cuadro": Vector2i(1, 1), "escala": 1.1,
		"colision": Rect2(-20, -4, 8, 4),
		"luces": [Vector2(15, -60)],
	},
	"tocon": {"cuadro": Vector2i(2, 1), "escala": 0.45, "colision": Rect2(-24, -10, 50, 10), "luces": []},
	"banco": {"cuadro": Vector2i(3, 1), "escala": 0.5, "colision": Rect2(-34, -10, 68, 10), "luces": []},
}

## Tipos altos: su copa o su cuerpo sobresale hacia arriba y pueden tapar a quien esté detrás (se vuelven transparentes).
const ALTOS: Array[String] = ["arbol_dorado", "cerezo", "arbol_redondo", "farol_poste"]
const ALPHA_TAPANDO := 0.45
const SEGUNDOS_FUNDIDO := 0.15
## Rectángulo opaco de cada tipo dentro de su cuadro (px del cuadro), para saber qué parte se ve de verdad.
static var _rectangulos: Dictionary = {}

## Tipos disponibles (para usarlos desde otros scripts).
const TIPOS: Array[String] = [
	"arbol_dorado", "cerezo", "arbol_redondo", "arbusto_flores", "roca", "farol_poste", "tocon", "banco",
]

@export_enum("arbol_dorado", "cerezo", "arbol_redondo", "arbusto_flores", "roca", "farol_poste", "tocon", "banco")
var tipo: String = "arbol_redondo"
## Escala del dibujo (y de su colisión y luces). 0 = la escala por defecto del tipo (ver DATOS).
@export var escala: float = 0.0
## Falso en los árboles de la franja del borde: ahí la casilla ya es sólida y no hace falta otra colisión.
@export var con_colision: bool = true

var _factor := 1.0
var _tapando := false
var _tween_alpha: Tween
var _rect_local := Rect2()   # lo que se ve del sprite, relativo a la base y ya escalado

@onready var _sprite: Sprite2D = $Sprite
@onready var _forma: CollisionShape2D = $Cuerpo/Forma
@onready var _luz: PointLight2D = $Luz


func _ready() -> void:
	if not DATOS.has(tipo):
		push_error("Prop: el tipo '%s' no existe." % tipo)
		return
	var datos: Dictionary = DATOS[tipo]
	var epoca := _epoca()

	# Escala: la del tipo (o la exportada) con una variación de ±8 % que depende de la posición, así que
	# el mismo objeto sale igual de grande en el Pasado y en el Presente
	var base_escala: float = escala if escala > 0.0 else float(datos["escala"])
	var azar := float(int(absf(position.x * 73.0 + position.y * 151.0)) % 1000) / 999.0
	var factor := base_escala * (1.0 + (azar - 0.5) * 0.16)

	# Dibujo: un recorte de la hoja, con la base del objeto sobre la posición del nodo
	var cuadro: Vector2i = datos["cuadro"]
	var textura := AtlasTexture.new()
	textura.atlas = HOJAS[epoca]
	textura.region = Rect2(cuadro * TAMANO_CUADRO, Vector2(TAMANO_CUADRO, TAMANO_CUADRO))
	_sprite.texture = textura
	_sprite.centered = false
	_sprite.offset = -APOYO
	_sprite.scale = Vector2(factor, factor)
	_factor = factor
	if ALTOS.has(tipo):
		add_to_group("props_altos")
		_rect_local = _rectangulo_visible(tipo, epoca, textura, factor)

	# Colisión pequeña, solo en la base (capa 1 = mundo)
	var rect: Rect2 = datos["colision"]
	if rect.has_area() and con_colision:
		var cuadrado := RectangleShape2D.new()
		cuadrado.size = rect.size * factor
		_forma.shape = cuadrado
		_forma.position = rect.get_center() * factor
	else:
		$Cuerpo.queue_free()

	# Luces cálidas: solo en el Pasado
	var luces: Array = datos["luces"]
	if epoca != "pasado" or luces.is_empty():
		_luz.queue_free()
		return
	for i in luces.size():
		var luz := _luz if i == 0 else _luz.duplicate() as PointLight2D
		luz.position = luces[i] * factor
		luz.texture_scale = 0.5 * minf(factor, 1.3)
		if i > 0:
			add_child(luz)


## El rectángulo (global) que ocupa lo visible del sprite. Solo tiene sentido en los tipos altos.
func rect_visible() -> Rect2:
	return Rect2(global_position + _rect_local.position, _rect_local.size)


## Pone o quita la transparencia (45 % con un fundido de 0.15 s) según tape o no a alguien.
func poner_tapando(tapa: bool) -> void:
	if tapa == _tapando:
		return
	_tapando = tapa
	if _tween_alpha != null:
		_tween_alpha.kill()
	_tween_alpha = create_tween()
	_tween_alpha.tween_property(_sprite, "modulate:a", ALPHA_TAPANDO if tapa else 1.0, SEGUNDOS_FUNDIDO)


func esta_tapando() -> bool:
	return _tapando


## El rectángulo de píxeles no transparentes del cuadro del tipo (se calcula una vez por tipo y época).
static func _rectangulo_visible(p_tipo: String, epoca: String, textura: AtlasTexture, factor: float) -> Rect2:
	var clave := "%s_%s" % [p_tipo, epoca]
	if not _rectangulos.has(clave):
		var imagen: Image = textura.atlas.get_image()
		var recorte := imagen.get_region(Rect2i(textura.region))
		var usado := recorte.get_used_rect()
		_rectangulos[clave] = Rect2(usado) if usado.has_area() else Rect2(0, 0, TAMANO_CUADRO, TAMANO_CUADRO)
	var r: Rect2 = _rectangulos[clave]
	return Rect2((r.position - APOYO) * factor, r.size * factor)


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
