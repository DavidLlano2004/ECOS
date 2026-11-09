shader_type canvas_item;
// Disolución con ruido: el título se deshace de abajo hacia arriba, con un borde dorado brillante.
// "progreso" va de 0 (entero) a 1 (desaparecido).

uniform float progreso : hint_range(0.0, 1.0) = 0.0;
uniform sampler2D ruido : repeat_enable;
uniform vec4 color_borde : source_color = vec4(1.0, 0.82, 0.45, 1.0);
uniform float ancho_borde = 0.09;

void fragment() {
	float n = texture(ruido, UV * vec2(3.0, 1.5)).r;
	// Lo de abajo se disuelve antes que lo de arriba
	float t = n * 0.55 + (1.0 - UV.y) * 0.45;
	float limite = progreso * (1.0 + ancho_borde * 2.0) - ancho_borde;
	if (t < limite) {
		discard;
	}
	float borde = 1.0 - smoothstep(0.0, ancho_borde, t - limite);
	COLOR.rgb = mix(COLOR.rgb, color_borde.rgb * 1.6, borde * COLOR.a);
}
