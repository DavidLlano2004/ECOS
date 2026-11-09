class_name BloqueoPresente
extends StaticBody2D
## Bloqueo de una emoción en el Presente. Cierra el camino de la zona (unos 96 px de ancho) y
## siempre refleja lo que decidiste en el Pasado (se lee de GameState.estado cada vez que se
## entra al Presente, y al instante si el estado cambia estando en él):
##
##   integrada -> se abre (una vez), sin colisión, y aparece la criatura ALIADA con su animación "calma"
##   atacada   -> bloqueo rojizo oscuro, partículas amenazantes y vibración
##   ignorada  -> bloqueo más grande (1.15), más oscuro y con más niebla
##   pendiente -> bloqueo normal
##
## Vive en el nodo Presente. Mundo lo crea con `datos` y `direccion` (hacia dónde sigue el camino).

## Largo de la barrera que cierra el camino (px).
const ANCHO_CAMINO := 96.0
## Punto de apoyo del dibujo (96x96, centrado y casi en el borde de abajo).
const APOYO := Vector2(48, 92)
const RUTA_FRAMES := "res://Resources/Mundo/frames_bloqueo_%s.tres"
const SEGUNDOS_ESPERA_VIAJE := 0.55

const TINTE_ATACADA := Color(0.8, 0.34, 0.34)
const TINTE_IGNORADA := Color(0.5, 0.5, 0.62)
const ESCALA_IGNORADA := 1.15

## Cierre de cada mensaje: invita a volver al Pasado, sin sermonear.
const INVITACION := {
	"pendiente": "Quizá en el Pasado haya algo que atender. Puedes volver cuando quieras.",
	"atacada": "Todavía se puede intentar de otra forma. El Pasado sigue ahí.",
	"ignorada": "El Pasado sigue esperando. Puedes volver cuando quieras.",
}

@export var datos: EmocionData
## Hacia dónde sigue el camino (hacia el centro de la zona). La barrera se coloca de lado a esa dirección.
@export var direccion: Vector2 = Vector2.UP

## Estado que se está mostrando: "" (aún ninguno), "pendiente", "atacada", "ignorada" o "integrada".
var estado_mostrado: String = ""

@onready var _sprite: AnimatedSprite2D = $Sprite
@onready var _forma: CollisionShape2D = $Forma
@onready var _forma_zona: CollisionShape2D = $Zona/Forma
@onready var _particulas: CPUParticles2D = $Particulas
@onready var _niebla: CPUParticles2D = $Niebla

var _aliada: Node2D
var _ocupado := false
var _tiempo := 0.0
var _vibra := false
var _version := 0   # cambia con cada actualización, para cancelar animaciones que ya no valen


func _ready() -> void:
	add_to_group("bloqueos_presente")
	if datos == null:
		push_warning("BloqueoPresente '%s': falta asignar 'datos' (EmocionData)." % name)
		return
	var ruta := RUTA_FRAMES % datos.id
	if ResourceLoader.exists(ruta):
		_sprite.sprite_frames = load(ruta)
	else:
		push_warning("BloqueoPresente: falta la hoja de '%s'; se usa un marcador temporal." % datos.id)
		_sprite.sprite_frames = load(RUTA_FRAMES % "rabia")
		_sprite.modulate = datos.color
	_sprite.centered = false
	_sprite.offset = -APOYO

	# Barrera de lado a lado del camino (capa 1 = mundo)
	var barrera := RectangleShape2D.new()
	barrera.size = Vector2(ANCHO_CAMINO, 22.0)
	_forma.shape = barrera
	_forma.position = Vector2(0, -8)
	_forma.rotation = direccion.angle() + PI / 2.0

	# Zona de interacción (capa 2)
	var circulo := CircleShape2D.new()
	circulo.radius = 62.0
	_forma_zona.shape = circulo
	_forma_zona.position = Vector2(0, -16)

	_preparar_particulas()
	GameState.epoca_cambiada.connect(_on_epoca_cambiada)
	GameState.emocion_resuelta.connect(_on_emocion_resuelta)
	actualizar(false)


func _process(delta: float) -> void:
	_tiempo += delta
	if _vibra:
		_sprite.offset = -APOYO + Vector2(randf_range(-1.0, 1.0), randf_range(-0.6, 0.6)) * 1.3


## Al entrar al Presente se vuelve a leer el estado (cuando el efecto del viaje ya se está yendo).
func _on_epoca_cambiada(epoca: String) -> void:
	if epoca == "presente":
		actualizar.call_deferred(true, SEGUNDOS_ESPERA_VIAJE)


