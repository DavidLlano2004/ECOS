extends Node
## Pruebas de humo de ECOS, SIN ventana. Recorre el juego forzando estados y cuenta cuántas comprobaciones pasan.
## Se ejecuta con:   godot --headless --path . res://tools/pruebas_humo.tscn
## (o con tools/ejecutar_pruebas.py, que además vigila que no haya errores ni advertencias en la consola).
## Imprime una línea "OK" o "FALLO" por comprobación y al final "RESULTADO: N de M".
##
## Protege los archivos de la carpeta de datos del jugador (partida, opciones, resultados...): los copia antes y los
## restaura al terminar.

const MUNDO := "res://Scenes/Mundo/Mundo.tscn"
const EMOCIONES := ["rabia", "miedo", "tristeza", "soledad", "culpa", "ansiedad", "verguenza"]
const ARCHIVOS_USUARIO := ["ecos_save.json", "ecos_save.json.tmp", "ecos_opciones.cfg", "ecos_resultados.csv", "ecos_resultados_v2.csv", "ecos_resultados_v3.csv"]
const RESPALDO := "user://_respaldo_pruebas"

var pasadas := 0
var total := 0
var mundo: Node
var jugador: Player
var _conductor := "ninguno"     # "cuestionario", "valoracion", "resultados", "consentimiento_si", "consentimiento_no"
var _ultimo_clic := 0


func comprobar(condicion: bool, nombre: String) -> void:
	total += 1
	if condicion:
		pasadas += 1
		print("OK     ", nombre)
	else:
		print("FALLO  ", nombre)


func _ready() -> void:
	Engine.time_scale = 8.0
	_respaldar()
	await get_tree().create_timer(0.3).timeout
	await _paso_titulo()
	await _paso_nueva_partida_y_consentimiento()
	await _paso_cuestionario_inicial()
	await _paso_mundo()
	await _paso_emociones()
	await _paso_viaje()
	await _paso_bloqueos_y_cofres()
	await _paso_habilidades()
	await _paso_menus()
	await _paso_guardar_y_cargar()
	await _paso_finales_y_evaluacion()
	await _paso_titulo_final()
	Engine.time_scale = 1.0
	_restaurar()
	print("RESULTADO: %d de %d comprobaciones pasaron" % [pasadas, total])
	get_tree().quit(0 if pasadas == total else 1)


# --- Respaldo de los archivos del jugador ---

func _respaldar() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(RESPALDO))
	for f in ARCHIVOS_USUARIO:
		if FileAccess.file_exists("user://" + f):
			DirAccess.copy_absolute(ProjectSettings.globalize_path("user://" + f), ProjectSettings.globalize_path(RESPALDO + "/" + f))
		_borrar("user://" + f)


func _restaurar() -> void:
	for f in ARCHIVOS_USUARIO:
		_borrar("user://" + f)
		if FileAccess.file_exists(RESPALDO + "/" + f):
			DirAccess.copy_absolute(ProjectSettings.globalize_path(RESPALDO + "/" + f), ProjectSettings.globalize_path("user://" + f))
	for carpeta in ["sesiones", "reportes"]:
		var d := DirAccess.open("user://" + carpeta)
		if d != null:
			for f in d.get_files():
				d.remove(f)
			DirAccess.remove_absolute(ProjectSettings.globalize_path("user://" + carpeta))
	var r := DirAccess.open(RESPALDO)
	if r != null:
		for f in r.get_files():
			r.remove(f)
		DirAccess.remove_absolute(ProjectSettings.globalize_path(RESPALDO))


func _borrar(ruta: String) -> void:
	if FileAccess.file_exists(ruta):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(ruta))


# --- Conductor: pulsa los botones de las pantallas de evaluación ---

