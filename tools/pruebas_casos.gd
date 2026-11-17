extends Node
## Casos extra de la revisión de calidad, SIN ventana. Se ejecuta con:
##   python tools/ejecutar_pruebas.py --escena res://tools/pruebas_casos.tscn
## (a) primer arranque sin archivos; (b) partidas de una versión anterior o con datos raros; (d) INTERACTUAR muy rápido sobre
## una emoción; (h) ESC en el cuestionario, el onboarding y el final; (i) integrar a las 7 y volver a hablar con ellas.
## Los casos de ventana (pantalla completa, minimizar) están en tools/pruebas_ventana.gd, que necesita ventana.

const ARCHIVOS_USUARIO := ["ecos_save.json", "ecos_save.json.tmp", "ecos_opciones.cfg", "ecos_resultados.csv"]
const RESPALDO := "user://_respaldo_casos"
const EMOCIONES := ["rabia", "miedo", "tristeza", "soledad", "culpa", "ansiedad", "verguenza"]
var pasadas := 0
var total := 0


func comprobar(c: bool, nombre: String) -> void:
	total += 1
	if c:
		pasadas += 1
		print("OK     ", nombre)
	else:
		print("FALLO  ", nombre)


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(RESPALDO))
	for f in ARCHIVOS_USUARIO:
		if FileAccess.file_exists("user://" + f):
			DirAccess.copy_absolute(ProjectSettings.globalize_path("user://" + f), ProjectSettings.globalize_path(RESPALDO + "/" + f))
		_borrar("user://" + f)
	await get_tree().create_timer(0.3).timeout
	await _caso_a()
	await _caso_b()
	await _caso_d()
	await _caso_h()
	await _caso_i()
	for f in ARCHIVOS_USUARIO:
		_borrar("user://" + f)
		if FileAccess.file_exists(RESPALDO + "/" + f):
			DirAccess.copy_absolute(ProjectSettings.globalize_path(RESPALDO + "/" + f), ProjectSettings.globalize_path("user://" + f))
	var r := DirAccess.open(RESPALDO)
	if r != null:
		for f in r.get_files():
			r.remove(f)
		DirAccess.remove_absolute(ProjectSettings.globalize_path(RESPALDO))
	print("RESULTADO: %d de %d comprobaciones pasaron" % [pasadas, total])
	get_tree().quit(0 if pasadas == total else 1)


func _borrar(ruta: String) -> void:
	if FileAccess.file_exists(ruta):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(ruta))


func _escribir(ruta: String, texto: String) -> void:
	var f := FileAccess.open(ruta, FileAccess.WRITE)
	f.store_string(texto)
	f.close()


# (a) Primer arranque: sin partida guardada, sin opciones, sin resultados
func _caso_a() -> void:
	print("--- (a) Primer arranque sin archivos ---")
	comprobar(not GameState.hay_partida_guardada() and GameState.diagnosticar_partida() == "falta", "(a) sin partida guardada se detecta como 'falta'")
	Opciones.cargar()
	comprobar(is_equal_approx(Opciones.volumen_musica, Opciones.VOLUMEN_POR_DEFECTO) and Opciones.avisos_pistas, "(a) sin opciones guardadas se usan los valores por defecto")
	var titulo: Node = load("res://Scenes/UI/PantallaTitulo.tscn").instantiate()
	add_child(titulo)
	await get_tree().create_timer(0.8).timeout
	comprobar(not titulo.get_node("%Continuar").visible, "(a) el título no ofrece 'Continuar' sin partida")
	titulo.queue_free()
	comprobar(not GameState.cargar(), "(a) cargar sin archivo devuelve false sin romper")