## Si el estado cambia estando en el Presente, el bloqueo se actualiza al instante.
func _on_emocion_resuelta(id: String, _resultado: String) -> void:
	if datos != null and id == datos.id and can_process():
		actualizar(true)


## Lee GameState.estado[id] y deja el bloqueo como corresponde.
## animar: si cambia a "integrada" se reproduce la apertura (con `espera` segundos de retraso antes).
func actualizar(animar: bool = true, espera: float = 0.0) -> void:
	if datos == null:
		return
	var nuevo: String = GameState.estado.get(datos.id, "pendiente")
	if nuevo == estado_mostrado:
		return
	var anterior := estado_mostrado
	estado_mostrado = nuevo
	_version += 1
	var version := _version
	_quitar_aliada()
	_vibra = false
	_sprite.offset = -APOYO
	# La colisión cambia al momento (cerrada salvo si está integrada)
	_poner_colision(nuevo != "integrada")
	_configurar_particulas(nuevo)
	match nuevo:
		"integrada":
			await _abrir(animar and anterior != "", espera, version)
		"atacada":
			_mostrar_bloqueo(TINTE_ATACADA, 1.0)
			_vibra = true
		"ignorada":
			_mostrar_bloqueo(TINTE_IGNORADA, ESCALA_IGNORADA)
		_:
			_mostrar_bloqueo(Color.WHITE, 1.0)


func puede_interactuar() -> bool:
	return estado_mostrado != "integrada" and not _ocupado


## Lo que dice el bloqueo (según el estado) y el cierre que invita a volver al Pasado.
func lineas_de_mensaje() -> Array:
	var texto := datos.mensaje_presente_bloqueo
	match estado_mostrado:
		"atacada":
			texto = datos.mensaje_presente_atacada if datos.mensaje_presente_atacada != "" else datos.mensaje_presente_bloqueo
		"ignorada":
			texto = datos.mensaje_presente_ignorada if datos.mensaje_presente_ignorada != "" else datos.mensaje_presente_bloqueo
	var lineas: Array = [texto]
	# Los mensajes que ya invitan a volver al Pasado no necesitan repetirlo
	if not texto.contains("Pasado"):
		lineas.append(INVITACION.get(estado_mostrado, INVITACION["pendiente"]))
	return lineas


func interactuar() -> void:
	if not puede_interactuar():
		return
	_ocupado = true
	await Dialogo.mostrar_texto("", lineas_de_mensaje())
	_ocupado = false


# --- Estados ---

func _mostrar_bloqueo(tinte: Color, escala: float) -> void:
	_sprite.modulate = tinte
	_sprite.scale = Vector2(escala, escala)
	_sprite.play(&"bloqueo")


## Apertura: una vez, con partículas del color de la emoción; luego aparece la forma aliada.
func _abrir(con_animacion: bool, espera: float, version: int) -> void:
	_sprite.modulate = Color.WHITE
	_sprite.scale = Vector2.ONE
	if con_animacion:
		if espera > 0.0:
			await get_tree().create_timer(espera).timeout
			if version != _version:
				return
		if _sprite.sprite_frames.has_animation(&"abriendo"):
			_sprite.play(&"abriendo")
			await _sprite.animation_finished
			if version != _version:
				return
		_chorro_de_particulas()
	_sprite.play(&"abierto")
	_aparecer_aliada(con_animacion)


func _poner_colision(activa: bool) -> void:
	# Mundo apaga y enciende las formas de la época oculta guardando este valor
	_forma.set_meta("ecos_apagada", not activa)
	if can_process():
		_forma.set_deferred("disabled", not activa)


func _aparecer_aliada(con_animacion: bool) -> void:
	var lado := direccion.orthogonal()
	_aliada = AliadaPresente.new()
	_aliada.name = "Aliada"
	_aliada.position = lado * 62.0
	add_child(_aliada)
	_aliada.preparar(datos)
	if con_animacion:
		_aliada.modulate.a = 0.0
		create_tween().tween_property(_aliada, "modulate:a", 1.0, 0.8)


func _quitar_aliada() -> void:
	if _aliada != null and is_instance_valid(_aliada):
		_aliada.queue_free()
	_aliada = null


# --- Partículas ---

