extends Node
## Atajos de depuración para probar los tres finales sin jugar todo el juego. SOLO en compilaciones de
## depuración (OS.is_debug_build()). No chocan con el movimiento (flechas y WASD) ni con las habilidades
## (ESPACIO, 1 a 7, R, F, G) ni con las teclas de las arenas de prueba (U, I, O) ni con M (panel de audio).
##
##   H  teletransporta al jugador a la Puerta del Reflejo
##   J  fuerza las 7 emociones integradas                         (final BUENO)
##   K  fuerza una mezcla: 4 integradas, 2 atacadas y 1 ignorada   (final NEUTRO)
##   L  fuerza la mayoría atacada o ignorada                       (final DIFÍCIL)
##
## Ojo: K deja las 7 emociones resueltas (no hay pendientes) a propósito: con alguna pendiente la Puerta del
## Reflejo no se abre y no se podría probar el final neutro.
## Cada tecla muestra un aviso de 2 segundos.

const SEGUNDOS_AVISO := 2.0

## Estados que fuerza cada tecla, en el orden de EmocionData.orden (rabia, miedo, tristeza, soledad, culpa, ansiedad, verguenza).
const MEZCLA := ["integrada", "atacada", "integrada", "ignorada", "integrada", "atacada", "integrada"]
const MAYORIA_MALA := ["atacada", "ignorada", "atacada", "ignorada", "integrada", "atacada", "ignorada"]

var _etiqueta: Label
var _tween: Tween


func _ready() -> void:
	if not OS.is_debug_build():
		set_process_unhandled_input(false)
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	var capa := CanvasLayer.new()
	capa.layer = 30
	add_child(capa)
	_etiqueta = Label.new()
	_etiqueta.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_etiqueta.anchor_left = 0.0
	_etiqueta.anchor_right = 1.0
	_etiqueta.offset_top = 6.0
	_etiqueta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_etiqueta.add_theme_font_size_override("font_size", 12)
	_etiqueta.add_theme_color_override("font_color", Color("fff4dc"))
	_etiqueta.add_theme_color_override("font_outline_color", Color("1e1b2e"))
	_etiqueta.add_theme_constant_override("outline_size", 4)
	_etiqueta.modulate.a = 0.0
	_etiqueta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	capa.add_child(_etiqueta)


func _unhandled_input(evento: InputEvent) -> void:
	if not OS.is_debug_build() or not (evento is InputEventKey) or not evento.pressed or evento.echo:
		return
	match evento.keycode:
		KEY_H:
			teletransportar_a_la_puerta()
		KEY_J:
			forzar(["integrada", "integrada", "integrada", "integrada", "integrada", "integrada", "integrada"], "J: las 7 emociones integradas (final bueno)")
		KEY_K:
			forzar(MEZCLA, "K: 4 integradas, 2 atacadas, 1 ignorada (final neutro)")
		KEY_L:
			forzar(MAYORIA_MALA, "L: mayoría atacada o ignorada (final difícil)")


## H: el jugador aparece delante de la Puerta del Reflejo (si hay un mundo con jugador).
func teletransportar_a_la_puerta() -> void:
	var jugador := get_tree().get_first_node_in_group("player") as Node2D
	var mundo := get_tree().get_first_node_in_group("mundo")
	if jugador == null or mundo == null:
		_avisar("H: aquí no hay mundo")
		return
	jugador.global_position = mundo.posicion_zona("Final") + Vector2(0, 56)
	_avisar("H: delante de la Puerta del Reflejo")


## Pone el estado de cada emoción (en el orden de EmocionData.orden).
func forzar(estados: Array, aviso: String) -> void:
	var ids := GameState.ids_emociones()
	for i in ids.size():
		GameState.resolver(ids[i], str(estados[mini(i, estados.size() - 1)]))
	_avisar(aviso)


func _avisar(texto: String) -> void:
	if _etiqueta == null:
		return
	_etiqueta.text = texto
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_etiqueta, "modulate:a", 1.0, 0.15)
	_tween.tween_interval(SEGUNDOS_AVISO - 0.45)
	_tween.tween_property(_etiqueta, "modulate:a", 0.0, 0.3)
