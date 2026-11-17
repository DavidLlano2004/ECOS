# ECOS: estado del proyecto (para la siguiente sesión)

Léelo junto con `CLAUDE.md` (reglas y arquitectura). Última actualización: 2026-11-13.
Godot 4.7.2, GDScript. Todo en español. Un commit por tarea y **sin líneas de atribución a Claude** (solo el perfil del usuario).

## SIGUIENTE PASO

**Lo que sigue es el prompt 4.7** (lo envía el usuario; todavía no se conoce su contenido, no lo supongas). Todo lo anterior está terminado y commiteado (último commit: `1850757` "Tecla E, texto unificado y consejos"). El usuario trabaja por prompts numerados que le prepara otro asistente (Claude chat) y los pega aquí.

## Lo hecho en la última etapa (commits, de más nuevo a más viejo)

- Sistema de evaluación y final (prompts 5.1 y 5.2): ver `CLAUDE.md`, sección "Evaluación y final del juego". La pantalla de resultados es TEMPORAL (falta el prompt 5.3).
- Santuarios, cofres y mejoras de habilidad (prompt 4.6): ver `CLAUDE.md`, sección "Santuarios, cofres de memoria y mejoras". El cofre ya está colocado en cada santuario.
- Compuertas de habilidad, progresión y pistas (prompt 4.5): ver `CLAUDE.md`, sección "Compuertas de habilidad y progresión". Antes, "Sprite del cofre de memoria" (`CofreMemoria.tscn`, `frames_cofre.tres`).

- `1850757` Tecla E, texto unificado y consejos: los textos dicen E para portales y grietas (Q sigue funcionando pero oculta); `Dialogo.mostrar_texto(nombre, texto, opciones, retrato, automatico)` es la única vía para mostrar texto (borrados `GloboCierre` y `Dialogo.preguntar`); `EmocionData.nombre_bloqueo`; 84 consejos en `Resources/Consejos/*.json` (`Consejos.charlar`), `GameState.consejos_vistos`; `docs/consejos_para_revision.md`.
- `0e8561f` Sistema de audio (`Sonido`: efectos, música y ambientes con fundido, pasos, portal por cercanía, panel de depuración con la tecla M).
- `6e81819` Audio del juego: los 60 audios de ElevenLabs procesados (`tools/procesar_audio.py`) e importados; originales en `audio_originales/` (ignorado por git).
- `8af8e26` Diario (TAB) y menú de pausa (ESC), opciones (buses `Musica` y `Efectos`, pantalla completa), autoguardado con ícono, guardado seguro y carga a prueba de archivos dañados, Continuar con posición y época.
- `999e6da` Acertijos de habilidad y fragmentos de memoria (7 recintos en el Presente, `Resources/Recuerdos.tres`).
- `f5e9b1a` Arte de los acertijos y los íconos de habilidad.
- `5e8da54`, `086170b`, `a8713ae` las 7 habilidades y el HUD. `975afd8` teclas de prueba de la arena (U, I, O).

## Cómo trabajar

