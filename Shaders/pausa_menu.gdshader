shader_type canvas_item;
// Fondo del menú de pausa: la imagen del juego desenfocada, más oscura y con un tinte morado.
// Va en un ColorRect a pantalla completa dentro de un CanvasLayer. fuerza = 0 no cambia nada.

uniform sampler2D pantalla : hint_screen_texture, filter_linear_mipmap;
uniform float fuerza : hint_range(0.0, 1.0) = 0.0;
uniform float radio : hint_range(0.0, 8.0) = 3.0;   // desenfoque, en píxeles reales de la ventana

void fragment() {
	vec2 paso = SCREEN_PIXEL_SIZE * radio;
	vec3 original = texture(pantalla, SCREEN_UV).rgb;
	vec3 suma = original * 4.0;
	// 8 direcciones a dos distancias: un desenfoque simple y barato
	for (int i = 0; i < 8; i++) {
		float angulo = float(i) * 0.785398;
		vec2 dir = vec2(cos(angulo), sin(angulo));
		suma += texture(pantalla, SCREEN_UV + dir * paso).rgb * 2.0;
		suma += texture(pantalla, SCREEN_UV + dir * paso * 2.0).rgb;
	}
	suma /= 28.0;
	vec3 oscuro = suma * vec3(0.5, 0.45, 0.65);
	COLOR = vec4(mix(original, oscuro, fuerza), 1.0);
}
