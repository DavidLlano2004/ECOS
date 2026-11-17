extends Node
## Sistema de audio de ECOS. Los archivos están en Assets/Audio/{Efectos,Ambiente,Musica}/ y el nombre
## del archivo (sin extensión) es el identificador del sonido; se aceptan .wav, .ogg y .mp3.
##
##   Sonido.efecto("ui_aceptar")                 un efecto suelto (varias voces a la vez)
##   Sonido.musica("musica_pasado", 1.5)         música, con fundido cruzado de 1.5 s
##   Sonido.ambiente("amb_presente")             sonido ambiente en bucle (por el bus de efectos)
##
## Los efectos y ambientes salen por el bus "Efectos" y la música por "Musica" (ver Opciones). Todo
## sigue sonando con el juego en pausa (para los sonidos del menú).
##
## Escucha las señales del juego (emociones, habilidades, fragmentos, diálogos...) y suena sin que cada
## objeto tenga que saber de audio. Lo que depende de un lugar concreto (pasos, acertijos, bloqueos,
## menús) llama a efecto() desde su propio script. Si falta un archivo, no pasa nada: se avisa una
## vez en la consola y aparece en el panel de depuración (tecla M).

const RAIZ := "res://Assets/Audio/"
const EXTENSIONES := ["wav", "ogg", "mp3"]
const CARPETAS := ["Efectos", "Ambiente", "Musica"]

const EFECTOS := [
	"dialogo_blip_guia", "dialogo_abrir", "dialogo_cerrar", "dialogo_opciones",
	"ui_mover", "ui_aceptar", "ui_elegir", "ui_cancelar", "diario_abrir", "diario_cerrar", "guardar",
	"emo_rabia", "emo_miedo", "emo_tristeza", "emo_soledad", "emo_culpa", "emo_ansiedad", "emo_verguenza",
	"emo_rabia_integrada", "emo_miedo_integrada", "emo_tristeza_integrada", "emo_soledad_integrada",
	"emo_culpa_integrada", "emo_ansiedad_integrada", "emo_verguenza_integrada",
	"integrar_exito", "atacar_ignorar", "habilidad_desbloqueada", "fragmento_recogido", "viaje_epoca", "bloqueo_abre",
	"hab_impulso", "hab_vision", "hab_calma", "hab_vinculo", "hab_reparar", "hab_pausa", "hab_revelar", "hab_denegada",
	"paso", "paso_piedra",
	"roca_rompe", "planta_florece", "placa_activa", "porton_repara", "puente_aparece", "niebla_disipa",
	"titulo_comenzar", "luz_blanca",
	"cofre_abre", "mejora_habilidad", "compuerta_abre", "pista",
]
const AMBIENTES := ["amb_pasado", "amb_presente", "amb_lluvia", "portal_activo"]
const MUSICAS := ["musica_titulo", "musica_pasado", "musica_presente", "final_bueno", "final_neutro", "final_dificil"]

## Volumen de cada efecto (dB) respecto a como quedó normalizado el archivo. Los que no estén aquí usan
## VOLUMEN_POR_DEFECTO. Se ajusta aquí, sin tocar el resto del código.
const VOLUMEN_POR_DEFECTO := -6.0
const VOLUMEN_DB := {
	"dialogo_blip_guia": -13.0,
	"paso": -9.0, "paso_piedra": -9.0,
	"ui_mover": -9.0, "ui_aceptar": -6.0, "ui_elegir": -6.0, "ui_cancelar": -6.0,
	"emo_rabia": -5.0, "emo_miedo": -5.0, "emo_tristeza": -5.0, "emo_soledad": -5.0,
	"emo_culpa": -5.0, "emo_ansiedad": -5.0, "emo_verguenza": -5.0,
}
const VOLUMEN_MUSICA_DB := -2.0
const VOLUMEN_AMBIENTE_DB := -4.0

## Habilidad -> efecto que suena al usarla.
const SONIDO_DE_HABILIDAD := {
	"impulso": "hab_impulso", "vision": "hab_vision", "calma": "hab_calma", "vinculo": "hab_vinculo",
	"reparacion": "hab_reparar", "pausa": "hab_pausa", "revelar": "hab_revelar",
}
const NUMERO_DE_VOCES := 14
## UN SOLO sonido de texto para todos los que hablan (Guía, emociones, aliadas, bloqueos, recuerdos, consejos, cuestionarios...):
## el blip del Guía, siempre con el mismo volumen y el mismo tono (sin variación por hablante).
const SONIDO_TEXTO := "dialogo_blip_guia"
## Suelos duros (adoquines, ruinas, muros, roca, acantilado): ahí suena paso_piedra.
const SUELOS_DUROS := "auMRC"
## Cada cuántas letras escritas suena un blip del diálogo.
const LETRAS_POR_BLIP := 2
const DISTANCIA_PORTAL := 280.0

