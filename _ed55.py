def edit(p, pares):
    s = open(p, encoding='utf-8').read()
    for a, b in pares:
        assert a in s, (p, a)
        s = s.replace(a, b, 1)
    open(p, 'w', encoding='utf-8', newline='\n').write(s)

edit('project.godot', [
 ('window/stretch/aspect="expand"\nwindow/stretch/scale_mode="integer"\n', 'window/stretch/aspect="keep"\nwindow/stretch/scale_mode="integer"\nwindow/stretch/scale_mode.web="fractional"\n'),
 ('run/main_scene="res://Scenes/UI/PantallaTitulo.tscn"', 'run/main_scene="res://Scenes/UI/ClicParaEmpezar.tscn"'),
 ('[rendering]\n', '[audio]\n\ngeneral/default_playback_type.web=0\n\n[rendering]\n'),
 ('textures/canvas_textures/default_texture_filter=0\n', 'textures/canvas_textures/default_texture_filter=0\nenvironment/defaults/default_clear_color=Color(0.105882, 0.0823529, 0.188235, 1)\n'),
])

edit('Scenes/Intro/Onboarding.tscn', [
 ('[ext_resource type="Texture2D" path="res://Assets/UI/fondo_titulo.png" id="2_fondo"]\n[ext_resource type="Shader" path="res://Shaders/desenfoque_oscuro.gdshader" id="3_shader"]\n', '[ext_resource type="Texture2D" path="res://Assets/UI/fondo_onboarding.png" id="2_fondo"]\n'),
 ('[sub_resource type="ShaderMaterial" id="ShaderMaterial_fondo"]\nshader = ExtResource("3_shader")\nshader_parameter/radio = 2.5\nshader_parameter/oscuridad = 0.3\nshader_parameter/tinte = Color(0.38, 0.45, 0.7, 1)\n\n', ''),
 ('z_index = -10\nmaterial = SubResource("ShaderMaterial_fondo")\ntexture = ExtResource("2_fondo")', 'z_index = -10\ntexture_filter = 1\ntexture = ExtResource("2_fondo")'),
])

edit('Scripts/UI/FondoEvaluacion.gd', [
 ('const FONDO := "res://Assets/UI/fondo_titulo.png"', 'const FONDO := "res://Assets/UI/fondo_onboarding.png"'),
 ('	fondo.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST\n	fondo.mouse_filter', '	fondo.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR\n	fondo.mouse_filter'),
 ('color = Color(0.06, 0.04, 0.12, 0.72)', 'color = Color(0.06, 0.04, 0.12, 0.45)'),
])

edit('Autoload/Sonido.gd', [
 ('''	var j := AudioStreamPlayer.new()
	j.bus = bus''', '''	var j := AudioStreamPlayer.new()
	j.bus = bus
	# Reproducción de Godot (no Web Audio): en la web el modo "Sample" no soporta bien buses, fundidos ni cambios de tono
	j.playback_type = AudioServer.PLAYBACK_TYPE_STREAM'''),
 ('''	faltan.clear()
	for nombre in EFECTOS + AMBIENTES + MUSICAS:
		if _cargar(nombre) == null:
			faltan.append(nombre)
	if not faltan.is_empty():
		push_warning("Sonido: faltan %d archivos de audio: %s" % [faltan.size(), ", ".join(faltan)])''', '''	faltan.clear()
	var todos: Array = EFECTOS + AMBIENTES + MUSICAS
	for nombre in todos:
		if _cargar(nombre) == null:
			faltan.append(nombre)
	if not faltan.is_empty():
		push_warning("Sonido: faltan %d archivos de audio: %s" % [faltan.size(), ", ".join(faltan)])
	# Registro visible (en la web sale en la consola del navegador): cuántos sonidos se cargaron y cómo está el audio
	print("Audio: %d de %d sonidos cargados%s" % [todos.size() - faltan.size(), todos.size(), "" if faltan.is_empty() else ". No se pudieron cargar: " + ", ".join(faltan)])
	print("Audio: Master %s a %.1f dB, Musica %.0f %%, Efectos %.0f %%, reproducción %s" % [
		"SILENCIADO" if AudioServer.is_bus_mute(0) else "activo", AudioServer.get_bus_volume_db(0),
		Opciones.volumen_musica * 100.0, Opciones.volumen_efectos * 100.0, "Stream (Godot)"])'''),
])

edit('Autoload/Opciones.gd', [
 ('func _aplicar_todo() -> void:\n', 'func _aplicar_todo() -> void:\n	# El bus Master no se toca desde las opciones: se asegura que nunca quede silenciado\n	AudioServer.set_bus_mute(0, false)\n	if AudioServer.get_bus_volume_db(0) < -40.0:\n		AudioServer.set_bus_volume_db(0, 0.0)\n'),
])
print('ok')
