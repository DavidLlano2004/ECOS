shader_type canvas_item;
// Niebla suave: desvanece los bordes de la franja para que no se vea el rectángulo.

uniform float desvanecer_y : hint_range(0.0, 0.5) = 0.35;
uniform float desvanecer_x : hint_range(0.0, 0.5) = 0.15;

void fragment() {
	float borde_y = smoothstep(0.0, desvanecer_y, UV.y) * smoothstep(0.0, desvanecer_y, 1.0 - UV.y);
	float borde_x = smoothstep(0.0, desvanecer_x, UV.x) * smoothstep(0.0, desvanecer_x, 1.0 - UV.x);
	COLOR.a *= borde_y * borde_x;
}
