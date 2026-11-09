shader_type canvas_item;
// Fondo del onboarding: la ilustración desenfocada, más oscura y con un tinte frío,
// para que el Guía y las emociones destaquen.

uniform float radio : hint_range(0.0, 8.0) = 2.5;   // desenfoque, en píxeles de la imagen
uniform float oscuridad : hint_range(0.0, 1.0) = 0.55;
uniform vec4 tinte : source_color = vec4(0.38, 0.45, 0.7, 1.0);

void fragment() {
	vec2 paso = TEXTURE_PIXEL_SIZE * radio;
	vec4 suma = texture(TEXTURE, UV) * 4.0;
	// 8 direcciones a dos distancias: un desenfoque simple y barato
	for (int i = 0; i < 8; i++) {
		float angulo = float(i) * 0.785398;
		vec2 dir = vec2(cos(angulo), sin(angulo));
		suma += texture(TEXTURE, UV + dir * paso) * 2.0;
		suma += texture(TEXTURE, UV + dir * paso * 2.0);
	}
	suma /= 28.0;
	vec3 color = suma.rgb * mix(vec3(1.0), tinte.rgb, 0.65) * (1.0 - oscuridad);
	COLOR = vec4(color, 1.0);
}