func _process(_delta: float) -> void:
	if _conductor == "ninguno" or Time.get_ticks_msec() - _ultimo_clic < 60:
		return
	for h in get_tree().root.get_children():
		if _conductor == "cuestionario" and h is Cuestionario:
			if h._panel_intro.visible and not h._boton_seguir.disabled:
				_pulsar(h._boton_seguir)
			elif h._panel_pregunta.visible and h._panel_pregunta.modulate.a > 0.9 and not h._botones.is_empty() and not h._botones[0].disabled:
				_pulsar(h._botones[randi() % h._botones.size()])   # al azar
			return
		if _conductor.begins_with("consentimiento") and h is Consentimiento:
			var botones: Array = h.find_children("*", "Button", true, false)
			if botones.size() >= 2:
				_pulsar(botones[0] if _conductor == "consentimiento_si" else botones[1])
			return
		if _conductor == "valoracion" and h is Valoracion:
			if h._cerrando:
				return
			var botones_v: Array = h._caja.find_children("*", "Button", true, false).filter(func(b): return not b.disabled and b.is_visible_in_tree())
			if botones_v.is_empty():
				return
			if not h._textos.is_empty():
				(h._textos["gusto"] as TextEdit).text = "Prueba de humo, con comas, y \"comillas\""
				for b in botones_v:
					if b.text == "Enviar":
						_pulsar(b)
				return
			for b in botones_v:
				if b.text != "Ahora no":
					_pulsar(b)
					return
			return
		if _conductor == "resultados" and h is Resultados:
			h.cerrar_para_pruebas()
			return


func _pulsar(boton: Button) -> void:
	_ultimo_clic = Time.get_ticks_msec()
	boton.pressed.emit()


func _esperar_a_que_no_haya(clase: Variant, limite_ms: int = 90000) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < limite_ms:
		var hay := false
		for h in get_tree().root.get_children():
			if is_instance_of(h, clase):
				hay = true
		if not hay:
			return
		await get_tree().create_timer(0.1).timeout


# --- Pasos ---

func _paso_titulo() -> void:
	print("--- Título ---")
	var titulo: Node = load("res://Scenes/UI/PantallaTitulo.tscn").instantiate()
	add_child(titulo)
	await get_tree().create_timer(1.0).timeout
	comprobar(titulo.get_node_or_null("%Comenzar") != null, "el título tiene el botón Comenzar")
	titulo.queue_free()
	await get_tree().create_timer(0.2).timeout


func _paso_nueva_partida_y_consentimiento() -> void:
	print("--- Nueva partida y consentimiento ---")
	GameState.nueva_partida()
	var todo_pendiente := true
	for id in EMOCIONES:
		todo_pendiente = todo_pendiente and GameState.estado.get(id) == "pendiente"
	comprobar(todo_pendiente and GameState.compuertas.is_empty() and GameState.cofres.is_empty(), "nueva partida: todo limpio")
	comprobar(Evaluacion.participante_id.length() == 6 and Evaluacion.valido, "evaluación: participante de 6 caracteres y banco válido")
	# Consentimiento aceptando
	_conductor = "consentimiento_si"
	await Consentimiento.mostrar(get_tree())
	comprobar(Evaluacion.consentimiento_dado and Evaluacion.consentimiento_guardar, "consentimiento: 'Acepto y continúo' guarda")
	# Consentimiento sin guardar
	Evaluacion.reiniciar()
	_conductor = "consentimiento_no"
	await Consentimiento.mostrar(get_tree())
	comprobar(Evaluacion.consentimiento_dado and not Evaluacion.consentimiento_guardar, "consentimiento: 'Jugar sin guardar' no guarda")
	_conductor = "ninguno"
	# Se vuelve a aceptar para el resto del recorrido
	Evaluacion.consentimiento_guardar = true


func _paso_cuestionario_inicial() -> void:
	print("--- Cuestionario inicial (al azar) ---")
	_conductor = "cuestionario"
	await Cuestionario.mostrar(get_tree(), "pre")
	_conductor = "ninguno"
	comprobar(Evaluacion.pre_completo() and Evaluacion.pre["respuestas"].size() == 16, "cuestionario inicial: 16 respuestas y fase completa")
	var p: Dictionary = Evaluacion.pre["puntajes"]
	comprobar(int(p["trivia"]) >= 0 and int(p["trivia"]) <= 7 and int(p["situaciones"]) <= 7 and int(p["escala"]) >= 2 and int(p["escala"]) <= 10, "cuestionario inicial: puntajes dentro de rango")
	comprobar(not Evaluacion.cuestionario_activo, "cuestionario inicial: libera la bandera de evaluación")


