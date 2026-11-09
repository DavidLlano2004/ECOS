class_name Atmosfera
extends RefCounted
## Efectos de ambiente que comparten varias escenas (título, onboarding...).


## Textura circular suave (blanco en el centro, transparente en el borde) para luces y partículas.
static func crear_textura_luz(tamano: int = 128) -> GradientTexture2D:
	var degradado := Gradient.new()
	degradado.set_color(0, Color.WHITE)
	degradado.set_color(1, Color(1, 1, 1, 0))
	var textura := GradientTexture2D.new()
	textura.gradient = degradado
	textura.fill = GradientTexture2D.FILL_RADIAL
	textura.fill_from = Vector2(0.5, 0.5)
	textura.fill_to = Vector2(1.0, 0.5)
	textura.width = tamano
	textura.height = tamano
	return textura


## Una franja de niebla: ruido suave con transparencia y bordes que se desvanecen
## (usa Shaders/niebla.gdshader). Devuelve un TextureRect listo para añadir a la escena.
static func crear_niebla(posicion: Vector2, tamano: Vector2, opacidad: float, desvanecer_x: float = 0.28) -> TextureRect:
	var ruido := FastNoiseLite.new()
	ruido.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	ruido.frequency = 0.012
	ruido.seed = randi()
	var rampa := Gradient.new()
	rampa.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	rampa.colors = PackedColorArray([Color(0.8, 0.88, 1.0, 0.0), Color(0.8, 0.88, 1.0, 0.5), Color(0.9, 0.95, 1.0, 1.0)])
	var textura := NoiseTexture2D.new()
	textura.noise = ruido
	textura.width = 256
	textura.height = 96
	textura.seamless = true
	textura.color_ramp = rampa
	var rect := TextureRect.new()
	rect.texture = textura
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.position = posicion
	rect.size = tamano
	rect.modulate.a = opacidad
	var material := ShaderMaterial.new()
	material.shader = load("res://Shaders/niebla.gdshader")
	material.set_shader_parameter("desvanecer_x", desvanecer_x)
	rect.material = material
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect
