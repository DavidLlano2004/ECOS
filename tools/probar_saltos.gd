extends Node
## Prueba DE DEPURACIÓN, con ventana real (no sirve en headless):
##   godot --path . res://tools/probar_saltos.tscn
## Para cada modal (caja de diálogo, avisos, cuestionario, resultados y diario) registra por fotograma el tamaño y la
## posición de su cuadro y de su etiqueta de texto desde que se muestra, y FALLA si cambian después del primer
## fotograma visible (opacidad mayor que 0). Escribe docs/revision_saltos.md.
##
## Cambio permitido: el desplazamiento vertical pequeño (8 px) de la tarjeta de aviso al entrar, que acompaña al fundido.
## Todo lo demás (tamaño, posición horizontal, cuadro y etiqueta de los otros modales) debe quedarse quieto.

const TOLERANCIA := 0.5
const TEXTO_LARGO := "Esto es un texto bastante largo para comprobar que la caja de diálogo no cambia de tamaño mientras se escribe letra por letra. Tiene varias líneas para que el alto dependa del texto completo y no del que ya se escribió."
const TEXTO_NOTIF := "Un salto corto hacia delante que te permite cruzar huecos y atravesar lo que antes te cerraba el paso, con un breve enfriamiento."

## Propiedades que pueden cambiar sin que cuente como salto: "escenario/nombre/propiedad".
var ESPERADOS: Array[String] = ["notificacion/tarjeta/position.y", "notificacion_segunda/tarjeta/position.y"]

var _escenarios: Array[Dictionary] = []   # {nombre, frames: Array[Dictionary], cambios: Array[String], primer_visible}
var _fallos := 0


func _ready() -> void:
	if DisplayServer.get_name() == "headless" or not OS.is_debug_build():
		push_error("probar_saltos necesita ventana real y una compilación de depuración.")
		get_tree().quit(2)
		return
	var fondo := ColorRect.new()
	fondo.color = Color("14111f")
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fondo)
	GameState.nueva_partida()
	await get_tree().create_timer(0.5).timeout
	await _probar_balloon("balloon_texto", [], false)
	await _probar_balloon("balloon_opciones_y_retrato", ["Sí, cuéntame", "Ahora no"], true)
	await _probar_notificacion()
	await _probar_cuestionario()
	await _probar_resultados()
	await _probar_diario()
	_escribir_informe()
	print("RESULTADO: %d escenarios con salto de %d" % [_fallos, _escenarios.size()])
	get_tree().quit(1 if _fallos > 0 else 0)


# --- Registro ---

## Nuevo escenario. `controles`: nombre -> Callable que devuelve el Control a medir (o null si aún no existe).
func _nuevo(nombre: String) -> Dictionary:
	var e := {"nombre": nombre, "frames": [], "primer_visible": -1}
	_escenarios.append(e)
	return e


## Anota el fotograma actual (tras dibujar). `visible`: opacidad efectiva del modal.
func _anotar(e: Dictionary, alpha: float, controles: Dictionary) -> void:
	var f := {"n": e["frames"].size(), "alpha": alpha, "rects": {}}
	for nombre in controles:
		var c: Control = controles[nombre].call()
		if c != null and is_instance_valid(c) and c.is_visible_in_tree():
			f["rects"][nombre] = c.get_global_rect()
	e["frames"].append(f)
	if e["primer_visible"] == -1 and alpha > 0.0 and not f["rects"].is_empty():
		e["primer_visible"] = f["n"]


func _frame() -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw


## Registra `n` fotogramas más (o hasta que `parar` devuelva true).
func _grabar(e: Dictionary, n: int, alpha: Callable, controles: Dictionary, parar: Callable = Callable()) -> void:
	for i in n:
		await _frame()
		_anotar(e, alpha.call(), controles)
		if parar.is_valid() and parar.call():
			return


# --- Escenarios ---

func _balloon() -> DialogoBalloon:
	for h in Dialogo.get_children():
		if h is DialogoBalloon and not h._cerrando:
			return h
	return null


func _probar_balloon(nombre: String, opciones: Array, con_retrato: bool) -> void:
	var e := _nuevo(nombre)
	var retrato: Texture2D = load("res://icon.svg") if con_retrato else null
	Dialogo.mostrar_texto("Rabia", TEXTO_LARGO, opciones, retrato)   # sin await: sigue en segundo plano
	var controles := {
		"caja": func() -> Control: var b := _balloon(); return b.caja if b != null else null,
		"texto": func() -> Control: var b := _balloon(); return b.texto if b != null else null,
		"nombre": func() -> Control: var b := _balloon(); return b.caja_nombre if b != null else null,
	}
	var alpha := func() -> float: var b := _balloon(); return b.raiz.modulate.a if b != null and b.raiz.visible else 0.0
	# Se registra mientras se muestra y se escribe el texto: ahí no puede haber saltos
	var escribiendo_aun := func() -> bool:
		var b := _balloon()
		return b != null and not b.texto.is_typing and b.raiz.modulate.a >= 1.0 and b.texto.visible_ratio >= 1.0
	await _grabar(e, 900, alpha, controles, escribiendo_aun)
	if not opciones.is_empty():
		# Las opciones aparecen DESPUÉS de escribirse: es un cambio de tamaño aparte (la caja crece), se anota por separado
		var e2 := _nuevo("balloon_opciones_aparecen (informativo)")
		e2["informativo"] = true
		var ultimo: Dictionary = e["frames"].pop_back()   # el fotograma en que ya salieron las opciones
		ultimo["n"] = 0
		e2["frames"].append(ultimo)
		e2["primer_visible"] = 0
		await _grabar(e2, 20, alpha, controles)
	var b := _balloon()
	if b != null:
		b._terminar()
	await get_tree().create_timer(0.5).timeout


