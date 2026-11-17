extends Node
## Opciones del juego: volumen de Música y de Efectos y pantalla completa. Se guardan aparte de la
## partida (user://ecos_opciones.cfg), así que valen para todas las partidas.
##
## Los buses de audio "Musica" y "Efectos" se crean aquí si no existen (los dos salen por "Master"):
## quien reproduzca música debe poner su AudioStreamPlayer en el bus "Musica", y los sonidos en "Efectos".

const RUTA := "user://ecos_opciones.cfg"
const BUS_MUSICA := "Musica"
const BUS_EFECTOS := "Efectos"
const VOLUMEN_POR_DEFECTO := 0.8

## Volumen de cada bus en lineal (0.0 = silencio, 1.0 = máximo).
var volumen_musica := VOLUMEN_POR_DEFECTO
var volumen_efectos := VOLUMEN_POR_DEFECTO
var pantalla_completa := false
## Aviso suave junto a una compuerta cerrada ("Quizás Culpa pueda ayudar con esto").
var avisos_pistas := true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_asegurar_bus(BUS_MUSICA)
	_asegurar_bus(BUS_EFECTOS)
	cargar()
	_aplicar_todo()


## Crea el bus si no existe (sale por "Master").
func _asegurar_bus(nombre: String) -> void:
	if AudioServer.get_bus_index(nombre) != -1:
		return
	AudioServer.add_bus()
	var indice := AudioServer.bus_count - 1
	AudioServer.set_bus_name(indice, nombre)
	AudioServer.set_bus_send(indice, "Master")


func poner_volumen(bus: String, valor: float) -> void:
	valor = clampf(valor, 0.0, 1.0)
	if bus == BUS_MUSICA:
		volumen_musica = valor
	elif bus == BUS_EFECTOS:
		volumen_efectos = valor
	else:
		return
	_aplicar_volumen(bus, valor)
	guardar()


func obtener_volumen(bus: String) -> float:
	return volumen_musica if bus == BUS_MUSICA else volumen_efectos


func poner_pantalla_completa(activa: bool) -> void:
	pantalla_completa = activa
	_aplicar_pantalla()
	guardar()


func poner_avisos_pistas(activos: bool) -> void:
	avisos_pistas = activos
	guardar()


func _aplicar_todo() -> void:
	# El bus Master no se toca desde las opciones: se asegura que nunca quede silenciado
	AudioServer.set_bus_mute(0, false)
	if AudioServer.get_bus_volume_db(0) < -40.0:
		AudioServer.set_bus_volume_db(0, 0.0)
	_aplicar_volumen(BUS_MUSICA, volumen_musica)
	_aplicar_volumen(BUS_EFECTOS, volumen_efectos)
	# En la web la pantalla completa solo se puede pedir tras un clic o una tecla: nunca al empezar
	if not OS.has_feature("web"):
		_aplicar_pantalla()


func _aplicar_volumen(bus: String, valor: float) -> void:
	var indice := AudioServer.get_bus_index(bus)
	if indice == -1:
		return
	AudioServer.set_bus_mute(indice, valor <= 0.001)
	AudioServer.set_bus_volume_db(indice, linear_to_db(maxf(valor, 0.001)))


func _aplicar_pantalla() -> void:
	# Sin ventana real (pruebas sin pantalla) no hay nada que cambiar
	if DisplayServer.get_name() == "headless":
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if pantalla_completa else DisplayServer.WINDOW_MODE_WINDOWED)


func guardar() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "musica", volumen_musica)
	config.set_value("audio", "efectos", volumen_efectos)
	config.set_value("pantalla", "completa", pantalla_completa)
	config.set_value("ayuda", "avisos_pistas", avisos_pistas)
	var error := config.save(RUTA)
	if error != OK:
		push_warning("Opciones: no se pudieron guardar (error %d)." % error)


## Lee las opciones guardadas. Un archivo que falta o está dañado deja los valores por defecto.
func cargar() -> void:
	var config := ConfigFile.new()
	if config.load(RUTA) != OK:
		return
	volumen_musica = clampf(float(config.get_value("audio", "musica", VOLUMEN_POR_DEFECTO)), 0.0, 1.0)
	volumen_efectos = clampf(float(config.get_value("audio", "efectos", VOLUMEN_POR_DEFECTO)), 0.0, 1.0)
	pantalla_completa = bool(config.get_value("pantalla", "completa", false)) and not OS.has_feature("web")
	avisos_pistas = bool(config.get_value("ayuda", "avisos_pistas", true))
