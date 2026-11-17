class_name EfectoVision
extends Node2D
## Efecto de la habilidad Visión (Miedo). Cuelga del jugador y contiene:
##  - una PointLight2D grande y suave (unos 120 px) con textura radial creada por código,
##  - un leve tinte violeta de claridad en pantalla (shader sobre un CanvasLayer),
##  - el manejo de los nodos del grupo "sombra": los cercanos reciben visionar(true) y al apagar
##    la Visión, visionar(false).
## Si se apaga la Visión con el jugador dentro de una zona de sombra, la zona no se cierra hasta que
## el jugador salga: se le empuja con suavidad al punto libre más cercano sin atravesar muros.

const RADIO_LUZ := 120.0
## Nivel 2 (cofre de Miedo): la luz llega más lejos.
const RADIO_LUZ_NIVEL_2 := 180.0
const TAMANO_TEXTURA := 256
const ENERGIA_LUZ := 0.85
const COLOR_LUZ := Color(0.78, 0.65, 1.0)
## Hasta dónde llega el efecto sobre las zonas de sombra, además de su propio `radio_sombra`.
const ALCANCE_SOMBRA := 140.0
const VELOCIDAD_EMPUJE := 90.0
const MARGEN_SALIDA := 12.0
const RUTA_SHADER := "res://Shaders/vision.gdshader"

var jugador: Player
var encendida := false

var _luz: PointLight2D
var _capa: CanvasLayer
var _rect: ColorRect
var _material: ShaderMaterial
var _tween: Tween
var _abiertas: Array[Node] = []     # zonas de sombra que ahora mismo tienen visionar(true)
var _destino_salida := Vector2.INF  # a dónde se empuja al jugador al apagar dentro de una zona

## 0 a 1: cuánto se nota el efecto (luz y tinte).
var fuerza := 0.0:
	set(valor):
		fuerza = valor
		if _luz != null:
			_luz.energy = ENERGIA_LUZ * valor
			_luz.visible = valor > 0.001
		if _material != null:
			_material.set_shader_parameter("fuerza", valor)
		if _rect != null:
			_rect.visible = valor > 0.001


## El radio de la luz según el nivel de la Visión.
static func radio_luz() -> float:
	return RADIO_LUZ_NIVEL_2 if Habilidades.nivel_de("vision") >= 2 else RADIO_LUZ


func _ready() -> void:
	_luz = PointLight2D.new()
	_luz.texture = Atmosfera.crear_textura_luz(TAMANO_TEXTURA)
	_luz.texture_scale = radio_luz() * 2.0 / TAMANO_TEXTURA
	_luz.color = COLOR_LUZ
	_luz.position = Vector2(0, -16)
	_luz.visible = false
	add_child(_luz)

	_capa = CanvasLayer.new()
	_capa.layer = 2  # sobre el mundo y bajo la viñeta (4), el HUD (5) y los diálogos
	_rect = ColorRect.new()
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_material = ShaderMaterial.new()
	_material.shader = load(RUTA_SHADER)
	_rect.material = _material
	_rect.visible = false
	_capa.add_child(_rect)
	add_child(_capa)
	fuerza = 0.0


func _exit_tree() -> void:
	# Si el efecto desaparece (nueva partida...), las zonas no se quedan abiertas
	for zona in _abiertas:
		if is_instance_valid(zona):
			zona.visionar(false)
	_abiertas.clear()


## Enciende la Visión (también cancela una salida pendiente).
func encender() -> void:
	encendida = true
	_destino_salida = Vector2.INF
	_animar_fuerza(1.0, 0.35)


## Apaga la Visión. Las zonas de sombra se cierran enseguida, salvo las que rodean al jugador.
func apagar() -> void:
	encendida = false
	_animar_fuerza(0.0, 0.5)
	_destino_salida = _buscar_punto_libre() if _jugador_en_alguna_zona() else Vector2.INF
	_cerrar_zonas_libres()


func esta_saliendo() -> bool:
	return not encendida and not _abiertas.is_empty()


func _animar_fuerza(destino: float, segundos: float) -> void:
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "fuerza", destino, segundos)


## Cambia el radio de la luz (por si la Visión sube de nivel con el efecto ya creado).
func set_radio(radio: float) -> void:
	if _luz != null:
		_luz.texture_scale = radio * 2.0 / TAMANO_TEXTURA


func _physics_process(delta: float) -> void:
	if jugador == null or not is_instance_valid(jugador):
		return
	if encendida:
		_actualizar_zonas()
	elif not _abiertas.is_empty():
		_paso_salida(delta)


