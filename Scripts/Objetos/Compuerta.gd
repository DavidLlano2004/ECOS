class_name Compuerta
extends StaticBody2D
## Compuerta de habilidad: tapa el único hueco de un cierre alrededor de una zona (ver
## tools/compuertas_mapa.py). Hay tres: un puente roto (Reparar), una roca enorme (Impulso) y un zarzal
## oscuro (Visión). Existe en las dos épocas, en la misma posición, y su estado (abierta o cerrada) es UNO
## SOLO: vive en GameState.compuertas. Si se abre en el Pasado, en el Presente también está abierta.
##
## Detección: tiene un Area2D de interacción que cubre todas sus casillas más 24 px de margen. Las
## habilidades (Reparar, Impulso y Visión) usan solapa_area(), no la distancia al origen.
##
## Ayudas: un ícono flotante de la habilidad con el color de la emoción que la da (a color si ya tienes la
## habilidad, en silueta si no; si la tienes, se selecciona sola al acercarte) y, con INTERACTUAR, una
## pista (por el mismo balloon de diálogo) que nombra la emoción, la habilidad y dónde está.
## Interfaces: "reparable" (puente), "rompible" (roca) y "sombra" (zarzal); solo mientras está cerrada.

signal abierta

const TAMANO_TILE := 32
const MARGEN := 24.0
const RUTA_ICONOS := "res://Assets/UI/iconos_habilidades.png"
const ORDEN_ICONOS := ["impulso", "vision", "calma", "vinculo", "reparacion", "pausa", "revelar", "candado"]
const FRAMES_ROCA := "res://Resources/Mundo/frames_objeto_roca_rompible.tres"
const FRAMES_ZARZAL := "res://Resources/Mundo/frames_objeto_niebla_sombra.tres"
## Distancia a la que aparece el ícono flotante.
const DISTANCIA_ICONO := 170.0

@export var id := ""
@export var habilidad_requerida := ""
@export_enum("puente", "roca", "zarzal") var tipo := "puente"

## Casillas del hueco y casillas por donde pasa el camino (coordenadas de tile [x, y]).
var celdas: Array = []
var paso: Array = []
## Tamaño del anillo de Reparar y alcance extra de la Visión (propiedades opcionales de los grupos).
var radio_reparar := 44.0
var radio_sombra := 60.0
var esta_abierta := false

var _rect := Rect2()                    # el área de interacción, global (con margen)
var _formas: Dictionary = {}            # Vector2i -> CollisionShape2D
var _sprite: AnimatedSprite2D
var _luz: PointLight2D
var _icono: Node2D
var _iconos: Texture2D
var _color := Color.WHITE
var _alpha_icono := 0.0
var _jugador_dentro := false
var _tiempo := 0.0


## Se llama antes de añadirla al árbol: coloca el origen (el centro del hueco; en la roca y el zarzal, su
## base, para que se ordene bien con el jugador) y guarda las casillas.
func configurar(datos: Dictionary) -> void:
	id = str(datos["id"])
	tipo = str(datos["tipo"])
	habilidad_requerida = str(datos["habilidad"])
	celdas = datos["celdas"]
	paso = datos["paso"]
	var minimo := Vector2(INF, INF)
	var maximo := Vector2(-INF, -INF)
	for c in celdas:
		minimo = minimo.min(Vector2(c[0], c[1]) * TAMANO_TILE)
		maximo = maximo.max(Vector2(c[0] + 1, c[1] + 1) * TAMANO_TILE)
	_rect = Rect2(minimo, maximo - minimo).grow(MARGEN)
	var centro := (minimo + maximo) / 2.0
	position = centro if tipo == "puente" else Vector2(centro.x, maximo.y - 10.0)


func _ready() -> void:
	add_to_group("compuerta")
	collision_layer = 1
	collision_mask = 0
	var datos := Progresion.compuerta(id)
	var emocion := GameState.obtener_datos(str(datos.get("emocion_que_la_da", "")))
	_color = emocion.color if emocion != null else Color.WHITE
	if ResourceLoader.exists(RUTA_ICONOS):
		_iconos = load(RUTA_ICONOS)
	_crear_formas()
	_crear_area()
	_crear_sprite()
	_crear_icono()
	GameState.compuerta_abierta.connect(_on_compuerta_abierta)
	GameState.partida_reiniciada.connect(_on_partida_reiniciada)
	GameState.partida_cargada.connect(_on_partida_reiniciada)
	if GameState.compuerta_esta_abierta(id):
		_aplicar_abierta(false)
	else:
		_unir_a_grupos(true)


# --- Construcción ---

func _crear_formas() -> void:
	for c in celdas:
		var forma := CollisionShape2D.new()
		var cuadro := RectangleShape2D.new()
		cuadro.size = Vector2(TAMANO_TILE, TAMANO_TILE)
		forma.shape = cuadro
		forma.position = Vector2(c[0] + 0.5, c[1] + 0.5) * TAMANO_TILE - position
		add_child(forma)
		_formas[Vector2i(c[0], c[1])] = forma


