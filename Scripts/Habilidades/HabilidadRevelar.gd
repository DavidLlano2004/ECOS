class_name HabilidadRevelar
extends HabilidadBase
## Revelar (Vergüenza): una onda de luz tipo espejo se expande desde el jugador hasta 220 px
## (cooldown de 12 s). Los nodos del grupo "oculto" que queden dentro del radio reciben
## revelar(6.0) cuando la onda los alcanza: se vuelven visibles y funcionales con un destello dorado
## y, pasado ese tiempo, se desvanecen (salvo los que tengan `permanente = true`; eso lo decide el
## propio objeto). También resalta con destellos suaves lo interactuable cercano.
## La vergüenza sana es poder mostrar lo que estaba escondido.

const RADIO := 220.0
## Nivel 2 (cofre de Vergüenza): la onda llega más lejos y lo revelado dura más.
const RADIO_NIVEL_2 := 320.0
const SEGUNDOS_REVELADO_NIVEL_2 := 10.0
const SEGUNDOS_ONDA := 0.8
const SEGUNDOS_REVELADO := 6.0
const MAXIMO_DESTELLOS := 12


func _init() -> void:
	id = "revelar"
	cooldown = 12.0
	duracion = 0.0


static func radio_actual() -> float:
	return RADIO_NIVEL_2 if Habilidades.nivel_de("revelar") >= 2 else RADIO


static func segundos_revelado_actual() -> float:
	return SEGUNDOS_REVELADO_NIVEL_2 if Habilidades.nivel_de("revelar") >= 2 else SEGUNDOS_REVELADO


func ejecutar(player: Player) -> bool:
	var radio := radio_actual()
	var efecto := EfectoRevelar.new()
	efecto.radio = radio
	efecto.segundos = SEGUNDOS_ONDA
	efecto.top_level = true
	player.add_child(efecto)
	efecto.global_position = player.global_position + Vector2(0, -10)

	var arbol := player.get_tree()
	# Lo oculto se revela cuando la onda lo alcanza
	for nodo in arbol.get_nodes_in_group("oculto"):
		if not (nodo is Node2D) or not nodo.has_method("revelar") or not nodo.is_visible_in_tree():
			continue  # lo de la época oculta no se ve ni se toca
		var distancia := player.global_position.distance_to(nodo.global_position)
		if distancia > radio:
			continue
		arbol.create_timer(SEGUNDOS_ONDA * distancia / radio, false).timeout.connect(func() -> void:
			if is_instance_valid(nodo):
				nodo.revelar(segundos_revelado_actual()))

	# Destellos suaves sobre lo interactuable cercano
	var cuantos := 0
	for nodo in _interactuables_cerca(arbol.root, player, radio):
		if cuantos >= MAXIMO_DESTELLOS:
			break
		var distancia := player.global_position.distance_to(nodo.global_position)
		EfectoDestello.crear(player, nodo.global_position + Vector2(0, -22), EfectoRevelar.DORADO,
			SEGUNDOS_ONDA * distancia / radio)
		cuantos += 1
	return true


## Nodos visibles con interactuar() a menos de RADIO px (criaturas, portales, objetos...).
func _interactuables_cerca(nodo: Node, player: Player, radio: float) -> Array[Node2D]:
	var resultado: Array[Node2D] = []
	_recorrer(nodo, player, resultado, radio)
	return resultado


func _recorrer(nodo: Node, player: Player, resultado: Array[Node2D], radio: float) -> void:
	for hijo in nodo.get_children():
		if hijo is Node2D and hijo != player and hijo.has_method("interactuar") and hijo.is_visible_in_tree() \
				and player.global_position.distance_to(hijo.global_position) <= radio:
			resultado.append(hijo)
		_recorrer(hijo, player, resultado, radio)
