extends Node
## Sistema de habilidades de ECOS: catálogo, selección, uso y esperas (cooldowns).
## Los datos salen de los EmocionData; qué habilidades hay desbloqueadas lo dice GameState.
##
## Reglas de diseño: ninguna habilidad hace daño y el camino principal nunca exige una.
## Todo se bloquea mientras hay un diálogo abierto, durante el onboarding (no hay jugador),
## con el juego en pausa o durante una transición de época.

## Cambió la habilidad elegida ("" = ninguna).
signal habilidad_seleccionada_cambiada(id: String)
## Se usó una habilidad con éxito.
signal habilidad_usada(id: String)
## Cambió la espera de una habilidad (restante y total en segundos).
signal cooldown_cambiado(id: String, restante: float, total: float)
## Cambió la velocidad del tiempo del mundo (Pausa).
signal factor_tiempo_cambiado(factor: float)
## Una habilidad no se pudo usar (bloqueada, o sin nada que hacer): suena el sonido de "denegada".
signal uso_denegado(id: String)
## El jugador intentó elegir o usar una habilidad que aún no tiene (el HUD hace temblar el candado).
signal intento_bloqueado(id: String)
## El nivel de una habilidad cambió (el cofre de memoria de su emoción la mejora a nivel 2).
signal nivel_cambiado(id: String, nivel: int)

## Teclas 1 a 7 -> posición en el catálogo.
const TECLAS_NUMERICAS: Array[Key] = [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7]

## Subclase de cada habilidad (una por id).
var _clases: Dictionary = {
	"impulso": HabilidadImpulso,
	"vision": HabilidadVision,
	"calma": HabilidadCalma,
	"vinculo": HabilidadVinculo,
	"reparacion": HabilidadReparacion,
	"pausa": HabilidadPausa,
	"revelar": HabilidadRevelar,
}

const ESCENA_HUD := preload("res://Scenes/UI/HUD.tscn")

## Velocidad del tiempo del mundo (1.0 = normal). La usa Pausa: los nodos del grupo "tiempo"
## (mecanismos, plataformas móviles, engranajes) y las emociones multiplican su delta por este
## valor. El jugador NO se ve afectado. No se usa Engine.time_scale. Las partículas del grupo
## "tiempo" (CPUParticles2D o GPUParticles2D) reciben el factor en su speed_scale automáticamente.
var factor_tiempo: float = 1.0:
	set(valor):
		if is_equal_approx(valor, factor_tiempo):
			return
		factor_tiempo = valor
		_aplicar_factor_a_particulas()
		factor_tiempo_cambiado.emit(valor)

var _tween_factor: Tween

## Catálogo en orden fijo: [{id, nombre, descripcion, color, emocion}] (de los EmocionData).
var catalogo: Array[Dictionary] = []

## id -> segundos que faltan para poder usarla otra vez.
var cooldowns: Dictionary = {}

## Lo que impide usarlas ahora: motivo -> true (ver bloquear() y liberar()).
var _bloqueos: Dictionary = {}
## id de habilidad -> nivel (1 normal, 2 mejorada por el cofre de memoria de su emoción).
var nivel: Dictionary = {}
## id -> instancia de HabilidadBase.
var _habilidades: Dictionary = {}
## id -> segundos que le quedan al efecto activo.
var _activas: Dictionary = {}
## id -> jugador que la activó (para llamar a terminar()).
var _jugadores: Dictionary = {}


## La habilidad elegida vive en GameState para guardarse con la partida.
var habilidad_seleccionada: String:
	get:
		return GameState.habilidad_seleccionada


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # sigue activo en pausa para poder bloquearse bien
	_construir_catalogo()
	GameState.habilidad_desbloqueada.connect(_on_habilidad_desbloqueada)
	GameState.partida_reiniciada.connect(_reiniciar)
	GameState.cofre_abierto.connect(func(_id: String) -> void: recalcular_niveles())
	GameState.partida_cargada.connect(_on_partida_cargada)
	recalcular_niveles()
	add_child(ESCENA_HUD.instantiate())


## Lee los EmocionData (ya vienen ordenados por `orden`) y crea una habilidad por cada uno.
func _construir_catalogo() -> void:
	catalogo.clear()
	_habilidades.clear()
	for emocion_id in GameState.ids_emociones():
		var datos := GameState.obtener_datos(emocion_id)
		if datos == null or datos.habilidad_id == "":
			continue
		catalogo.append({
			"id": datos.habilidad_id,
			"nombre": datos.habilidad_nombre,
			"descripcion": datos.habilidad_descripcion,
			"color": datos.color,
			"emocion": datos.id,
		})
		var clase: GDScript = _clases.get(datos.habilidad_id, null)
		var habilidad: HabilidadBase = clase.new() if clase != null else HabilidadBase.new()
		habilidad.id = datos.habilidad_id
		habilidad.color = datos.color
		_habilidades[datos.habilidad_id] = habilidad