## El Area2D de interacción: cubre todo el hueco más 24 px. El jugador la detecta (capa 2) y así
## INTERACTUAR funciona desde cualquier borde del objeto.
func _crear_area() -> void:
	var area := Area2D.new()
	area.name = "AreaInteraccion"
	area.collision_layer = 2
	area.collision_mask = 0
	var forma := CollisionShape2D.new()
	var rectangulo := RectangleShape2D.new()
	rectangulo.size = _rect.size
	forma.shape = rectangulo
	forma.position = _rect.get_center() - position
	area.add_child(forma)
	add_child(area)


func _crear_sprite() -> void:
	if tipo == "puente":
		return   # el puente y el barranco se dibujan en RavinaCompuerta (a ras de suelo, bajo el jugador)
	var ruta := FRAMES_ROCA if tipo == "roca" else FRAMES_ZARZAL
	_sprite = AnimatedSprite2D.new()
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.sprite_frames = load(ruta)
	_sprite.animation = &"inicial"
	_sprite.centered = false
	if tipo == "roca":
		_sprite.offset = Vector2(-64, -118)
		_sprite.scale = Vector2(1.7, 1.7)
	else:
		_sprite.offset = Vector2(-64, -126)
		_sprite.scale = Vector2(1.6, 1.6)
		_luz = PointLight2D.new()
		_luz.texture = Atmosfera.crear_textura_luz(128)
		_luz.texture_scale = 1.6
		_luz.color = Color("ffcf8a")
		_luz.energy = 0.0
		_luz.position = Vector2(0, -60)
		add_child(_luz)
	add_child(_sprite)


func _crear_icono() -> void:
	_icono = Node2D.new()
	_icono.z_index = 20
	var alto := _rect.size.y
	_icono.position = Vector2(0, -(alto if tipo != "puente" else alto / 2.0) - 22.0) + Vector2(0, -20.0 if tipo == "puente" else 0.0)
	_icono.draw.connect(_dibujar_icono)
	add_child(_icono)


## Qué grupos de habilidad cumple mientras está cerrada.
func _unir_a_grupos(unir: bool) -> void:
	var grupo := "reparable" if tipo == "puente" else ("rompible" if tipo == "roca" else "sombra")
	if unir:
		add_to_group(grupo)
	else:
		remove_from_group(grupo)


# --- Detección ---

## ¿Está el punto (global) dentro del área de interacción? Es lo que usan Reparar, Impulso y Visión.
func solapa_area(punto: Vector2) -> bool:
	return _rect.grow(4.0).has_point(punto)


## Distancia desde un punto al borde del área (0 si está dentro).
func distancia_al_area(punto: Vector2) -> float:
	var cerca := Vector2(clampf(punto.x, _rect.position.x, _rect.end.x), clampf(punto.y, _rect.position.y, _rect.end.y))
	return punto.distance_to(cerca)


## Los datos de la emoción que da la habilidad (para la pista y el color).
func datos_progresion() -> Dictionary:
	return Progresion.compuerta(id)


func _process(delta: float) -> void:
	_tiempo += delta
	var jugador := get_tree().get_first_node_in_group("player") as Node2D
	if jugador == null or esta_abierta or not is_visible_in_tree():
		_alpha_icono = 0.0
		_jugador_dentro = false
		return
	var distancia := distancia_al_area(jugador.global_position)
	if distancia < DISTANCIA_ICONO:
		GameState.marcar_compuerta_vista(id)   # a partir de aquí sus conexiones se ven en el diario
	_alpha_icono = move_toward(_alpha_icono, clampf((DISTANCIA_ICONO - distancia) / 50.0, 0.0, 1.0), delta * 3.0)
	_icono.queue_redraw()
	# Con la habilidad ya conseguida, se elige sola al acercarse (una vez por visita)
	var dentro := solapa_area(jugador.global_position)
	if dentro and not _jugador_dentro and GameState.tiene_habilidad(habilidad_requerida):
		Habilidades.seleccionar(habilidad_requerida)
	_jugador_dentro = dentro


func _dibujar_icono() -> void:
	if _alpha_icono <= 0.01 or esta_abierta:
		return
	var tiene := GameState.tiene_habilidad(habilidad_requerida)
	var flote := Vector2(0, sin(_tiempo * 3.0) * 2.5)
	# Medallón del color de la emoción
	_icono.draw_circle(flote, 15.0, Color(0.1, 0.08, 0.16, 0.85 * _alpha_icono))
	_icono.draw_arc(flote, 15.0, 0.0, TAU, 28, Color(_color, _alpha_icono), 2.0, true)
	if _iconos == null:
		return
	var indice := ORDEN_ICONOS.find(habilidad_requerida)
	if indice < 0:
		return
	var origen := Vector2((indice % 4) * 32, (indice / 4) * 32)
	var destino := Rect2(flote - Vector2(12, 12), Vector2(24, 24))
	# A color si ya tienes la habilidad; si no, en silueta oscura
	var tinte := Color(1, 1, 1, _alpha_icono) if tiene else Color(0.12, 0.1, 0.18, 0.9 * _alpha_icono)
	_icono.draw_texture_rect_region(_iconos, destino, Rect2(origen, Vector2(32, 32)), tinte)