func _paso_mundo() -> void:
	print("--- Mundo ---")
	mundo = load(MUNDO).instantiate()
	add_child(mundo)
	await get_tree().create_timer(0.8).timeout
	jugador = get_tree().get_first_node_in_group("player") as Player
	comprobar(jugador != null, "mundo: hay jugador")
	var compuertas := get_tree().get_nodes_in_group("compuerta").size()
	comprobar(compuertas == 6, "mundo: 3 compuertas en cada época (%d)" % compuertas)
	comprobar(get_tree().get_nodes_in_group("santuario").size() == 7, "mundo: 7 santuarios en el Presente")
	comprobar(get_tree().get_nodes_in_group("bloqueos_presente").size() == 7, "mundo: 7 bloqueos del Presente")
	comprobar(get_tree().get_nodes_in_group("portales").size() >= 8, "mundo: portales y grietas")
	comprobar(Sonido.faltan.is_empty(), "audio: no falta ningún sonido del catálogo")


## Recorre un .dialogue con DialogueManager (sin pantalla) eligiendo la respuesta `indice`; devuelve las líneas leídas.
func _recorrer(id_emocion: String, indice: int, detener_en: int = -1) -> int:
	var recurso := load("res://Dialogos/%s.dialogue" % id_emocion) as DialogueResource
	var linea: DialogueLine = await DialogueManager.get_next_dialogue_line(recurso, "start", [])
	var leidas := 0
	while linea != null and leidas < 40:
		leidas += 1
		if detener_en != -1 and leidas >= detener_en:
			return leidas   # cancelar: se corta a la mitad, sin ejecutar nada más
		var siguiente := linea.next_id
		if not linea.responses.is_empty():
			siguiente = linea.responses[mini(indice, linea.responses.size() - 1)].next_id
		linea = await DialogueManager.get_next_dialogue_line(recurso, siguiente, [])
	return leidas


func _paso_emociones() -> void:
	print("--- Hablar con cada emoción: atacar, ignorar, escuchar y cancelar ---")
	var esperado := ["atacada", "ignorada", "integrada"]
	for id in EMOCIONES:
		var bien := true
		for opcion in 3:
			GameState.resolver(id, "pendiente")
			var leidas := await _recorrer(id, opcion)
			if GameState.estado.get(id) != esperado[opcion] or leidas < 3:
				bien = false
		comprobar(bien, "%s: atacar, ignorar y escuchar dan atacada, ignorada e integrada" % id)
		# Cancelar a la mitad: no cambia nada
		GameState.resolver(id, "pendiente")
		await _recorrer(id, 0, 2)
		comprobar(GameState.estado.get(id) == "pendiente", "%s: cancelar a la mitad no cambia el estado" % id)
		GameState.resolver(id, "pendiente")
	# Los textos de integración/fallo existen y son del nombre de la emoción
	var datos_completos := true
	for id in EMOCIONES:
		var d := GameState.obtener_datos(id)
		for c in [d.nombre, d.mensaje_integracion, d.mensaje_fallo, d.mensaje_presente_aliada, d.frase_cierre, d.regalo_nombre, d.frase_agradecimiento]:
			if str(c).strip_edges() == "":
				datos_completos = false
	comprobar(datos_completos, "emociones: todos los textos de las 7 están escritos")


func _paso_viaje() -> void:
	print("--- Viajar de época y volver ---")
	var antes := GameState.epoca
	mundo.viajar()
	await get_tree().create_timer(1.8).timeout
	comprobar(GameState.epoca != antes, "viajar: cambia de época")
	mundo.viajar()
	await get_tree().create_timer(1.8).timeout
	comprobar(GameState.epoca == antes, "viajar: vuelve a la época de origen")
	# Viajar con la Pausa y la Visión activas
	for e in ["ansiedad", "miedo"]:
		GameState.resolver(e, "integrada")
	Habilidades.seleccionar("pausa")
	Habilidades.usar(jugador)
	var factor_activo := not is_equal_approx(Habilidades.factor_tiempo, 1.0) or Habilidades.esta_activa("pausa")
	mundo.viajar()
	await get_tree().create_timer(1.8).timeout
	comprobar(factor_activo, "viajar con Pausa activa: el efecto estaba en marcha")
	Habilidades.reiniciar_para_pruebas() if Habilidades.has_method("reiniciar_para_pruebas") else null
	Habilidades.seleccionar("vision")
	Habilidades.usar(jugador)
	mundo.viajar()
	await get_tree().create_timer(1.8).timeout
	comprobar(is_instance_valid(jugador) and GameState.epoca in ["pasado", "presente"], "viajar con Visión activa: sin romper nada")
	if GameState.epoca != "pasado":
		mundo.viajar()
		await get_tree().create_timer(1.8).timeout
	for e in ["ansiedad", "miedo"]:
		GameState.resolver(e, "pendiente")


