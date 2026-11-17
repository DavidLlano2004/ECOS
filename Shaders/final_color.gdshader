shader_type canvas_item;
// Fondo de la secuencia final: `color_amount` va de 0 (gris apagado) a 1 (todo su color). Así el mundo
// "recupera su color" según cuántas emociones se integraron.

uniform float color_amount : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float luz = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	vec3 gris = vec3(luz) * vec3(0.8, 0.85, 1.0);
	vec3 resultado = mix(gris, c.rgb, color_amount);
	// más oscuro y azulado cuanto menos color
	resultado *= mix(0.65, 1.0, color_amount);
	COLOR = vec4(resultado, c.a);
}
