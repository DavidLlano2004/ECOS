# ECOS

Juego 2D top-down de psicología hecho en **Godot 4.7** con **GDScript**.

## Concepto

El mundo existe en dos épocas:

- **Pasado**: cálido, lleno de recuerdos.
- **Presente**: gris, roto.

En el Pasado viven 7 criaturas-emoción: **Rabia, Miedo, Tristeza, Soledad, Culpa, Ansiedad y Vergüenza**.
En un diálogo, el jugador decide cómo tratarlas. Solo "escucharlas" las **integra**.
Una emoción integrada da una habilidad y, en el Presente, pasa de ser un bloqueo a ser una aliada.

| Emoción  | Habilidad | Qué hace                                          |
|----------|-----------|---------------------------------------------------|
| Rabia    | Impulso   | Dash                                              |
| Miedo    | Visión    | Ver en la oscuridad                               |
| Tristeza | Calma     | Devolver el agua y la vida                        |
| Soledad  | Vínculo   | Un compañero que ayuda con mecanismos dobles      |
| Culpa    | Reparar   | Arreglar lo roto                                  |
| Ansiedad | Pausa     | Ralentiza el tiempo unos segundos para cruzar mecanismos y plataformas móviles |
| Vergüenza | Revelar  | Muestra caminos, puentes y puertas ocultos en el Presente |

**Mensaje central:** "Lo que atiendes hoy define el mundo de mañana."

## Reglas del juego

- No hay game over.
- Atacar o ignorar una emoción empeora el Presente, pero se puede reparar volviendo al Pasado.
- Cada decisión tiene una consecuencia visible en la otra época.
- 3 finales:
  - **Bueno**: las 7 emociones integradas.
  - **Difícil**: 4 o más emociones atacadas o ignoradas.
  - **Neutro**: el resto.
- Onboarding: una pregunta por emoción (7) al inicio, que se repiten al final para comparar el antes y el después.

### Estados de cada emoción

`pendiente`, `atacada`, `ignorada`, `integrada`.

### Vergüenza: la mecánica "no la mires fijamente"

Comportamiento `ESCONDERSE`. Deambula lento. En cada momento se revisa:

- Si el jugador está a **menos de 90 px** y su dirección de mirada (propiedad `facing` del `Player`) apunta hacia ella (**producto punto mayor a 0.5**), la Vergüenza se vuelve semitransparente (**alpha 0.35**), se aleja despacio y **no se puede interactuar** con ella.
- Si el jugador se acerca de lado o sin mirarla de frente, se queda visible (**alpha 1**) y **se puede hablar** con ella.

Nota: `Player.gd` todavía no tiene la propiedad `facing`; hay que añadirla cuando se implemente esta criatura.

## Arte

- Pixel art, frames de **64x64**.
- UI en paleta **morada y dorada**.
- Pasado: tonos cálidos. Presente: grises azulados.
- Fuente: **Pixelify Sans** (`res://Assets/PixelifySans-VariableFont_wght.ttf`).
- Pantalla: viewport 640x360, ventana 1280x720, estiramiento `canvas_items` con escala entera y filtro Nearest.

## Acciones de entrada (Input Map)

`IZQUIERDA`, `DERECHA`, `ARRIBA`, `ABAJO`, `INTERACTUAR` (E), `DIARIO` (Tab), `PAUSA` (Esc), `VIAJAR` (Q), `HABILIDAD` (Espacio).

## Estructura del proyecto