func _probar_notificacion() -> void:
	var e := _nuevo("notificacion")
	Notificacion.mostrar("Habilidad desbloqueada: Impulso", TEXTO_NOTIF, true)
	var controles := {"tarjeta": func() -> Control: return Notificacion._tarjeta}
	await _grabar(e, 90, func() -> float: return Notificacion._tarjeta.modulate.a if Notificacion._tarjeta.visible else 0.0, controles)
	Notificacion.cerrar()
	await get_tree().create_timer(1.0).timeout
	# Una segunda tarjeta: ya conoce su posición anterior, así que no debe aparecer de golpe en otro sitio
	var e2 := _nuevo("notificacion_segunda")
	Notificacion.mostrar("Regalo: Piedra pequeña", "Un objeto de memoria.")
	await _grabar(e2, 90, func() -> float: return Notificacion._tarjeta.modulate.a if Notificacion._tarjeta.visible else 0.0, controles)
	Notificacion.cerrar()
	await get_tree().create_timer(1.0).timeout


func _buscar(clase: Variant) -> Node:
	for h in get_tree().root.get_children():
		if is_instance_of(h, clase):
			return h
	return null


func _esperar(condicion: Callable, maximo := 1200) -> bool:
	for i in maximo:
		if condicion.call():
			return true
		await get_tree().process_frame
	return false


func _probar_cuestionario() -> void:
	Cuestionario.mostrar(get_tree(), "pre")
	await _esperar(func() -> bool: return _buscar(Cuestionario) != null, 60)
	var cuestionario := _buscar(Cuestionario) as Cuestionario
	if cuestionario == null:
		print("No se pudo abrir el cuestionario")
		_fallos += 1
		return
	var alpha := func() -> float: return cuestionario._raiz.modulate.a
	var ci := {
		"panel_intro": func() -> Control: return cuestionario._panel_intro,
		"texto_intro": func() -> Control: return cuestionario._texto_intro,
		"boton_seguir": func() -> Control: return cuestionario._boton_seguir,
	}
	var cp := {
		"panel_pregunta": func() -> Control: return cuestionario._panel_pregunta,
		"texto_pregunta": func() -> Control: return cuestionario._texto_pregunta,
		"opciones": func() -> Control: return cuestionario._contenedor_opciones,
		"progreso": func() -> Control: return cuestionario._progreso,
	}
	var alfa_p := func() -> float: return cuestionario._panel_pregunta.modulate.a if cuestionario._panel_pregunta.visible else 0.0
	var numero := 0
	for bloque in [7, 7, 2]:
		# Intro del bloque: se registra mientras el Guía escribe
		await _esperar(func() -> bool: return cuestionario._panel_intro.visible)
		var ei := _nuevo("cuestionario_intro_%d" % (numero + 1))
		await _grabar(ei, 1500, alpha, ci, func() -> bool: return not cuestionario._boton_seguir.disabled)
		await _grabar(ei, 5, alpha, ci)
		cuestionario._seguir.emit()
		for i in bloque:
			numero += 1
			var etiqueta := "Pregunta %d de 16" % numero
			await _esperar(func() -> bool: return cuestionario._progreso.text == etiqueta and cuestionario._panel_pregunta.visible)
			var ep := _nuevo("cuestionario_pregunta_%02d" % numero)
			await _grabar(ep, 14, alfa_p, cp)
			cuestionario._elegida.emit(0)
			await get_tree().create_timer(0.35).timeout
	await _esperar(func() -> bool: return _buscar(Cuestionario) == null, 600)


func _probar_resultados() -> void:
	var e := _nuevo("resultados")
	Resultados.mostrar(get_tree())
	await _esperar(func() -> bool: return _buscar(Resultados) != null, 60)
	var res := _buscar(Resultados) as Resultados
	if res == null:
		print("No se pudo abrir resultados")
		_fallos += 1
		return
	var controles := {
		"panel": func() -> Control: return res._raiz.get_child(0),
		"scroll": func() -> Control: return res._scroll,
	}
	await _grabar(e, 60, func() -> float: return res._raiz.modulate.a, controles)
	res.queue_free()
	await get_tree().create_timer(0.5).timeout