## Sonó un efecto (para depurar y probar).
signal efecto_reproducido(nombre: String)

## Nombres pedidos o del catálogo que no tienen archivo (lo muestra el panel de depuración).
var faltan: Array[String] = []
## Últimos efectos que sonaron: {"nombre", "tiempo"} (para el panel de depuración).
var historial: Array[Dictionary] = []

var _cache: Dictionary = {}          # nombre -> AudioStream (o null si no existe)
var _voces: Array[AudioStreamPlayer] = []
var _ultima_vez: Dictionary = {}     # nombre -> ms de la última vez que sonó
var _musica := Capa.new()
var _ambiente := Capa.new()
var _portal: AudioStreamPlayer
var _letras := 0
## La voz propia del blip de texto (así se puede cortar cuando el texto se completa de golpe).
var _voz_blip: AudioStreamPlayer
var _panel: CanvasLayer
var _texto_panel: Label
var _tiempo_panel := 0.0


## Una capa de audio con dos reproductores para poder hacer fundidos cruzados.
class Capa:
	var jugadores: Array[AudioStreamPlayer] = []
	var activo := 0
	var nombre := ""
	var tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in NUMERO_DE_VOCES:
		_voces.append(_crear_jugador("Efectos"))
	_voz_blip = _crear_jugador("Efectos")
	for i in 2:
		_musica.jugadores.append(_crear_jugador("Musica"))
		_ambiente.jugadores.append(_crear_jugador("Efectos"))
	_portal = _crear_jugador("Efectos")
	_revisar_catalogo()
	_conectar_senales()
	_crear_panel()
	get_tree().auto_accept_quit = false   # al cerrar la ventana se sale con calma (ver salir())


func _notification(que: int) -> void:
	if que == NOTIFICATION_WM_CLOSE_REQUEST:
		salir()


## Cierra el juego con calma: para el audio y espera un instante antes de salir. Si el programa se cierra
## con un sonido a medias, el motor avisa en la consola de recursos "aún en uso".
func salir() -> void:
	_detener(_musica, 0.05)
	_detener(_ambiente, 0.05)
	_portal.stop()
	for v in _voces:
		v.stop()
	await get_tree().create_timer(0.2, true, false, true).timeout
	get_tree().quit()


## Al cerrar el juego se sueltan los audios (si no, el motor avisa de recursos "aún en uso").
func _exit_tree() -> void:
	for capa in [_musica, _ambiente]:
		if capa.tween != null:
			capa.tween.kill()
		capa.jugadores.clear()
	for hijo in get_children():
		if hijo is AudioStreamPlayer:
			hijo.stop()
			hijo.stream = null
			hijo.free()   # liberar el reproductor suelta también su reproducción en curso
	_voces.clear()
	_cache.clear()


func _crear_jugador(bus: String) -> AudioStreamPlayer:
	var j := AudioStreamPlayer.new()
	j.bus = bus
	# Reproducción de Godot (no Web Audio): en la web el modo "Sample" no soporta bien buses, fundidos ni cambios de tono
	j.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	j.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(j)
	return j


## Mira qué archivos del catálogo existen y avisa (una vez) de los que faltan.
func _revisar_catalogo() -> void:
	faltan.clear()
	var todos: Array = EFECTOS + AMBIENTES + MUSICAS
	for nombre in todos:
		if _cargar(nombre) == null:
			faltan.append(nombre)
	if not faltan.is_empty():
		push_warning("Sonido: faltan %d archivos de audio: %s" % [faltan.size(), ", ".join(faltan)])
	# Registro visible (en la web sale en la consola del navegador): cuántos sonidos se cargaron y cómo está el audio
	print("Audio: %d de %d sonidos cargados%s" % [todos.size() - faltan.size(), todos.size(), "" if faltan.is_empty() else ". No se pudieron cargar: " + ", ".join(faltan)])
	print("Audio: Master %s a %.1f dB, Musica %.0f %%, Efectos %.0f %%, reproducción %s" % [
		"SILENCIADO" if AudioServer.is_bus_mute(0) else "activo", AudioServer.get_bus_volume_db(0),
		Opciones.volumen_musica * 100.0, Opciones.volumen_efectos * 100.0, "Stream (Godot)"])