- Godot (consola): `/c/Users/Usuario/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe`
- Python (con Pillow): `C:\Users\Usuario\AppData\Local\Programs\Python\Python312\python.exe` (el alias `python` de la tienda no sirve).
- Receta tras cambiar arte o mapa (detalle en `CLAUDE.md`, sección `tools/`): `generar_tileset.py` -> `godot --headless --import` -> `construir_tileset.gd` -> `generar_mapa.py` -> `godot --path . res://tools/preview_mapa.tscn` (necesita ventana). Regenerar siempre `tools/preview_mapa_*.png`.
- Tras crear un `.dialogue`, `.png` o shader nuevo, ejecutar `--import` **dos veces** (la primera vez falla el `preload`).
- Pruebas: scripts temporales fuera del proyecto y se borran. Para probar con el mundo cargado hay que usar una escena temporal (los autoloads no existen con `--script`). Ejemplos de lo que se verificó: alcance físico cada 8 px con la forma real del jugador, cancelar diálogos, estados de bloqueos.
- Lecciones de esta etapa: (1) las teclas F5 a F10 son atajos del editor de Godot (pausan o detienen el juego): para depurar se usan letras (U, I, O en `PruebaHabilidades`; F2, F3 y F4 sí funcionan). (2) En el balloon de diálogo las opciones se mueven con las flechas, no con W y S; para salir de un texto sin opciones hay que MANTENER ESC (0.7 s), con opciones basta pulsarlo. (3) Mis `git add -A` pueden colarse archivos que el usuario copió o cachés: revisar `git status` antes de commitear (`__pycache__` ya está ignorado). (4) Al editar `project.godot` con el editor abierto, avisar de que lo recargue. (5) Las pruebas con ventana real (`godot --path .`) sirven para shaders, UI y audio (WASAPI); las `--headless` para lógica y física. Las pruebas no deben dejar archivos en `%APPDATA%\Godot\app_userdata\ECOS` (guardado y opciones del usuario): respaldar y restaurar. (6) En modo headless con `--quit-after`, cerrar con un sonido a medias imprime "resources still in use": es inofensivo (el juego real sale con calma, `Sonido.salir()`). (7) ffmpeg no está instalado: `tools/procesar_audio.py` usa `imageio-ffmpeg` desde un entorno virtual en `%TEMP%\ecos_audio_venv` (fuera del proyecto).
- No editar escenas que puedan estar abiertas en el editor sin avisar. No borrar archivos sin permiso. Las entidades del mundo (portales, props, Guía, criaturas, bloqueos, puerta) se crean por código en `Mundo.gd`, así que `Mundo.tscn` casi no se toca.

## Qué está hecho

- **Base:** autoloads `GameState`, `Dialogo` (Dialogue Manager 4.2.0), `Notificacion`; `Player` (8 direcciones, interacción, cámara); 7 criaturas con su comportamiento (`Emocion.gd`) y sus `.dialogue`; guardado JSON (`user://ecos_save.json`); finales bueno, difícil y neutro calculados en `GameState.calcular_final()`.
- **Flujo:** pantalla de título -> onboarding cinematográfico (Guía, consentimiento, cuestionario inicial de 16 preguntas, portal) -> `Scenes/Mundo/Mundo.tscn`. "Continuar" también va a `Mundo.tscn`. `PruebaEmociones.tscn` se conserva como escena de pruebas (F6; F3 panel, F4 reinicio).
- **Mundo (96x54 tiles, 32 px):** dos épocas con la misma forma. Mapa en `Resources/Mundo/mapa.txt`, generado por `tools/generar_mapa.py` (caminos curvos, zonas orgánicas, límite natural con franja de árboles `T`, mesetas de Soledad y Rabia con anillo de acantilado, río de Culpa con puente roto y un paso de tierra, muros solo en tramos de 3 o más). Tileset por código (`tools/generar_tileset.py` + `construir_tileset.gd`). Capas creadas por código: `Sombras`, `DetallesSuelo` (16x16), `Tono` (shader de hierba clara y oscura). Todo el agua es sólida.
- **Props:** `Prop` (8 tipos, escala por tipo ±8 %, colisión en la base, luces solo en el Pasado) colocados por `Decorador.gd`. Solo el nodo `Objetos` ordena en Y (ninguna entidad activa `y_sort_enabled` en su raíz).
- **Ambiente:** `CanvasModulate` por época, luciérnagas (Pasado) y ceniza (Presente), viñeta, transición de épocas con shader de ondas (`Mundo.viajar()`), shader de saturación del Presente según emociones integradas.
- **Portales:** `Portal.tscn` (principal en `Spawn_Hub` y una grieta por zona; se viaja con E).
- **Guía:** `Guia.tscn` junto al portal, con `Dialogos/guia.dialogue` que cambia según el progreso.
- **Presente reactivo:** `BloqueoPresente` por zona (integrada, atacada, ignorada, pendiente, con mensajes y forma aliada que deambula). `PuertaReflejo` en `Zona_Final`.
- **Cancelar conversaciones:** "Ahora no" y ESC (mantener durante el texto), globo de despedida (`frase_cierre`), el onboarding no se puede cancelar. Cancelar nunca cambia estados.
- **Emociones integradas:** siguen vivas (deambulan, se les puede volver a hablar y dan un consejo distinto cada vez, ver `Consejos`).
- **Git:** repo `https://github.com/DavidLlano2004/ECOS.git`. Se reescribió el historial para quitar la coautoría de Claude y se subió con force-with-lease. Rama local `backup-antes-de-limpiar`. `.claude/settings.json` tiene la atribución vacía.

