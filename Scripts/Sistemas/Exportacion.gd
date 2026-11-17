class_name Exportacion
extends RefCounted
## Exportación de los resultados de la evaluación. SOLO si el jugador aceptó guardar
## (Evaluacion.consentimiento_guardar); si no, no escribe ningún archivo.
##
## Al terminar la fase "post" (lo dispara Evaluacion) se agrega una fila a user://ecos_resultados.csv (UTF-8, con
## coma; con encabezado si el archivo no existe) y se escribe un JSON detallado en user://sesiones/<id>.json.
## Si el archivo ya existe pero con otras columnas (cambió el banco de preguntas) se usa ecos_resultados_v2.csv
## (v3, v4... si hiciera falta) en vez de mezclar formatos.
##
## Columnas: id_participante, fecha_iso, duracion_min, final, integradas, atacadas, ignoradas, pendientes,
## fragmentos, habilidades, pre_trivia, pre_situaciones, pre_escala, post_trivia, post_situaciones, post_escala y,
## por cada pregunta del banco: pre_<id>, post_<id> (índice ORIGINAL elegido; en escala, el valor 1-5) y, solo en
## trivia y situaciones, pre_ok_<id> y post_ok_<id> (1 si es correcta o sana, 0 si no).

const RUTA_CSV := "user://ecos_resultados.csv"
const CARPETA_SESIONES := "user://sesiones"
const NOMBRE_EXPORTADO := "ECOS_resultados.csv"

## El CSV donde se escribió por última vez (para exportarlo).
static var ultima_ruta := ""


## Las columnas, en orden (dependen del banco de preguntas).
static func columnas() -> Array[String]:
	var c: Array[String] = ["id_participante", "fecha_iso", "duracion_min", "final", "integradas", "atacadas", "ignoradas",
		"pendientes", "fragmentos", "habilidades", "pre_trivia", "pre_situaciones", "pre_escala", "post_trivia",
		"post_situaciones", "post_escala"]
	for bloque in Evaluacion.BLOQUES:
		for p in Evaluacion.banco.get(bloque, []):
			c.append("pre_" + str(p["id"]))
			c.append("post_" + str(p["id"]))
			if bloque != "escala":
				c.append("pre_ok_" + str(p["id"]))
				c.append("post_ok_" + str(p["id"]))
	# La valoración del jugador (vacías si no la envió)
	for u in Valoracion.USABILIDAD:
		c.append("val_" + u[0])
	c.append_array(["val_nota", "val_frecuencia", "val_sus", "val_gusto", "val_mejorar", "val_error"])
	return c


## La fila de esta partida como diccionario columna -> valor.
static func fila() -> Dictionary:
	var comparacion := Evaluacion.comparar()
	var contar := {"integrada": 0, "atacada": 0, "ignorada": 0, "pendiente": 0}
	for id in GameState.ids_emociones():
		contar[GameState.estado.get(id, "pendiente")] += 1
	var f := {
		"id_participante": Evaluacion.participante_id,
		"fecha_iso": Time.get_datetime_string_from_system(false),
		"duracion_min": snappedf(float(comparacion["duracion_segundos"]) / 60.0, 0.1),
		"final": GameState.calcular_final(),
		"integradas": contar["integrada"], "atacadas": contar["atacada"], "ignoradas": contar["ignorada"], "pendientes": contar["pendiente"],
		"fragmentos": GameState.cantidad_fragmentos(),
		"habilidades": GameState.habilidades.size(),
	}
	for fase in Evaluacion.FASES:
		var puntajes: Dictionary = Evaluacion._fase(fase).get("puntajes", {})
		f["%s_trivia" % fase] = int(puntajes.get("trivia", 0))
		f["%s_situaciones" % fase] = int(puntajes.get("situaciones", 0))
		f["%s_escala" % fase] = int(puntajes.get("escala", 0))
		var respuestas: Dictionary = Evaluacion._fase(fase)["respuestas"]
		for bloque in Evaluacion.BLOQUES:
			for p in Evaluacion.banco.get(bloque, []):
				var id := str(p["id"])
				f["%s_%s" % [fase, id]] = int(respuestas[id]) if respuestas.has(id) else ""
				if bloque != "escala":
					var punto := Evaluacion.puntaje_de(fase, id)
					f["%s_ok_%s" % [fase, id]] = punto if punto >= 0 else ""
	var v: Dictionary = Evaluacion.valoracion
	var respuestas_v: Dictionary = v.get("respuestas", {})
	for u in Valoracion.USABILIDAD:
		f["val_" + u[0]] = int(respuestas_v[u[0]]) if respuestas_v.has(u[0]) else ""
	f["val_nota"] = int(v["nota"]) if v.has("nota") else ""
	f["val_frecuencia"] = str(v.get("frecuencia", ""))
	f["val_sus"] = snappedf(float(v["sus_puntaje"]), 0.1) if float(v.get("sus_puntaje", -1.0)) >= 0.0 else ""
	f["val_gusto"] = str(v.get("gusto", ""))
	f["val_mejorar"] = str(v.get("mejorar", ""))
	f["val_error"] = str(v.get("error", ""))
	return f