# (b) Partidas de una versión anterior o con datos raros
func _caso_b() -> void:
	print("--- (b) Partidas de versiones anteriores ---")
	# Formato antiguo: tenía respuestas_inicio y no tenía compuertas, cofres, regalos ni evaluación
	_escribir("user://ecos_save.json", JSON.stringify({"epoca": "presente", "estado": {"rabia": "integrada", "miedo": "atacada"}, "habilidades": ["impulso"],
		"habilidad_seleccionada": "impulso", "fragmentos": ["rabia"], "respuestas_inicio": [0, 1, 2, 0, 1, 2, 0], "respuestas_final": [], "diario": [{"id": "rabia", "texto": "x"}], "guia_conocida": true}))
	comprobar(GameState.diagnosticar_partida() == "ok" and GameState.cargar(), "(b) una partida del formato antiguo se carga")
	comprobar(GameState.estado.get("rabia") == "integrada" and GameState.estado.get("soledad") == "pendiente" and GameState.compuertas.is_empty() and GameState.regalos.is_empty() and GameState.epoca == "presente", "(b) lo que falta queda en su valor por defecto")
	# Datos con el tipo equivocado: no debe romperse
	_escribir("user://ecos_save.json", JSON.stringify({"epoca": 5, "estado": {"rabia": "integrada", "inventada": "x", "miedo": 3}, "habilidades": "no es lista", "compuertas": "texto",
		"cofres": 5, "regalos": {"a": 1}, "pistas": [1, 2, "x"], "pista_niveles": [], "consejos_vistos": 7, "evaluacion": 3, "posicion": ["a", "b"], "fragmentos": [1, 2]}))
	comprobar(GameState.cargar(), "(b) datos con el tipo equivocado se ignoran sin romper")
	comprobar(GameState.estado.get("rabia") == "integrada" and GameState.estado.get("miedo") == "pendiente", "(b) solo se aceptan estados válidos")
	# Evaluación guardada con consentimiento pero con respuestas inventadas
	_escribir("user://ecos_save.json", JSON.stringify({"estado": {}, "evaluacion": {"participante_id": "ABCDEF", "consentimiento_dado": true, "consentimiento_guardar": true, "pre_completo": true,
		"pre": {"respuestas": {"t_rabia": 0, "no_existe": 9}, "completa": true, "marca": "x"}, "post": 4, "valoracion": 7}}))
	comprobar(GameState.cargar() and Evaluacion.participante_id == "ABCDEF" and Evaluacion.pre_completo(), "(b) una evaluación a medias o dañada se carga sin romper")
	comprobar(not Evaluacion.pre["respuestas"].has("no_existe"), "(b) las preguntas que ya no existen se descartan")
	_borrar("user://ecos_save.json")
	GameState.nueva_partida()


# (d) Pulsar INTERACTUAR muy rápido sobre una emoción
func _caso_d() -> void:
	print("--- (d) INTERACTUAR muy rápido ---")
	GameState.nueva_partida()
	Dialogo.respuesta_de_prueba = -99
	var mundo: Node = load("res://Scenes/Mundo/Mundo.tscn").instantiate()
	add_child(mundo)
	await get_tree().create_timer(0.8).timeout
	var rabia: Emocion
	for n in get_tree().get_nodes_in_group("calmable"):
		if n is Emocion and n.datos != null and n.datos.id == "rabia":
			rabia = n
	comprobar(rabia != null, "(d) la criatura de Rabia está en el Pasado")
	for i in 12:
		rabia.interactuar()   # doce pulsaciones en el mismo fotograma
	await get_tree().create_timer(0.8).timeout
	var balloons := 0
	for h in Dialogo.get_children():
		if h is DialogoBalloon:
			balloons += 1
	comprobar(balloons == 1 and Dialogo._abiertos == 1, "(d) doce pulsaciones abren UN solo diálogo (%d)" % balloons)
	for h in Dialogo.get_children():
		if h is DialogoBalloon:
			h._cancelar()
	await get_tree().create_timer(4.0).timeout   # la criatura se despide con una frase breve antes de soltar al jugador
	comprobar(not Dialogo.hay_dialogo() and GameState.estado.get("rabia") == "pendiente", "(d) cancelar cierra el diálogo y no cambia el estado")
	var jugador := get_tree().get_first_node_in_group("player") as Player
	comprobar(jugador.can_move and not rabia._ocupada, "(d) el jugador y la criatura quedan libres después")
	mundo.queue_free()
	await get_tree().create_timer(0.4).timeout


func _esc() -> void:
	for accion in ["PAUSA", "ui_cancel"]:
		var e := InputEventAction.new()
		e.action = accion
		e.pressed = true
		Input.parse_input_event(e)
	var k := InputEventKey.new()
	k.keycode = KEY_ESCAPE
	k.physical_keycode = KEY_ESCAPE
	k.pressed = true
	Input.parse_input_event(k)


