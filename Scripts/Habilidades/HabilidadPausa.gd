class_name HabilidadPausa
extends HabilidadBase
## Pausa (Ansiedad): ralentiza el tiempo del mundo 5 s (cooldown de 10 s, que corre desde que se
## usa). Pone Habilidades.factor_tiempo en 0.25: los nodos del grupo "tiempo" y las emociones
## multiplican su delta por ese factor. El jugador NO se ve afectado y no se usa Engine.time_scale.
## Al terminar, el factor vuelve a 1.0 con una transición suave. La ansiedad sana es saber parar.

const FACTOR := 0.25
const SEGUNDOS_ENTRADA := 0.2
const SEGUNDOS_SALIDA := 0.8

var _efecto: EfectoPausa


func _init() -> void:
	id = "pausa"
	cooldown = 10.0
	duracion = 5.0


## Nivel 2 (cofre de Ansiedad): dura más y se recupera antes.
func aplicar_nivel(nivel: int) -> void:
	duracion = 8.0 if nivel >= 2 else 5.0
	cooldown = 7.0 if nivel >= 2 else 10.0


func ejecutar(_player: Player) -> bool:
	activa = true
	Habilidades.transicionar_factor(FACTOR, SEGUNDOS_ENTRADA)
	_quitar_efecto()
	_efecto = EfectoPausa.new()
	Habilidades.add_child(_efecto)
	_efecto.aparecer()
	return true


## Pasan los 5 s: el tiempo vuelve a la normalidad poco a poco.
func terminar(_player: Player) -> void:
	activa = false
	Habilidades.transicionar_factor(1.0, SEGUNDOS_SALIDA)
	if _efecto != null and is_instance_valid(_efecto):
		_efecto.desaparecer()
	_efecto = null


func reiniciar() -> void:
	activa = false
	_quitar_efecto()


func _quitar_efecto() -> void:
	if _efecto != null and is_instance_valid(_efecto):
		_efecto.queue_free()
	_efecto = null