# --- Interacción ---

func puede_interactuar() -> bool:
	return not esta_abierta and not Dialogo.hay_dialogo()


## INTERACTUAR: una pista amable con el nombre del obstáculo. Sube de nivel cada vez que se pide.
func interactuar() -> void:
	if not puede_interactuar():
		return
	GameState.marcar_compuerta_vista(id)
	var datos := Progresion.compuerta(id)
	if not GameState.tiene_habilidad(habilidad_requerida):
		Sonido.pista()   # la pista de un obstáculo cerrado sin la habilidad
	await Dialogo.mostrar_texto(str(datos.get("nombre", "")), GameState.pista_de_compuerta(id))


# --- Interfaces de habilidad ---

## "reparable" (puente): Reparar la llama al completar el anillo.
func reparar() -> void:
	if tipo == "puente":
		GameState.abrir_compuerta(id)


## "rompible" (roca): el Impulso la llama al tocarla.
func romper() -> void:
	if tipo == "roca":
		GameState.abrir_compuerta(id)


## "sombra" (zarzal): la Visión la abre (true). Una vez abierto no vuelve a cerrarse.
func visionar(activa: bool) -> void:
	if activa and tipo == "zarzal":
		GameState.abrir_compuerta(id)


## "sombra": el zarzal abierto ya no vuelve, así nadie queda atrapado.
func contiene_punto(_punto: Vector2, _margen: float = 0.0) -> bool:
	return false


# --- Abrir ---

func _on_compuerta_abierta(abierta_id: String) -> void:
	if abierta_id == id and not esta_abierta:
		_aplicar_abierta(true)


func _on_partida_reiniciada() -> void:
	# Nueva partida o carga: se vuelve a leer el estado (cerrada de nuevo o abierta según el guardado)
	if GameState.compuerta_esta_abierta(id) == esta_abierta:
		return
	esta_abierta = false
	for forma in _formas.values():
		Colisiones.apagar(forma, false)
	if _sprite != null:
		_sprite.animation = &"inicial"
		_sprite.modulate = Color.WHITE
		_sprite.scale = Vector2(1.7, 1.7) if tipo == "roca" else Vector2(1.6, 1.6)
	if _luz != null:
		_luz.energy = 0.0
	_unir_a_grupos(true)
	if GameState.compuerta_esta_abierta(id):
		_aplicar_abierta(false)


## Deja la compuerta abierta: la colisión se apaga (en el puente solo la del camino; los laterales del
## barranco siguen bloqueando) y se cambia el aspecto. `con_efecto` solo si se ve ahora mismo.
func _aplicar_abierta(con_efecto: bool) -> void:
	esta_abierta = true
	_unir_a_grupos(false)
	var paso_libre: Array[Vector2i] = []
	for c in paso:
		paso_libre.append(Vector2i(c[0], c[1]))
	for celda in _formas:
		if tipo != "puente" or paso_libre.has(celda):
			Colisiones.apagar(_formas[celda], true)
	var visible_ahora := con_efecto and is_visible_in_tree()
	var datos := Progresion.compuerta(id)
	if _sprite != null:
		_sprite.animation = &"resuelto"
	if tipo == "roca" and visible_ahora:
		Sonido.efecto("roca_rompe")
		_lanzar_pedazos()
		var t := create_tween()
		t.tween_property(_sprite, "scale", _sprite.scale * 1.06, 0.06)
		t.tween_property(_sprite, "scale", _sprite.scale, 0.12)
	elif tipo == "zarzal":
		if visible_ahora:
			Sonido.efecto("niebla_disipa")
			_sprite.modulate.a = 0.0
			var t2 := create_tween().set_parallel(true)
			t2.tween_property(_sprite, "modulate:a", 0.9, 0.7)
			t2.tween_property(_luz, "energy", 0.8, 0.7)
		else:
			_sprite.modulate.a = 0.9
			_luz.energy = 0.8
	elif tipo == "puente" and visible_ahora:
		Sonido.efecto("porton_repara")
	abierta.emit()
	if visible_ahora and str(datos.get("mensaje_abierta", "")) != "" and not Dialogo.hay_dialogo():
		Dialogo.mostrar_texto(str(datos.get("nombre", "")), str(datos["mensaje_abierta"]), [], null, true)


func _lanzar_pedazos() -> void:
	var p := CPUParticles2D.new()
	p.position = Vector2(0, -50)
	p.amount = 40
	p.one_shot = true
	p.explosiveness = 1.0
	p.lifetime = 0.9
	p.spread = 180.0
	p.direction = Vector2.UP
	p.gravity = Vector2(0, 160)
	p.initial_velocity_min = 50.0
	p.initial_velocity_max = 150.0
	p.scale_amount_min = 3.0
	p.scale_amount_max = 5.0
	var degradado := Gradient.new()
	degradado.set_color(0, Color("e8a14a"))
	degradado.set_color(1, Color(0.45, 0.4, 0.5, 0.0))
	p.color_ramp = degradado
	add_child(p)
	p.emitting = true
	get_tree().create_timer(1.2).timeout.connect(p.queue_free)