func _paso_bloqueos_y_cofres() -> void:
	print("--- Los 7 bloqueos y los cofres ---")
	Dialogo.respuesta_de_prueba = 0   # los mensajes automáticos (compuertas, agradecimientos) no abren ventanas
	GameState.nueva_partida()
	Evaluacion.consentimiento_dado = true
	Evaluacion.consentimiento_guardar = true
	if GameState.epoca != "presente":
		GameState.cambiar_epoca()
	await get_tree().create_timer(1.5).timeout
	for id in EMOCIONES:
		GameState.resolver(id, "integrada")
	await get_tree().create_timer(2.5).timeout
	var abiertos := 0
	for b in get_tree().get_nodes_in_group("bloqueos_presente"):
		if b.estado_mostrado == "integrada":
			abiertos += 1
	comprobar(abiertos == 7, "bloqueos: los 7 se abren al integrar (%d)" % abiertos)
	for id in ["puente_rabia", "roca_verguenza", "zarzal_ansiedad"]:
		GameState.abrir_compuerta(id)
	var cofres := {}
	for s in get_tree().get_nodes_in_group("santuario"):
		cofres[s.datos.id] = s.get_node("Cofre")
	var todos_abiertos := true
	for id in EMOCIONES:
		var cofre: CofreMemoria = cofres[id]
		cofre.interactuar()
		await get_tree().create_timer(2.6).timeout
		if not GameState.cofre_esta_abierto(id):
			todos_abiertos = false
	comprobar(todos_abiertos and GameState.regalos.size() == 7 and GameState.regalos_completos, "cofres: los 7 se abren y dan sus regalos")
	var niveles_ok := true
	for entrada in Habilidades.catalogo:
		niveles_ok = niveles_ok and Habilidades.nivel_de(entrada["id"]) == 2
	comprobar(niveles_ok, "cofres: las 7 habilidades suben a nivel 2")
	# Solo se entregan una vez
	comprobar(not GameState.abrir_cofre("rabia"), "cofres: no se vuelve a entregar")


func _paso_habilidades() -> void:
	print("--- Cada habilidad ---")
	jugador.global_position = mundo.posicion_zona("Hub") + Vector2(0, 80)
	var sin_error := true
	for entrada in Habilidades.catalogo:
		var id: String = entrada["id"]
		Habilidades.cooldowns.clear()
		Habilidades.seleccionar(id)
		jugador.facing = Vector2.RIGHT
		Habilidades.usar(jugador)
		await get_tree().create_timer(0.5).timeout
		if id == "impulso" or id == "calma" or id == "revelar" or id == "vinculo" or id == "pausa" or id == "vision":
			sin_error = sin_error and is_instance_valid(jugador)
		# Se apagan los efectos que quedan encendidos
		if id in ["vision", "pausa", "vinculo"]:
			Habilidades.cooldowns.clear()
			Habilidades.usar(jugador)
			await get_tree().create_timer(0.3).timeout
		jugador.terminar_impulso()
	comprobar(sin_error, "habilidades: las 7 se usan sin romper nada")
	comprobar(Habilidades.catalogo.size() == 7, "habilidades: el catálogo tiene 7")
	# Reparar sin nada cerca avisa y no gasta cooldown
	jugador.global_position = mundo.posicion_zona("Hub") + Vector2(0, 120)
	Habilidades.cooldowns.clear()
	Habilidades.seleccionar("reparacion")
	Habilidades.usar(jugador)
	await get_tree().create_timer(0.3).timeout
	comprobar(Habilidades.cooldown_restante("reparacion") == 0.0, "Reparar sin nada cerca no gasta cooldown")


