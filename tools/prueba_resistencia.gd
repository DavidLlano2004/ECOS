extends Node
## Prueba de resistencia (con ventana): el jugador camina al azar por el mundo, usa habilidades y viaja de época durante
## N minutos, y cada 30 s se anota el FPS, la memoria y la cantidad de objetos, para ver si algo crece sin parar.
##   godot --path . res://tools/prueba_resistencia.tscn -- MINUTOS
## Imprime líneas "MUESTRA ..." y al final "RESUMEN ...".

var minutos := 15.0
var muestras: Array = []
var _t := 0.0
var _siguiente_muestra := 30.0
var _cambio_direccion := 0.0
var _fps_acumulados: Array = []
var _acciones := ["IZQUIERDA", "DERECHA", "ARRIBA", "ABAJO"]
var _mundo: Node
var _jugador: Player
var _siguiente_viaje := 90.0
var _siguiente_habilidad := 7.0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		minutos = float(args[0])
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)   # para medir lo que aguanta, sin tope de 60
	Engine.max_fps = 0
	GameState.nueva_partida()
	for id in ["rabia", "miedo", "tristeza", "soledad", "culpa", "ansiedad", "verguenza"]:
		GameState.resolver(id, "integrada")
	_mundo = load("res://Scenes/Mundo/Mundo.tscn").instantiate()
	add_child(_mundo)
	await get_tree().create_timer(1.0).timeout
	_jugador = get_tree().get_first_node_in_group("player") as Player
	for id in ["puente_rabia", "roca_verguenza", "zarzal_ansiedad"]:
		GameState.abrir_compuerta(id)
	print("INICIO: render=%s, adaptador=%s, %.0f minutos" % [RenderingServer.get_current_rendering_method(), RenderingServer.get_video_adapter_name(), minutos])
	_muestrear()


func _process(delta: float) -> void:
	if _jugador == null:
		return
	_t += delta
	_fps_acumulados.append(Engine.get_frames_per_second())
	# Caminar al azar (cambia de dirección cada 0.4 a 1.5 s)
	_cambio_direccion -= delta
	if _cambio_direccion <= 0.0:
		_cambio_direccion = randf_range(0.4, 1.5)
		for a in _acciones:
			Input.action_release(a)
		var elegidas := 1 + randi() % 2
		for i in elegidas:
			Input.action_press(_acciones[randi() % 4])
	# De vez en cuando, una habilidad
	_siguiente_habilidad -= delta
	if _siguiente_habilidad <= 0.0:
		_siguiente_habilidad = randf_range(4.0, 10.0)
		var entrada: Dictionary = Habilidades.catalogo[randi() % Habilidades.catalogo.size()]
		Habilidades.seleccionar(entrada["id"])
		Habilidades.usar(_jugador)
	# Viajar de época cada 90 s
	_siguiente_viaje -= delta
	if _siguiente_viaje <= 0.0:
		_siguiente_viaje = 90.0
		_mundo.viajar()
	if _t >= _siguiente_muestra:
		_siguiente_muestra += 30.0
		_muestrear()
	if _t >= minutos * 60.0:
		_terminar()


func _muestrear() -> void:
	var fps_medio := 0.0
	var fps_min := 9999.0
	for f in _fps_acumulados:
		fps_medio += f
		fps_min = minf(fps_min, f)
	fps_medio = fps_medio / maxf(_fps_acumulados.size(), 1)
	_fps_acumulados.clear()
	var m := {
		"t": int(_t), "fps_medio": snappedf(fps_medio, 0.1), "fps_min": snappedf(fps_min if fps_min < 9999.0 else 0.0, 0.1),
		"memoria_mb": snappedf(OS.get_static_memory_usage() / 1048576.0, 0.1),
		"nodos": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)), "objetos": int(Performance.get_monitor(Performance.OBJECT_COUNT)),
		"huerfanos": int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),
		"recursos": int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)),
	}
	muestras.append(m)
	print("MUESTRA ", m)


func _terminar() -> void:
	for a in _acciones:
		Input.action_release(a)
	var primera: Dictionary = muestras[1] if muestras.size() > 1 else muestras[0]
	var ultima: Dictionary = muestras[muestras.size() - 1]
	var fps_total := 0.0
	var fps_peor := 99999.0
	for m in muestras:
		fps_total += m["fps_medio"]
		fps_peor = minf(fps_peor, m["fps_min"])
	print("RESUMEN: %.0f minutos | FPS medio %.0f (el peor tramo %.0f) | memoria %.1f MB -> %.1f MB | nodos %d -> %d | objetos %d -> %d | huérfanos %d -> %d" % [
		minutos, fps_total / muestras.size(), fps_peor, primera["memoria_mb"], ultima["memoria_mb"], primera["nodos"], ultima["nodos"], primera["objetos"], ultima["objetos"], primera["huerfanos"], ultima["huerfanos"]])
	get_tree().quit()