- `Autoload/`: singletons (`GameState`, `Dialogo`, `Notificacion`).
- `Scenes/{Personajes,Emociones,Mundo,UI,Objetos}`: escenas.
- `Scripts/{Personajes,Emociones,Mundo,UI,Datos,Sistemas}`: scripts.
- `Assets/{Personajes,Emociones,Mundo,UI,Audio,Fuentes,Efectos}`: arte, audio y fuentes.
- `Resources/Emociones`: datos de cada emoción en `.tres`.
- `Dialogos/`: contenido de los diálogos.
- `Scenes/UI/PantallaTitulo.tscn`: pantalla de título (escena principal): Comenzar -> onboarding cinematográfico (`Scenes/Intro/Onboarding.tscn`) -> `Scenes/Mundo/Mundo.tscn`; Continuar -> `Mundo.tscn`. Se salta la entrada con INTERACTUAR o Enter. Shaders en `Shaders/`.
- `Scenes/Mundo/PruebaEmociones.tscn`: arena para probar las 7 emociones (se juega con **F6**, no es la escena principal). En depuración: **F3** muestra/oculta el panel de estado, **F4** reinicia la partida y recarga la escena.
- `Scenes/Mundo/Mundo.tscn`: el mundo de 96x54 tiles (32 px) en dos épocas con la misma forma: nodos `Pasado` y `Presente`. Se prueba con **F6**; en depuración **F2** cambia de época. El diseño está en `Resources/Mundo/mapa.txt` (un carácter por tile, leyenda al inicio del archivo): edítalo y pulsa "Reconstruir mapa" en el inspector de `Mundo` (el `@tool` también lo dibuja en el editor). Los marcadores de zonas (`Spawn_Hub`, `Zona_*`) y de decoración (grupos `arboles`, `rocas`, `faroles`, `bancos`, `arcos`, `espejos`) son `Marker2D`; `Mundo.colocar_decoracion()` los rellena cuando existan los sprites.
- `tools/`: generadores. `generar_tileset.py` (Python + Pillow) dibuja `Assets/Mundo/tileset_*.png`; `construir_tileset.gd` (Godot) crea los `TileSet` de `Resources/Mundo/`; `generar_mapa.py` genera `mapa.txt` (caminos curvos con ruido, zonas orgánicas, límite natural con una franja `T` de árboles) y comprueba que sea transitable; `preview_mapa.gd` dibuja `preview_mapa_pasado.png` y `preview_mapa_presente.png`. El Presente es el mismo tileset con otra paleta.
  Receta tras cambiar el mapa o el arte: `python tools/generar_tileset.py` (solo si cambió el arte) -> `godot --headless --path . --import` -> `godot --headless --path . --script res://tools/construir_tileset.gd` (solo si cambió el arte) -> `python tools/generar_mapa.py` -> `godot --path . res://tools/preview_mapa.tscn` (hace falta ventana). **Regenera siempre las vistas previas cuando cambies el mapa.**
- `addons/`: plugins (solo con permiso del usuario).

## Capas de física

1 = `mundo` (muros, acantilados, agua profunda), 2 = `interactuable`.

## Reglas de trabajo

- Todos los textos del juego van **en español**.
- Código GDScript **tipado, simple y comentado en español**.
- Los datos van en **Resources (`.tres`)**, no escritos en el código.
- Usar **señales** en vez de referencias directas entre nodos.
- **Un commit por tarea.**
- Explicar cada cambio **en español sencillo**.
- **Pedir confirmación** antes de: instalar addons, borrar archivos o editar una escena que pueda estar abierta en el editor de Godot.
- No borrar ni mover archivos existentes sin permiso.

## Bloqueos del Presente

Siete hojas `Assets/Mundo/bloqueo_<id>.png` (384x192, cuadros de 96x96, 4 columnas x 2 filas) con sus `SpriteFrames` en `Resources/Mundo/frames_bloqueo_<id>.tres` (6 FPS). Animaciones: `bloqueo` y `abierto` en bucle; `abriendo` sin bucle (~0.4 s, un solo cuadro). **Regla general:** si una hoja no tiene `abriendo`, se pasa directo de `bloqueo` a `abierto`. Filas y columnas contadas desde 1:

| id | bloqueo | abriendo | abierto |
|----|---------|----------|---------|
| rabia | fila 1 (4 cuadros) | cuadro 1 de la fila 2 | cuadros 2, 3 y 4 de la fila 2 |
| miedo | fila 1 | no tiene | fila 2 |
| tristeza | fila 1 | no tiene | fila 2 |
| soledad | fila 1 | cuadro 1 de la fila 2 | cuadros 2, 3 y 4 de la fila 2 |
| culpa | cuadros 1, 2 y 3 de la fila 1 | cuadro 4 de la fila 1 | fila 2 |
| ansiedad | fila 1 | no tiene | fila 2 |
| verguenza | fila 1 | no tiene | fila 2 |

Reglas de cada bloqueo (para la tarea 3.3):