func _paso_menus() -> void:
	print("--- Diario y pausa ---")
	await get_tree().create_timer(0.3).timeout
	Menus.abrir_diario()
	await get_tree().create_timer(0.4).timeout
	comprobar(Menus.diario.abierto and get_tree().paused, "diario: se abre y pausa el juego")
	# Recorre las 7 secciones
	var secciones_ok := true
	for i in Menus.diario.SECCIONES.size():
		Menus.diario.ir_a_seccion(i)
		await get_tree().process_frame
		secciones_ok = secciones_ok and Menus.diario.seccion == i
	comprobar(secciones_ok, "diario: las %d secciones se muestran" % Menus.diario.SECCIONES.size())
	Menus.cerrar_diario()
	await get_tree().create_timer(0.4).timeout
	comprobar(not Menus.diario.abierto and not get_tree().paused, "diario: se cierra y reanuda el juego")
	Menus.abrir_pausa()
	await get_tree().create_timer(0.4).timeout
	comprobar(Menus.pausa.abierta and get_tree().paused, "pausa: se abre y pausa el juego")
	Menus.cerrar_pausa()
	await get_tree().create_timer(0.4).timeout
	comprobar(not Menus.pausa.abierta and not get_tree().paused, "pausa: se cierra y reanuda")
	# Abrir y cerrar muchas veces seguidas
	for i in 40:
		Menus.abrir_diario()
		await get_tree().process_frame
		Menus.cerrar_diario()
		Menus.abrir_pausa()
		await get_tree().process_frame
		Menus.cerrar_pausa()
	await get_tree().create_timer(0.6).timeout
	comprobar(not Menus.hay_menu() and not get_tree().paused, "menús: 40 aperturas y cierres seguidos no dejan el juego pausado")
	Dialogo.respuesta_de_prueba = -99


func _paso_guardar_y_cargar() -> void:
	print("--- Guardar y cargar con estados mezclados ---")
	GameState.nueva_partida()
	var mezcla := ["integrada", "atacada", "ignorada", "pendiente", "integrada", "atacada", "integrada"]
	for i in EMOCIONES.size():
		GameState.resolver(EMOCIONES[i], mezcla[i])
	GameState.abrir_compuerta("puente_rabia")
	GameState.recoger_fragmento("rabia")
	GameState.abrir_cofre("rabia")
	Evaluacion.consentimiento_dado = true
	Evaluacion.consentimiento_guardar = true
	var antes_estado := GameState.estado.duplicate()
	var antes_habilidades := GameState.habilidades.duplicate()
	comprobar(GameState.guardar(), "guardar: escribe el archivo")
	comprobar(GameState.diagnosticar_partida() == "ok", "guardar: el archivo es válido")
	GameState.nueva_partida()
	comprobar(GameState.cargar(), "cargar: lee la partida")
	var igual := true
	for id in EMOCIONES:
		igual = igual and GameState.estado.get(id) == antes_estado.get(id)
	comprobar(igual, "cargar: los estados mezclados coinciden")
	comprobar(GameState.habilidades == antes_habilidades and GameState.compuerta_esta_abierta("puente_rabia") and GameState.tiene_fragmento("rabia") and GameState.cofre_esta_abierto("rabia"), "cargar: habilidades, compuertas, fragmentos y cofres")
	# Archivo dañado, vacío y borrado a mitad de partida
	var f := FileAccess.open("user://ecos_save.json", FileAccess.WRITE)
	f.store_string("{esto no es json")
	f.close()
	comprobar(GameState.diagnosticar_partida() == "danada" and not GameState.cargar(), "partida dañada: se detecta y no rompe")
	f = FileAccess.open("user://ecos_save.json", FileAccess.WRITE)
	f.close()
	comprobar(GameState.diagnosticar_partida() == "danada" and not GameState.cargar(), "partida vacía: se detecta y no rompe")
	_borrar("user://ecos_save.json")
	comprobar(GameState.diagnosticar_partida() == "falta" and not GameState.cargar(), "partida borrada: se detecta y no rompe")
	comprobar(GameState.guardar() and GameState.diagnosticar_partida() == "ok", "después de borrarla se puede volver a guardar")
	_borrar("user://ecos_save.json")