func _preparar_particulas() -> void:
	var punto := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	punto.fill(Color.WHITE)
	_particulas.texture = ImageTexture.create_from_image(punto)
	_particulas.position = Vector2(0, -40)
	_particulas.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_particulas.emission_rect_extents = Vector2(40, 28)
	_particulas.local_coords = false
	_niebla.texture = Atmosfera.crear_textura_luz(32)
	_niebla.position = Vector2(0, -22)
	_niebla.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_niebla.emission_rect_extents = Vector2(46, 14)
	_niebla.local_coords = false


## Partículas de cada estado: amenazantes si fue atacada, niebla si fue ignorada, motas tenues si está pendiente.
func _configurar_particulas(estado: String) -> void:
	_particulas.one_shot = false
	_particulas.explosiveness = 0.0
	_particulas.emitting = false
	_niebla.emitting = false
	if estado == "integrada":
		return
	var degradado := Gradient.new()
	_particulas.direction = Vector2(0, -1)
	_particulas.spread = 25.0
	_particulas.gravity = Vector2.ZERO
	_particulas.lifetime = 1.4
	match estado:
		"atacada":
			# Brasas rojas que suben deprisa y se agitan
			_particulas.amount = 28
			_particulas.initial_velocity_min = 25.0
			_particulas.initial_velocity_max = 55.0
			_particulas.spread = 50.0
			_particulas.scale_amount_min = 1.0
			_particulas.scale_amount_max = 2.0
			degradado.offsets = PackedFloat32Array([0.0, 0.2, 1.0])
			degradado.colors = PackedColorArray([Color(1.0, 0.3, 0.2, 0.0), Color(1.0, 0.3, 0.2, 0.9), Color(0.5, 0.05, 0.1, 0.0)])
		"ignorada":
			_particulas.amount = 10
			_particulas.initial_velocity_min = 2.0
			_particulas.initial_velocity_max = 6.0
			_particulas.scale_amount_min = 1.0
			_particulas.scale_amount_max = 1.5
			degradado.offsets = PackedFloat32Array([0.0, 0.3, 1.0])
			degradado.colors = PackedColorArray([Color(0.6, 0.6, 0.75, 0.0), Color(0.6, 0.6, 0.75, 0.5), Color(0.4, 0.4, 0.55, 0.0)])
			# Más niebla: nubes grandes y suaves que se arrastran
			_configurar_niebla(true)
		_:
			_particulas.amount = 8
			_particulas.initial_velocity_min = 3.0
			_particulas.initial_velocity_max = 8.0
			_particulas.scale_amount_min = 1.0
			_particulas.scale_amount_max = 1.5
			degradado.offsets = PackedFloat32Array([0.0, 0.3, 1.0])
			degradado.colors = PackedColorArray([Color(datos.color, 0.0), Color(datos.color, 0.55), Color(datos.color, 0.0)])
	_particulas.color_ramp = degradado
	_particulas.emitting = true


func _configurar_niebla(activa: bool) -> void:
	var degradado := Gradient.new()
	degradado.offsets = PackedFloat32Array([0.0, 0.4, 1.0])
	degradado.colors = PackedColorArray([Color(0.5, 0.5, 0.6, 0.0), Color(0.5, 0.5, 0.6, 0.28), Color(0.5, 0.5, 0.6, 0.0)])
	_niebla.color_ramp = degradado
	_niebla.amount = 14
	_niebla.lifetime = 4.0
	_niebla.direction = Vector2(1, 0)
	_niebla.spread = 180.0
	_niebla.gravity = Vector2.ZERO
	_niebla.initial_velocity_min = 3.0
	_niebla.initial_velocity_max = 8.0
	_niebla.scale_amount_min = 2.0
	_niebla.scale_amount_max = 3.5
	_niebla.emitting = activa


## Chorro de partículas del color de la emoción al abrirse (una sola vez).
func _chorro_de_particulas() -> void:
	var degradado := Gradient.new()
	degradado.offsets = PackedFloat32Array([0.0, 0.15, 1.0])
	degradado.colors = PackedColorArray([Color(datos.color, 0.0), Color(datos.color.lightened(0.3), 1.0), Color(datos.color, 0.0)])
	_particulas.color_ramp = degradado
	_particulas.amount = 46
	_particulas.lifetime = 1.4
	_particulas.one_shot = true
	_particulas.explosiveness = 0.95
	_particulas.direction = Vector2(0, -1)
	_particulas.spread = 180.0
	_particulas.initial_velocity_min = 25.0
	_particulas.initial_velocity_max = 70.0
	_particulas.gravity = Vector2(0, 30)
	_particulas.scale_amount_min = 1.5
	_particulas.scale_amount_max = 2.5
	_particulas.restart()
	_particulas.emitting = true
