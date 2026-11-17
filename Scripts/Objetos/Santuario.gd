class_name Santuario
extends Node2D
## El santuario de una emoción, en el Presente: el claro cerrado por acantilados del centro de su zona.
## Aquí van las cosas que se ven "de pie" (se ordenan con el jugador): un pequeño altar de piedra en el
## centro (la forma aliada flota sobre él, la crea el bloqueo), luces del color de la emoción y el cofre de
## memoria. Las flores van aparte, a ras de suelo (SantuarioSuelo). ARTE TEMPORAL: altar y luces dibujados
## por código.
##
## Origen del nodo: el centro del claro. `direccion` apunta desde el acceso hacia el centro: el cofre se
## coloca más allá del altar, al fondo, y las luces dejan libre el lado del acceso.

const COFRE := preload("res://Scenes/Objetos/CofreMemoria.tscn")
const DISTANCIA_COFRE := 54.0
const RADIO_LUCES := 80.0

var datos: EmocionData
var direccion := Vector2.UP
var _luces: Array[PointLight2D] = []
var _fases: Array[float] = []
var _tiempo := 0.0


func _ready() -> void:
	add_to_group("santuario")
	_crear_altar()
	_crear_luces()
	_crear_cofre()


func _process(delta: float) -> void:
	_tiempo += delta
	for i in _luces.size():
		_luces[i].energy = 0.75 + sin(_tiempo * 2.0 + _fases[i]) * 0.18
	queue_redraw()


func _crear_altar() -> void:
	var cuerpo := StaticBody2D.new()
	cuerpo.collision_layer = 1
	cuerpo.collision_mask = 0
	var forma := CollisionShape2D.new()
	var caja := RectangleShape2D.new()
	caja.size = Vector2(26, 10)
	forma.shape = caja
	forma.position = Vector2(0, -5)
	cuerpo.add_child(forma)
	add_child(cuerpo)


## Un pequeño altar de piedra con un emblema brillante del color de la emoción.
func _draw() -> void:
	if datos == null:
		return
	var color := datos.color
	var piedra := Color("5b5470")
	draw_rect(Rect2(-15, -9, 30, 9), piedra.darkened(0.35))          # base
	draw_rect(Rect2(-15, -9, 30, 2), piedra.lightened(0.15))          # canto
	draw_rect(Rect2(-12, -17, 24, 8), piedra)                          # cuerpo
	draw_rect(Rect2(-12, -17, 24, 2), piedra.lightened(0.3))           # tapa
	var pulso := 0.6 + 0.4 * sin(_tiempo * 2.4)
	var centro := Vector2(0, -13)
	draw_colored_polygon(PackedVector2Array([centro + Vector2(0, -4), centro + Vector2(4, 0), centro + Vector2(0, 4), centro + Vector2(-4, 0)]), Color(color.lightened(0.3), 0.7 + 0.3 * pulso))


func _crear_luces() -> void:
	# Cuatro luces en el anillo del claro, dejando libre el lado del acceso (opuesto a `direccion`)
	var hacia_acceso := (-direccion).angle()
	for i in 4:
		var angulo := hacia_acceso + deg_to_rad(65.0 + i * 76.0)
		var posicion := Vector2.from_angle(angulo) * RADIO_LUCES
		var luz := PointLight2D.new()
		luz.texture = Atmosfera.crear_textura_luz(128)
		luz.texture_scale = 1.1
		luz.color = datos.color
		luz.energy = 0.75
		luz.position = posicion + Vector2(0, -16)
		add_child(luz)
		_luces.append(luz)
		_fases.append(float(i) * 1.7)
		_crear_farolito(posicion)


## Un farolito de piedra con una llama del color de la emoción (se dibuja con sus propios nodos).
func _crear_farolito(posicion: Vector2) -> void:
	var farol := Node2D.new()
	farol.position = posicion
	var color := datos.color
	farol.draw.connect(func() -> void:
		farol.draw_rect(Rect2(-3, -12, 6, 12), Color("4a4560"))
		farol.draw_rect(Rect2(-4, -16, 8, 5), Color("6a6384"))
		farol.draw_circle(Vector2(0, -14), 2.6, Color(color.lightened(0.45), 0.95)))
	add_child(farol)


func _crear_cofre() -> void:
	var cofre := COFRE.instantiate() as CofreMemoria
	cofre.emocion_id = datos.id
	cofre.position = direccion * DISTANCIA_COFRE
	cofre.name = "Cofre"
	add_child(cofre)
