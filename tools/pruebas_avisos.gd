extends Node
## Pruebas de los avisos (Notificacion), SIN ventana:
##   python tools/ejecutar_pruebas.py --escena res://tools/pruebas_avisos.tscn
## Duración según el texto, pausa con el ratón encima y con diálogo, cola con contador, cierre con X y con
## clic en la ✕, historial y guardado.

var pasadas := 0
var total := 0


func comprobar(c: bool, nombre: String) -> void:
	total += 1
	if c:
		pasadas += 1
		print("OK     ", nombre)
	else:
		print("FALLO  ", nombre)


const RESPALDO := "user://_respaldo_avisos.json"
var _habia_partida := false


func _ready() -> void:
	# La prueba guarda partidas: la tuya se respalda ahora y se restaura al terminar
	_habia_partida = FileAccess.file_exists(GameState.RUTA_GUARDADO)
	if _habia_partida:
		DirAccess.copy_absolute(ProjectSettings.globalize_path(GameState.RUTA_GUARDADO), ProjectSettings.globalize_path(RESPALDO))
	await get_tree().create_timer(0.3).timeout
	GameState.nueva_partida()
	Opciones.duracion_avisos = 0
	await _duraciones()
	await _cierre_con_x()
	await _cierre_con_clic()
	await _pausa()
	await _cola()
	await _historial_y_guardado()
	Opciones.duracion_avisos = 0
	DirAccess.remove_absolute(ProjectSettings.globalize_path(GameState.RUTA_GUARDADO))
	if _habia_partida:
		DirAccess.copy_absolute(ProjectSettings.globalize_path(RESPALDO), ProjectSettings.globalize_path(GameState.RUTA_GUARDADO))
		DirAccess.remove_absolute(ProjectSettings.globalize_path(RESPALDO))
	print("RESULTADO: %d de %d comprobaciones pasaron" % [pasadas, total])
	get_tree().quit(0 if pasadas == total else 1)


func _esperar_fin() -> void:
	var limite := 0
	while Notificacion.mostrando and limite < 600:
		await get_tree().process_frame
		limite += 1


func _duraciones() -> void:
	var N := Notificacion
	comprobar(is_equal_approx(N.segundos_base("Hola", "corto"), 6.0), "texto corto: mínimo de 6 s")
	comprobar(is_equal_approx(N.segundos_base("A", "x".repeat(79)), 4.0 + 0.07 * 80.0), "texto medio: 4 s + 0.07 s por carácter (9.6 s)")
	comprobar(is_equal_approx(N.segundos_base("A", "x".repeat(500)), 14.0), "texto largo: máximo de 14 s")
	comprobar(is_equal_approx(N.segundos_base("A", "x", true), 20.0), "importante: espera hasta 20 s")
	Opciones.duracion_avisos = 1
	comprobar(is_equal_approx(N.duracion_para("Hola", "corto"), 12.0), "opción Larga: el doble")
	Opciones.duracion_avisos = 2
	comprobar(N.duracion_para("Hola", "corto") == INF, "opción Hasta cerrar: sin límite")
	Opciones.duracion_avisos = 0


func _cierre_con_x() -> void:
	Notificacion.mostrar("Prueba X", "Se cierra con la tecla X.")
	await get_tree().create_timer(0.8).timeout
	comprobar(Notificacion.mostrando and Notificacion._tarjeta.visible, "el aviso se ve")
	comprobar(Notificacion.restante > 5.0 and Notificacion.restante <= 6.0, "la cuenta atrás parte de 6 s")
	var ev := InputEventAction.new()
	ev.action = "CERRAR_AVISO"
	ev.pressed = true
	Input.parse_input_event(ev)
	await get_tree().create_timer(0.8).timeout
	comprobar(not Notificacion.mostrando and not Notificacion._tarjeta.visible, "la tecla X cierra el aviso con fundido")


func _cierre_con_clic() -> void:
	Notificacion.mostrar("Prueba clic", "Se cierra con la ✕.")
	await get_tree().create_timer(0.8).timeout
	Notificacion._boton_cerrar.pressed.emit()
	await get_tree().create_timer(0.8).timeout
	comprobar(not Notificacion.mostrando, "el botón ✕ cierra el aviso")
	# Sin aviso en pantalla, X no hace nada ni rompe
	Notificacion.cerrar()
	comprobar(not Notificacion.mostrando, "cerrar sin aviso no hace nada")