## Una celda de CSV: con comillas si lleva coma, comillas o saltos de línea.
static func celda(valor: Variant) -> String:
	var texto := str(valor)
	if texto.contains(",") or texto.contains("\"") or texto.contains("\n"):
		return "\"%s\"" % texto.replace("\"", "\"\"")
	return texto


static func linea(valores: Array) -> String:
	var partes: Array[String] = []
	for v in valores:
		partes.append(celda(v))
	return ",".join(partes)


## Qué archivo CSV usar: el de siempre si no existe o tiene las mismas columnas; si no, _v2, _v3...
static func ruta_para(encabezado: String) -> String:
	var ruta := RUTA_CSV
	var version := 1
	while FileAccess.file_exists(ruta):
		var lectura := FileAccess.open(ruta, FileAccess.READ)
		var primera := lectura.get_line() if lectura != null else ""
		if lectura != null:
			lectura.close()
		if primera.strip_edges() == encabezado:
			break
		version += 1
		ruta = RUTA_CSV.replace(".csv", "_v%d.csv" % version)
	return ruta


## Agrega la fila de esta partida al CSV y escribe el JSON de la sesión. Devuelve la ruta del CSV, o "" si no se
## escribió nada (sin consentimiento, o banco no válido).
static func agregar_fila() -> String:
	if not Evaluacion.consentimiento_guardar or not Evaluacion.valido:
		return ""
	var cols := columnas()
	var encabezado := linea(cols)
	var ruta := ruta_para(encabezado)
	var existe := FileAccess.file_exists(ruta)
	var archivo := FileAccess.open(ruta, FileAccess.READ_WRITE if existe else FileAccess.WRITE)
	if archivo == null:
		push_warning("Exportacion: no se pudo abrir %s (error %d)." % [ruta, FileAccess.get_open_error()])
		return ""
	if existe:
		archivo.seek_end()
	else:
		archivo.store_line(encabezado)
	var f := fila()
	var valores: Array = []
	for c in cols:
		valores.append(f.get(c, ""))
	archivo.store_line(linea(valores))
	archivo.close()
	ultima_ruta = ruta
	_escribir_sesion(f)
	return ruta


## Cuando el jugador envía su valoración (después de terminar el "post"): reemplaza las columnas val_* de su fila
## en el CSV (el resto de la fila se queda igual) y reescribe el JSON de sesión. Si la fila no existe, la agrega.
## Los comentarios libres se escriben bien aunque tengan comas, comillas o saltos de línea.
static func actualizar_con_valoracion() -> String:
	if not Evaluacion.consentimiento_guardar or not Evaluacion.valido:
		return ""
	var cols := columnas()
	var encabezado := linea(cols)
	var ruta := ruta_para(encabezado)
	if not FileAccess.file_exists(ruta):
		return agregar_fila()
	var lectura := FileAccess.open(ruta, FileAccess.READ)
	if lectura == null:
		return ""
	lectura.get_csv_line()   # el encabezado
	var filas: Array = []
	while not lectura.eof_reached():
		var campos := lectura.get_csv_line()
		if campos.size() > 1 or (campos.size() == 1 and campos[0] != ""):
			filas.append(campos)
	lectura.close()
	var f := fila()
	var primera_val := cols.find("val_" + Valoracion.USABILIDAD[0][0])
	var encontrada := false
	for i in filas.size():
		if str(filas[i][0]) == Evaluacion.participante_id and filas[i].size() == cols.size():
			var nueva: Array = []
			for j in cols.size():
				nueva.append(filas[i][j] if j < primera_val else f.get(cols[j], ""))
			filas[i] = nueva
			encontrada = true
	if not encontrada:
		var valores: Array = []
		for c in cols:
			valores.append(f.get(c, ""))
		filas.append(valores)
	var escritura := FileAccess.open(ruta, FileAccess.WRITE)
	if escritura == null:
		return ""
	escritura.store_line(encabezado)
	for fila_guardada in filas:
		escritura.store_line(linea(fila_guardada))
	escritura.close()
	ultima_ruta = ruta
	_escribir_sesion(f)
	return ruta


