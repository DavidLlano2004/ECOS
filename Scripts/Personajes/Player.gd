class_name Player
extends CharacterBody2D
## Jugador de ECOS: movimiento suave en 8 direcciones, interacción con objetos
## cercanos, sombra, burbuja de ayuda "E" y cámara.
##
## El origen del nodo está en los PIES del personaje (así funciona bien el y-sort).

## Se emite cuando cambia el objeto con el que se puede interactuar (puede ser null).
signal interactuable_cambiado(nodo: Node)

const RUTA_FUENTE := "res://Assets/PixelifySans-VariableFont_wght.ttf"

@export_group("Movimiento")
## Velocidad máxima en píxeles por segundo.
@export var velocidad: float = 70.0
## Qué tan rápido alcanza la velocidad máxima (px/s²).
@export var aceleracion: float = 600.0
## Qué tan rápido se frena al soltar las teclas (px/s²).
@export var friccion: float = 800.0

@export_group("Animación")
## Altura máxima del rebote al caminar (px).
@export var rebote_altura: float = 1.5
## Rebotes por segundo (uno por paso; la animación de caminar va a 8 FPS).
@export var rebote_velocidad: float = 4.0

@export_group("Ayuda")
## Dónde flota la burbuja "E" respecto al objeto activo.
@export var desplazamiento_ayuda: Vector2 = Vector2(0, -44)

## Última dirección de movimiento, normalizada. Vergüenza la usa para saber hacia dónde mira el jugador.
var facing: Vector2 = Vector2.DOWN

## true si el jugador puede moverse e interactuar. Se puede asignar directamente
## (can_move = false) o con bloquear() / liberar(). También se bloquea solo mientras hay un diálogo.
var can_move: bool:
	get:
		return not _bloqueado and not _dialogo_abierto
	set(valor):
		_bloqueado = not valor

## Objetos interactuables que están dentro de la zona.
var interactuables: Array[Node] = []
## El objeto con el que se interactuaría ahora (el más cercano que lo permita).
var activo: Node = null

var _bloqueado := false
var _dialogo_abierto := false
var _tiempo_rebote := 0.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var zona: Area2D = $ZonaInteraccion
@onready var camara: Camera2D = $Camera2D
@onready var burbuja: Node2D = $BurbujaAyuda
@onready var panel_burbuja: PanelContainer = $BurbujaAyuda/Panel
@onready var etiqueta_burbuja: Label = $BurbujaAyuda/Panel/Etiqueta


func _ready() -> void:
	add_to_group("player")
	# Solo el nodo Objetos de cada época ordena en Y: el jugador es un elemento más (sus hijos, como
	# el sprite que está 29 px más arriba de los pies, no deben ordenarse por su cuenta).
	y_sort_enabled = false
	_aplicar_estilo_burbuja()
	burbuja.hide()

	zona.area_entered.connect(_on_zona_area_entrada)
	zona.area_exited.connect(_on_zona_area_salida)
	zona.body_entered.connect(_on_zona_cuerpo_entrada)
	zona.body_exited.connect(_on_zona_cuerpo_salida)

	# Se bloquea mientras haya un diálogo abierto
	Dialogo.dialogo_abierto.connect(func() -> void: _dialogo_abierto = true)
	Dialogo.dialogo_cerrado.connect(func() -> void: _dialogo_abierto = false)
	_dialogo_abierto = Dialogo.hay_dialogo()

	_actualizar_animacion(false)


func _physics_process(delta: float) -> void:
	if can_move:
		var direccion := Input.get_vector("IZQUIERDA", "DERECHA", "ARRIBA", "ABAJO")
		if direccion != Vector2.ZERO:
			facing = direccion.normalized()
		# Aceleración suave al moverse, fricción suave al soltar
		var cambio := aceleracion if direccion != Vector2.ZERO else friccion
		velocity = velocity.move_toward(direccion * velocidad, cambio * delta)
	else:
		velocity = Vector2.ZERO

	move_and_slide()
	_actualizar_animacion(velocity.length() > 5.0, delta)
	_actualizar_activo()


func _process(_delta: float) -> void:
	_actualizar_burbuja()


func _unhandled_input(evento: InputEvent) -> void:
	if not can_move:
		return
	# Con _unhandled_input, el diálogo puede "comerse" la tecla sin que el jugador la use también
	if evento.is_action_pressed("INTERACTUAR") and activo != null:
		get_viewport().set_input_as_handled()
		activo.interactuar()
	elif evento.is_action_pressed("VIAJAR"):
		# Solo viaja si está dentro de la zona de un portal o de una grieta
		for nodo in interactuables:
			if is_instance_valid(nodo) and nodo.is_in_group("portales"):
				get_viewport().set_input_as_handled()
				nodo.interactuar()
				break
	elif evento.is_action_pressed("HABILIDAD"):
		usar_habilidad()


# --- Bloqueo ---

## Impide que el jugador se mueva e interactúe (por ejemplo, en una cinemática).
func bloquear() -> void:
	_bloqueado = true


## Devuelve el control al jugador. No lo libera si todavía hay un diálogo abierto.
func liberar() -> void:
	_bloqueado = false


# --- Habilidades ---

## Gancho para las habilidades (Impulso, Visión, Calma, Vínculo, Reparar, Pausa, Revelar).
## Se llama al pulsar la acción HABILIDAD. Todavía no hace nada: se implementará
## consultando GameState.tiene_habilidad(id).
func usar_habilidad() -> void:
	pass