## Busca el archivo por nombre (en Efectos, Ambiente y Musica; .wav, .ogg o .mp3). Guarda el resultado.
func _cargar(nombre: String) -> AudioStream:
	if _cache.has(nombre):
		return _cache[nombre]
	var recurso: AudioStream = null
	for carpeta in CARPETAS:
		for extension in EXTENSIONES:
			var ruta := "%s%s/%s.%s" % [RAIZ, carpeta, nombre, extension]
			if ResourceLoader.exists(ruta):
				recurso = load(ruta)
				break
		if recurso != null:
			break
	_cache[nombre] = recurso
	if recurso == null and not faltan.has(nombre):
		faltan.append(nombre)
		push_warning("Sonido: no existe el audio '%s'." % nombre)
	return recurso


# --- Efectos ---

## El sonido de una pista suave (el aviso junto a una compuerta, la pista al interactuar con ella y la respuesta
## de la Guía): -6 dB, tono +-5 % y como mucho una vez cada 5 s (se repite mucho).
const SEGUNDOS_ENTRE_PISTAS := 5.0
var _ultima_pista := -INF


func pista() -> void:
	var ahora := Time.get_ticks_msec() / 1000.0
	if ahora - _ultima_pista < SEGUNDOS_ENTRE_PISTAS:
		return
	_ultima_pista = ahora
	efecto("pista", -6.0, 0.05)


## Reproduce un efecto. volumen_db sobreescribe el de VOLUMEN_DB; variacion = cuánto cambia el tono al azar
## (0.05 = un 5 % arriba o abajo). Dos veces el mismo efecto en menos de 40 ms cuentan como una.
func efecto(nombre: String, volumen_db: float = NAN, variacion: float = 0.0, retraso: float = 0.0) -> void:
	if nombre == "":
		return
	var ahora := Time.get_ticks_msec()
	if ahora - int(_ultima_vez.get(nombre, -1000)) < 40:
		return
	var flujo := _cargar(nombre)
	if flujo == null:
		return
	_ultima_vez[nombre] = ahora
	_anotar(nombre)
	if retraso > 0.0:
		await get_tree().create_timer(retraso, true, false, true).timeout
	var voz := _voz_libre()
	voz.stream = flujo
	voz.volume_db = volumen_db if not is_nan(volumen_db) else float(VOLUMEN_DB.get(nombre, VOLUMEN_POR_DEFECTO))
	voz.pitch_scale = 1.0 + randf_range(-variacion, variacion)
	voz.play()
	efecto_reproducido.emit(nombre)


func _voz_libre() -> AudioStreamPlayer:
	for v in _voces:
		if not v.playing:
			return v
	# Todas ocupadas: se reutiliza la que más avanzó
	var elegida := _voces[0]
	for v in _voces:
		if v.get_playback_position() > elegida.get_playback_position():
			elegida = v
	return elegida


func _anotar(nombre: String) -> void:
	historial.push_front({"nombre": nombre, "tiempo": Time.get_ticks_msec()})
	if historial.size() > 8:
		historial.pop_back()


## El paso del jugador en `posicion` (global): suena distinto sobre piedra que sobre hierba o tierra.
func paso(posicion: Vector2) -> void:
	var mundo := get_tree().get_first_node_in_group("mundo")
	var suelo := ""
	if mundo != null and mundo.has_method("suelo_en"):
		suelo = mundo.suelo_en(posicion)
	efecto("paso_piedra" if suelo != "" and SUELOS_DUROS.contains(suelo) else "paso", NAN, 0.08)


# --- Música y ambiente ---

## Pone una música (con fundido cruzado). Si ya suena esa, no la reinicia.
func musica(nombre: String, fundido: float = 1.5) -> void:
	_reproducir(_musica, nombre, fundido, VOLUMEN_MUSICA_DB)


func detener_musica(fundido: float = 1.0) -> void:
	_detener(_musica, fundido)


func ambiente(nombre: String, fundido: float = 1.5) -> void:
	_reproducir(_ambiente, nombre, fundido, VOLUMEN_AMBIENTE_DB)


func detener_ambiente(fundido: float = 1.0) -> void:
	_detener(_ambiente, fundido)


func musica_actual() -> String:
	return _musica.nombre


func ambiente_actual() -> String:
	return _ambiente.nombre


## Música y ambiente de una época (Mundo lo llama al mostrarla).
func ambientar_epoca(epoca: String) -> void:
	musica("musica_presente" if epoca == "presente" else "musica_pasado")
	ambiente("amb_presente" if epoca == "presente" else "amb_pasado")