## El JSON detallado de la sesión: user://sesiones/<id>.json
static func _escribir_sesion(f: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CARPETA_SESIONES))
	var detalle := {
		"id_participante": Evaluacion.participante_id,
		"fecha_iso": f["fecha_iso"],
		"final": f["final"],
		"duracion_min": f["duracion_min"],
		"estado_emociones": GameState.estado,
		"habilidades": GameState.habilidades,
		"fragmentos": GameState.fragmentos,
		"pre": Evaluacion.pre,
		"post": Evaluacion.post,
		"comparacion": Evaluacion.comparar(),
		"valoracion": Evaluacion.valoracion,
	}
	var archivo := FileAccess.open("%s/%s.json" % [CARPETA_SESIONES, Evaluacion.participante_id], FileAccess.WRITE)
	if archivo != null:
		archivo.store_string(JSON.stringify(detalle, "  "))
		archivo.close()


## Descarga un archivo de user:// en el navegador (solo en la web, con JavaScriptBridge). Devuelve true si lo pidió.
static func descargar(ruta_usuario: String, nombre: String, mime: String) -> bool:
	if not OS.has_feature("web") or not FileAccess.file_exists(ruta_usuario):
		return false
	var bytes := FileAccess.get_file_as_bytes(ruta_usuario)
	JavaScriptBridge.download_buffer(bytes, nombre, mime)
	return true


## En la web no hay carpeta Documentos: el botón DESCARGA el CSV (ECOS_resultados.csv) y el JSON de la sesión.
static func _exportar_descargando() -> Dictionary:
	var resultado := {"ok": false, "ruta": "", "ruta_usuario": ""}
	var origen := ultima_ruta if ultima_ruta != "" else RUTA_CSV
	if not Evaluacion.consentimiento_guardar or not FileAccess.file_exists(origen):
		return resultado
	if descargar(origen, NOMBRE_EXPORTADO, "text/csv;charset=utf-8"):
		resultado["ok"] = true
		resultado["ruta"] = "descargas de tu navegador (%s)" % NOMBRE_EXPORTADO
		var sesion := "%s/%s.json" % [CARPETA_SESIONES, Evaluacion.participante_id]
		descargar(sesion, "ECOS_sesion_%s.json" % Evaluacion.participante_id, "application/json;charset=utf-8")
	return resultado


## Copia el CSV a la carpeta Documentos del usuario como ECOS_resultados.csv. Devuelve
## {ok, ruta (donde quedó), ruta_usuario (la carpeta de user:// en el disco)}.
static func exportar_a_documentos() -> Dictionary:
	if OS.has_feature("web"):
		return _exportar_descargando()
	var origen := ultima_ruta if ultima_ruta != "" else RUTA_CSV
	var carpeta_usuario := ProjectSettings.globalize_path("user://")
	var resultado := {"ok": false, "ruta": "", "ruta_usuario": carpeta_usuario}
	if not Evaluacion.consentimiento_guardar or not FileAccess.file_exists(origen):
		return resultado
	var documentos := OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
	if documentos == "" or not DirAccess.dir_exists_absolute(documentos):
		return resultado
	var destino := documentos.path_join(NOMBRE_EXPORTADO)
	if DirAccess.copy_absolute(ProjectSettings.globalize_path(origen), destino) == OK:
		resultado["ok"] = true
		resultado["ruta"] = destino
	return resultado
