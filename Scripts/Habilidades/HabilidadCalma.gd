class_name HabilidadCalma
extends HabilidadBase
## Calma (Tristeza): un pulso en anillo que se expande desde el jugador (90 px en 0.6 s).
## Llama a calmar() en los nodos del grupo "calmable" que estén dentro del radio, justo cuando
## el anillo los alcanza. Las emociones agitadas (atacadas o ignoradas) implementan calmar():
## recuperan su velocidad normal durante 8 s. No hace daño.

const RADIO := 90.0
const SEGUNDOS := 0.6


func _init() -> void:
	id = "calma"
	cooldown = 3.0
	duracion = 0.0


func ejecutar(player: Player) -> bool:
	var efecto := EfectoCalma.new()
	efecto.radio = RADIO
	efecto.segundos = SEGUNDOS
	efecto.color = color
	efecto.top_level = true
	player.add_child(efecto)
	efecto.global_position = player.global_position + Vector2(0, -10)

	for nodo in player.get_tree().get_nodes_in_group("calmable"):
		if not (nodo is Node2D) or not nodo.has_method("calmar"):
			continue
		var distancia := player.global_position.distance_to(nodo.global_position)
		if distancia > RADIO:
			continue
		# Se calma cuando el anillo llega a ella
		var espera := SEGUNDOS * distancia / RADIO
		player.get_tree().create_timer(espera, false).timeout.connect(func() -> void:
			if is_instance_valid(nodo):
				nodo.calmar())
	return true