# (h) ESC en el cuestionario, el onboarding y el final
func _caso_h() -> void:
	print("--- (h) ESC en las pantallas que no se pueden saltar ---")
	GameState.nueva_partida()
	Dialogo.respuesta_de_prueba = -99
	Evaluacion.consentimiento_dado = true
	Evaluacion.consentimiento_guardar = false
	Cuestionario.mostrar.call(get_tree(), "pre")
	await get_tree().create_timer(1.5).timeout
	var cuest: Cuestionario
	for h in get_tree().root.get_children():
		if h is Cuestionario:
			cuest = h
	for i in 5:
		_esc()
		await get_tree().create_timer(0.1).timeout
	comprobar(is_instance_valid(cuest) and not cuest.is_queued_for_deletion() and not Menus.pausa.abierta and not get_tree().paused, "(h) ESC en el cuestionario no lo salta ni abre la pausa")
	comprobar(not Menus.puede_abrir(), "(h) durante la evaluación no se pueden abrir el diario ni la pausa")
	cuest.queue_free()
	Evaluacion.cuestionario_activo = false
	await get_tree().create_timer(0.3).timeout
	# Onboarding
	var onboarding: Node = load("res://Scenes/Intro/Onboarding.tscn").instantiate()
	add_child(onboarding)
	await get_tree().create_timer(4.0).timeout
	var habia := Dialogo.hay_dialogo()
	for i in 6:
		_esc()
		await get_tree().create_timer(0.15).timeout
	comprobar(habia and Dialogo.hay_dialogo() and not Dialogo.pausa_permitida() and not Menus.pausa.abierta, "(h) ESC en el onboarding no cierra la introducción ni abre la pausa")
	onboarding.queue_free()
	for h in Dialogo.get_children():
		if h is DialogoBalloon:
			h.queue_free()
	await get_tree().create_timer(0.5).timeout
	Dialogo._abiertos = 0
	Dialogo._sin_cancelar = 0
	# Final
	for id in EMOCIONES:
		GameState.resolver(id, "integrada")
	var fin: Final = (load("res://Scenes/Final/Final.tscn") as PackedScene).instantiate() as Final
	add_child(fin)
	await get_tree().create_timer(8.0).timeout
	var pausa_antes := Menus.pausa.abierta
	for i in 4:
		_esc()
		await get_tree().create_timer(0.15).timeout
	comprobar(not pausa_antes and not Menus.pausa.abierta and not get_tree().paused and is_instance_valid(fin), "(h) ESC en el final no abre la pausa")
	fin.queue_free()
	for h in Dialogo.get_children():
		if h is DialogoBalloon:
			h.queue_free()
	await get_tree().create_timer(0.5).timeout
	Dialogo._abiertos = 0
	Dialogo._sin_cancelar = 0


# (i) Integrar a las 7 y volver a hablar con todas
func _caso_i() -> void:
	print("--- (i) Hablar de nuevo con las emociones integradas ---")
	GameState.nueva_partida()
	var mundo: Node = load("res://Scenes/Mundo/Mundo.tscn").instantiate()
	add_child(mundo)
	await get_tree().create_timer(0.8).timeout
	for id in EMOCIONES:
		GameState.resolver(id, "integrada")
	await get_tree().create_timer(0.5).timeout
	Dialogo.respuesta_de_prueba = 1   # "Gracias" en la charla de consejos
	var charlas := 0
	for n in get_tree().get_nodes_in_group("calmable"):
		if n is Emocion and n.is_visible_in_tree():
			await n.interactuar()
			charlas += 1
	comprobar(charlas == 7, "(i) se habla con las 7 emociones integradas (%d)" % charlas)
	comprobar(GameState.cantidad_consejos_vistos() >= 7, "(i) cada una da un consejo (%d vistos)" % GameState.cantidad_consejos_vistos())
	var integradas := true
	for id in EMOCIONES:
		integradas = integradas and GameState.estado.get(id) == "integrada"
	comprobar(integradas and GameState.habilidades.size() == 7, "(i) volver a hablar no cambia los estados ni repite habilidades")
	Dialogo.respuesta_de_prueba = -99
	mundo.queue_free()