# --- Niveles ---

## El nivel de una habilidad (1 si no está mejorada).
func nivel_de(id: String) -> int:
	return int(nivel.get(id, 1))


## Lee los cofres abiertos de GameState: la habilidad de cada emoción con cofre abierto pasa a nivel 2.
func recalcular_niveles() -> void:
	for entrada in catalogo:
		var id: String = entrada["id"]
		var nuevo := 2 if GameState.cofre_esta_abierto(str(entrada["emocion"])) else 1
		var anterior := nivel_de(id)
		nivel[id] = nuevo
		if _habilidades.has(id):
			_habilidades[id].aplicar_nivel(nuevo)
		if nuevo != anterior:
			nivel_cambiado.emit(id, nuevo)


# --- Consultas ---

## Entrada del catálogo (diccionario vacío si el id no existe).
func info(id: String) -> Dictionary:
	for entrada in catalogo:
		if entrada["id"] == id:
			return entrada
	return {}


## Posición (0 a 6) de la habilidad en el catálogo, o -1.
func indice_de(id: String) -> int:
	for i in catalogo.size():
		if catalogo[i]["id"] == id:
			return i
	return -1


func esta_desbloqueada(id: String) -> bool:
	return GameState.tiene_habilidad(id)


## Segundos que faltan para poder usarla (0 si está lista).
func cooldown_restante(id: String) -> float:
	return cooldowns.get(id, 0.0)


## true mientras la habilidad tiene un efecto en marcha (Visión encendida, Pausa, compañero invocado).
func esta_activa(id: String) -> bool:
	var habilidad: HabilidadBase = _habilidades.get(id, null)
	return habilidad != null and habilidad.activa


## Lleva factor_tiempo suavemente hasta `destino` en `segundos` (es lo que usa Pausa).
func transicionar_factor(destino: float, segundos: float) -> void:
	if _tween_factor != null:
		_tween_factor.kill()
	_tween_factor = create_tween()
	_tween_factor.tween_property(self, "factor_tiempo", destino, segundos)


## Pone el factor en las partículas del grupo "tiempo" (su speed_scale).
func _aplicar_factor_a_particulas() -> void:
	if not is_inside_tree():
		return
	for nodo in get_tree().get_nodes_in_group("tiempo"):
		if nodo is CPUParticles2D or nodo is GPUParticles2D:
			nodo.speed_scale = factor_tiempo


## Segundos de espera total de la habilidad (0 si no existe).
func cooldown_total(id: String) -> float:
	var habilidad: HabilidadBase = _habilidades.get(id, null)
	return habilidad.cooldown if habilidad != null else 0.0


## true si el sistema puede aceptar órdenes ahora (diálogo, onboarding, pausa, transición).
func puede_operar() -> bool:
	if not _bloqueos.is_empty() or Dialogo.hay_dialogo() or get_tree().paused:
		return false
	# Sin jugador en escena (título, onboarding) no hay nada que hacer
	return get_tree().get_first_node_in_group("player") != null


## true si hay un bloqueo activo por ese motivo (por ejemplo "transicion", mientras se viaja de época).
func bloqueado_por(motivo: String) -> bool:
	return _bloqueos.has(motivo)


## Bloquea las habilidades por un motivo (ej. "transicion"). Hay que liberar con el mismo motivo.
func bloquear(motivo: String) -> void:
	_bloqueos[motivo] = true


func liberar(motivo: String) -> void:
	_bloqueos.erase(motivo)


# --- Selección ---

## Elige una habilidad (también una bloqueada: así se ve su candado).
func seleccionar(id: String) -> void:
	if not puede_operar() or indice_de(id) == -1:
		return
	_poner_seleccion(id)
	if not esta_desbloqueada(id):
		intento_bloqueado.emit(id)
		uso_denegado.emit(id)


## Pasa a la siguiente habilidad desbloqueada (da la vuelta al final).
func siguiente() -> void:
	_mover_seleccion(1)


func anterior() -> void:
	_mover_seleccion(-1)


func _mover_seleccion(paso: int) -> void:
	if not puede_operar():
		return
	var libres: Array[String] = []
	for entrada in catalogo:
		if esta_desbloqueada(entrada["id"]):
			libres.append(entrada["id"])
	if libres.is_empty():
		return
	var posicion := libres.find(habilidad_seleccionada)
	if posicion == -1:
		_poner_seleccion(libres[0] if paso > 0 else libres[libres.size() - 1])
	else:
		_poner_seleccion(libres[posmod(posicion + paso, libres.size())])


