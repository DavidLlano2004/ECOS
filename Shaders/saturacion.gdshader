shader_type canvas_item;
// Color del Presente. `saturacion` va de 0.25 (ninguna emoción integrada: el Presente se ve gris
// azulado, tal como está dibujado) hasta 1.0 (todas integradas: el mundo recupera su color).
// El arte del Presente ya viene apagado: con 0.25 se deja tal cual y con 1.0 se realza.

uniform float saturacion : hint_range(0.0, 1.0) = 0.25;

void fragment() {
	float luz = dot(COLOR.rgb, vec3(0.299, 0.587, 0.114));
	float vida = clamp((saturacion - 0.25) / 0.75, 0.0, 1.0);
	// con 0.25 se ve el arte tal cual; con 1.0 recupera color (hasta 2.4 veces más saturado)
	vec3 color = mix(vec3(luz), COLOR.rgb, mix(1.0, 2.4, vida));
	// y vuelven los tonos cálidos y un poco de contraste
	color *= mix(vec3(1.0), vec3(1.3, 1.06, 0.78), vida);
	color = (color - vec3(0.5)) * (1.0 + vida * 0.25) + vec3(0.5);
	COLOR = vec4(clamp(color, 0.0, 1.0), COLOR.a);
}