# --- Zonas de sombra ---

## Abre las zonas cercanas y cierra las que quedaron lejos (si el jugador no está dentro).
func _actualizar_zonas() -> void:
	for nodo in get_tree().get_nodes_in_group("sombra"):
		if not (nodo is Node2D) or not nodo.has_method("visionar") or not nodo.is_visible_in_tree():
			continue  # lo de la época oculta no se ve ni se toca
		var cerca := _alcance_a(nodo) <= 0.0
		if cerca and not _abiertas.has(nodo):
			nodo.visionar(true)
			_abiertas.append(nodo)
		elif not cerca and _abiertas.has(nodo) and not _jugador_dentro(nodo):
			nodo.visionar(false)
			_abiertas.erase(nodo)
	for i in range(_abiertas.size() - 1, -1, -1):
		if not is_instance_valid(_abiertas[i]):
			_abiertas.remove_at(i)


## Cuánto falta para estar al alcance de una zona (<= 0: está al alcance).
func _alcance_a(nodo: Node2D) -> float:
	# Una compuerta se mide por su área (cubre todo el objeto), no por su origen
	if nodo.has_method("solapa_area") and nodo.solapa_area(jugador.global_position):
		return -1.0
	var extra := float(nodo.get("radio_sombra")) if "radio_sombra" in nodo else 0.0
	return jugador.global_position.distance_to(nodo.global_position) - (ALCANCE_SOMBRA + extra)


## true si el punto está dentro de la zona (con un margen para que quepa el cuerpo del jugador).
func _jugador_dentro(zona: Node, margen: float = MARGEN_SALIDA) -> bool:
	return zona.has_method("contiene_punto") and zona.contiene_punto(jugador.global_position, margen)


func _jugador_en_alguna_zona() -> bool:
	for zona in _abiertas:
		if is_instance_valid(zona) and _jugador_dentro(zona):
			return true
	return false


## Cierra (visionar(false)) las zonas abiertas que no tienen al jugador dentro.
func _cerrar_zonas_libres() -> void:
	for zona in _abiertas.duplicate():
		if not is_instance_valid(zona):
			_abiertas.erase(zona)
		elif not _jugador_dentro(zona):
			zona.visionar(false)
			_abiertas.erase(zona)


## Con la Visión apagada: empuja al jugador despacio hacia el punto libre y cierra cada zona
## en cuanto él sale de ella.
func _paso_salida(delta: float) -> void:
	_cerrar_zonas_libres()
	if _abiertas.is_empty() or _destino_salida == Vector2.INF:
		return
	var hacia := _destino_salida - jugador.global_position
	if hacia.length() < 1.0:
		_destino_salida = Vector2.INF
		return
	var choque := jugador.move_and_collide(hacia.normalized() * minf(VELOCIDAD_EMPUJE * delta, hacia.length()))
	if choque != null:
		_destino_salida = Vector2.INF  # algo lo frena: que salga caminando


## El punto libre más cercano al jugador: fuera de las zonas abiertas, sin muros encima y
## con el camino hasta él despejado (así nunca se atraviesa una pared).
func _buscar_punto_libre() -> Vector2:
	var espacio := get_world_2d().direct_space_state
	var origen := jugador.global_position
	var cuerpo: CollisionShape2D = jugador.get_node_or_null("CollisionShape2D")
	for radio in range(12, 161, 8):
		for i in 16:
			var punto := origen + Vector2.from_angle(TAU * i / 16.0) * radio
			if _punto_en_zonas(punto):
				continue
			# camino despejado
			var rayo := PhysicsRayQueryParameters2D.create(origen, punto, 1, [jugador.get_rid()])
			if not espacio.intersect_ray(rayo).is_empty():
				continue
			# el cuerpo del jugador cabe en ese punto
			if cuerpo != null:
				var consulta := PhysicsShapeQueryParameters2D.new()
				consulta.shape = cuerpo.shape
				consulta.transform = Transform2D(0.0, punto + cuerpo.position)
				consulta.collision_mask = 1
				consulta.exclude = [jugador.get_rid()]
				if not espacio.intersect_shape(consulta, 1).is_empty():
					continue
			return punto
	return Vector2.INF


func _punto_en_zonas(punto: Vector2) -> bool:
	for zona in _abiertas:
		if is_instance_valid(zona) and zona.has_method("contiene_punto") and zona.contiene_punto(punto, MARGEN_SALIDA):
			return true
	return false