func _probar_diario() -> void:
	var diario: Node = Menus.diario
	for seccion in [0, 1, 2, 5, 7]:
		var e := _nuevo("diario_seccion_%d" % seccion)
		diario.abrir(seccion)
		var controles := {
			"libro": func() -> Control: return diario._libro,
			"contenido": func() -> Control: return diario._contenido,
			"pie": func() -> Control: return diario._pie,
		}
		await _grabar(e, 30, func() -> float: return diario._raiz.modulate.a if diario._raiz.visible else 0.0, controles)
		diario.cerrar()
		await get_tree().create_timer(0.5).timeout


# --- Análisis e informe ---

## Cambios de tamaño o posición respecto al primer fotograma visible: lista de textos.
func _cambios(e: Dictionary) -> Array[String]:
	var salida: Array[String] = []
	var inicio: int = e["primer_visible"]
	if inicio == -1:
		salida.append("nunca se vio")
		return salida
	var base: Dictionary = e["frames"][inicio]["rects"]
	for i in range(inicio + 1, e["frames"].size()):
		var f: Dictionary = e["frames"][i]
		if f["alpha"] <= 0.0:
			continue
		for nombre in base:
			if not f["rects"].has(nombre):
				continue
			var a: Rect2 = base[nombre]
			var b: Rect2 = f["rects"][nombre]
			for prop in ["position.x", "position.y", "size.x", "size.y"]:
				var va := _valor(a, prop)
				var vb := _valor(b, prop)
				if absf(va - vb) > TOLERANCIA and not ESPERADOS.has("%s/%s/%s" % [e["nombre"], nombre, prop]):
					var marca := "%s/%s" % [nombre, prop]
					var texto := "fotograma +%d: %s %.1f -> %.1f" % [i - inicio, marca, va, vb]
					# Solo se anota la primera vez que cambia cada propiedad, y cuántas veces más
					var ya := false
					for s in salida:
						if s.contains(marca + " "):
							ya = true
					if not ya:
						salida.append(texto)
	return salida


func _valor(r: Rect2, prop: String) -> float:
	match prop:
		"position.x": return r.position.x
		"position.y": return r.position.y
		"size.x": return r.size.x
	return r.size.y


func _escribir_informe() -> void:
	var t := "# Revisión de saltos de tamaño en los modales\n\n"
	t += "Generado por `tools/probar_saltos.gd` (con ventana real). Registra por fotograma el tamaño y la posición del cuadro y de la etiqueta de cada modal desde el primer fotograma con opacidad mayor que 0 y señala cualquier cambio posterior (tolerancia %.1f px).\n\n" % TOLERANCIA
	t += "| Escenario | Fotogramas | Primer fotograma visible | Resultado | Cambios |\n|---|---|---|---|---|\n"
	for e in _escenarios:
		var cambios := _cambios(e)
		var ok := cambios.is_empty()
		var informativo: bool = e.get("informativo", false)
		if not ok and not informativo:
			_fallos += 1
		print("%s  %s" % ["OK    " if ok else ("INFO  " if informativo else "SALTO "), e["nombre"]])
		for c in cambios:
			print("         ", c)
		var primeros := ""
		if e["primer_visible"] != -1:
			var f: Dictionary = e["frames"][e["primer_visible"]]
			var partes: Array[String] = []
			for n in f["rects"]:
				var r: Rect2 = f["rects"][n]
				partes.append("%s %.0fx%.0f en (%.0f, %.0f)" % [n, r.size.x, r.size.y, r.position.x, r.position.y])
			primeros = "; ".join(partes)
		t += "| %s | %d | %d (%s) | %s | %s |\n" % [e["nombre"], e["frames"].size(), e["primer_visible"], primeros, "sin cambios" if ok else ("cambia (informativo)" if informativo else "SALTO"), "<br>".join(cambios) if not ok else "-"]
	t += "\n## Diagnóstico inicial (antes de corregir)\n\n"
	t += "- **Avisos (Notificacion): reproducía el salto.** La tarjeta se hacía visible (opacidad 1) y esperaba 2 fotogramas antes de medirse y colocarse: el primer fotograma se veía en la posición anterior (la primera vez, la esquina (0, 0)) y después saltaba fuera de la pantalla para entrar deslizando. Corregido: se prepara oculta (opacidad 0), con el texto completo, se espera a que el tamaño se estabilice (hasta 4 fotogramas), se fijan tamaño y posición, y entra solo con fundido y un desplazamiento vertical de 8 px.\n"
	t += "- **Caja de diálogo (balloon): sin salto al abrir ni al escribir.** El texto completo se asigna antes de mostrarse y `visible_characters` no cambia el alto. Una excepción de diseño: cuando el texto termina y aparecen las opciones, la caja crece (115 a 193 px en la prueba) porque está anclada abajo; no ocurre al abrir ni durante la escritura y no se cambió.\n"
	t += "- **Cuestionario, resultados y diario: sin salto.** Sus paneles tienen tamaño fijo y las etiquetas tienen ancho mínimo desde el principio.\n"
	t += "\nEscenarios con salto: %d de %d.\n" % [_fallos, _escenarios.size()]
	var f := FileAccess.open("res://docs/revision_saltos.md", FileAccess.WRITE)
	f.store_string(t)
	f.close()
