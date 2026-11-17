# Casos extra de la revisión de calidad: resultados

Se ejecutaron con `python tools/ejecutar_pruebas.py` (sin ventana), `tools/pruebas_ventana.gd` (con ventana) y
`tools/prueba_resistencia.gd`. Resumen: **pruebas de humo 72 de 72**, **casos extra 21 de 21**, **casos de ventana 7 de 8**
(el que falló fue un tiempo de espera demasiado corto de la propia prueba, ya corregido) y la consola quedó sin errores ni
advertencias (se ignoran solo dos avisos esperados: el de "archivo de guardado dañado" que provoca la prueba a propósito y el
de "sin URL del formulario").

| Caso | Resultado |
|---|---|
| (a) Abrir por primera vez, sin partida, sin opciones y sin resultados | **Pasó.** Se detecta como "falta", se usan los valores por defecto y el título no ofrece "Continuar". Godot crea siempre la carpeta `user://` al arrancar, así que "sin carpeta" se probó como "sin ningún archivo dentro". |
| (b) Cargar una partida de una versión anterior, corrupta o vacía | **Pasó.** El formato antiguo (con `respuestas_inicio`) se carga con lo que falta por defecto; los datos con el tipo equivocado se ignoran; el archivo dañado o vacío se detecta y no rompe nada. |
| (c) Borrar el archivo de guardado a mitad de partida | **Pasó.** Se detecta como "falta", no rompe y se puede volver a guardar. |
| (d) INTERACTUAR muy rápido sobre una emoción | **Pasó.** Doce pulsaciones en el mismo fotograma abren UN solo diálogo; al cancelar, la criatura se despide, el estado no cambia y el jugador queda libre. |
| (e) Abrir y cerrar el diario y la pausa muchas veces seguidas | **Pasó.** 40 aperturas y cierres seguidos no dejan el juego pausado. |
| (f) Cambiar el tamaño de la ventana y la pantalla completa con un diálogo abierto | **Pasó** (con ventana): el diálogo sigue abierto y sin controles de tamaño inválido. |
| (g) Minimizar y restaurar | **Pasó** (con ventana): el juego y el diálogo siguen. |
| (h) ESC en el cuestionario, el onboarding y el final | **Pasó.** No saltan ni abren la pausa. Ojo, es diseño: en las decisiones de los finales neutro y difícil, ESC equivale a "Todavía no" y vuelve al mundo (así nunca hay softlock). |
| (i) Integrar a las 7 y volver a hablar con ellas | **Pasó.** Dan consejos, no cambian estados ni repiten habilidades. |
| (j) Viajar de época con una habilidad activa (Pausa, Visión) | **Pasó** en la prueba de humo (no se rompe nada). |
| (k) Jugar 15 minutos y medir FPS y memoria | **Parcial: 5 minutos** (la prueba se detuvo por decisión del usuario). Caminando al azar, con habilidades y un viaje de época: FPS medio ~930 sin límite de vsync (RTX 3050; el peor tramo medio fue ~560), memoria 134.5 → 135.7 MB, nodos 2722 → 2708, 0 nodos huérfanos. No hay señal de fugas, pero 5 minutos no demuestran una hora. |

## Lo que NO se pudo comprobar

- **Web:** cambiar de pestaña del navegador y volver (música y juego), audio tras el primer clic, guardado y descarga en el navegador,
  rendimiento en Chrome y Firefox. Hace falta exportar (faltan las plantillas de exportación de Godot 4.7.2) y mirarlo a mano.
- **Tamaño del juego exportado:** solo hay una estimación: ~23 MB de recursos sin comprimir (audio 20 MB) más el motor.
- **Advertencias de nodo** (triángulos amarillos) de las escenas: esta versión de Godot no permite leerlas desde un script; ninguna
  escena dio error al abrirse.
