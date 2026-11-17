# Revisión de calidad de ECOS

Generado por `tools/revisar_proyecto.py` (no arregla nada). Las pruebas con el juego en marcha están en `tools/pruebas_humo.gd` y `tools/pruebas_casos.gd` (`python tools/ejecutar_pruebas.py`), y los resultados de los casos extra, en `docs/pruebas_casos.md`.

## Resumen

- Referencias res:// rotas: 0
- Saltos de diálogo comprobados: 0
- Textos con teclas que no corresponden: 0
- Acciones del Input Map: ARRIBA (ARRIBA/W), ABAJO (ABAJO/S), DERECHA (D/DERECHA), IZQUIERDA (A/IZQUIERDA), INTERACTUAR (E), DIARIO (TAB), PAUSA (ESC), VIAJAR (Q), HABILIDAD (ESPACIO), BRUJULA (G), HAB_SIGUIENTE (R), HAB_ANTERIOR (F)
- Posibles faltas de tilde (candidatas): 0
- Audios del catálogo: 63 (0 sin conectar a ningún evento)
- Recursos EmocionData revisados: 7
- Archivos de más de 5 MB: 0
- Peso aproximado del juego exportado (sin comprimir, sin el motor): 23.1 MB (.ogg 11.3 MB, .wav 8.7 MB, .png 2.0 MB, .gd 0.5 MB)
- Teclas de depuración sin proteger: 0
- Revisión con Godot: omitida (--sin-godot)

## Bloquea la entrega (0)

_Nada en esta categoría._

## Conviene arreglar (1)

- **Sobra el audio «dialogo_blip» (no está en el catálogo de Sonido.gd)**
  - Assets/Audio/Efectos/

## Detalle (1)

- **El motor web pesa aparte**
  - El .wasm de Godot (sin hilos) pesa unas decenas de MB sin comprimir; solo se puede medir exportando (faltan las plantillas de exportación).