## Qué puede faltar (por orden aproximado)

1. **Subir a GitHub** el commit "Configuración del proyecto" (`git push origin main`, lo hace el usuario).
2. **Habilidades:** hechas las 7 (4.1 sistema y HUD, 4.2 Impulso/Calma/Reparar, 4.3 Visión/Pausa/Revelar/Vínculo; ver `CLAUDE.md`, sección "Habilidades", con los 7 grupos e interfaces: `rompible`, `calmable`, `reparable`, `sombra`, `tiempo`, `oculto`, `placa_doble`). Aún no hay objetos de juego que usen las interfaces (acertijos del prompt 4.4); solo la arena `PruebaHabilidades.tscn`. Pendiente de ajustar jugando: tiempos, radios y cooldowns (provisionales).
2b. **Acertijos y fragmentos de memoria:** hechos (ver `CLAUDE.md`, sección "Acertijos de habilidad y fragmentos de memoria"): 7 recintos en el Presente, cada uno con su acertijo y un fragmento con su recuerdo (`Resources/Recuerdos.tres`). Arte temporal: la puerta de las placas y el abismo (dibujados por código). Pendiente: usar `GameState.recuerdos_completos` en el final, y mostrar los recuerdos del diario cuando exista la pantalla del diario.
3. **Bloqueos específicos por emoción** (reglas completas en `CLAUDE.md`, sección "Bloqueos del Presente"): hoy todos usan el mismo `BloqueoPresente` genérico. Faltan: luz parpadeante de Miedo, lluvia con nube y colisión propia de Tristeza (estanque al lado del camino), colisión solo en laterales y hueco libre de 24 px en Soledad, Ansiedad y Vergüenza, y el puente vertical de Culpa (el río del mapa es vertical, no horizontal; revisar el diseño).
4. **Las zonas no están cercadas:** los bloqueos cierran el camino (96 px) pero se pueden rodear por la hierba. Para que bloqueen de verdad hay que ponerlos en un paso estrecho (la apertura del anillo de las mesetas) o cercar las zonas con árboles o rocas.
5. **Final del juego:** HECHO (`Scenes/Final/Final.tscn`, cuestionario final, resultados, valoración, exportación y código de resultados; ver `CLAUDE.md`). `Dialogos/final.dialogue` quedó vacío y sin uso.
6. **Menú de pausa, diario, opciones y guardado:** hechos (ver `CLAUDE.md`, sección "Diario, menú de pausa, opciones y guardado"). **Audio:** los 60 archivos están procesados e importados en `Assets/Audio/` y el sistema `Sonido` los reproduce en todos los eventos del juego, con panel de depuración (tecla M); ver `CLAUDE.md`, sección "Audio". Pendiente: que suene `amb_lluvia` (cuando exista la lluvia de Tristeza), la música y el sonido de la secuencia final real, y ajustar a oído los volúmenes (`VOLUMEN_DB` en `Sonido.gd`).
7. **Continuar desde el título** ya carga la partida, la época y la posición; con el archivo dañado avisa y ofrece una partida nueva.
8. **Arte provisional:** la `PuertaReflejo`, el tileset, los props y los detalles están generados por código (no hay arte final). Arcos y espejos de Vergüenza (marcadores `arcos` y `espejos`) siguen sin sprite. `arbol_redondo` mide solo ~90-100 px (pedido: 130-160); subir su `escala` a 1.5 si se quiere.
9. **Detalles menores conocidos:** los caminos diagonales aún tienen escalones de 2 o 3 tiles (disimulados por bordes redondeados); la ilustración del título puede "temblar" con el zoom y filtro Nearest; una ventana que no sea 16:9 deja franjas; mensaje `Unrecognized UID` ocasional al importar (inofensivo); git avisa de CRLF en `tools/*.json` (inofensivo).
10. **Rendimiento:** medido ~1.300 FPS sin vsync en una RTX 3050 (unos 390 nodos en `Objetos` por época). Vigilar si se añaden más efectos.
