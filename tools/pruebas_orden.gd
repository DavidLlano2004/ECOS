extends Node
## Prueba DE DEPURACIÓN, con ventana real (no sirve en headless):
##   godot --path . res://tools/pruebas_orden.tscn
## 1) ORDEN DE DIBUJO: para cada objeto del Presente (cofre, altar, planta, portón, placas, puentes, estanque...)
##    pone al jugador en 8 posiciones a su alrededor, guarda una captura en tools/capturas_orden/ y comprueba
##    por código el orden efectivo: lo PLANO (suelo) debe dibujarse siempre bajo el jugador y lo ALTO debe
##    ordenarse por su base (Y).
## 2) COLISIÓN: ninguna celda de 8 px dentro de la base del cofre y del altar es alcanzable, y el cofre se puede
##    abrir (queda a alcance de interacción) desde sus cuatro lados.
## Escribe docs/revision_orden.md con los resultados.

const CARPETA := "res://tools/capturas_orden"
const RADIO := 22.0
const NOMBRES_POSICION := ["arriba", "arriba_der", "derecha", "abajo_der", "abajo", "abajo_izq", "izquierda", "arriba_izq"]
const DIRECCIONES := [Vector2(0, -1), Vector2(1, -1), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1), Vector2(-1, 1), Vector2(-1, 0), Vector2(-1, -1)]
const PREFIJOS_PLANOS := ["PlantaMarchita", "PlacaDoble", "CaminoOculto", "PlataformaMovil"]

var _mundo: Node2D
var _jugador: CharacterBody2D
var _filas: Array[String] = []
var _filas_colision: Array[String] = []
var _fallos := 0
var _total := 0


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("pruebas_orden necesita ventana real: ejecútala sin --headless.")
		get_tree().quit(2)
		return
	if not OS.is_debug_build():
		get_tree().quit(2)
		return
	GameState.nueva_partida()
	_mundo = (load("res://Scenes/Mundo/Mundo.tscn") as PackedScene).instantiate()
	add_child(_mundo)
	await get_tree().create_timer(1.0).timeout
	_jugador = get_tree().get_first_node_in_group("player") as CharacterBody2D
	_mundo.viajar()
	await get_tree().create_timer(2.0).timeout
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CARPETA))
	var camara := _jugador.get_node_or_null("Camera2D") as Camera2D
	if camara != null:
		camara.position_smoothing_enabled = false   # la cámara debe quedar centrada en el jugador al instante
	var mascara := _jugador.collision_mask
	_jugador.collision_mask = 0   # para el orden de dibujo el jugador solo se coloca
	_jugador.set_physics_process(false)

	var objetos := _objetos_a_probar()
	print("Objetos a probar: ", objetos.size())
	for o in objetos:
		await _probar_orden(o)
	_jugador.collision_mask = mascara
	await _probar_colision()
	_escribir_informe()
	print("RESULTADO: %d de %d comprobaciones pasaron" % [_total - _fallos, _total])
	get_tree().quit(1 if _fallos > 0 else 0)


func _es_plano_por_nombre(nombre: String) -> bool:
	for p in PREFIJOS_PLANOS:
		if nombre.begins_with(p):
			return true
	return false


## Lista de {nombre, nodo, clase}: clase "ALTO" o "PLANO".
func _objetos_a_probar() -> Array:
	var presente := _mundo.get_node("Presente")
	var objetos := presente.get_node("Objetos")
	var lista: Array = []
	var vistos: Dictionary = {}   # un ejemplar por tipo de objeto basta
	for n in objetos.get_children():
		var nom := String(n.name)
		if n is Santuario:
			if not vistos.has("Santuario"):
				vistos["Santuario"] = true
				lista.append({"nombre": nom + " (altar)", "nodo": n, "clase": "ALTO"})
				var cofre := n.get_node_or_null("Cofre")
				if cofre != null:
					lista.append({"nombre": nom + "/Cofre", "nodo": cofre, "clase": "ALTO"})
		elif n is BloqueoPresente:
			if n.datos != null and n.datos.id == "tristeza":
				lista.append({"nombre": nom + " (estanque)", "nodo": n._sprite, "clase": "PLANO", "origen": n.global_position})
			elif n.datos != null and n.datos.id == "rabia":
				lista.append({"nombre": nom, "nodo": n, "clase": "ALTO"})
		elif nom.begins_with("PortonRoto") or nom.begins_with("RocaRompible") or nom.begins_with("NieblaSombra") or nom.begins_with("PuertaPlacas"):
			var tipo := nom.split("_")[0]
			if not vistos.has(tipo):
				vistos[tipo] = true
				lista.append({"nombre": nom, "nodo": n, "clase": "ALTO"})
		elif _es_plano_por_nombre(nom):
			lista.append({"nombre": nom + " (en Objetos)", "nodo": n, "clase": "PLANO"})   # no debería ocurrir
	# Lo plano vive entre el suelo y Objetos
	for n in presente.get_children():
		var nom := String(n.name)
		if n is Node2D and _es_plano_por_nombre(nom):
			var tipo := nom.split("_")[0]
			if not vistos.has(tipo):
				vistos[tipo] = true
				lista.append({"nombre": nom, "nodo": n, "clase": "PLANO"})
		elif nom.begins_with("Ravina_") and not vistos.has("Ravina"):
			vistos["Ravina"] = true
			lista.append({"nombre": nom + " (puente)", "nodo": n, "clase": "PLANO", "origen": _centro_ravina(n)})
	return lista


