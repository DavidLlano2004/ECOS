shader_type canvas_item;
// Brillo del título "ECOS": una onda de luz que ondula suave de izquierda a derecha
// y un pulso lento. Solo afecta al relleno dorado, no al contorno oscuro.

uniform vec4 color_brillo : source_color = vec4(1.0, 0.94, 0.72, 1.0);
uniform float intensidad : hint_range(0.0, 2.0) = 0.7;
uniform float velocidad_ola = 1.4;
uniform float frecuencia_ola = 0.03;
uniform float velocidad_pulso = 1.6;

varying vec2 pos_mundo;

void vertex() {
	// Posición en pantalla, para que la onda sea continua entre las letras
	pos_mundo = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	float luma = dot(COLOR.rgb, vec3(0.299, 0.587, 0.114));
	float es_relleno = smoothstep(0.35, 0.6, luma);
	float ola = 0.5 + 0.5 * sin(pos_mundo.x * frecuencia_ola - TIME * velocidad_ola);
	float pulso = 0.5 + 0.5 * sin(TIME * velocidad_pulso);
	float brillo = (ola * 0.7 + pulso * 0.3) * intensidad * es_relleno;
	COLOR.rgb = mix(COLOR.rgb, color_brillo.rgb, brillo * 0.6) + COLOR.rgb * brillo * 0.35;
}
