shader_type canvas_item;
// Manchas de hierba más clara y más oscura repartidas con ruido en el mundo (no por casillas).
// Los bordes siguen las curvas del ruido y se tramán con puntitos ordenados, así que no hay rectángulos.
// `mascara` tiene un píxel por casilla del mapa: blanco donde hay hierba.

uniform sampler2D mascara : filter_nearest, repeat_disable;
uniform vec2 tamano_mundo = vec2(3072.0, 1728.0);
uniform vec4 color_oscuro : source_color = vec4(0.08, 0.1, 0.03, 0.34);
uniform vec4 color_claro : source_color = vec4(0.97, 0.9, 0.55, 0.26);
// Tamaño de las manchas, en píxeles del mundo
uniform float escala = 150.0;

const int BAYER[16] = int[16](0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float ruido(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p) {
	return 0.62 * ruido(p) + 0.28 * ruido(p * 2.1 + vec2(7.3, 1.9)) + 0.10 * ruido(p * 4.3 + vec2(1.7, 5.1));
}

void fragment() {
	vec2 px = floor(UV * tamano_mundo);
	// el ruido se deforma un poco para que los bordes sean irregulares
	vec2 p = px / escala;
	p += vec2(ruido(p * 3.0 + vec2(3.1, 8.2)), ruido(p * 3.0 + vec2(9.4, 2.7))) * 0.35;
	float n = fbm(p);
	int ix = int(mod(px.x, 4.0));
	int iy = int(mod(px.y, 4.0));
	float umbral = (float(BAYER[iy * 4 + ix]) + 0.5) / 16.0;
	float oscuro = smoothstep(0.44, 0.32, n);
	float claro = smoothstep(0.57, 0.69, n);
	float hierba = texture(mascara, UV).r;
	vec4 resultado = vec4(0.0);
	if (oscuro > umbral) {
		resultado = color_oscuro;
	} else if (claro > umbral) {
		resultado = color_claro;
	}
	COLOR = vec4(resultado.rgb, resultado.a * hierba);
}
