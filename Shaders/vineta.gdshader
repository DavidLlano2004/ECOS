shader_type canvas_item;
// Viñeta suave: oscurece un poco los bordes de la pantalla para dar atmósfera.

uniform float intensidad : hint_range(0.0, 1.0) = 0.5;
uniform float radio : hint_range(0.2, 1.4) = 0.78;
uniform float suavidad : hint_range(0.05, 1.0) = 0.6;
uniform vec4 color : source_color = vec4(0.07, 0.03, 0.12, 1.0);

void fragment() {
	vec2 p = (UV - vec2(0.5)) * 2.0;
	p.y *= 0.9;
	float d = length(p);
	float a = smoothstep(radio, radio + suavidad, d) * intensidad;
	COLOR = vec4(color.rgb, a);
}
