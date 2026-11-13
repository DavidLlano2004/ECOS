class_name PuertaPlacas
extends StaticBody2D
## Puerta de piedra de un mecanismo doble. Se abre cuando TODAS las placas con su mismo
## `id_mecanismo` están ocupadas a la vez (una por el jugador y otra por el compañero) y se queda
## abierta para siempre (así nadie queda encerrado detrás de ella).
## ARTE TEMPORAL: se dibuja por código (no hay sprite todavía). Origen: el centro del hueco.

signal abierta

## Ancho del hueco que cierra (px).
@export var ancho := 64.0
@export var id_mecanismo := ""

@onready var _forma: CollisionShape2D = $Forma

var esta_abierta := false
var _placas: Array[Node] = []
var _apertura := 0.0:   # 0 = cerrada, 1 = abierta
	set(valor):
		_apertura = valor
		queue_redraw()


func _ready() -> void:
	collision_layer = 1
	var rectangulo := RectangleShape2D.new()
	rectangulo.size = Vector2(ancho, 32.0)
	_forma.shape = rectangulo
	# Se engancha por señales a las placas con su mismo id (pueden crearse después que ella)
	_buscar_placas.call_deferred()


func _buscar_placas() -> void:
	for placa in get_tree().get_nodes_in_group("placa_doble"):
		if "id_mecanismo" in placa and placa.id_mecanismo == id_mecanismo and not _placas.has(placa):
			_placas.append(placa)
			placa.ocupacion_cambiada.connect(_revisar)
	_revisar()


## Cuántas placas de este mecanismo están ocupadas ahora (para el dibujo y las pruebas).
func placas_ocupadas() -> int:
	var total := 0
	for placa in _placas:
		if is_instance_valid(placa) and placa.ocupada:
			total += 1
	return total


func _revisar() -> void:
	queue_redraw()
	if esta_abierta or _placas.size() < 2:
		return
	if placas_ocupadas() == _placas.size():
		_abrir()


func _abrir() -> void:
	esta_abierta = true
	Colisiones.apagar(_forma, true)
	create_tween().tween_property(self, "_apertura", 1.0, 0.8).set_trans(Tween.TRANS_SINE)
	abierta.emit()


func _draw() -> void:
	# Dos hojas de piedra que se deslizan hacia los lados al abrirse
	var mitad := ancho / 2.0
	var hueco := mitad * _apertura
	var alto := 44.0
	for lado in [-1.0, 1.0]:
		var x := hueco if lado > 0.0 else -mitad - hueco
		var rect := Rect2(x, -alto, mitad, alto)
		draw_rect(rect, Color("5b5775").lerp(Color("2d2845"), _apertura * 0.5))
		draw_rect(rect, Color("a79fc4"), false, 2.0)
	# Dos luces: una por placa, se encienden al ocuparla
	for i in 2:
		var encendida := i < placas_ocupadas()
		draw_circle(Vector2(-6 + 12 * i, -alto - 6), 2.5, Color("f4c77b") if encendida else Color("3b3650"))
