extends Node
## Revisión desde Godot (sin ventana), la usa tools/revisar_proyecto.py:
##   - Abre cada escena de Scenes/ y lista las advertencias de nodo (los "triángulos amarillos" del editor).
##   - Carga cada .dialogue y comprueba que se compiló y que tiene al menos un título.
## Imprime líneas "AVISO_ESCENA|...", "ERROR_ESCENA|..." y "ERROR_DIALOGO|...".

func _ready() -> void:
	await get_tree().process_frame
	var escenas := _archivos("res://Scenes", ".tscn")
	for ruta in escenas:
		var recurso := load(ruta)
		if not (recurso is PackedScene):
			print("ERROR_ESCENA|%s|no se pudo cargar como escena" % ruta)
			continue
		var nodo: Node = (recurso as PackedScene).instantiate()
		if nodo == null:
			print("ERROR_ESCENA|%s|no se pudo instanciar" % ruta)
			continue
		_avisos(ruta, nodo, nodo)
		nodo.free()
	var dialogos := _archivos("res://Dialogos", ".dialogue")
	for ruta in dialogos:
		var r := load(ruta)
		if not (r is DialogueResource):
			print("ERROR_DIALOGO|%s|no se compiló (¿error de sintaxis?)" % ruta)
		elif (r as DialogueResource).get_cues().is_empty():
			print("ERROR_DIALOGO|%s|no tiene ningún título (~ nombre)" % ruta)
	print("REVISADO|%d escenas|%d diálogos" % [escenas.size(), dialogos.size()])
	get_tree().quit()


var _avisos_no_disponibles := false


func _avisos(ruta: String, raiz: Node, nodo: Node) -> void:
	# En algunas versiones de Godot los nodos con script no exponen get_configuration_warnings() fuera del editor
	if not nodo.has_method("get_configuration_warnings"):
		if not _avisos_no_disponibles:
			_avisos_no_disponibles = true
			print("AVISOS_NO_DISPONIBLES|esta versión de Godot no permite leer las advertencias de nodo desde un script en ejecución")
		for hijo in nodo.get_children():
			_avisos(ruta, raiz, hijo)
		return
	for w in nodo.get_configuration_warnings():
		print("AVISO_ESCENA|%s|%s|%s" % [ruta, raiz.get_path_to(nodo), str(w).replace("\n", " ")])
	for hijo in nodo.get_children():
		_avisos(ruta, raiz, hijo)


func _archivos(carpeta: String, extension: String) -> Array[String]:
	var res: Array[String] = []
	var d := DirAccess.open(carpeta)
	if d == null:
		return res
	for f in d.get_files():
		var nombre := f.trim_suffix(".remap")
		if nombre.ends_with(extension):
			res.append(carpeta.path_join(nombre))
	for sub in d.get_directories():
		res.append_array(_archivos(carpeta.path_join(sub), extension))
	res.sort()
	return res
