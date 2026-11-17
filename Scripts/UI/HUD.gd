extends CanvasLayer
## HUD de ECOS (capa 5): las 7 casillas de habilidades abajo a la izquierda y, arriba a la
## izquierda, la época actual y el contador de emociones integradas.
## Mismo estilo que la caja de diálogo: morado oscuro, borde dorado, Pixelify Sans.
## Se oculta con fundido mientras Habilidades.puede_operar() sea false (diálogos, onboarding,
## cuestionarios, pausa, transiciones) y vuelve después. Se construye por código.

const RUTA_FUENTE := "res://Assets/PixelifySans-VariableFont_wght.ttf"
const MARGEN := 8.0
const SEPARACION := 4.0
const COLOR_DORADO := Color("f4c77b")
const COLOR_TEXTO := Color("fff4dc")
const COLOR_PASADO := Color("f4b860")
const COLOR_PRESENTE := Color("7f9cc4")
const SEGUNDOS_FUNDIDO := 0.25
const SEGUNDOS_PISTA := 6.0

var _raiz: Control
var _casillas: Dictionary = {}  # id de habilidad -> CasillaHabilidad
var _icono_epoca: Control
var _etiqueta_epoca: Label
var _etiqueta_emociones: Label
var _pista: Label
var _fuente: Font
## Habilidades recién desbloqueadas que aún no se han celebrado (el HUD estaba oculto).
var _por_celebrar: Array[String] = []
var _visible_objetivo := false
var _tween_pista: Tween


func _ready() -> void:
	layer = 5
	process_mode = Node.PROCESS_MODE_ALWAYS  # para poder desvanecerse también en pausa
	if ResourceLoader.exists(RUTA_FUENTE):
		_fuente = load(RUTA_FUENTE)
	_raiz = Control.new()
	_raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	_raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.modulate.a = 0.0
	add_child(_raiz)
	_construir_casillas()
	_construir_indicadores()

	Habilidades.habilidad_seleccionada_cambiada.connect(func(_id: String) -> void: _refrescar_casillas())
	Habilidades.cooldown_cambiado.connect(_on_cooldown_cambiado)
	Habilidades.intento_bloqueado.connect(_on_intento_bloqueado)
	GameState.habilidad_desbloqueada.connect(_on_habilidad_desbloqueada)
	Habilidades.nivel_cambiado.connect(func(_id: String, _n: int) -> void: _refrescar_casillas())
	GameState.epoca_cambiada.connect(func(_e: String) -> void: _refrescar_indicadores())
	GameState.emocion_resuelta.connect(func(_i: String, _r: String) -> void: _refrescar_indicadores())
	GameState.partida_reiniciada.connect(_on_partida_cambiada)
	GameState.partida_cargada.connect(_on_partida_cambiada)
	_on_partida_cambiada()


func _process(delta: float) -> void:
	_visible_objetivo = Habilidades.puede_operar()
	var destino := 1.0 if _visible_objetivo else 0.0
	_raiz.modulate.a = move_toward(_raiz.modulate.a, destino, delta / SEGUNDOS_FUNDIDO)
	# El halo de las habilidades en marcha late, así que se redibuja mientras estén activas
	for id in _casillas:
		var casilla: CasillaHabilidad = _casillas[id]
		casilla.activa = Habilidades.esta_activa(id)
		if casilla.activa:
			casilla.queue_redraw()
	# Las celebraciones esperan a que el HUD se vea
	if _visible_objetivo and _raiz.modulate.a > 0.9 and not _por_celebrar.is_empty():
		_celebrar(_por_celebrar.pop_front())


# --- Construcción ---

func _construir_casillas() -> void:
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", int(SEPARACION))
	fila.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fila.anchor_top = 1.0
	fila.anchor_bottom = 1.0
	fila.offset_left = MARGEN
	fila.offset_top = -(MARGEN + CasillaHabilidad.TAMANO.y + 14.0)
	_raiz.add_child(fila)
	var numero := 1
	for entrada in Habilidades.catalogo:
		var columna := VBoxContainer.new()
		columna.add_theme_constant_override("separation", 0)
		columna.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var casilla := CasillaHabilidad.new()
		casilla.habilidad_id = entrada["id"]
		casilla.nombre = entrada["nombre"]
		casilla.color = entrada["color"]
		columna.add_child(casilla)
		var etiqueta := _crear_etiqueta(str(numero), 10, Color("8a7fa3"))
		etiqueta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		columna.add_child(etiqueta)
		fila.add_child(columna)
		_casillas[entrada["id"]] = casilla
		numero += 1

	# Pista que aparece una vez al desbloquear, encima de las casillas
	_pista = _crear_etiqueta("", 12, COLOR_DORADO)
	_pista.anchor_top = 1.0
	_pista.anchor_bottom = 1.0
	_pista.offset_left = MARGEN
	_pista.offset_top = fila.offset_top - 18.0
	_pista.modulate.a = 0.0
	_raiz.add_child(_pista)


