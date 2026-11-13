# ECOS: estado del proyecto (para la siguiente sesión)

Léelo junto con `CLAUDE.md` (reglas y arquitectura). Última actualización: 2026-11-09.
Godot 4.7.2, GDScript. Todo en español. Un commit por tarea y **sin líneas de atribución a Claude** (solo el perfil del usuario).

## Cómo trabajar

- Godot (consola): `/c/Users/Usuario/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe`
- Python (con Pillow): `C:\Users\Usuario\AppData\Local\Programs\Python\Python312\python.exe` (el alias `python` de la tienda no sirve).
- Receta tras cambiar arte o mapa (detalle en `CLAUDE.md`, sección `tools/`): `generar_tileset.py` -> `godot --headless --import` -> `construir_tileset.gd` -> `generar_mapa.py` -> `godot --path . res://tools/preview_mapa.tscn` (necesita ventana). Regenerar siempre `tools/preview_mapa_*.png`.
- Tras crear un `.dialogue`, `.png` o shader nuevo, ejecutar `--import` **dos veces** (la primera vez falla el `preload`).
- Pruebas: scripts temporales fuera del proyecto y se borran. Para probar con el mundo cargado hay que usar una escena temporal (los autoloads no existen con `--script`). Ejemplos de lo que se verificó: alcance físico cada 8 px con la forma real del jugador, cancelar diálogos, estados de bloqueos.
- No editar escenas que puedan estar abiertas en el editor sin avisar. No borrar archivos sin permiso. Las entidades del mundo (portales, props, Guía, criaturas, bloqueos, puerta) se crean por código en `Mundo.gd`, así que `Mundo.tscn` casi no se toca.

## Qué está hecho

- **Base:** autoloads `GameState`, `Dialogo` (Dialogue Manager 4.2.0), `Notificacion`; `Player` (8 direcciones, interacción, cámara, tecla Q); 7 criaturas con su comportamiento (`Emocion.gd`) y sus `.dialogue`; guardado JSON (`user://ecos_save.json`); finales bueno, difícil y neutro calculados en `GameState.calcular_final()`.
- **Flujo:** pantalla de título -> onboarding cinematográfico (Guía, 7 preguntas, portal) -> `Scenes/Mundo/Mundo.tscn`. "Continuar" también va a `Mundo.tscn`. `PruebaEmociones.tscn` se conserva como escena de pruebas (F6; F3 panel, F4 reinicio).
- **Mundo (96x54 tiles, 32 px):** dos épocas con la misma forma. Mapa en `Resources/Mundo/mapa.txt`, generado por `tools/generar_mapa.py` (caminos curvos, zonas orgánicas, límite natural con franja de árboles `T`, mesetas de Soledad y Rabia con anillo de acantilado, río de Culpa con puente roto y un paso de tierra, muros solo en tramos de 3 o más). Tileset por código (`tools/generar_tileset.py` + `construir_tileset.gd`). Capas creadas por código: `Sombras`, `DetallesSuelo` (16x16), `Tono` (shader de hierba clara y oscura). Todo el agua es sólida.
- **Props:** `Prop` (8 tipos, escala por tipo ±8 %, colisión en la base, luces solo en el Pasado) colocados por `Decorador.gd`. Solo el nodo `Objetos` ordena en Y (ninguna entidad activa `y_sort_enabled` en su raíz).
- **Ambiente:** `CanvasModulate` por época, luciérnagas (Pasado) y ceniza (Presente), viñeta, transición de épocas con shader de ondas (`Mundo.viajar()`), shader de saturación del Presente según emociones integradas.
- **Portales:** `Portal.tscn` (principal en `Spawn_Hub` y una grieta por zona; E o Q, Q solo dentro de su zona).
- **Guía:** `Guia.tscn` junto al portal, con `Dialogos/guia.dialogue` que cambia según el progreso.
- **Presente reactivo:** `BloqueoPresente` por zona (integrada, atacada, ignorada, pendiente, con mensajes y forma aliada que deambula). `PuertaReflejo` en `Zona_Final`.
- **Cancelar conversaciones:** "Ahora no" y ESC (mantener durante el texto), globo de despedida (`frase_cierre`), el onboarding no se puede cancelar. Cancelar nunca cambia estados.
- **Emociones integradas:** siguen vivas (deambulan, se pueden volver a hablar con 4 frases rotadas en `despues` y `aliada_despues`).
- **Git:** repo `https://github.com/DavidLlano2004/ECOS.git`. Se reescribió el historial para quitar la coautoría de Claude y se subió con force-with-lease. Rama local `backup-antes-de-limpiar`. `.claude/settings.json` tiene la atribución vacía.