# --- Cámara ---

## Limita hasta dónde puede mostrar la cámara (usar con el rectángulo del mapa, en píxeles).
func establecer_limites(rect: Rect2) -> void:
	camara.limit_left = int(rect.position.x)
	camara.limit_top = int(rect.position.y)
	camara.limit_right = int(rect.end.x)
	camara.limit_bottom = int(rect.end.y)


# --- Animación ---

## Nombre de la animación según hacia dónde mira el jugador.
func _animacion_actual() -> StringName:
	if absf(facing.x) >= absf(facing.y):
		return &"walk_right" if facing.x > 0.0 else &"walk_left"
	return &"walk_down" if facing.y > 0.0 else &"walk_up"


func _actualizar_animacion(caminando: bool, delta: float = 0.0) -> void:
	var anim := _animacion_actual()
	if sprite.animation != anim:
		sprite.animation = anim
	if caminando:
		if not sprite.is_playing():
			sprite.play(anim)
		# Rebote vertical leve, siempre hacia arriba
		_tiempo_rebote += delta * rebote_velocidad
		sprite.offset.y = -absf(sin(_tiempo_rebote * PI)) * rebote_altura
	else:
		# Quieto: primer cuadro de la dirección actual
		sprite.stop()
		sprite.frame = 0
		_tiempo_rebote = 0.0
		sprite.offset.y = move_toward(sprite.offset.y, 0.0, 20.0 * delta)


# --- Sombra ---

## Elipse oscura translúcida bajo los pies (se dibuja antes que los hijos, o sea, debajo del sprite).
func _draw() -> void:
	draw_set_transform(Vector2(0, -1), 0.0, Vector2(1.0, 0.4))
	draw_circle(Vector2.ZERO, 11.0, Color(0, 0, 0, 0.3))


# --- Interacción ---

## Devuelve el nodo interactuable que corresponde a un área o cuerpo, o null.
func _resolver_interactuable(nodo: Node) -> Node:
	if nodo.has_method("interactuar"):
		return nodo
	var padre := nodo.get_parent()
	if padre != null and padre != self and padre.has_method("interactuar"):
		return padre
	return null


func _agregar_interactuable(nodo: Node) -> void:
	var objetivo := _resolver_interactuable(nodo)
	if objetivo != null and not interactuables.has(objetivo):
		interactuables.append(objetivo)


func _quitar_interactuable(nodo: Node) -> void:
	var objetivo := _resolver_interactuable(nodo)
	if objetivo != null:
		interactuables.erase(objetivo)


func _on_zona_area_entrada(area: Area2D) -> void:
	_agregar_interactuable(area)


func _on_zona_area_salida(area: Area2D) -> void:
	_quitar_interactuable(area)


func _on_zona_cuerpo_entrada(cuerpo: Node2D) -> void:
	_agregar_interactuable(cuerpo)


func _on_zona_cuerpo_salida(cuerpo: Node2D) -> void:
	_quitar_interactuable(cuerpo)


## Elige el interactuable más cercano que permita interactuar ahora.
func _actualizar_activo() -> void:
	var mejor: Node = null
	var mejor_distancia := INF
	for nodo in interactuables.duplicate():
		if not is_instance_valid(nodo):
			interactuables.erase(nodo)
			continue
		# Si no tiene puede_interactuar(), se asume que sí se puede
		if nodo.has_method("puede_interactuar") and not nodo.puede_interactuar():
			continue
		var distancia := 0.0
		if nodo is Node2D:
			distancia = global_position.distance_to(nodo.global_position)
		if distancia < mejor_distancia:
			mejor_distancia = distancia
			mejor = nodo
	if mejor != activo:
		activo = mejor
		interactuable_cambiado.emit(activo)


# --- Burbuja de ayuda ("E") ---

func _aplicar_estilo_burbuja() -> void:
	var caja := StyleBoxFlat.new()
	caja.bg_color = Color("1e1b2e", 0.95)
	caja.border_color = Color("f4c77b")
	caja.set_border_width_all(1)
	caja.set_corner_radius_all(3)
	caja.content_margin_left = 5
	caja.content_margin_right = 5
	caja.content_margin_top = 1
	caja.content_margin_bottom = 1
	panel_burbuja.add_theme_stylebox_override("panel", caja)
	if ResourceLoader.exists(RUTA_FUENTE):
		etiqueta_burbuja.add_theme_font_override("font", load(RUTA_FUENTE))
	etiqueta_burbuja.add_theme_font_size_override("font_size", 12)
	etiqueta_burbuja.add_theme_color_override("font_color", Color("f4c77b"))


## Muestra la burbuja sobre el objeto activo, flotando suavemente.
func _actualizar_burbuja() -> void:
	var visible_ahora := activo != null and is_instance_valid(activo) and can_move
	burbuja.visible = visible_ahora
	if not visible_ahora:
		return
	var base := global_position
	if activo is Node2D:
		base = activo.global_position
	var flote := sin(Time.get_ticks_msec() / 1000.0 * 4.0) * 2.0
	burbuja.global_position = (base + desplazamiento_ayuda + Vector2(0, flote)).round()
	# Centra el panel sobre ese punto
	panel_burbuja.position = -panel_burbuja.size / 2.0
