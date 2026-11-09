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

## Cada tipo: "cuadro" (columna, fila en la hoja), "colision" (Rect2 relativo a la base; vacío = sin
## colisión) y "luces" (posiciones de las luces relativas a la base, solo en el Pasado).
const DATOS := {
	"arbol_dorado": {
		"cuadro": Vector2i(0, 0),
		"colision": Rect2(-13, -8, 26, 8),
		"luces": [Vector2(-27, -39), Vector2(27, -38)],
	},
	"cerezo": {"cuadro": Vector2i(1, 0), "colision": Rect2(-10, -8, 20, 8), "luces": []},
	"arbol_redondo": {"cuadro": Vector2i(2, 0), "colision": Rect2(-6, -8, 12, 8), "luces": []},
	"arbusto_flores": {"cuadro": Vector2i(3, 0), "colision": Rect2(), "luces": []},
	"roca": {"cuadro": Vector2i(0, 1), "colision": Rect2(-30, -14, 68, 14), "luces": []},
	"farol_poste": {
		"cuadro": Vector2i(1, 1),
		"colision": Rect2(-20, -4, 8, 4),
		"luces": [Vector2(15, -60)],
	},
	"tocon": {"cuadro": Vector2i(2, 1), "colision": Rect2(-24, -10, 50, 10), "luces": []},
	"banco": {"cuadro": Vector2i(3, 1), "colision": Rect2(-34, -10, 68, 10), "luces": []},
}

## Tipos disponibles (para usarlos desde otros scripts).
const TIPOS: Array[String] = [
	"arbol_dorado", "cerezo", "arbol_redondo", "arbusto_flores", "roca", "farol_poste", "tocon", "banco",
]

@export_enum("arbol_dorado", "cerezo", "arbol_redondo", "arbusto_flores", "roca", "farol_poste", "tocon", "banco")
var tipo: String = "arbol_redondo"
## Falso en los árboles de la franja del borde: ahí la casilla ya es sólida y no hace falta otra colisión.
@export var con_colision: bool = true

@onready var _sprite: Sprite2D = $Sprite
@onready var _forma: CollisionShape2D = $Cuerpo/Forma
@onready var _luz: PointLight2D = $Luz


func _ready() -> void:
	if not DATOS.has(tipo):
		push_error("Prop: el tipo '%s' no existe." % tipo)
		return
	var datos: Dictionary = DATOS[tipo]
	var epoca := _epoca()

	# Dibujo: un recorte de la hoja, con la base del objeto sobre la posición del nodo
	var cuadro: Vector2i = datos["cuadro"]
	var textura := AtlasTexture.new()
	textura.atlas = HOJAS[epoca]
	textura.region = Rect2(cuadro * TAMANO_CUADRO, Vector2(TAMANO_CUADRO, TAMANO_CUADRO))
	_sprite.texture = textura
	_sprite.centered = false
	_sprite.offset = -APOYO

	# Colisión pequeña, solo en la base (capa 1 = mundo)
	var rect: Rect2 = datos["colision"]
	if rect.has_area() and con_colision:
		var cuadrado := RectangleShape2D.new()
		cuadrado.size = rect.size
		_forma.shape = cuadrado
		_forma.position = rect.get_center()
	else:
		$Cuerpo.queue_free()

	# Luces cálidas: solo en el Pasado
	var luces: Array = datos["luces"]
	if epoca != "pasado" or luces.is_empty():
		_luz.queue_free()
		return
	for i in luces.size():
		var luz := _luz if i == 0 else _luz.duplicate() as PointLight2D
		luz.position = luces[i]
		if i > 0:
			add_child(luz)


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