- **Rabia**: bloquea el paso mientras está `bloqueo`; al abrirse se puede pasar.
- **Miedo**: en `abierto`, una `PointLight2D` cálida y pequeña con parpadeo suave sobre la linterna del centro.
- **Tristeza** (caso especial): el sprite (el estanque) va **al lado del camino**, no encima. Mientras está bloqueado, una zona de lluvia intensa (partículas de gotas y la sombra de una nube) cubre el camino y tiene su propia colisión. Al integrarse, la lluvia se detiene con un fundido, desaparece esa colisión y el estanque lleno conserva una colisión propia para no caminar sobre el agua.
- **Soledad**: escala 1.25. En `abierto`, la colisión solo cubre los laterales del marco y los pedestales; el hueco central queda libre (mínimo 24 px). `PointLight2D` pequeña y cálida sobre cada luciérnaga.
- **Culpa**: es un puente **vertical** sobre el río horizontal de la zona de Culpa. Los tiles de agua de debajo **no** tienen colisión propia: la pone el bloqueo. Bloqueado no se puede cruzar; en `abierto` se camina sobre el puente y el río a los lados sigue bloqueando. Si el puente queda corto para el río, escalarlo en vertical o ajustar el río a 3 tiles en ese punto.
- **Ansiedad**: en `abierto`, la colisión cubre solo las dos columnas de engranajes; el arco central queda libre (mínimo 24 px).
- **Vergüenza**: en `abierto`, la colisión cubre solo los laterales (telas y espejos); el arco de luz central queda libre (mínimo 24 px).

## Decorados (props)

- `Assets/Mundo/props_pasado.png` y `props_presente.png`: 512x256, cuadros de 128x128 (4x2). Fila 1: `arbol_dorado` (con faroles), `cerezo`, `arbol_redondo`, `arbusto_flores`. Fila 2: `roca`, `farol_poste`, `tocon`, `banco`. Cada objeto está apoyado en la base de su cuadro (a 2 px del borde de abajo).
- `Scenes/Objetos/Prop.tscn` + `Scripts/Objetos/Prop.gd`: `@export var tipo` (los 8 nombres). Elige la hoja según el ancestro `Pasado` o `Presente`. Colisión pequeña solo en la base (el arbusto no tiene). Las luces cálidas (`PointLight2D` con `Resources/Mundo/luz_calida.tres`) solo existen en el Pasado.
- `Scripts/Mundo/Decorador.gd` decide las posiciones (marcadores de `Decoracion` + extras por tema de zona + faroles junto a los caminos) y `Mundo.colocar_props()` los crea en las dos épocas en las mismas posiciones. No se guardan en la escena. Dejan libres caminos, agua, muros y la zona de 150 px alrededor de cada marcador de zona (donde irán el portal y los bloqueos).

## Arte y forma del mapa (versión orgánica)

- **Tileset:** colores planos con manchas grandes y detalles agrupados (matas de 3 px, racimos de flores, piedritas de 2x2). Autotiles de 47 piezas con esquinas redondeadas: línea de 1 px más oscura donde la hierba se monta sobre camino y arena, y agua con espuma clara y sombra de 2 px por fuera. La variación de la hierba (zonas más claras y más oscuras, con ruido de baja frecuencia) va en las capas `TonoOscuro` y `TonoClaro`; además está `sombra_s`, la sombra que cae bajo muros y acantilados (capa `Sombras`).
- **Capas creadas por código** (sin dueño, no se guardan en la escena): `TonoOscuro` y `TonoClaro` (manchas de hierba como autotiles translúcidos con borde tramado), `Sombras` y `DetallesSuelo` (16x16: matas, flores, piedritas y hojas caídas en el Pasado u hojas secas en el Presente; `Resources/Mundo/detalles_*.tres`) dentro de cada época. `Mundo.reconstruir_todo()` (botón del inspector) rehace mapa, props, detalles y ambiente.
- **Ambiente:** `CanvasModulate` "Atardecer" (cálido en el Pasado, frío en el Presente, con fundido al viajar), luces `Luz_Portal` (hub) y `Luz_Reflejo` (Puerta del Reflejo) en cada época, y una viñeta (`Shaders/vineta.gdshader`, `CanvasLayer` "Vineta", capa 4) que solo existe en el juego. La "Puerta del Reflejo" es `Zona_Final` y el portal es `Spawn_Hub`.
- **Límite del mapa:** acantilados al norte y este, agua al sur y oeste, y por dentro una franja de 2 a 4 casillas `T` (sólidas) con árboles encima (`Decorador`, sin colisión propia).
- **Mesetas** de Soledad y del volcán de Rabia: anillo de acantilado de 2 tiles con sombra, abierto donde pasa el camino.

## Épocas, portales y Guía

