class_name RavinaCompuerta
extends Node2D
## El barranco y el puente de la compuerta del puente roto, a ras de suelo (va entre el suelo y los
## objetos, así el jugador siempre se dibuja por encima). ARTE TEMPORAL del barranco (se dibuja por
## código); el puente reutiliza el arte del puente de Culpa (frames_bloqueo_culpa.tres), girado 90 grados
## si el camino cruza de lado a lado.
## Cerrada: el barranco cubre todo el hueco y el puente se ve roto. Abierta: el barranco queda solo a
## los lados y el puente se ve entero, sobre el camino.

const TAMANO_TILE := 32
const FRAMES := "res://Resources/Mundo/frames_bloqueo_culpa.tres"
const COLOR_FONDO := Color("0b0814")
const COLOR_MEDIO := Color("1a1226")
const COLOR_BORDE := Color("5a4636")
const COLOR_BORDE_CLARO := Color("8a6c4c")

var id := ""
var celdas: Array = []
var paso: Array = []
var cruza := "v"

var _sprite: AnimatedSprite2D
var _huecos: Dictionary = {}   # Vector2i -> true (las casillas del barranco)
var _abierto := false


func configurar(datos: Dictionary) -> void:
	id = str(datos["id"])
	celdas = datos["celdas"]
	paso = datos["paso"]
	cruza = str(datos["cruza"])


func _ready() -> void:
	for c in celdas:
		_huecos[Vector2i(c[0], c[1])] = true
	_crear_puente()
	GameState.compuerta_abierta.connect(func(otra: String) -> void:
		if otra == id:
			_abrir(true))
	GameState.partida_reiniciada.connect(_leer_estado)
	GameState.partida_cargada.connect(_leer_estado)
	_leer_estado()


func _leer_estado() -> void:
	_abierto = false
	if _sprite != null:
		_sprite.animation = &"bloqueo"
	if GameState.compuerta_esta_abierta(id):
		_abrir(false)
	queue_redraw()


func _crear_puente() -> void:
	var gmin := Vector2(INF, INF)
	var gmax := Vector2(-INF, -INF)
	for c in celdas:
		gmin = gmin.min(Vector2(c[0], c[1]) * TAMANO_TILE)
		gmax = gmax.max(Vector2(c[0] + 1, c[1] + 1) * TAMANO_TILE)
	_sprite = AnimatedSprite2D.new()
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.sprite_frames = load(FRAMES)
	_sprite.animation = &"bloqueo"
	_sprite.position = (gmin + gmax) / 2.0
	# El puente mide 96 px de largo: se estira para cubrir el barranco de lado a lado
	var largo := (gmax.y - gmin.y) if cruza == "v" else (gmax.x - gmin.x)
	var escala := largo / 96.0
	_sprite.scale = Vector2(escala, escala)
	if cruza == "h":
		_sprite.rotation = PI / 2.0
	add_child(_sprite)


func _abrir(con_animacion: bool) -> void:
	_abierto = true
	queue_redraw()
	if _sprite == null:
		return
	if con_animacion and is_visible_in_tree():
		_sprite.play(&"abriendo")
		get_tree().create_timer(0.4).timeout.connect(func() -> void:
			if is_instance_valid(_sprite):
				_sprite.play(&"abierto"))
	else:
		_sprite.play(&"abierto")


func _draw() -> void:
	var paso_libre: Dictionary = {}
	if _abierto:
		for c in paso:
			paso_libre[Vector2i(c[0], c[1])] = true
	for celda in _huecos:
		if paso_libre.has(celda):
			continue
		var p := Vector2(celda) * TAMANO_TILE
		draw_rect(Rect2(p, Vector2(TAMANO_TILE, TAMANO_TILE)), COLOR_FONDO)
		# Un poco de profundidad: rocas del fondo más claras
		draw_rect(Rect2(p + Vector2(4, 6), Vector2(TAMANO_TILE - 8, TAMANO_TILE - 12)), COLOR_MEDIO)
		# Borde del barranco donde hay suelo al lado
		for d in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
			var vecino: Vector2i = celda + d
			if _huecos.has(vecino) and not paso_libre.has(vecino):
				continue
			var a := p
			var b := p
			if d == Vector2i(0, -1):
				b = p + Vector2(TAMANO_TILE, 0)
			elif d == Vector2i(0, 1):
				a = p + Vector2(0, TAMANO_TILE)
				b = p + Vector2(TAMANO_TILE, TAMANO_TILE)
			elif d == Vector2i(-1, 0):
				b = p + Vector2(0, TAMANO_TILE)
			else:
				a = p + Vector2(TAMANO_TILE, 0)
				b = p + Vector2(TAMANO_TILE, TAMANO_TILE)
			draw_line(a, b, COLOR_BORDE, 4.0)
			draw_line(a, b, COLOR_BORDE_CLARO, 1.5)
