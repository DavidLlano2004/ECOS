class_name HabilidadBase
extends RefCounted
## Clase base de las habilidades. Ninguna hace daño: cada una refleja la función sana de su emoción.
## Las subclases (una por habilidad) se implementan en las tareas 4.2 y 4.3; por ahora ejecutar()
## solo hace un destello del color de la emoción y avisa en la consola.

## id de la habilidad ("impulso", "vision", ...). Lo pone Habilidades al crearla.
var id: String = ""
## Color de la emoción (lo pone Habilidades desde el EmocionData).
var color: Color = Color.WHITE
## Segundos de espera antes de poder volver a usarla.
var cooldown: float = 1.0
## Segundos que dura el efecto (0 = instantáneo). Al acabar se llama a terminar().
var duracion: float = 0.0
## true mientras hay un efecto en marcha que el HUD debe mostrar (Visión encendida, Pausa,
## compañero invocado). Lo mantienen las subclases.
var activa: bool = false


## Se llama cuando cambia el nivel de la habilidad (1 o 2, ver Habilidades.nivel_de). Las subclases ajustan
## aquí su cooldown o su duración; lo demás lo leen directamente de Habilidades.nivel_de(id).
func aplicar_nivel(_nivel: int) -> void:
	pass


## Apaga todo lo que haya en marcha (se llama al empezar una nueva partida).
func reiniciar() -> void:
	activa = false


## Condición extra para poder usarla (por ejemplo, "hay algo cerca"). Habilidades ya comprueba
## desbloqueo, cooldown, diálogos y transiciones.
func puede_usar(_player: Player) -> bool:
	return true


## Hace el efecto. Las subclases lo sobrescriben. Devuelve true si la habilidad se usó de verdad
## (entonces se gasta el cooldown y se emite habilidad_usada) y false si no pasó nada
## (por ejemplo, Reparar sin nada cerca: no se gasta cooldown).
func ejecutar(player: Player) -> bool:
	print("Habilidad '%s' usada (todavía sin efecto)." % id)
	_destello(player)
	return true


## Se llama cuando acaba la duración (si duracion > 0). Las subclases lo sobrescriben.
func terminar(_player: Player) -> void:
	pass


## Destello breve del color de la emoción sobre el sprite del jugador.
func _destello(player: Player) -> void:
	if player == null or not is_instance_valid(player) or player.sprite == null:
		return
	var sprite := player.sprite
	sprite.modulate = Color(color.r * 2.0, color.g * 2.0, color.b * 2.0, 1.0)  # más de 1 = brilla
	var t := player.create_tween()
	t.tween_property(sprite, "modulate", Color.WHITE, 0.35)