func _pausa() -> void:
	Notificacion.mostrar("Prueba pausa", "La cuenta atrás espera.")
	await get_tree().create_timer(0.8).timeout
	var antes := Notificacion.restante
	await get_tree().create_timer(0.5).timeout
	comprobar(Notificacion.restante < antes - 0.3, "la cuenta atrás baja con normalidad")
	Notificacion._tarjeta.mouse_entered.emit()
	await get_tree().process_frame
	var fijo := Notificacion.restante
	await get_tree().create_timer(0.5).timeout
	comprobar(is_equal_approx(Notificacion.restante, fijo) and not Notificacion.contando, "con el ratón encima se pausa")
	Notificacion._tarjeta.mouse_exited.emit()
	Dialogo._abiertos += 1   # simula un diálogo abierto
	await get_tree().process_frame
	fijo = Notificacion.restante
	await get_tree().create_timer(0.5).timeout
	comprobar(is_equal_approx(Notificacion.restante, fijo), "con un diálogo abierto se pausa")
	Dialogo._abiertos -= 1
	await get_tree().create_timer(0.4).timeout
	comprobar(Notificacion.restante < fijo - 0.2, "al cerrarse el diálogo sigue contando")
	Notificacion.cerrar()
	await _esperar_fin()


func _cola() -> void:
	Notificacion.mostrar("Uno", "primero")
	Notificacion.mostrar("Dos", "segundo")
	Notificacion.mostrar("Tres", "tercero")
	await get_tree().create_timer(0.8).timeout
	comprobar(Notificacion._contador.text == "1 de 3" and Notificacion._titulo.text == "Uno", "cola: sale primero 'Uno' con '1 de 3'")
	comprobar(Notificacion.pendientes() == 2, "cola: quedan 2 esperando")
	Notificacion.cerrar()
	await get_tree().create_timer(0.55).timeout   # fundido + hueco: aún no ha salido el siguiente
	comprobar(Notificacion._titulo.text == "Uno" or not Notificacion._tarjeta.visible, "cola: no se superponen")
	await get_tree().create_timer(1.2).timeout
	comprobar(Notificacion._titulo.text == "Dos" and Notificacion._contador.text == "2 de 3", "cola: el siguiente es 'Dos' con '2 de 3'")
	Notificacion.cerrar()
	await get_tree().create_timer(1.6).timeout
	Notificacion.cerrar()
	await _esperar_fin()
	comprobar(not Notificacion.mostrando and Notificacion.pendientes() == 0, "cola: se vacía sin perder ninguno")
	# Importante + Hasta cerrar
	Opciones.duracion_avisos = 2
	Notificacion.mostrar("Importante", "Hasta cerrar", true)
	await get_tree().create_timer(0.8).timeout
	comprobar(Notificacion.restante == INF, "Hasta cerrar: no caduca")
	Notificacion.cerrar()
	await _esperar_fin()
	Opciones.duracion_avisos = 0


func _historial_y_guardado() -> void:
	GameState.avisos.clear()
	for i in 35:
		GameState.registrar_aviso("Aviso %d" % i, "texto %d" % i)
	comprobar(GameState.avisos.size() == 30 and GameState.avisos[0]["titulo"] == "Aviso 5", "historial: solo los últimos 30")
	GameState.tiempo_jugado = 125.0
	GameState.registrar_aviso("Con hora", "x")
	comprobar(is_equal_approx(float(GameState.avisos[-1]["hora"]), 125.0), "historial: guarda la hora de juego")
	var ok := GameState.guardar()
	GameState.nueva_partida()
	comprobar(GameState.avisos.is_empty(), "nueva partida limpia los avisos")
	GameState.cargar()
	comprobar(ok and GameState.avisos.size() == 30 and GameState.avisos[-1]["titulo"] == "Con hora", "los avisos se guardan y se cargan")
	comprobar(GameState.tiempo_jugado >= 125.0, "el tiempo jugado se carga")
	GameState.nueva_partida()