func _construir_indicadores() -> void:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.position = Vector2(MARGEN, MARGEN)
	var caja := StyleBoxFlat.new()
	caja.bg_color = Color("1e1b2e", 0.95)
	caja.border_color = COLOR_DORADO
	caja.set_border_width_all(2)
	caja.set_corner_radius_all(4)
	caja.set_content_margin_all(5)
	panel.add_theme_stylebox_override("panel", caja)
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 6)
	fila.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(fila)
	_icono_epoca = Control.new()
	_icono_epoca.custom_minimum_size = Vector2(20, 20)
	_icono_epoca.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icono_epoca.draw.connect(_dibujar_icono_epoca)
	fila.add_child(_icono_epoca)
	var textos := VBoxContainer.new()
	textos.add_theme_constant_override("separation", -2)
	textos.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_etiqueta_epoca = _crear_etiqueta("Pasado", 14, COLOR_DORADO)
	_etiqueta_emociones = _crear_etiqueta("Emociones 0/7", 12, COLOR_TEXTO)
	textos.add_child(_etiqueta_epoca)
	textos.add_child(_etiqueta_emociones)
	fila.add_child(textos)
	_raiz.add_child(panel)


func _crear_etiqueta(texto: String, tamano: int, color: Color) -> Label:
	var etiqueta := Label.new()
	etiqueta.text = texto
	etiqueta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _fuente != null:
		etiqueta.add_theme_font_override("font", _fuente)
	etiqueta.add_theme_font_size_override("font_size", tamano)
	etiqueta.add_theme_color_override("font_color", color)
	return etiqueta


## Círculo cálido (Pasado) o frío (Presente) con un pequeño brillo.
func _dibujar_icono_epoca() -> void:
	var es_pasado := GameState.epoca == "pasado"
	var color := COLOR_PASADO if es_pasado else COLOR_PRESENTE
	var centro := _icono_epoca.size / 2.0
	_icono_epoca.draw_circle(centro, 9.0, color.darkened(0.4))
	_icono_epoca.draw_circle(centro, 7.0, color)
	_icono_epoca.draw_circle(centro + Vector2(-2, -2), 2.0, color.lightened(0.5))


# --- Actualización ---

func _refrescar_casillas() -> void:
	for id in _casillas:
		var casilla: CasillaHabilidad = _casillas[id]
		casilla.desbloqueada = Habilidades.esta_desbloqueada(id)
		casilla.nivel = Habilidades.nivel_de(id)
		casilla.seleccionada = id == Habilidades.habilidad_seleccionada
		var total := _total_cooldown(id)
		casilla.espera = Habilidades.cooldown_restante(id) / total if total > 0.0 else 0.0


func _total_cooldown(id: String) -> float:
	return Habilidades.cooldown_total(id)


func _refrescar_indicadores() -> void:
	var es_pasado := GameState.epoca == "pasado"
	_etiqueta_epoca.text = "Pasado" if es_pasado else "Presente"
	_etiqueta_epoca.add_theme_color_override("font_color", COLOR_PASADO if es_pasado else COLOR_PRESENTE)
	_etiqueta_emociones.text = "Emociones %d/%d" % [GameState.cantidad_integradas(), GameState.ids_emociones().size()]
	_icono_epoca.queue_redraw()


func _on_partida_cambiada() -> void:
	_por_celebrar.clear()
	_pista.modulate.a = 0.0
	_refrescar_casillas()
	_refrescar_indicadores()


func _on_cooldown_cambiado(id: String, restante: float, total: float) -> void:
	var casilla: CasillaHabilidad = _casillas.get(id, null)
	if casilla != null:
		casilla.espera = restante / total if total > 0.0 else 0.0


func _on_intento_bloqueado(id: String) -> void:
	var casilla: CasillaHabilidad = _casillas.get(id, null)
	if casilla != null:
		casilla.temblar()


## Al desbloquear: se actualiza ya la casilla y la celebración (brillo, sonido y pista) espera a que el HUD se vea.
func _on_habilidad_desbloqueada(id: String) -> void:
	_refrescar_casillas()
	_por_celebrar.append(id)


func _celebrar(id: String) -> void:
	var casilla: CasillaHabilidad = _casillas.get(id, null)
	if casilla == null:
		return
	casilla.brillar()
	_reproducir_sonido_desbloqueo()
	var numero := Habilidades.indice_de(id) + 1
	_pista.text = "Pulsa %d para elegirla y ESPACIO para usarla" % numero
	if _tween_pista != null:
		_tween_pista.kill()
	_tween_pista = create_tween()
	_tween_pista.tween_property(_pista, "modulate:a", 1.0, 0.3)
	_tween_pista.tween_interval(SEGUNDOS_PISTA)
	_tween_pista.tween_property(_pista, "modulate:a", 0.0, 0.6)


## Hueco para el sonido de desbloqueo (todavía no hay audio).
func _reproducir_sonido_desbloqueo() -> void:
	pass
