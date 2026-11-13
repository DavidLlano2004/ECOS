shader_type canvas_item;
// Visión (Miedo): leve tinte violeta de claridad sobre toda la pantalla.
// Va en un ColorRect a pantalla completa dentro de un CanvasLayer. fuerza = 0 no cambia nada.

uniform sampler2D pantalla : hint_screen_texture, filter_linear_mipmap;
uniform float fuerza : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec3 c = texture(pantalla, SCREEN_UV).rgb;
	float centro = 1.0 - smoothstep(0.15, 0.85, distance(UV, vec2(0.5)));
	vec3 violeta = vec3(0.55, 0.35, 0.95);
	// un poco más de claridad y un velo violeta, más notable cerca del centro
	c = c * (1.0 + 0.10 * fuerza) + violeta * (0.035 + 0.045 * centro) * fuerza;
	COLOR = vec4(c, 1.0);
}