func _centro_ravina(n: Node2D) -> Vector2:
	var celdas: Variant = n.get("celdas")
	if celdas is Array and not (celdas as Array).is_empty():
		var suma := Vector2.ZERO
		for c in celdas:
			suma += Vector2(float(c[0]) + 0.5, float(c[1]) + 0.5) * 32.0
		return suma / float((celdas as Array).size())
	return n.global_position


## Posición donde se dibuja la base de un nodo.
func _base(o: Dictionary) -> Vector2:
	return o["origen"] if o.has("origen") else (o["nodo"] as Node2D).global_position


## ¿El nodo se dibuja por debajo de `Objetos` (suelo)? Sube hasta el hijo directo de la época.
func _es_suelo(nodo: Node) -> bool:
	var objetos := _mundo.get_node("Presente/Objetos")
	var n := nodo
	while n.get_parent() != null and n.get_parent().name != "Presente":
		n = n.get_parent()
	return n != objetos and n.get_index() < objetos.get_index()


## ¿El nodo se ordena en Y junto con el jugador? Todos sus padres hasta Objetos deben tener y_sort_enabled.
func _ordena_con_jugador(nodo: Node) -> bool:
	var objetos := _mundo.get_node("Presente/Objetos") as Node2D
	if not objetos.y_sort_enabled:
		return false
	var n := nodo.get_parent()
	while n != null and n != objetos:
		if not (n is Node2D and (n as Node2D).y_sort_enabled):
			return false
		n = n.get_parent()
	return n == objetos


func _nombre_archivo(nombre: String) -> String:
	return nombre.replace("/", "_").replace(" ", "_").replace("(", "").replace(")", "")


func _probar_orden(o: Dictionary) -> void:
	var nodo: Node = o["nodo"]
	var clase: String = o["clase"]
	var base := _base(o)
	var buenas := 0
	for i in 8:
		_jugador.global_position = base + DIRECCIONES[i].normalized() * RADIO
		await _esperar_fotogramas(4)
		_capturar("%s/%s_%s.png" % [CARPETA, _nombre_archivo(o["nombre"]), NOMBRES_POSICION[i]], base)
		var bien := false
		if clase == "PLANO":
			bien = _es_suelo(nodo)   # bajo Objetos: bajo el jugador siempre
		else:
			# El jugador queda detrás cuando su Y de ordenamiento es menor que la de la base del objeto
			var tapa := _jugador.global_position.y < base.y
			bien = _ordena_con_jugador(nodo) and tapa == (DIRECCIONES[i].y < 0.0)
		_total += 1
		if bien:
			buenas += 1
		else:
			_fallos += 1
	print("%s  %s (%s)  %d/8" % ["OK    " if buenas == 8 else "FALLO ", o["nombre"], clase, buenas])
	var padre := nodo.get_parent()
	var ysort := " (y-sort)" if (padre is Node2D and (padre as Node2D).y_sort_enabled) else ""
	_filas.append("| %s | %s | %s%s | %d/8 | `tools/capturas_orden/%s_*.png` |" % [o["nombre"], clase, padre.name if padre != null else "-", ysort, buenas, _nombre_archivo(o["nombre"])])


func _esperar_fotogramas(n: int) -> void:
	for i in n:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw


func _capturar(ruta: String, centro_mundo: Vector2) -> void:
	var img := get_viewport().get_texture().get_image()
	var escala := float(img.get_width()) / get_viewport().get_visible_rect().size.x
	var pantalla := (get_viewport().get_canvas_transform() * centro_mundo) * escala
	var lado := 160.0 * escala
	var recorte := Rect2i(Vector2i((pantalla - Vector2(lado, lado) / 2.0).round()), Vector2i(int(lado), int(lado)))
	recorte = recorte.intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	if recorte.size.x > 0 and recorte.size.y > 0:
		img.get_region(recorte).save_png(ruta)


