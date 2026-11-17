class_name HabilidadReparacion
extends HabilidadBase
## Reparar (Culpa): mantén ESPACIO unos 1.2 s cerca (a menos de 48 px) de un nodo del grupo
## "reparable". Aparece un anillo de progreso dorado y una cinta que lo rodea; al completarse se
## llama a reparar() del objeto. Si se suelta antes, se cancela sin penalización. Si no hay nada
## cerca, muestra una pista breve y NO gasta cooldown (esta habilidad no tiene cooldown propio).
## La culpa sana es reparar lo que se rompió.

const DISTANCIA := 48.0
const TEXTO_NADA := "No hay nada que reparar aquí."

var _efecto: EfectoReparar


func _init() -> void:
	id = "reparacion"
	cooldown = 0.0
	duracion = 0.0


func puede_usar(_player: Player) -> bool:
	# No se empieza otra mientras hay una reparación en curso
	return _efecto == null or not is_instance_valid(_efecto) or not _efecto.esta_activo()


func ejecutar(player: Player) -> bool:
	var objetivo := _buscar_objetivo(player)
	if objetivo == null:
		# Una pista breve con el mismo balloon que todo; habla la Culpa, dueña de esta habilidad
		if not Dialogo.hay_dialogo():
			Dialogo.mostrar_texto(GameState.obtener_datos("culpa").nombre, TEXTO_NADA, [], null, true)
		return false
	_efecto = EfectoReparar.new()
	player.add_child(_efecto)
	_efecto.iniciar(player, objetivo)
	return true


## El nodo "reparable" más cercano a menos de DISTANCIA px, o null.
func _buscar_objetivo(player: Player) -> Node2D:
	var mejor: Node2D = null
	var mejor_distancia := DISTANCIA
	for nodo in player.get_tree().get_nodes_in_group("reparable"):
		if not (nodo is Node2D) or not nodo.has_method("reparar") or not nodo.is_visible_in_tree():
			continue  # lo de la época oculta no se ve ni se toca
		# Las compuertas se detectan por su área de interacción (cubre todo el objeto), no por su origen
		if nodo.has_method("solapa_area"):
			if nodo.solapa_area(player.global_position):
				return nodo
			continue
		var distancia := player.global_position.distance_to(nodo.global_position)
		if distancia <= mejor_distancia:
			mejor_distancia = distancia
			mejor = nodo
	return mejor