- **Viaje:** `Mundo.viajar()` (lo piden los portales con la señal `viaje_pedido`, y F2 en depuración): bloquea al jugador, ondas (`Shaders/transicion_epoca.gdshader`, en un `ColorRect` de la capa 6) con destello, `GameState.cambiar_epoca()` y libera al jugador. La época contraria queda con `visible = false`, `process_mode = DISABLED` y las formas de colisión apagadas (`Mundo._activar_epoca`); la posición del jugador se conserva.
- **Portales** (`Scenes/Objetos/Portal.tscn`, `@export escala` y `es_grieta`): uno principal en `Spawn_Hub` y una grieta (escala 0.5) a unos 110 px de cada zona, hacia el hub. Hay uno en cada época (luz dorada en el Pasado, azul en el Presente). **E** o **Q** (solo dentro de su zona; `Player` busca nodos del grupo `portales`) viajan.
- **Entidades por código:** `Mundo.colocar_entidades()` crea portales, grietas, la Guía y las 7 criaturas (solo en el Pasado, en sus `Zona_*`) sin tocar `Mundo.tscn`.
- **Ambiente:** luciérnagas doradas (Pasado) y ceniza gris (Presente) que siguen al jugador, `CanvasModulate` por época y shader de saturación (`Shaders/saturacion.gdshader`) en el Presente: parámetro `saturacion` = 0.25 + 0.75 * integradas / total, con animación suave al integrar una emoción.
- **Guía** (`Scenes/Personajes/Guia.tscn`): junto al portal del hub en las dos épocas (alpha 0.7 en el Presente). `Dialogos/guia.dialogue` cambia según `GameState.guia_conocida`, `todas_resueltas()` y `cantidad_integradas()`.

## Presente reactivo y Puerta del Reflejo

- **`BloqueoPresente`** (`Scenes/Objetos/BloqueoPresente.tscn`, `@export datos: EmocionData`): uno por zona en el nodo `Presente`, sobre una casilla de camino a ~110 px del centro (entre la grieta, que está más lejos, y el centro). Lee `GameState.estado[id]` al entrar al Presente y al instante si el estado cambia estando en él. `integrada`: se abre una vez (animación `abriendo` si la hoja la tiene, partículas del color de la emoción), apaga su colisión y aparece la forma aliada (`AliadaPresente`, animación `calma`, luz del color, mensaje `mensaje_presente_aliada`). `atacada`: tinte rojizo oscuro, brasas y vibración (`mensaje_presente_atacada`). `ignorada`: escala 1.15, más oscuro y con niebla (`mensaje_presente_ignorada`). `pendiente`: normal (`mensaje_presente_bloqueo`). Los mensajes de bloqueo terminan invitando a volver al Pasado.
- Las zonas NO están cercadas: el bloqueo cierra el camino (barrera de 96 px) pero se puede rodear por la hierba. Para cerrarlas del todo hay que ponerlas en un paso estrecho (por ejemplo la apertura del anillo de las mesetas de Soledad y Rabia) o rodearlas de árboles/rocas.
- `Dialogo.mostrar_texto(personaje, lineas)` muestra líneas de texto sin archivo `.dialogue` (evita ":" en las del narrador y `[ ]`, `{{ }}`).
- **`PuertaReflejo`** (`Scenes/Objetos/PuertaReflejo.tscn`, arte de `tools/generar_puerta_reflejo.py`): en `Zona_Final`, en las dos épocas (espejo agrietado en el Presente). Con alguna emoción pendiente dice que aún falta algo; con todas resueltas muestra `GameState.calcular_final()` como texto simple. **TEMPORAL**: la secuencia final se hace después.
- Las grietas quedan a 170-210 px del centro de su zona y el bloqueo más cerca, para que viajar por una grieta no se salte el bloqueo.

## Cancelar conversaciones

- **Regla de diseño:** cancelar ("Ahora no" o ESC) NO es una decisión del juego. No cambia `GameState.estado`, no cuenta como ignorada, no escribe en el diario ni afecta a los finales. `Dialogo.mostrar()` devuelve `Dialogo.CANCELADO` (-2) y quien lo llama no debe cambiar ningún estado.
- **Balloon:** con opciones visibles aparece "Ahora no" (más pequeña, gris violácea, separada por una línea tenue) y una pulsación de ESC (`PAUSA`) cancela. Durante el texto, mantener ESC 0.7 s sale (hay una pista "Mantén ESC para salir"). Una conversación cancelada a la mitad no aplica ningún cambio porque los `$>` del `.dialogue` aún no se ejecutaron.
- **Despedida:** la criatura (y la forma aliada, el bloqueo y la Guía) dicen una frase breve en un globo pequeño (`GloboCierre`); la frase de cada emoción es `frase_cierre` en su `.tres`.
- **NO cancelables:** el cuestionario de entrada (onboarding) y el de salida. Se abren con `Dialogo.mostrar(recurso, titulo, [self], false)`; ESC no hace nada y `Dialogo.pausa_permitida()` devuelve false mientras duran (el menú de pausa, cuando exista, debe consultarlo).
