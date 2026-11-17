class_name HabilidadImpulso
extends HabilidadBase
## Impulso (Rabia): un dash corto en la dirección en que mira el jugador. La rabia sana es fuerza
## para romper lo que estorba. No hace daño: no afecta a las emociones. Se usa en las dos épocas.
## El movimiento y la estela viven en Player.iniciar_impulso(); los objetos del grupo "rompible"
## que se tocan durante el dash reciben romper().

const DISTANCIA := 140.0
## Nivel 2: llega más lejos y rompe también las rocas grandes (las que piden `nivel_requerido` 2).
const DISTANCIA_NIVEL_2 := 200.0
const SEGUNDOS := 0.18


func _init() -> void:
	id = "impulso"
	cooldown = 0.8
	duracion = SEGUNDOS


func puede_usar(player: Player) -> bool:
	return not player.impulsando


func ejecutar(player: Player) -> bool:
	# Una roca enorme (compuerta) se rompe si el jugador está en su área y mira hacia ella; el área cubre
	# todo el objeto, no solo su origen. (Si no, el dash la rompe igualmente al chocar con ella.)
	for nodo in player.get_tree().get_nodes_in_group("rompible"):
		if nodo.has_method("solapa_area") and nodo.is_visible_in_tree() and nodo.solapa_area(player.global_position):
			var hacia: Vector2 = (nodo.global_position - player.global_position).normalized()
			if hacia.dot(player.facing) > 0.2:
				nodo.romper()
	player.iniciar_impulso(distancia_actual(), SEGUNDOS, color)
	return true


## La distancia del dash según el nivel de la habilidad.
static func distancia_actual() -> float:
	return DISTANCIA_NIVEL_2 if Habilidades.nivel_de("impulso") >= 2 else DISTANCIA


func terminar(player: Player) -> void:
	if player != null:
		player.terminar_impulso()