func _reproducir(capa: Capa, nombre: String, fundido: float, volumen_db: float) -> void:
	if capa.nombre == nombre and capa.jugadores[capa.activo].playing:
		return
	var flujo := _cargar(nombre)
	if flujo == null:
		return
	if capa.tween != null:
		capa.tween.kill()
	var saliente := capa.jugadores[capa.activo]
	capa.activo = 1 - capa.activo
	var entrante := capa.jugadores[capa.activo]
	capa.nombre = nombre
	entrante.stream = flujo
	entrante.volume_db = -80.0 if fundido > 0.0 else volumen_db
	entrante.play()
	if fundido <= 0.0:
		saliente.stop()
		return
	capa.tween = create_tween().set_parallel(true)
	capa.tween.tween_property(entrante, "volume_db", volumen_db, fundido)
	if saliente.playing:
		capa.tween.tween_property(saliente, "volume_db", -80.0, fundido)
		capa.tween.chain().tween_callback(saliente.stop)


func _detener(capa: Capa, fundido: float) -> void:
	capa.nombre = ""
	if capa.tween != null:
		capa.tween.kill()
	capa.tween = create_tween().set_parallel(true)
	for j in capa.jugadores:
		if j.playing:
			capa.tween.tween_property(j, "volume_db", -80.0, maxf(fundido, 0.01))
	capa.tween.chain().tween_callback(func() -> void:
		for j in capa.jugadores:
			j.stop())


# --- Señales del juego ---

func _conectar_senales() -> void:
	GameState.emocion_resuelta.connect(_on_emocion_resuelta)
	GameState.habilidad_desbloqueada.connect(func(_id: String) -> void: efecto("habilidad_desbloqueada"))
	GameState.fragmento_recogido.connect(func(_id: String) -> void: efecto("fragmento_recogido"))
	# Mejora de habilidad: suena 0.9 s después del cofre, justo cuando sale la tarjeta de la mejora
	GameState.cofre_abierto.connect(func(_id: String) -> void: efecto("mejora_habilidad", NAN, 0.0, 0.9))
	GameState.compuerta_abierta.connect(func(_id: String) -> void: efecto("compuerta_abre"))
	Habilidades.habilidad_usada.connect(func(id: String) -> void: efecto(SONIDO_DE_HABILIDAD.get(id, "")))
	Habilidades.uso_denegado.connect(func(_id: String) -> void: efecto("hab_denegada"))
	Dialogo.dialogo_abierto.connect(func() -> void: efecto("dialogo_abrir"))
	Dialogo.dialogo_cerrado.connect(func() -> void: efecto("dialogo_cerrar"))
	Dialogo.opciones_mostradas.connect(func() -> void: efecto("dialogo_opciones"))
	Dialogo.respuesta_elegida.connect(func() -> void: efecto("ui_elegir"))
	Dialogo.cancelado_por_jugador.connect(func() -> void: efecto("ui_cancelar"))
	Dialogo.letra_escrita.connect(_on_letra)
	Dialogo.linea_terminada.connect(cortar_blip)   # el texto se completó (solo o de golpe con INTERACTUAR): el blip se corta


func _on_emocion_resuelta(id: String, resultado: String) -> void:
	match resultado:
		"integrada":
			efecto("integrar_exito")
			efecto("emo_%s_integrada" % id, NAN, 0.0, 0.25)
		"atacada", "ignorada":
			efecto("atacar_ignorar")


## El blip de texto: el MISMO para todos los que hablan. Suena una vez cada 2 letras, no en los espacios ni en la puntuación.
## Es la única función de sonido de letras del juego: el balloon (Dialogo.mostrar y mostrar_texto) y las etiquetas
## que se escriben solas (Dialogo.escribir_etiqueta) emiten Dialogo.letra_escrita y llegan aquí.
func _on_letra(_personaje: String, letra: String) -> void:
	if not _es_letra_o_cifra(letra):
		return
	_letras += 1
	if _letras % LETRAS_POR_BLIP != 0:
		return
	blip()


func _es_letra_o_cifra(letra: String) -> bool:
	return letra.length() > 0 and (letra.to_lower() != letra.to_upper() or letra.is_valid_int())