## Qué puede faltar (por orden aproximado)

1. **Subir a GitHub** el commit "Configuración del proyecto" (`git push origin main`, lo hace el usuario).
2. **Habilidades:** hechas las 7 (4.1 sistema y HUD, 4.2 Impulso/Calma/Reparar, 4.3 Visión/Pausa/Revelar/Vínculo; ver `CLAUDE.md`, sección "Habilidades", con los 7 grupos e interfaces: `rompible`, `calmable`, `reparable`, `sombra`, `tiempo`, `oculto`, `placa_doble`). Aún no hay objetos de juego que usen las interfaces (acertijos del prompt 4.4); solo la arena `PruebaHabilidades.tscn`. Pendiente de ajustar jugando: tiempos, radios y cooldowns (provisionales).
2b. **Acertijos y fragmentos de memoria:** hechos (ver `CLAUDE.md`, sección "Acertijos de habilidad y fragmentos de memoria"): 7 recintos en el Presente, cada uno con su acertijo y un fragmento con su recuerdo (`Resources/Recuerdos.tres`). Arte temporal: la puerta de las placas y el abismo (dibujados por código). Pendiente: usar `GameState.recuerdos_completos` en el final, y mostrar los recuerdos del diario cuando exista la pantalla del diario.
3. **Bloqueos específicos por emoción** (reglas completas en `CLAUDE.md`, sección "Bloqueos del Presente"): hoy todos usan el mismo `BloqueoPresente` genérico. Faltan: luz parpadeante de Miedo, lluvia con nube y colisión propia de Tristeza (estanque al lado del camino), colisión solo en laterales y hueco libre de 24 px en Soledad, Ansiedad y Vergüenza, y el puente vertical de Culpa (el río del mapa es vertical, no horizontal; revisar el diseño).
4. **Las zonas no están cercadas:** los bloqueos cierran el camino (96 px) pero se pueden rodear por la hierba. Para que bloqueen de verdad hay que ponerlos en un paso estrecho (la apertura del anillo de las mesetas) o cercar las zonas con árboles o rocas.
5. **Final del juego:** `Puerta del Reflejo` solo muestra el resultado de `calcular_final()` como texto **TEMPORAL**. Falta la secuencia final, el cuestionario de salida (`respuestas_final`, comparar antes y después; no cancelable) y `Dialogos/final.dialogue` (está vacío).
6. **Menú de pausa:** no existe (ESC solo cancela diálogos). Cuando se haga debe consultar `Dialogo.pausa_permitida()`.
7. **Diario (Tab)** y menú del título: comprobar que el diario muestra `GameState.diario` y que "Continuar" carga la partida guardada (`GameState.cargar()`); no se ha verificado en esta etapa.
8. **Arte provisional:** la `PuertaReflejo`, el tileset, los props y los detalles están generados por código (no hay arte final). Arcos y espejos de Vergüenza (marcadores `arcos` y `espejos`) siguen sin sprite. `arbol_redondo` mide solo ~90-100 px (pedido: 130-160); subir su `escala` a 1.5 si se quiere.
9. **Detalles menores conocidos:** los caminos diagonales aún tienen escalones de 2 o 3 tiles (disimulados por bordes redondeados); la ilustración del título puede "temblar" con el zoom y filtro Nearest; una ventana que no sea 16:9 deja franjas; mensaje `Unrecognized UID` ocasional al importar (inofensivo); git avisa de CRLF en `tools/*.json` (inofensivo).
10. **Rendimiento:** medido ~1.300 FPS sin vsync en una RTX 3050 (unos 390 nodos en `Objetos` por época). Vigilar si se añaden más efectos.