func _paso_finales_y_evaluacion() -> void:
	print("--- Los tres finales, cuestionario final, resultados, valoración y exportación ---")
	if is_instance_valid(mundo):
		mundo.queue_free()
	await get_tree().create_timer(0.4).timeout
	var casos := [
		["bueno", ["integrada", "integrada", "integrada", "integrada", "integrada", "integrada", "integrada"]],
		["neutro", ["integrada", "atacada", "integrada", "ignorada", "integrada", "atacada", "integrada"]],
		["dificil", ["atacada", "ignorada", "atacada", "ignorada", "integrada", "atacada", "ignorada"]],
	]
	for caso in casos:
		GameState.nueva_partida()
		Evaluacion.consentimiento_dado = true
		Evaluacion.consentimiento_guardar = true
		for i in EMOCIONES.size():
			GameState.resolver(EMOCIONES[i], caso[1][i])
		for id in EMOCIONES:
			GameState.recoger_fragmento(id)
		# Se hace el "pre" directo (el cuestionario real ya se probó) para centrarse en el final
		Evaluacion.iniciar_fase("pre")
		for p in Evaluacion.orden_para("pre"):
			Evaluacion.registrar("pre", p["id"], 1 if p["bloque"] != "escala" else 2)
		Evaluacion.calcular("pre")
		Dialogo.respuesta_de_prueba = 1   # "Cerrar mi viaje" en los finales con decisión
		var f: Final = (load("res://Scenes/Final/Final.tscn") as PackedScene).instantiate() as Final
		f.modo_prueba = true
		var destino := [""]
		f.secuencia_terminada.connect(func(d: String) -> void: destino[0] = d)
		add_child(f)
		# Al cerrar el viaje se hace el cuestionario final (al azar) y se muestran los resultados
		_conductor = "cuestionario"
		var t0 := Time.get_ticks_msec()
		var vio_resultados := false
		while destino[0] == "" and Time.get_ticks_msec() - t0 < 150000:
			await get_tree().create_timer(0.2).timeout
			for h in get_tree().root.get_children():
				if h is Resultados:
					vio_resultados = true
					_conductor = "valoracion" if not Evaluacion.valoracion_enviada() else "resultados"
					if _conductor == "valoracion":
						# primero se abre la valoración desde los resultados
						h._dar_opinion.call()
						await get_tree().create_timer(0.5).timeout
						await _esperar_a_que_no_haya(Valoracion, 60000)
						_conductor = "resultados"
		_conductor = "ninguno"
		comprobar(f.tipo == caso[0] and destino[0] == "titulo", "final %s: se llega al título tras el cuestionario final y los resultados" % caso[0])
		comprobar(vio_resultados and Evaluacion.post_completo(), "final %s: cuestionario final completo y pantalla de resultados" % caso[0])
		var codigo := CodigoResultados.generar()
		comprobar(CodigoResultados.decodificar(codigo)["ok"] and codigo.length() < 600, "final %s: el código de resultados se genera y se decodifica (%d caracteres)" % [caso[0], codigo.length()])
		comprobar(Evaluacion.valoracion_enviada(), "final %s: la valoración se envió" % caso[0])
		f.queue_free()
		await get_tree().create_timer(0.5).timeout
	Dialogo.respuesta_de_prueba = -99
	# Exportación: el CSV con su fila y la valoración
	comprobar(FileAccess.file_exists("user://ecos_resultados.csv"), "exportación: existe ecos_resultados.csv")
	var lectura := FileAccess.open("user://ecos_resultados.csv", FileAccess.READ)
	var cabecera := lectura.get_csv_line()
	var filas := 0
	while not lectura.eof_reached():
		var c := lectura.get_csv_line()
		if c.size() == cabecera.size():
			filas += 1
	lectura.close()
	comprobar(filas == 3 and cabecera.has("val_nota") and cabecera.has("pre_t_rabia"), "exportación: 3 filas (una por final) y las columnas de preguntas y valoración (%d filas)" % filas)
	# Sin consentimiento no se escribe nada
	_borrar("user://ecos_resultados.csv")
	Evaluacion.reiniciar()
	Evaluacion.consentimiento_dado = true
	Evaluacion.consentimiento_guardar = false
	Evaluacion.iniciar_fase("post")
	for p in Evaluacion.orden_para("post"):
		Evaluacion.registrar("post", p["id"], 0 if p["bloque"] != "escala" else 4)
	Evaluacion.calcular("post")
	Evaluacion.fase_terminada.emit("post")
	comprobar(not FileAccess.file_exists("user://ecos_resultados.csv"), "exportación: sin consentimiento no se escribe el CSV")


func _paso_titulo_final() -> void:
	print("--- Volver al título ---")
	var titulo: Node = load("res://Scenes/UI/PantallaTitulo.tscn").instantiate()
	add_child(titulo)
	await get_tree().create_timer(1.0).timeout
	comprobar(titulo.get_node_or_null("%Comenzar") != null and not Evaluacion.cuestionario_activo, "título: vuelve a mostrarse con todo liberado")
	comprobar(not get_tree().paused and not Dialogo.hay_dialogo(), "título: el juego no queda pausado ni con diálogos")
	titulo.queue_free()