## Reproduce el blip de texto (mismo archivo, volumen y tono siempre).
func blip() -> void:
	var flujo := _cargar(SONIDO_TEXTO)
	if flujo == null:
		return
	_anotar(SONIDO_TEXTO)
	_voz_blip.stream = flujo
	_voz_blip.volume_db = float(VOLUMEN_DB.get(SONIDO_TEXTO, VOLUMEN_POR_DEFECTO))
	_voz_blip.pitch_scale = 1.0
	_voz_blip.play()
	efecto_reproducido.emit(SONIDO_TEXTO)


## Corta el blip (cuando el texto termina o se completa de golpe).
func cortar_blip() -> void:
	if _voz_blip != null and _voz_blip.playing:
		_voz_blip.stop()


# --- Portal: suena más fuerte cuanto más cerca estás ---

func _process(delta: float) -> void:
	_actualizar_portal()
	if _panel.visible:
		_tiempo_panel -= delta
		if _tiempo_panel <= 0.0:
			_tiempo_panel = 0.25
			_actualizar_panel()


func _actualizar_portal() -> void:
	var jugador := get_tree().get_first_node_in_group("player") as Node2D
	var cerca := INF
	if jugador != null and get_tree().current_scene is Mundo:
		for portal in get_tree().get_nodes_in_group("portales"):
			if portal is Node2D and portal.is_visible_in_tree():
				cerca = minf(cerca, jugador.global_position.distance_to(portal.global_position))
	if cerca >= DISTANCIA_PORTAL:
		if _portal.playing:
			_portal.stop()
		return
	var flujo := _cargar("portal_activo")
	if flujo == null:
		return
	if not _portal.playing:
		_portal.stream = flujo
		_portal.volume_db = -40.0
		_portal.play()
	var cercania := 1.0 - cerca / DISTANCIA_PORTAL
	_portal.volume_db = lerpf(-40.0, -8.0, cercania * cercania)


# --- Panel de depuración (tecla M, solo en compilaciones de depuración) ---

func _crear_panel() -> void:
	_panel = CanvasLayer.new()
	_panel.layer = 30
	_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	_panel.visible = false
	add_child(_panel)
	_texto_panel = EstiloUI.etiqueta("", 10, EstiloUI.CREMA)
	_texto_panel.position = Vector2(6, 4)
	_texto_panel.add_theme_color_override("font_outline_color", EstiloUI.MORADO_OSCURO)
	_texto_panel.add_theme_constant_override("outline_size", 4)
	_panel.add_child(_texto_panel)


func _unhandled_input(evento: InputEvent) -> void:
	if not OS.is_debug_build():
		return
	if evento is InputEventKey and evento.pressed and not evento.echo and evento.keycode == KEY_M:
		_panel.visible = not _panel.visible
		_tiempo_panel = 0.0


## Cuántos audios del catálogo no tienen archivo (sin contar nombres sueltos que alguien pidió por error).
func faltan_del_catalogo() -> Array[String]:
	var lista: Array[String] = []
	for nombre in faltan:
		if EFECTOS.has(nombre) or AMBIENTES.has(nombre) or MUSICAS.has(nombre):
			lista.append(nombre)
	return lista


func _actualizar_panel() -> void:
	var total := EFECTOS.size() + AMBIENTES.size() + MUSICAS.size()
	var del_catalogo := faltan_del_catalogo()
	var lineas: Array[String] = ["SONIDO   [M] cerrar", ""]
	lineas.append("Archivos: %d de %d%s" % [total - del_catalogo.size(), total, "" if faltan.is_empty() else "   FALTAN %d" % faltan.size()])
	if not faltan.is_empty():
		lineas.append("Faltan: " + ", ".join(faltan.slice(0, 12)) + (" ..." if faltan.size() > 12 else ""))
	lineas.append("Música: %s    Ambiente: %s" % [_musica.nombre if _musica.nombre != "" else "-", _ambiente.nombre if _ambiente.nombre != "" else "-"])
	lineas.append("Portal: %s" % ("%.0f dB" % _portal.volume_db if _portal.playing else "apagado"))
	lineas.append("Volumen   Música %d%%   Efectos %d%%" % [roundi(Opciones.volumen_musica * 100.0), roundi(Opciones.volumen_efectos * 100.0)])
	lineas.append("Voces de efectos en uso: %d de %d" % [_voces.filter(func(v: AudioStreamPlayer) -> bool: return v.playing).size(), _voces.size()])
	lineas.append("")
	lineas.append("Últimos efectos:")
	var ahora := Time.get_ticks_msec()
	for h in historial:
		lineas.append("  %s   (hace %.1f s)" % [h["nombre"], (ahora - int(h["tiempo"])) / 1000.0])
	_texto_panel.text = "\n".join(lineas)
