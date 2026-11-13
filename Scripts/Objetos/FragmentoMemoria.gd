class_name FragmentoMemoria
extends Area2D
## Fragmento de memoria: un cristal que brilla y custodia un recuerdo de infancia. Se recoge con
## INTERACTUAR o simplemente tocándolo. Al recogerlo: destello, se registra en GameState (con su
## recuerdo en el diario) y se abre el recuerdo en un globo de diálogo. Hay siete, uno por emoción.
## Origen del nodo: la base del cristal.

## Se emite al recogerlo (además de GameState.fragmento_recogido).
signal recogido(id: String)

## El id de la emoción a la que pertenece ("rabia", "miedo"...).
@export var id := ""

@onready var _sprite: AnimatedSprite2D = $Sprite
@onready var _forma: CollisionShape2D = $Forma

var _luz: PointLight2D
var _chispas: CPUParticles2D
var _recogido := false
var _tiempo := 0.0


func _ready() -> void:
	add_to_group("fragmentos")
	# Zona pequeña: se recoge al tocarlo (cuerpo del jugador, capa 1) o con INTERACTUAR (capa 2)
	var circulo := CircleShape2D.new()
	circulo.radius = 16.0
	_forma.shape = circulo
	_forma.position = Vector2(0, -8)
	_sprite.animation = &"resuelto"  # el cristal dorado y brillante
	_luz = PointLight2D.new()
	_luz.texture = Atmosfera.crear_textura_luz(128)
	_luz.texture_scale = 0.9
	_luz.color = Color("ffd77a")
	_luz.energy = 0.9
	_luz.position = Vector2(0, -10)
	add_child(_luz)
	_preparar_chispas()
	body_entered.connect(_on_cuerpo_entra)
	_tiempo = randf() * TAU


func _process(delta: float) -> void:
	if _recogido:
		return
	_tiempo += delta
	_sprite.position.y = sin(_tiempo * 2.0) * 2.0           # flota
	_luz.energy = 0.85 + sin(_tiempo * 3.0) * 0.2           # late


# --- Interacción (la usa Player con INTERACTUAR) ---

func puede_interactuar() -> bool:
	return not _recogido


func interactuar() -> void:
	_recoger()


func _on_cuerpo_entra(cuerpo: Node2D) -> void:
	if cuerpo.is_in_group("player"):
		_recoger()


func _recoger() -> void:
	if _recogido:
		return
	_recogido = true
	GameState.recoger_fragmento(id)
	recogido.emit(id)
	Colisiones.apagar(_forma, true)
	_chispas.emitting = false
	_destello()
	# El recuerdo se abre en un globo de diálogo (el jugador se bloquea solo mientras dura)
	var recuerdo := GameState.obtener_recuerdo(id)
	if recuerdo != null and not recuerdo.lineas.is_empty():
		await get_tree().create_timer(0.35).timeout
		await Dialogo.mostrar_texto("Recuerdo", Array(recuerdo.lineas))
	queue_free()


## Destello al recogerlo: luz que sube y se apaga, ráfaga de chispas y el cristal que se desvanece.
func _destello() -> void:
	var rafaga := CPUParticles2D.new()
	rafaga.position = Vector2(0, -10)
	rafaga.amount = 28
	rafaga.one_shot = true
	rafaga.explosiveness = 1.0
	rafaga.lifetime = 0.9
	rafaga.spread = 180.0
	rafaga.direction = Vector2.UP
	rafaga.gravity = Vector2.ZERO
	rafaga.initial_velocity_min = 40.0
	rafaga.initial_velocity_max = 110.0
	rafaga.scale_amount_min = 1.5
	rafaga.scale_amount_max = 3.0
	var degradado := Gradient.new()
	degradado.set_color(0, Color("fff2b0"))
	degradado.set_color(1, Color(1.0, 0.8, 0.3, 0.0))
	rafaga.color_ramp = degradado
	add_child(rafaga)
	rafaga.emitting = true
	var t := create_tween().set_parallel(true)
	t.tween_property(_luz, "energy", 3.2, 0.12)
	t.tween_property(_luz, "texture_scale", 2.4, 0.5)
	t.chain().tween_property(_luz, "energy", 0.0, 0.8)
	t.parallel().tween_property(_sprite, "scale", _sprite.scale * 1.8, 0.35)
	t.parallel().tween_property(_sprite, "modulate:a", 0.0, 0.35)


func _preparar_chispas() -> void:
	_chispas = CPUParticles2D.new()
	_chispas.position = Vector2(0, -10)
	_chispas.amount = 8
	_chispas.lifetime = 1.4
	_chispas.direction = Vector2.UP
	_chispas.spread = 40.0
	_chispas.gravity = Vector2(0, -6)
	_chispas.initial_velocity_min = 3.0
	_chispas.initial_velocity_max = 10.0
	_chispas.scale_amount_min = 1.0
	_chispas.scale_amount_max = 1.8
	var degradado := Gradient.new()
	degradado.set_color(0, Color("fff2b0"))
	degradado.set_color(1, Color(1.0, 0.85, 0.4, 0.0))
	_chispas.color_ramp = degradado
	add_child(_chispas)
	_chispas.emitting = true
