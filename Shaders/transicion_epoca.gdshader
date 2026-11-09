shader_type canvas_item;
// Transición entre épocas: la pantalla ondula desde el centro y se llena de luz.
// Se dibuja sobre un ColorRect de pantalla completa que usa la textura de la pantalla.

uniform sampler2D pantalla : hint_screen_texture, filter_linear, repeat_disable;
uniform float fuerza : hint_range(0.0, 1.0) = 0.0;
uniform float destello : hint_range(0.0, 1.0) = 0.0;
uniform vec4 color_destello : source_color = vec4(1.0, 0.92, 0.72, 1.0);

void fragment() {
	vec2 c = SCREEN_UV - vec2(0.5);
	float d = length(c * vec2(1.78, 1.0));
	// ondas circulares que salen del centro
	float onda = sin(d * 38.0 - TIME * 16.0);
	vec2 empuje = normalize(c + vec2(0.0001)) * onda * 0.022 * fuerza;
	// temblor horizontal suave
	empuje.x += sin(SCREEN_UV.y * 28.0 - TIME * 11.0) * 0.008 * fuerza;
	vec2 uv = SCREEN_UV + empuje;
	vec3 col;
	// pequeña separación de colores en los bordes de las ondas
	col.r = texture(pantalla, uv + vec2(0.004 * fuerza, 0.0)).r;
	col.g = texture(pantalla, uv).g;
	col.b = texture(pantalla, uv - vec2(0.004 * fuerza, 0.0)).b;
	// destello de luz: más fuerte en el centro
	float brillo = destello * (1.0 - smoothstep(0.0, 1.2, d) * 0.45);
	col = mix(col, color_destello.rgb, clamp(brillo, 0.0, 1.0));
	COLOR = vec4(col, 1.0);
}
