# Revisión de saltos de tamaño en los modales

Generado por `tools/probar_saltos.gd` (con ventana real). Registra por fotograma el tamaño y la posición del cuadro y de la etiqueta de cada modal desde el primer fotograma con opacidad mayor que 0 y señala cualquier cambio posterior (tolerancia 0.5 px).

| Escenario | Fotogramas | Primer fotograma visible | Resultado | Cambios |
|---|---|---|---|---|
| balloon_texto | 875 | 0 (caja 608x95 en (16, 255); texto 592x60 en (24, 263); nombre 51x28 en (26, 229)) | sin cambios | - |
| balloon_opciones_y_retrato | 880 | 0 (caja 608x115 en (16, 235); texto 520x80 en (96, 243); nombre 51x28 en (26, 209)) | sin cambios | - |
| balloon_opciones_aparecen (informativo) | 21 | 0 (caja 608x193 en (16, 157); texto 520x80 en (96, 165); nombre 51x28 en (26, 131)) | sin cambios | - |
| notificacion | 90 | 1 (tarjeta 220x175 en (408, 5)) | sin cambios | - |
| notificacion_segunda | 90 | 1 (tarjeta 220x83 en (408, 5)) | sin cambios | - |
| cuestionario_intro_1 | 609 | 0 (panel_intro 452x220 en (168, 70); texto_intro 424x100 en (182, 124); boton_seguir 120x27 en (486, 238)) | sin cambios | - |
| cuestionario_pregunta_01 | 14 | 0 (panel_pregunta 452x290 en (168, 36); texto_pregunta 424x58 en (182, 84); opciones 424x128 en (182, 150); progreso 424x15 en (182, 50)) | sin cambios | - |
| cuestionario_pregunta_02 | 14 | 0 (panel_pregunta 452x290 en (168, 36); texto_pregunta 424x58 en (182, 84); opciones 424x120 en (182, 150); progreso 424x15 en (182, 50)) | sin cambios | - |
| cuestionario_pregunta_03 | 14 | 0 (panel_pregunta 452x290 en (168, 36); texto_pregunta 424x58 en (182, 84); opciones 424x120 en (182, 150); progreso 424x15 en (182, 50)) | sin cambios | - |
| cuestionario_pregunta_04 | 14 | 0 (panel_pregunta 452x290 en (168, 36); texto_pregunta 424x58 en (182, 84); opciones 424x120 en (182, 150); progreso 424x15 en (182, 50)) | sin cambios | - |
| cuestionario_pregunta_05 | 14 | 0 (panel_pregunta 452x290 en (168, 36); texto_pregunta 424x58 en (182, 84); opciones 424x120 en (182, 150); progreso 424x15 en (182, 50)) | sin cambios | - |
| cuestionario_pregunta_06 | 14 | 0 (panel_pregunta 452x290 en (168, 36); texto_pregunta 424x58 en (182, 84); opciones 424x120 en (182, 150); progreso 424x15 en (182, 50)) | sin cambios | - |
| cuestionario_pregunta_07 | 14 | 0 (panel_pregunta 452x290 en (168, 36); texto_pregunta 424x58 en (182, 84); opciones 424x128 en (182, 150); progreso 424x15 en (182, 50)) | sin cambios | - |
| cuestionario_intro_8 | 575 | 0 (panel_intro 452x220 en (168, 70); texto_intro 424x100 en (182, 124); boton_seguir 120x27 en (486, 238)) | sin cambios | - |
| cuestionario_pregunta_08 | 14 | 0 (panel_pregunta 452x290 en (168, 36); texto_pregunta 424x58 en (182, 84); opciones 424x120 en (182, 150); progreso 424x15 en (182, 50)) | sin cambios | - |
| cuestionario_pregunta_09 | 14 | 0 (panel_pregunta 452x290 en (168, 36); texto_pregunta 424x58 en (182, 84); opciones 424x120 en (182, 150); progreso 424x15 en (182, 50)) | sin cambios | - |
| cuestionario_pregunta_10 | 14 | 0 (panel_pregunta 452x290 en (168, 36); texto_pregunta 424x58 en (182, 84); opciones 424x120 en (182, 150); progreso 424x15 en (182, 50)) | sin cambios | - |
| cuestionario_pregunta_11 | 14 | 0 (panel_pregunta 452x290 en (168, 36); texto_pregunta 424x58 en (182, 84); opciones 424x120 en (182, 150); progreso 424x15 en (182, 50)) | sin cambios | - |
| cuestionario_pregunta_12 | 14 | 0 (panel_pregunta 452x290 en (168, 36); texto_pregunta 424x58 en (182, 84); opciones 424x120 en (182, 150); progreso 424x15 en (182, 50)) | sin cambios | - |
| cuestionario_pregunta_13 | 14 | 0 (panel_pregunta 452x290 en (168, 36); texto_pregunta 424x58 en (182, 84); opciones 424x120 en (182, 150); progreso 424x15 en (182, 50)) | sin cambios | - |
| cuestionario_pregunta_14 | 14 | 0 (panel_pregunta 452x290 en (168, 36); texto_pregunta 424x58 en (182, 84); opciones 424x120 en (182, 150); progreso 424x15 en (182, 50)) | sin cambios | - |
| cuestionario_intro_15 | 341 | 0 (panel_intro 452x220 en (168, 70); texto_intro 424x100 en (182, 124); boton_seguir 120x27 en (486, 238)) | sin cambios | - |
| cuestionario_pregunta_15 | 14 | 0 (panel_pregunta 452x290 en (168, 36); texto_pregunta 424x58 en (182, 84); opciones 424x63 en (182, 150); progreso 424x15 en (182, 50)) | sin cambios | - |
| cuestionario_pregunta_16 | 14 | 0 (panel_pregunta 452x290 en (168, 36); texto_pregunta 424x58 en (182, 84); opciones 424x63 en (182, 150); progreso 424x15 en (182, 50)) | sin cambios | - |
| resultados | 60 | 0 (panel 640x380 en (16, 10); scroll 616x232 en (28, 50)) | sin cambios | - |
| diario_seccion_0 | 30 | 0 (libro 580x316 en (30, 22); contenido 544x228 en (48, 70); pie 544x23 en (48, 310)) | sin cambios | - |
| diario_seccion_1 | 30 | 0 (libro 580x316 en (30, 22); contenido 544x228 en (48, 70); pie 544x23 en (48, 310)) | sin cambios | - |
| diario_seccion_2 | 30 | 0 (libro 580x316 en (30, 22); contenido 544x228 en (48, 70); pie 544x23 en (48, 310)) | sin cambios | - |
| diario_seccion_5 | 30 | 0 (libro 580x316 en (30, 22); contenido 544x228 en (48, 70); pie 544x23 en (48, 310)) | sin cambios | - |
| diario_seccion_7 | 30 | 0 (libro 580x316 en (30, 22); contenido 544x228 en (48, 70); pie 544x23 en (48, 310)) | sin cambios | - |

Escenarios con salto: 0 de 30.
