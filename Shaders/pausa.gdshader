shader_type canvas_item;
// Pausa (Ansiedad): leve desaturación azulada y una viñeta que se cierra un poco.
// Va en un ColorRect a pantalla completa dentro de un CanvasLayer. fuerza = 0 no cambia nada.

uniform sampler2D pantalla : hint_screen_texture, filter_linear_mipmap;
uniform float fuerza : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec3 c = texture(pantalla, SCREEN_UV).rgb;
	float gris = dot(c, vec3(0.299, 0.587, 0.114));
	vec3 azulado = vec3(gris) * vec3(0.85, 0.95, 1.15);
	c = mix(c, azulado, 0.45 * fuerza);
	// la viñeta se cierra un poco hacia los bordes
	float borde = smoothstep(0.35, 0.85, distance(UV, vec2(0.5)));
	c *= 1.0 - borde * 0.5 * fuerza;
	COLOR = vec4(c, 1.0);
}
