shader_type canvas_item;
// Tinte cálido a la izquierda (Pasado) y frío a la derecha (Presente), con una
// transición central que ondula lentamente.

uniform vec4 color_pasado : source_color = vec4(1.0, 0.62, 0.3, 0.2);
uniform vec4 color_presente : source_color = vec4(0.45, 0.58, 0.8, 0.28);
uniform float ancho_transicion = 0.16;

void fragment() {
	float onda = sin(UV.y * 9.0 + TIME * 0.6) * 0.025 + sin(UV.y * 3.0 - TIME * 0.4) * 0.02;
	float t = smoothstep(0.5 + onda - ancho_transicion, 0.5 + onda + ancho_transicion, UV.x);
	COLOR = mix(color_pasado, color_presente, t);
}
