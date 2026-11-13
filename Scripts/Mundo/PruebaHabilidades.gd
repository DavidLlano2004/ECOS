extends Node2D
## Arena pequeña para probar las habilidades Impulso, Calma y Reparar. Se juega con F6 (no es la
## escena principal). Tiene un muro interior, una roca rompible, una planta seca, un objeto roto
## y dos emociones (Rabia y Miedo) para ver cómo les afecta Calma.
##
## Teclas de depuración (solo en compilaciones de depuración):
##   U = desbloquear las 7 habilidades (sin tocar el estado de las emociones)
##   I = poner a Rabia como "atacada" y a Miedo como "ignorada" (para probar Calma con ellas)
##   O = reiniciar los objetos (recarga la escena; conserva las habilidades)
## (Se evitan las teclas F5 a F10: son atajos del editor de Godot, que pausa o detiene el juego antes de que las reciba.)

const ARENA := Rect2(0, 0, 800, 480)
const RUTA_FUENTE := "res://Assets/PixelifySans-VariableFont_wght.ttf"

@onready var jugador: Player = $Mundo/Player

var _panel: Label


func _ready() -> void:
	jugador.establecer_limites(ARENA)
	_poner_marcador($Mundo/Roca, "Roca: Impulso")
	_poner_marcador($Mundo/PlantaSeca, "Planta seca: Calma")
	_poner_marcador($Mundo/ObjetoRoto, "Roto: mantén ESPACIO (Reparar)")
	_poner_marcador($MuroInterior, "Muro (el Impulso no lo atraviesa)", Vector2(0, 86))
	_crear_panel()
	_actualizar_panel()


func _process(_delta: float) -> void:
	_actualizar_panel()


func _unhandled_input(evento: InputEvent) -> void:
	if not OS.is_debug_build():
		return
	if evento is InputEventKey and evento.pressed and not evento.echo:
		match evento.keycode:
			KEY_U:
				_desbloquear_todas()
			KEY_I:
				GameState.estado["rabia"] = "atacada"
				GameState.estado["miedo"] = "ignorada"
			KEY_O:
				get_tree().reload_current_scene()


## Añade todas las habilidades sin pasar por las emociones. partida_cargada hace que el HUD se
## refresque y que Habilidades elija la primera si no había ninguna.
func _desbloquear_todas() -> void:
	for entrada in Habilidades.catalogo:
		if not GameState.habilidades.has(entrada["id"]):
			GameState.habilidades.append(entrada["id"])
	GameState.partida_cargada.emit()


# --- Marcadores y panel ---

func _poner_marcador(nodo: Node2D, texto: String, desplazamiento: Vector2 = Vector2(0, 6)) -> void:
	var etiqueta := Label.new()
	etiqueta.text = texto
	etiqueta.z_index = 5
	etiqueta.custom_minimum_size = Vector2(180, 0)
	etiqueta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	etiqueta.position = desplazamiento + Vector2(-90, 0)
	_estilo_etiqueta(etiqueta, 9)
	nodo.add_child(etiqueta)


func _crear_panel() -> void:
	var capa := CanvasLayer.new()
	capa.layer = 5
	capa.visible = OS.is_debug_build()
	add_child(capa)
	_panel = Label.new()
	_panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_panel.offset_right = -6.0
	_panel.offset_bottom = -6.0
	_panel.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_estilo_etiqueta(_panel, 10)
	capa.add_child(_panel)


func _estilo_etiqueta(etiqueta: Label, tamano: int) -> void:
	if ResourceLoader.exists(RUTA_FUENTE):
		etiqueta.add_theme_font_override("font", load(RUTA_FUENTE))
	etiqueta.add_theme_font_size_override("font_size", tamano)
	etiqueta.add_theme_color_override("font_color", Color("fff4dc"))
	etiqueta.add_theme_color_override("font_outline_color", Color("1e1b2e"))
	etiqueta.add_theme_constant_override("outline_size", 4)


func _actualizar_panel() -> void:
	var lineas: Array[String] = [
		"PRUEBA DE HABILIDADES",
		"[U] desbloquear todas  [I] agitar emociones  [O] reiniciar",
		"1-7 elegir · R/F cambiar · ESPACIO usar",
	]
	for nombre in ["Rabia", "Miedo"]:
		var emocion: Emocion = get_node_or_null("Mundo/%s" % nombre)
		if emocion != null:
			var estado: String = GameState.estado.get(emocion.datos.id, "pendiente")
			lineas.append("%s: %s (calma %.1f s)" % [nombre, estado, emocion.segundos_de_calma()])
	_panel.text = "\n".join(lineas)