func _poner_seleccion(id: String) -> void:
	if GameState.habilidad_seleccionada == id:
		return
	GameState.habilidad_seleccionada = id
	habilidad_seleccionada_cambiada.emit(id)


# --- Uso ---

## Usa la habilidad elegida. Si no está desbloqueada o está esperando, no pasa nada
## (con una bloqueada se hace temblar el candado del HUD).
func usar(player: Player) -> void:
	var id := habilidad_seleccionada
	if id == "" or player == null or not puede_operar() or not player.can_move:
		return
	if not esta_desbloqueada(id):
		intento_bloqueado.emit(id)
		uso_denegado.emit(id)
		return
	if cooldown_restante(id) > 0.0 or _activas.has(id):
		return
	var habilidad: HabilidadBase = _habilidades.get(id, null)
	if habilidad == null or not habilidad.puede_usar(player):
		return
	if not habilidad.ejecutar(player):
		uso_denegado.emit(id)
		return  # no se usó (ej. Reparar sin nada cerca): ni cooldown ni señal
	habilidad_usada.emit(id)
	if habilidad.duracion > 0.0:
		_activas[id] = habilidad.duracion
		_jugadores[id] = player
	if habilidad.cooldown > 0.0:
		cooldowns[id] = habilidad.cooldown
		cooldown_cambiado.emit(id, habilidad.cooldown, habilidad.cooldown)


func _process(delta: float) -> void:
	if get_tree().paused:
		return
	# Esperas (en tiempo real: la Pausa no ralentiza los cooldowns)
	for id in cooldowns.keys():
		var restante: float = maxf(0.0, cooldowns[id] - delta)
		var total: float = _habilidades[id].cooldown if _habilidades.has(id) else 1.0
		if restante <= 0.0:
			cooldowns.erase(id)
		else:
			cooldowns[id] = restante
		cooldown_cambiado.emit(id, restante, total)
	# Efectos con duración
	for id in _activas.keys():
		_activas[id] -= delta
		if _activas[id] <= 0.0:
			_terminar_efecto(id)


func _terminar_efecto(id: String) -> void:
	_activas.erase(id)
	var player: Player = _jugadores.get(id, null)
	_jugadores.erase(id)
	var habilidad: HabilidadBase = _habilidades.get(id, null)
	if habilidad != null:
		habilidad.terminar(player if is_instance_valid(player) else null)


# --- Entrada ---

func _unhandled_input(evento: InputEvent) -> void:
	if not puede_operar():
		return
	if evento is InputEventKey and evento.pressed and not evento.echo:
		var posicion := TECLAS_NUMERICAS.find(evento.physical_keycode)
		if posicion != -1 and posicion < catalogo.size():
			get_viewport().set_input_as_handled()
			seleccionar(catalogo[posicion]["id"])
			return
	if evento.is_action_pressed("HAB_SIGUIENTE"):
		get_viewport().set_input_as_handled()
		siguiente()
	elif evento.is_action_pressed("HAB_ANTERIOR"):
		get_viewport().set_input_as_handled()
		anterior()
	elif evento is InputEventMouseButton and evento.pressed:
		if evento.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			siguiente()
		elif evento.button_index == MOUSE_BUTTON_WHEEL_UP:
			anterior()


# --- Reacciones a GameState ---

## Al desbloquear la primera habilidad, se selecciona sola.
func _on_habilidad_desbloqueada(id: String) -> void:
	if GameState.habilidad_seleccionada == "" or not esta_desbloqueada(GameState.habilidad_seleccionada):
		_poner_seleccion(id)


## Nueva partida: se borra todo (esperas, efectos activos, tiempo normal).
func _reiniciar() -> void:
	for id in _activas.keys():
		_terminar_efecto(id)
	cooldowns.clear()
	_bloqueos.clear()
	if _tween_factor != null:
		_tween_factor.kill()
	factor_tiempo = 1.0
	for habilidad in _habilidades.values():
		habilidad.reiniciar()  # apaga Visión, Pausa, el compañero, etc.
	recalcular_niveles()
	habilidad_seleccionada_cambiada.emit(GameState.habilidad_seleccionada)


## Partida cargada: se comprueba que la elegida siga siendo válida y esté desbloqueada.
func _on_partida_cargada() -> void:
	recalcular_niveles()
	var id := GameState.habilidad_seleccionada
	if indice_de(id) == -1 or not esta_desbloqueada(id):
		var primera := ""
		for entrada in catalogo:
			if esta_desbloqueada(entrada["id"]):
				primera = entrada["id"]
				break
		GameState.habilidad_seleccionada = primera
	habilidad_seleccionada_cambiada.emit(GameState.habilidad_seleccionada)