# --- Colisión de la base del cofre y del altar ---

func _probar_colision() -> void:
	for santuario in get_tree().get_nodes_in_group("santuario"):
		var cofre := santuario.get_node_or_null("Cofre") as CofreMemoria
		if cofre == null or not santuario.is_visible_in_tree():
			continue
		await _colision_de("Cofre " + cofre.emocion_id, cofre, Rect2(-21, -15, 42, 15), true)
		await _colision_de("Altar " + cofre.emocion_id, santuario, Rect2(-15, -10, 30, 10), false)
		break   # basta con un santuario: son idénticos


func _colision_de(nombre: String, nodo: Node2D, base: Rect2, abre: bool) -> void:
	_jugador.set_physics_process(false)
	var centro := nodo.global_position
	var alcanzables := 0
	var celdas := 0
	var y := base.position.y + 4.0
	while y < base.end.y:
		var x := base.position.x + 4.0
		while x < base.end.x:
			celdas += 1
			var objetivo := centro + Vector2(x, y)
			var llego := false
			for dir in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
				_jugador.global_position = objetivo + dir * 60.0
				for paso in 60:
					var restante := objetivo - _jugador.global_position
					if restante.length() < 1.5:
						break
					if _jugador.move_and_collide(restante.limit_length(3.0)) != null:
						break
				if _jugador.global_position.distance_to(objetivo) < 4.0:
					llego = true
			if llego:
				alcanzables += 1
			x += 8.0
		y += 8.0
	_total += 1
	var bien := alcanzables == 0
	if not bien:
		_fallos += 1
	print("%s  %s: %d de %d celdas de 8 px de la base alcanzables" % ["OK    " if bien else "FALLO ", nombre, alcanzables, celdas])
	_filas_colision.append("| %s | %d | %d | %s |" % [nombre, celdas, alcanzables, "sí" if bien else "NO"])
	if abre:
		# Desde cada lado, el jugador se acerca hasta chocar y debe quedar a alcance de interacción
		var cofre := nodo as CofreMemoria
		_jugador.set_physics_process(true)
		for lado in [["arriba", Vector2.UP], ["abajo", Vector2.DOWN], ["izquierda", Vector2.LEFT], ["derecha", Vector2.RIGHT]]:
			_jugador.global_position = centro + lado[1] * 70.0
			_jugador.velocity = Vector2.ZERO
			for paso in 60:
				var resto := centro + Vector2(0, -7) - _jugador.global_position
				_jugador.move_and_collide(resto.limit_length(2.0))
			await get_tree().physics_frame
			await get_tree().physics_frame
			var a_alcance: bool = _jugador.interactuables.has(cofre)
			_total += 1
			if not a_alcance:
				_fallos += 1
			print("%s  el cofre se alcanza desde %s" % ["OK    " if a_alcance else "FALLO ", lado[0]])
			_filas_colision.append("| Interacción con el cofre desde %s | - | - | %s |" % [lado[0], "sí" if a_alcance else "NO"])
		_jugador.set_physics_process(false)


func _escribir_informe() -> void:
	var t := "# Revisión del orden de dibujo y de la colisión del cofre\n\n"
	t += "Generado por `tools/pruebas_orden.gd` (con ventana). Las capturas están en `tools/capturas_orden/` (160x160 px del mundo; el jugador a %d px de la base del objeto, en 8 posiciones).\n\n" % int(RADIO)
	t += "**Regla:** PLANO = suelo, siempre bajo el jugador (hijo de la época entre el suelo y `Objetos`). ALTO = dentro de `Objetos` (con y-sort), ordenado por su base.\n\n"
	t += "## Orden de dibujo\n\n| Objeto | Clase | Padre | Posiciones correctas | Capturas |\n|---|---|---|---|---|\n"
	t += "\n".join(_filas) + "\n\n"
	t += "## Colisión de la base (celdas de 8 px dentro de la base que se pueden alcanzar)\n\n| Prueba | Celdas | Alcanzables | Correcto |\n|---|---|---|---|\n"
	t += "\n".join(_filas_colision) + "\n\n"
	t += "Resultado: %d de %d comprobaciones.\n" % [_total - _fallos, _total]
	var f := FileAccess.open("res://docs/revision_orden.md", FileAccess.WRITE)
	f.store_string(t)
	f.close()
