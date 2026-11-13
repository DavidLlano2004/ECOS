class_name HabilidadImpulso
extends HabilidadBase
## Impulso (Rabia): un dash corto en la dirección en que mira el jugador. La rabia sana es fuerza
## para romper lo que estorba. No hace daño: no afecta a las emociones. Se usa en las dos épocas.
## El movimiento y la estela viven en Player.iniciar_impulso(); los objetos del grupo "rompible"
## que se tocan durante el dash reciben romper().

const DISTANCIA := 140.0
const SEGUNDOS := 0.18


func _init() -> void:
	id = "impulso"
	cooldown = 0.8
	duracion = SEGUNDOS


func puede_usar(player: Player) -> bool:
	return not player.impulsando


func ejecutar(player: Player) -> bool:
	player.iniciar_impulso(DISTANCIA, SEGUNDOS, color)
	return true


func terminar(player: Player) -> void:
	if player != null:
		player.terminar_impulso()
