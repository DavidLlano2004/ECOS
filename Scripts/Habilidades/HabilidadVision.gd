class_name HabilidadVision
extends HabilidadBase
## Visión (Miedo): ESPACIO la enciende y la apaga (alterna). Mientras está encendida hay una luz
## grande y suave alrededor del jugador, un leve tinte violeta en pantalla y los nodos del grupo
## "sombra" cercanos reciben visionar(true): su niebla se disipa y su colisión se desactiva.
## Al apagarla reciben visionar(false). Cooldown de 0.5 s para evitar parpadeos.
## Todo el trabajo está en EfectoVision. El miedo sano es ver con claridad lo que da miedo.

var _efecto: EfectoVision


func _init() -> void:
	id = "vision"
	cooldown = 0.5
	duracion = 0.0


func ejecutar(player: Player) -> bool:
	if _efecto != null and is_instance_valid(_efecto) and not _efecto.encendida:
		_efecto.set_radio(EfectoVision.radio_luz())   # por si subió de nivel desde la última vez
	if _efecto == null or not is_instance_valid(_efecto):
		_efecto = EfectoVision.new()
		_efecto.jugador = player
		player.add_child(_efecto)
	if _efecto.encendida:
		_efecto.apagar()
		activa = false
	else:
		_efecto.encender()
		activa = true
	return true


func reiniciar() -> void:
	activa = false
	if _efecto != null and is_instance_valid(_efecto):
		_efecto.queue_free()
	_efecto = null
