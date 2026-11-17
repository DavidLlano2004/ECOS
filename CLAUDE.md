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
- Evaluación: 16 preguntas (7 trivia, 7 situaciones, 2 escala) al inicio ("pre", tras el onboarding) y otra vez al final ("post") para comparar el antes y el después. Ver "Evaluación y final del juego".

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

`IZQUIERDA`, `DERECHA`, `ARRIBA`, `ABAJO`, `INTERACTUAR` (E), `DIARIO` (Tab), `PAUSA` (Esc), `VIAJAR` (Q: alternativa oculta a E junto a un portal; no se anuncia en ningún texto del juego), `HABILIDAD` (Espacio).

## Estructura del proyecto

- `Autoload/`: singletons (`GameState`, `Dialogo`, `Notificacion`, `Habilidades`, `Opciones`, `Guardado`, `Menus`).
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

- **Tileset:** colores planos con manchas grandes y detalles agrupados (matas de 3 px, racimos de flores, piedritas de 2x2). Autotiles de 47 piezas con esquinas redondeadas: línea de 1 px más oscura donde la hierba se monta sobre camino y arena, y agua con espuma clara y sombra de 2 px por fuera. La variación de la hierba (zonas más claras y más oscuras) va en el nodo `Tono` (shader); además está `sombra_s`, la sombra que cae bajo muros y acantilados (capa `Sombras`).
- **Capas creadas por código** (sin dueño, no se guardan en la escena): `Tono` (un `ColorRect` con `Shaders/tono_hierba.gdshader`: manchas de hierba clara y oscura con ruido en el mundo, bordes irregulares y trama ordenada, sin rejilla), `Sombras` y `DetallesSuelo` (16x16: matas, flores, piedritas y hojas caídas en el Pasado u hojas secas en el Presente; `Resources/Mundo/detalles_*.tres`) dentro de cada época. `Mundo.reconstruir_todo()` (botón del inspector) rehace mapa, props, detalles y ambiente.
- **Ambiente:** `CanvasModulate` "Atardecer" (cálido en el Pasado, frío en el Presente, con fundido al viajar), luces `Luz_Portal` (hub) y `Luz_Reflejo` (Puerta del Reflejo) en cada época, y una viñeta (`Shaders/vineta.gdshader`, `CanvasLayer` "Vineta", capa 4) que solo existe en el juego. La "Puerta del Reflejo" es `Zona_Final` y el portal es `Spawn_Hub`.
- **Límite del mapa:** acantilados al norte y este, agua al sur y oeste, y por dentro una franja de 2 a 4 casillas `T` (sólidas) con árboles encima (`Decorador`, sin colisión propia).
- **Mesetas** de Soledad y del volcán de Rabia: anillo de acantilado de 2 tiles con sombra, abierto donde pasa el camino.

## Épocas, portales y Guía

- **Viaje:** `Mundo.viajar()` (lo piden los portales con la señal `viaje_pedido`, y F2 en depuración): bloquea al jugador, ondas (`Shaders/transicion_epoca.gdshader`, en un `ColorRect` de la capa 6) con destello, `GameState.cambiar_epoca()` y libera al jugador. La época contraria queda con `visible = false`, `process_mode = DISABLED` y las formas de colisión apagadas (`Mundo._activar_epoca`); la posición del jugador se conserva.
- **Portales** (`Scenes/Objetos/Portal.tscn`, `@export escala` y `es_grieta`): uno principal en `Spawn_Hub` y una grieta (escala 0.5) a unos 110 px de cada zona, hacia el hub. Hay uno en cada época (luz dorada en el Pasado, azul en el Presente). Se viaja con **E** junto al portal o la grieta (la burbuja muestra "E"). Q (`VIAJAR`) sigue funcionando como alternativa oculta, solo dentro de su zona (`Player` busca nodos del grupo `portales`); ningún texto la menciona.
- **Entidades por código:** `Mundo.colocar_entidades()` crea portales, grietas, la Guía y las 7 criaturas (solo en el Pasado, en sus `Zona_*`) sin tocar `Mundo.tscn`.
- **Ambiente:** luciérnagas doradas (Pasado) y ceniza gris (Presente) que siguen al jugador, `CanvasModulate` por época y shader de saturación (`Shaders/saturacion.gdshader`) en el Presente: parámetro `saturacion` = 0.25 + 0.75 * integradas / total, con animación suave al integrar una emoción.
- **Guía** (`Scenes/Personajes/Guia.tscn`): junto al portal del hub en las dos épocas (alpha 0.7 en el Presente). `Dialogos/guia.dialogue` cambia según `GameState.guia_conocida`, `todas_resueltas()` y `cantidad_integradas()`.

## Presente reactivo y Puerta del Reflejo

- **`BloqueoPresente`** (`Scenes/Objetos/BloqueoPresente.tscn`, `@export datos: EmocionData`): uno por zona en el nodo `Presente`, sobre una casilla de camino a ~110 px del centro (entre la grieta, que está más lejos, y el centro). Lee `GameState.estado[id]` al entrar al Presente y al instante si el estado cambia estando en él. `integrada`: se abre una vez (animación `abriendo` si la hoja la tiene, partículas del color de la emoción), apaga su colisión y aparece la forma aliada (`AliadaPresente`, animación `calma`, luz del color, mensaje `mensaje_presente_aliada`). `atacada`: tinte rojizo oscuro, brasas y vibración (`mensaje_presente_atacada`). `ignorada`: escala 1.15, más oscuro y con niebla (`mensaje_presente_ignorada`). `pendiente`: normal (`mensaje_presente_bloqueo`). Los mensajes de bloqueo terminan invitando a volver al Pasado.
- Las zonas NO están cercadas: el bloqueo cierra el camino (barrera de 96 px) pero se puede rodear por la hierba. Para cerrarlas del todo hay que ponerlas en un paso estrecho (por ejemplo la apertura del anillo de las mesetas de Soledad y Rabia) o rodearlas de árboles/rocas.
- **UN SOLO texto para todo:** todo mensaje con efecto de escritura sale con el mismo balloon (`Scenes/UI/DialogoBalloon.tscn`): misma velocidad (`Dialogo.SEGUNDOS_POR_LETRA`, una sola constante), mismo blip por letra, misma etiqueta de nombre y mismo aviso "Mantén ESC para salir". Los `.dialogue` van con `Dialogo.mostrar(recurso, titulo, [estados])` y todo lo demás con `Dialogo.mostrar_texto(nombre, texto, opciones = [], retrato = null, automatico = false)`: `texto` es un String o una lista de páginas; `opciones` añade botones y devuelve el índice elegido (0, 1...) o -1 si no se eligió nada o se canceló (después de esperar, `Dialogo.cancelada` dice si fue por cancelar); `automatico` hace que el texto se cierre solo tras leerse (despedidas y pistas); `[ ]`, `{{ }}` y los saltos de línea se limpian solos. **Nombre en la etiqueta:** el de la emoción para su diálogo y su aliada, `EmocionData.nombre_bloqueo` para los bloqueos del Presente ("La oscuridad", "La tormenta", "La roca de lava", "Las puertas cerradas", "El puente roto", "El reloj sin parar", "Los espejos tapados"), "Guía" para el Guía, "Recuerdo" para los fragmentos y "Puerta del Reflejo" para la puerta. En los `.dialogue` los mensajes `{{...mensaje_fallo}}` y `{{...mensaje_integracion}}` llevan también el nombre de la emoción. **Excepciones permitidas:** las tarjetas de `Notificacion`, los avisos del HUD y el cuestionario (que usa el mismo balloon, con su pantalla propia). `Dialogo.preguntar` y el globito `GloboCierre` ya no existen.
- **`PuertaReflejo`** (`Scenes/Objetos/PuertaReflejo.tscn`, arte de `tools/generar_puerta_reflejo.py`): en `Zona_Final`, en las dos épocas (espejo agrietado en el Presente). Con alguna emoción pendiente dice que aún falta algo; con todas resueltas muestra `GameState.calcular_final()` como texto simple. **TEMPORAL**: la secuencia final se hace después.
- Las grietas quedan a 170-210 px del centro de su zona y el bloqueo más cerca, para que viajar por una grieta no se salte el bloqueo.

## Cancelar conversaciones

- **Regla de diseño:** cancelar ("Ahora no" o ESC) NO es una decisión del juego. No cambia `GameState.estado`, no cuenta como ignorada, no escribe en el diario ni afecta a los finales. `Dialogo.mostrar()` devuelve `Dialogo.CANCELADO` (-2) y quien lo llama no debe cambiar ningún estado.
- **Balloon:** con opciones visibles aparece "Ahora no" (más pequeña, gris violácea, separada por una línea tenue) y una pulsación de ESC (`PAUSA`) cancela. Durante el texto, mantener ESC 0.7 s sale (hay una pista "Mantén ESC para salir"). Una conversación cancelada a la mitad no aplica ningún cambio porque los `$>` del `.dialogue` aún no se ejecutaron.
- **Despedida:** la criatura (y la forma aliada, el bloqueo y la Guía) dicen una frase breve con el mismo balloon, que se cierra solo (`Dialogo.despedida(nombre, frase)`); la frase de cada emoción es `frase_cierre` en su `.tres`. Las pistas breves ("No hay nada que reparar aquí.", "Mejor no pisar el vacío.") usan también `Dialogo.mostrar_texto(..., automatico = true)`.
- **NO cancelables:** el cuestionario de entrada (onboarding) y el de salida. Se abren con `Dialogo.mostrar(recurso, titulo, [self], false)`; ESC no hace nada y `Dialogo.pausa_permitida()` devuelve false mientras duran (el menú de pausa, cuando exista, debe consultarlo).

## Reglas de jugabilidad (correcciones)

- **Orden de dibujo:** solo el nodo `Objetos` de cada época tiene `y_sort_enabled`. Ninguna entidad (Player, Emocion, Prop, Portal, Guía, bloqueos, puerta) lo activa en su raíz: si lo hicieran, sus hijos (por ejemplo el sprite del jugador, 29 px sobre sus pies) se ordenarían por su cuenta y los árboles taparían al jugador estando delante. `Pasado` y `Presente` tampoco lo activan. Cada entidad tiene su origen en la base (los pies) y `z_index` 0.
- **Proporciones:** el jugador mide unos 56 px. `Prop` tiene `@export escala` (0 = la del tipo, en `DATOS`): arbol_dorado 1.3, cerezo 1.2, arbol_redondo 1.1, farol_poste 1.1, arbusto 0.55, roca 0.5, tocon 0.45, banco 0.5, con ±8 % por instancia (según la posición, igual en las dos épocas). Escala también la colisión y las luces.
- **Agua:** todo `w` es sólido (colisión en toda celda de agua, orilla y estanques incluidos). Solo se pisan los tramos de puente `P`, `q` y `Q`. En Culpa, el antiguo vado es ahora un paso de tierra (`c`) que cruza el río.
- **Muros `M`:** solo en tramos de 3 casillas o más (ruinas de Culpa, arcos en el borde de la plaza del hub y a los lados de la plataforma de la Puerta del Reflejo). `generar_mapa.py` borra los muros aislados.
- **Emoción integrada:** sigue viva. En el Pasado deambula despacio con la animación `calma` dentro de su `radio_zona`, se acerca un poco si el jugador se queda cerca y nunca lo empuja. En el Presente la aliada deambula a menos de 100 px de su bloqueo, sin atravesar muros ni pegarse al jugador o a un portal.
- **Seguir hablando = consejos:** una integrada siempre puede interactuar. En el Pasado, o en su forma aliada del Presente (la primera vez dice su `mensaje_presente_aliada`), `Consejos.charlar(datos)` le dice una frase de consejo y ofrece "Otro consejo" y "Gracias"; cancelar (ESC o "Ahora no") también cierra, con la despedida. Las 12 frases por emoción (84 en total) están en `Resources/Consejos/<id>.json` (lista `frases`, editables sin tocar código; las escribe `tools/generar_consejos.py` y `tools/generar_revision_consejos.py` crea `docs/consejos_para_revision.md`). Se elige al azar sin repetir los últimos 4 de esa emoción y `GameState.consejos_vistos` (id -> índices, se guarda) anota cuáles vio el jugador para que el diario las pueda listar. No concede nada ni repite el efecto de integración. El diálogo de decisión (`start`) solo se abre con pendientes, atacadas o ignoradas.

## Habilidades

- **Sistema** (4.1): autoload `Habilidades` (catálogo desde los `EmocionData`, selección, cooldowns, `factor_tiempo`), `HabilidadBase` + una subclase por habilidad en `Scripts/Habilidades/`, HUD en `Scenes/UI/HUD.tscn` (capa 5). Teclas: ESPACIO usa, 1-7 y rueda eligen, R/F anterior y siguiente. `HabilidadBase.ejecutar(player)` devuelve `bool`: `false` = no se usó (sin cooldown ni señal `habilidad_usada`). Regla de diseño: ninguna habilidad hace daño. **Esto REEMPLAZA la regla antigua de "el camino principal nunca exige una habilidad"**: ahora solo TRES zonas (Rabia, Vergüenza y Ansiedad) lo exigen, mediante compuertas (ver "Compuertas de habilidad"); además abren acertijos opcionales.
- **Impulso** (Rabia): dash de 140 px en 0.18 s en la dirección `facing`, cooldown 0.8 s. Lo mueve `Player.iniciar_impulso()` con `move_and_collide` (no atraviesa muros, agua ni objetos sólidos; contra una pared de frente se detiene y en diagonal desliza). Estela de fantasmas, polvo y temblor de cámara (`EfectosHabilidades`). No afecta a las emociones.
- **Calma** (Tristeza): anillo azul que se expande hasta 90 px en 0.6 s (`EfectoCalma`, dibujado con `_draw`), cooldown 3 s. Cada nodo "calmable" del radio recibe `calmar()` cuando el anillo lo alcanza. `Emocion.calmar()`: si está atacada o ignorada, recupera su velocidad normal 8 s y deja de huir (tinte azul mientras dura); en otro estado no hace nada.
- **Reparar** (Culpa): mantener ESPACIO 1.2 s a menos de 48 px de un nodo "reparable" (`EfectoReparar`: anillo dorado en el suelo, cinta en espiral y partículas). Al completarse llama a `reparar()`. Soltar antes, alejarse más de 56 px o cambiar de habilidad cancela sin penalización. Sin nada cerca muestra "No hay nada que reparar aquí" y no gasta nada. Sin cooldown propio.

### Grupos e interfaces (los objetos del mundo los implementan; los usará el prompt 4.4)

| Grupo | Método | Quién lo llama | Notas |
|-------|--------|----------------|-------|
| `rompible` | `romper()` | Impulso, al tocarlo durante el dash | Debe ser un cuerpo sólido (capa 1 `mundo`) o tener un hijo sólido; el jugador lo atraviesa tras romperlo. Debe quitarse o desactivar su colisión al romperse. |
| `calmable` | `calmar()` | Calma, al llegar el anillo (radio 90 px) | `Emocion` ya está en este grupo. El nodo debe ser `Node2D`. |
| `reparable` | `reparar()` | Reparar, al completar 1.2 s | El nodo debe ser `Node2D`. Propiedad opcional `radio_reparar` (px) para el tamaño del anillo. Al repararse debe salir del grupo. |
| `sombra` | `visionar(activa: bool)` | Visión, para las zonas cercanas (`ALCANCE_SOMBRA` 140 px + su `radio_sombra`) | Con `true`: la niebla se disipa y la colisión se apaga. Con `false`: vuelven. **Opcional pero necesario para la salida suave:** `contiene_punto(punto, margen := 0.0) -> bool`; con él, si el jugador apaga la Visión dentro de la zona, la zona no se cierra hasta que lo empuja con suavidad al punto libre más cercano (sin atravesar muros). Propiedad opcional `radio_sombra` (px extra de alcance). |
| `tiempo` | *(ninguno)* usa `Habilidades.factor_tiempo` | Pausa (pone el factor en 0.25 durante 5 s y vuelve a 1.0 con transición suave) | Mecanismos, plataformas, engranajes: `delta * Habilidades.factor_tiempo`. Las `CPUParticles2D`/`GPUParticles2D` del grupo reciben el factor en `speed_scale` solas (las partículas de ambiente de `Mundo` ya están en el grupo). `Emocion` ya lo aplica a su movimiento. El jugador no se ve afectado. Señal `Habilidades.factor_tiempo_cambiado(factor)`. **Nunca** `Engine.time_scale`. |
| `oculto` | `revelar(segundos: float)` | Revelar, cuando la onda (220 px, 0.8 s) alcanza el nodo | El nodo se hace visible y funcional con un destello dorado y pasados los segundos (6.0) se desvanece, salvo que tenga `permanente = true` (lo gestiona el propio nodo). Debe ser `Node2D`. |
| `placa_doble` | *(ninguno)*: la placa detecta | Ella misma, cada fotograma | Detecta al jugador (grupo `player`) y al compañero (grupo `companero`) a menos de su `radio`. Es el punto donde Vínculo posa al compañero (el jugador debe estar a menos de 60 px de la placa). Debe ser `Node2D`. |

- **Visión** (Miedo): ESPACIO alterna (cooldown 0.5 s). `EfectoVision` cuelga del jugador: `PointLight2D` de ~120 px con textura radial de `Atmosfera.crear_textura_luz`, tinte violeta (`Shaders/vision.gdshader` en un `CanvasLayer` capa 2) y manejo de las zonas "sombra".
- **Pausa** (Ansiedad): 5 s de efecto, cooldown de 10 s contados desde que se usa. `EfectoPausa` (capa 3): desaturación azulada y viñeta cerrada (`Shaders/pausa.gdshader`) y un reloj tenue en el borde derecho. Las pausas de comportamiento de las emociones (`Temporizador`) siguen en tiempo real; solo se ralentiza su movimiento.
- **Revelar** (Vergüenza): `EfectoRevelar` (onda dorada tipo espejo con reflejos, dibujada con `_draw`), cooldown 12 s. Además lanza `EfectoDestello` sobre lo interactuable visible a menos de 220 px (nodos con `interactuar()`, máximo 12).
- **Vínculo** (Soledad): ESPACIO invoca la luciérnaga (`Scenes/Personajes/Companero.tscn`, dibujada por código, con `PointLight2D` y partículas); cerca de una placa la envía a posarse; lejos de la placa (o a más de 300 px, o al cambiar de época) vuelve con el jugador; sin placa cerca y siguiéndolo, la despide. Cooldown 1 s. **No tiene cuerpo físico** (no estorba a nadie) y vive en el mismo nodo que el jugador, así que viaja entre épocas; está en el grupo `companero`.
- **HUD:** una casilla con un efecto en marcha (Visión encendida, Pausa, compañero invocado) muestra un halo que late (`HabilidadBase.activa`, `Habilidades.esta_activa(id)`). `HabilidadBase.reiniciar()` apaga todo al empezar una nueva partida.
- **Arena de pruebas:** `Scenes/Mundo/PruebaHabilidades.tscn` (F6, no es la principal, 1200x520). A la izquierda: muro, roca rompible, planta seca, objeto roto, Rabia y Miedo, dos placas dobles y una reja que se abre con las dos ocupadas. A la derecha (por la puerta del muro grande): una zona de sombra tapando la puerta (Visión), un abismo con una plataforma que va de lado a lado (solo se cruza con Pausa) y un puente oculto sobre un segundo abismo (Revelar). El abismo no hace daño: si pisas el vacío sin apoyo vuelves al último punto seguro. En depuración: **U** desbloquea las 7 habilidades (sin tocar las emociones), **I** pone a Rabia como atacada y a Miedo como ignorada, **O** reinicia los objetos. (Se evitan F5 a F10: son atajos del editor y pausan o detienen el juego.)

## Arte de los acertijos de habilidad y de los íconos

- **Íconos del HUD:** `Assets/UI/iconos_habilidades.png` (128x64, cuadros de 32x32, 4 columnas x 2 filas; orden: impulso, vision, calma, vinculo, reparacion, pausa, revelar, candado). `CasillaHabilidad` los usa solos si existen (si no, dibuja marcadores por código).
- **Hojas de objetos:** `Assets/Mundo/objetos_habilidad_a.png` y `_b.png` (512x256, cuadros de 128x128, 4 columnas x 2 filas; fila 1 = estado inicial, fila 2 = resuelto). Columnas: hoja A = `roca_rompible`, `planta_marchita`, `placa_doble`, `porton_roto`; hoja B = `plataforma_movil`, `camino_oculto`, `niebla_sombra`, `fragmento`.
- **Importación:** las tres imágenes van sin compresión con pérdida (`compress/mode=0`, lossless), sin mipmaps, y se dibujan con filtro Nearest (es el filtro por defecto del proyecto, `default_texture_filter=0`; los nodos que las usan lo repiten explícito).
- **SpriteFrames:** `tools/generar_frames_objetos.py` escribe `Resources/Mundo/frames_objeto_<nombre>.tres` (uno por objeto) con dos animaciones de un cuadro: `inicial` y `resuelto`.
- **Escalas iniciales** (el jugador mide 56 px; cada cuadro es de 128 px) y el sitio de apoyo en el cuadro (px, para poner el origen del nodo):

| objeto | escala | tamaño útil en el juego | origen del nodo |
|--------|--------|-------------------------|-----------------|
| roca_rompible | 0.41 | ~39x37 px | base de la roca (y=118 del cuadro) |
| planta_marchita | 0.38 | ~43x43 px | base (y=126) |
| placa_doble | 0.42 | ~40x32 px, plana | borde de arriba de la placa (y=42) |
| porton_roto | 0.5 | ~56x54 px | base (y=120) |
| plataforma_movil | 1.15 | disco de ~94 px de ancho; **la niebla del abismo va dentro del sprite**, debajo del disco | borde de arriba del disco (y=35) |
| camino_oculto | 0.8 | ~96x53 px, plano; el estado `inicial` ya es semitransparente | borde de arriba (y=60) |
| niebla_sombra | 0.92 | ~109x93 px; el estado `resuelto` son solo jirones lila (se le añade una `PointLight2D` cálida para el brillo) | base (y=126) |
| fragmento | 0.5 | ~12x16 px | base (y=122) |

- **Orden de dibujo:** los objetos de pie (roca, planta, portón, niebla, fragmento) tienen el origen en la base. Los planos o sobre los que se camina (placa, plataforma, camino) lo tienen en su borde de arriba, para que el jugador (cuyo origen son los pies) siempre se dibuje por encima.
- **Colisión de la plataforma:** solo en el disco de arriba, no en el abismo.

## Acertijos de habilidad y fragmentos de memoria (solo en el Presente)

- **Idea:** cada habilidad abre un acertijo OPCIONAL que custodia un fragmento de memoria. Los acertijos nunca bloquean el camino principal ni las compuertas (que son otra cosa, ver más abajo): sin habilidades se llega a todo lo que las compuertas permitan, menos a los 7 fragmentos.
- **Dónde:** `tools/generar_mapa.py` (fase 11, módulo `tools/acertijos_mapa.py`) excava 7 recintos cerrados (muro de acantilado `C` de 2 tiles) en sitios libres, cada uno en la zona más cercana que NO sea la de la emoción que da su habilidad, con UNA sola entrada tapada por el acertijo y una rama lateral de camino hasta un camino principal. Escribe `Resources/Mundo/acertijos.json` (objetos, abismos, fragmento y zona reservada de cada uno). `Mundo.colocar_acertijos()` los crea solo en `Presente/Objetos` (los abismos, como capa entre el suelo y los objetos) y `Decorador.reservadas` deja libres los recintos. En el Pasado los recintos existen pero están vacíos. La receta del mapa no cambia: `python tools/generar_mapa.py` (ahora también escribe `acertijos.json`) y regenerar las vistas previas.
- **Objetos** (`Scenes/Objetos/`, con su sprite de `Resources/Mundo/frames_objeto_*.tres` y las escalas de la sección de arte):

| Escena | Grupo / interfaz | Cómo funciona |
|--------|------------------|---------------|
| `RocaRompible` | `rompible` → `romper()` | Tapa un nicho (sólida). El Impulso la rompe y deja de bloquear. |
| `PlantaMarchita` | `calmable` → `calmar()` | Tres juntas tapan la entrada de un jardín. Al calmarlas florecen, dejan una luz rosada y dejan de bloquear. |
| `PlacaDoble` + `PuertaPlacas` | `placa_doble`; la puerta se une a sus placas por `id_mecanismo` | La puerta exige TODAS sus placas ocupadas a la vez (una el jugador y otra el compañero) y se queda abierta. La puerta es arte temporal (dibujada por código). |
| `PortonRoto` | `reparable` → `reparar()` | Cierra un recinto. Reparado se ve entero con su lazo dorado, se abre y deja de bloquear. |
| `PlataformaMovil` + `Abismo` | `tiempo` y `soporte` | Va de lado a lado sobre un abismo que no se cruza a pie. A velocidad normal (150 px/s) NO deja subirse (límite `VELOCIDAD_ABORDAJE` 90 px/s); con Pausa (x0.25) sí, y una vez a bordo te lleva aunque la Pausa termine. El abismo es una regla (sin apoyo vuelves al último punto seguro, sin daño), dibujado por código (arte temporal). |
| `CaminoOculto` | `oculto` → `revelar(segundos)` y `soporte` | Puente sobre una ravina. Fantasma y no pisable hasta que Revelar lo activa; mientras dura (6 s) se ve sólido y se pisa. |
| `NieblaSombra` | `sombra` → `visionar(activa)` | Llena la entrada de una cueva. La Visión la disipa (quedan jirones lila y una luz cálida) y deja de bloquear; con `permanente = true` (lo normal) ya no vuelve, así nadie queda encerrado. |
| `FragmentoMemoria` | grupo `fragmentos` | Se recoge con INTERACTUAR o tocándolo: destello, `GameState.recoger_fragmento(id)` y el recuerdo en un globo de diálogo. |

- **Interfaz `soporte`:** un nodo con `sostiene(punto_global) -> bool`; los `Abismo` no dejan pisar su zona sin un soporte que lo diga.
- **Sin quedar atrapado:** todo bloqueo se abre para siempre (roca, plantas, portón, niebla, puerta de placas). Las dos únicas excepciones son temporales y se recuperan: el puente (se vuelve a revelar tras los 12 s de cooldown) y la plataforma (se vuelve a usar Pausa tras su cooldown de 10 s); ambas cruzan siempre con la habilidad, que nunca se pierde.
- **Colisiones y épocas:** un objeto que apaga su colisión debe usar `Colisiones.apagar(forma, apagada)`; así `Mundo` no la vuelve a encender al viajar y volver. Las habilidades solo actúan sobre nodos visibles (`is_visible_in_tree()`), para no tocar objetos de la época oculta.
- **Datos de los fragmentos:** `GameState.fragmentos` (ids de emoción, se guardan y se cargan), `GameState.recuerdos_completos` (true con los 7; se usará en el final), señal `GameState.fragmento_recogido(id)`. Cada recogida escribe una entrada `recuerdo_<id>` en el diario. Los 7 recuerdos (título y páginas del globo; 2 o 3 frases, primera persona, sin `:` ni `[ ]`) están en `Resources/Recuerdos.tres` (`ColeccionRecuerdos` y `RecuerdoData`), editables sin tocar código.
- **Dónde quedó cada uno** (puede cambiar si cambia el mapa): rabia/Impulso en la zona de Vergüenza, miedo/Visión en Vergüenza, tristeza/Calma en Ansiedad, soledad/Vínculo en Miedo, culpa/Reparar en Soledad, ansiedad/Pausa en Rabia, vergüenza/Revelar en Tristeza.

## Diario, menú de pausa, opciones y guardado

- **`Menus`** (autoload) es el dueño del diario y de la pausa: los instancia, decide cuándo se pueden abrir y mantiene `get_tree().paused` mientras haya alguno abierto (con una red de seguridad en `_process` para que el juego nunca se quede congelado). **Reglas:** ninguno se abre durante un diálogo (incluidos el onboarding y los cuestionarios), sin jugador en escena (título, onboarding) ni durante una transición de época (`Habilidades.bloqueado_por("transicion")`). **ESC:** la cancelación de conversaciones tiene prioridad (el balloon se la queda y mientras hay diálogo la pausa no se abre); con el diario abierto ESC lo cierra; dentro de la pausa retrocede de pantalla o reanuda. Todo el control de TAB y ESC está en `Menus._input` (así los botones con foco no se comen el TAB).
- **Diario** (`Scenes/UI/Diario.tscn`, capa 8, `Scripts/UI/Diario.gd`): libro morado y dorado con fundido de entrada. Se abre con TAB; izquierda y derecha (o A y D, o las pestañas y flechas con el ratón) cambian de sección. Secciones: **Emociones** (7 tarjetas en el orden de `EmocionData.orden`, con sprite animado, sello de estado de color, habilidad y, si está integrada, su mensaje), **Habilidades** (ícono, descripción y tecla; las bloqueadas, `???`), **Recuerdos** (lista y texto; arriba y abajo eligen; los no encontrados dicen "Un recuerdo aún sin encontrar") y **Progreso** (integradas X/7, recuerdos Y/7, consejos vistos X/84 y en qué época estás). Con el juego en pausa mientras está abierto. Los botones del diario no toman el foco del teclado (TAB debe llegar a `Menus`).
- **Pausa** (`Scenes/UI/Pausa.tscn`, capa 9, `Scripts/UI/MenuPausa.gd`, `process_mode` siempre): fondo desenfocado y oscuro (`Shaders/pausa_menu.gdshader`) y panel con Continuar, Diario, Controles, Opciones, Guardar partida y Volver al título (con confirmación; el foco empieza en "No"; guarda antes de salir). Navegable con flechas o W y S, ENTER y ratón, con el foco dorado. "Guardar partida" está desactivado fuera de `Mundo.tscn` (las arenas de prueba no tocan la partida real).
- **Estilo común:** `Scripts/UI/EstiloUI.gd` (cajas, etiquetas y un `Theme` con botones, deslizadores y casilla en morado y dorado).
- **Opciones** (`Autoload/Opciones.gd`, `user://ecos_opciones.cfg`, aparte de la partida): crea los buses `Musica` y `Efectos` si no existen (salen por `Master`), volumen de cada uno (0 = silencio) y pantalla completa. Quien reproduzca música debe poner su `AudioStreamPlayer` en el bus `Musica`, y los sonidos en `Efectos` (el título ya lo hace).
- **Guardado** (`Autoload/Guardado.gd` + `GameState.guardar()`/`cargar()`): autoguarda al cambiar el estado de una emoción, al recoger un fragmento y al viajar de época, con un ícono de "Guardado" 1.5 s abajo a la derecha (capa 11). Solo guarda dentro de `Mundo.tscn` (`Guardado.puede_guardar()`). Guarda también la posición del jugador: `GameState.posicion_jugador`; al cargar, `GameState.restaurar_posicion` hace que `Mundo` lo coloque ahí (una sola vez). La escritura es segura (archivo `.tmp` y renombrado). `GameState.diagnosticar_partida()` devuelve `"falta"`, `"danada"` u `"ok"`; `cargar()` valida el tipo de cada dato y nunca rompe con un archivo dañado: en el título, "Continuar" con una partida dañada o ausente avisa con una notificación, oculta el botón y deja el foco en Comenzar (partida nueva).

## Compuertas de habilidad y progresión (prompt 4.5)

- **Regla:** tres zonas están cercadas y su único hueco lo tapa una compuerta que solo abre una habilidad. Tristeza, Soledad, Miedo, Culpa, el hub y la **Puerta del Reflejo** están SIEMPRE abiertos. El juego le dice siempre al jugador qué emoción y qué habilidad necesita.
- **Grafo de dependencias (sin ciclos; la emoción que da la habilidad siempre está en una zona libre o detrás de una compuerta que abre una habilidad anterior):**
  `Culpa (libre) --Reparar--> puente roto --> Rabia --Impulso--> roca enorme --> Vergüenza` y `Miedo (libre) --Visión--> zarzal oscuro --> Ansiedad`.
  Si se añade otra compuerta hay que mantener esto (el generador lo comprueba: "el grafo se resuelve sin ciclos").
- **`Compuerta`** (`Scenes/Objetos/Compuerta.tscn` + `Scripts/Objetos/Compuerta.gd`, `@export id`, `habilidad_requerida`, `tipo`: puente, roca o zarzal): `Mundo.colocar_compuertas()` la crea en el Pasado Y en el Presente, en la misma posición, desde `Resources/Mundo/compuertas.json` (lo escribe `tools/generar_mapa.py`; no se guarda en `Mundo.tscn`). Su estado es UNO SOLO: `GameState.compuertas` (id -> abierta; se guarda, se carga y se limpia en `nueva_partida`) con la señal `GameState.compuerta_abierta(id)`; las dos instancias reaccionan a la señal. Colisión por casilla (32 px); al abrirse el puente solo libera las casillas del camino (los lados del barranco siguen bloqueando); roca y zarzal se abren del todo. El barranco y el puente van en `RavinaCompuerta` (a ras de suelo, entre el suelo y `Objetos`; barranco dibujado por código = ARTE TEMPORAL; el puente reutiliza `frames_bloqueo_culpa.tres`, girado si cruza de lado a lado). La roca y el zarzal reutilizan `frames_objeto_roca_rompible` y `frames_objeto_niebla_sombra`, ampliados.
- **Detección:** cada compuerta tiene un `Area2D` (capa 2) que cubre todas sus casillas + 24 px. Reparar, Impulso y Visión usan `Compuerta.solapa_area(punto)` (no la distancia al origen). Mientras está cerrada pertenece al grupo `reparable` (puente), `rompible` (roca) o `sombra` (zarzal). *Diagnóstico del fallo antiguo:* el puente de Culpa eran solo tiles `P q w Q` (sin nodo ni grupo) y Reparar medía 48 px hasta el origen del nodo.
- **Cercado en el mapa** (`tools/compuertas_mapa.py`): banda elíptica de 3 casillas de muro (`C` Rabia, `R` Vergüenza, `T` Ansiedad) alrededor de la zona; el hueco es el camino que la cruza (+1 casilla). El generador comprueba, con la caja real del jugador (14x8) cada 8 px y simulando cada conjunto de compuertas abiertas, que: sin habilidades se llega a Hub, Final, Tristeza, Soledad, Miedo y Culpa y NO a Rabia, Vergüenza ni Ansiedad; cada compuerta abre solo su zona; ninguna combinación encierra al jugador (siempre vuelve al hub). Las mismas comprobaciones se hicieron con la física real de Godot. Regenera las vistas previas cuando cambies esto.
- **Datos y textos** (editables sin tocar código): `Resources/Progresion.json` (dirección de cada zona, y por compuerta: id, habilidad, emoción que la da, zona destino, tres pistas sin la habilidad, pista con ella, aviso, texto de la Guía y mensaje al abrirse). Lógica en `Scripts/Sistemas/Progresion.gd` (estática).
- **Pistas:** (a) ícono flotante sobre la compuerta cerrada (ícono de la habilidad en un medallón del color de la emoción; a color si tienes la habilidad, en silueta si no; con ella se selecciona sola al acercarte). (b) INTERACTUAR da una pista por `Dialogo.mostrar_texto` con el nombre del obstáculo ("El puente roto"...), que escala: 1 insinúa, 2 nombra la emoción, 3 dice dónde está; con la habilidad dice cómo usarla. (c) `AyudaPistas` (creada por `Mundo`): aviso discreto tras 25 s a menos de 80 px de una compuerta cerrada sin la habilidad, como mucho cada 2 min; se apaga en Opciones ("Avisos de pistas", `Opciones.avisos_pistas`). (d) La Guía ofrece "¿Qué hago ahora?" (`GameState.texto_siguiente_paso()`; prioridad: 1 emociones libres sin integrar, 2 abrir una compuerta con la habilidad ya conseguida, 3 zonas nuevas abiertas, 4 la Puerta del Reflejo) y en su primera charla avisa de que hay caminos cerrados. (e) Diario: secciones "Conexiones" (tarjetas y flechas; "???" hasta ver la compuerta, con visto si está abierta) y "Pistas". (f) Brújula: tecla **G** (acción `BRUJULA`, solo con el HUD visible) dibuja 4 s una flecha del color de la emoción hacia lo que sugirió la Guía; está en Controles.
- **Estado guardado extra:** `GameState.compuertas_vistas`, `pistas` (id, titulo, texto) y `pista_niveles`.

## Santuarios, cofres de memoria y mejoras de habilidad (prompt 4.6)

- **Santuario** (uno por emoción, en el Presente): un claro de ~3 casillas de radio en el centro de la zona, rodeado por un anillo de acantilado (`C`) de 2 casillas con UN solo acceso, el del camino de la zona. `tools/santuarios_mapa.py` lo levanta (antes de las compuertas y los acertijos) y escribe `Resources/Mundo/santuarios.json` (centro, abertura, dirección y casillas del acceso). El bloqueo del Presente se coloca en esa abertura y **sella sus casillas con colisión** mientras la emoción no esté integrada (`BloqueoPresente.celdas_sello`), así el santuario no se alcanza ni rodeando la barrera. En el Pasado el acceso está libre (ahí vive la criatura). El generador y la física real de Godot lo comprueban (cada 8 px, forma real del jugador). Para que quepa todo, `acertijos_mapa.py` amplía su rango de búsqueda si hace falta y coloca primero a Culpa y Soledad (`ORDEN_PRIMERO`). Las grietas ahora están a 190-250 px del centro (fuera del anillo).
- **Decorado** (`Mundo.colocar_santuarios()`, solo en `Presente`): `SantuarioSuelo` (flores y un halo del color de la emoción, a ras de suelo entre el suelo y `Objetos`) y `Santuario` (altar de piedra con colisión, 4 farolitos con `PointLight2D` del color de la emoción y el cofre; arte temporal dibujado por código). La forma aliada flota sobre el altar (`AliadaPresente.centro_fijo`, radio de paseo 16 px) y está en el grupo `aliadas_presente`.
- **Cofre** (`Scenes/Objetos/CofreMemoria.tscn`, `@export emocion_id`, sprite `Assets/Mundo/cofre.png` 384x192 en cuadros de 96, `frames_cofre.tres`): solo se abre con la emoción integrada (bloqueo abierto) y UNA sola vez (`GameState.abrir_cofre(id)` devuelve false si no). Al abrirse: destello del color de la emoción y luz dorada, dos avisos de `Notificacion` (mejora y regalo) y la forma aliada dice su `frase_agradecimiento` por el balloon (`AliadaPresente.agradecer()`).
- **Estado:** `GameState.cofres` (id -> true), `GameState.regalos` (ids), `GameState.regalos_completos` (true con los 7; el final añade una línea sobre los 7 regalos en `PuertaReflejo`), señal `GameState.cofre_abierto(id)`. Se guardan, se cargan y se limpian en `nueva_partida`. Los datos de cada emoción (`mejora_descripcion`, `regalo_nombre`, `regalo_texto`, `frase_agradecimiento`) están en su `.tres`.
- **Mejoras (nivel 2):** `Habilidades.nivel[id]` / `Habilidades.nivel_de(id)` (se recalcula con `recalcular_niveles()` al abrir un cofre, al cargar y al reiniciar; señal `nivel_cambiado`). Impulso 140 -> 200 px (y rompe también `rompible` con `nivel_requerido` 2: el mecanismo existe en `Player._puede_romper`, pero la roca de la compuerta de Vergüenza NO lo pide, porque el camino debe poder abrirse con el nivel 1); Visión luz 120 -> 180 px; Calma 90 -> 140 px y calma de 8 -> 12 s; Vínculo 300 -> 500 px de la placa y brilla más; Reparar 1.2 -> 0.6 s; Pausa 5 -> 8 s y espera 10 -> 7 s (`HabilidadBase.aplicar_nivel`); Revelar 220 -> 320 px y 6 -> 10 s. HUD: estrella pequeña en la casilla mejorada. Diario: la sección Habilidades muestra el nivel y la descripción de la mejora, y hay una sección nueva "Regalos" (7 tarjetas, "???" hasta tenerlos).

## Evaluación y final del juego (prompts 5.1 y 5.2)

- **Banco de preguntas:** `Resources/Cuestionario/preguntas.json` (editable sin tocar código): bloques `trivia` (7, una por emoción, con `explicacion`), `situaciones` (7) y `escala` (2, de 1 a 5). En el archivo la opción `correcta` (o más sana) es siempre la 0; en pantalla las opciones se barajan. Se quitaron las 7 preguntas antiguas de `Dialogos/onboarding.dialogue` (de 3 opciones, sin respuesta correcta) y de `GameState.respuestas_inicio`/`respuestas_final`: ahora todo vive en `Evaluacion`.
- **`Evaluacion`** (autoload, `Autoload/Evaluacion.gd`): carga y valida el banco (`valido`, `errores`); `participante_id` (6 caracteres aleatorios, sin datos personales), `consentimiento_guardar`, `pre`/`post` (respuestas por id con el índice ORIGINAL elegido, puntajes `trivia` 0-7, `situaciones` 0-7, `total` 0-14, `escala` 2-10, marca de tiempo), `momento_inicio_juego` (para la duración). Funciones: `iniciar_fase`, `orden_para(fase)` (7 trivia + 7 situaciones + 2 escala; barajado con una semilla por participante y fase), `registrar`, `calcular`, `comparar()` (diferencias por bloque y por emoción) y `a_diccionario()`/`desde_diccionario()` (van dentro del guardado de `GameState`; sin consentimiento NO se escriben respuestas, solo si el "pre" ya se hizo). `GameState.nueva_partida` reinicia todo y genera un participante nuevo.
- **Pantallas** (capa 12, mismo fondo que el onboarding, `Assets/UI/fondo_titulo.png`, con el Guía a un lado; `FondoEvaluacion`): `Consentimiento.tscn` ("Acepto y continúo" / "Jugar sin guardar mis respuestas"), `Cuestionario.tscn` (una pregunta a la vez, "Pregunta N de 16" y barra; el Guía introduce cada bloque; **no se puede cancelar**: ESC, TAB y la habilidad no hacen nada, `Evaluacion.cuestionario_activo` impide el diario y la pausa; nunca dice si se acertó) y `Resultados.tscn` (**TEMPORAL**: tabla antes/después hasta que llegue la pantalla de resultados definitiva, prompt 5.3). Uso: `await Consentimiento.mostrar(get_tree())`, `await Cuestionario.mostrar(get_tree(), "pre")`, `await Resultados.mostrar(get_tree())`.
- **Flujo:** título -> onboarding (introducción del Guía -> consentimiento -> "pre" -> despedida y portal) -> mundo. Con "Continuar" no se repite el "pre". Al final: Puerta del Reflejo -> secuencia final -> "post" (sin consentimiento) -> resultados -> título.
- **Puerta del Reflejo:** con alguna emoción pendiente dice que falta algo (sin decir cuántas). Con todas resueltas, el Guía pregunta "¿Quieres cerrar tu viaje aquí?" ("Sí, cruzar el espejo" / "Todavía no"; este diálogo SÍ se cancela). Al cruzar: fundido a blanco y `Scenes/Final/Final.tscn`. La posición queda guardada para volver.
- **Final** (`Scenes/Final/Final.tscn`, `Scripts/Final/Final.gd`, `EspejoFinal.gd` = marco dorado dibujado por código, `Shaders/final_color.gdshader` = el color del mundo del fondo): según `calcular_final()`. BUENO: las 7 emociones aparecen una a una en "calma" con su luz y el mundo recupera todo el color. NEUTRO: solo las integradas; las demás, siluetas tenues; opción "Volver al mundo a seguir explorando" o "Cerrar mi viaje". DIFÍCIL: la mayoría son siluetas grises; "Volver al Pasado a escucharlas" o "Cerrar mi viaje" (tono cálido, nunca culpabilizante). Música `final_<tipo>`. Con `recuerdos_completos`, el reflejo recita una frase corta por emoción (la última página de cada recuerdo, hasta el primer punto) y con `regalos_completos` menciona los 7 regalos. Volver (o cancelar) siempre regresa al mundo con todo el estado intacto: no hay softlock.
- **Depuración** (`Autoload/Depuracion.gd`, solo con `OS.is_debug_build()`; aviso de 2 s): **H** teletransporta a la Puerta del Reflejo, **J** fuerza las 7 integradas (bueno), **K** fuerza 4 integradas + 2 atacadas + 1 ignorada (neutro; deliberadamente SIN pendientes, porque con alguna pendiente la puerta no abre), **L** fuerza mayoría atacada o ignorada (difícil). No chocan con movimiento, habilidades (ESPACIO, 1-7, R, F, G), U/I/O de las arenas ni M.
- **Resultados** (`Scenes/UI/Resultados.tscn`, capa 12; ya NO es temporal): "Tu viaje en números" con barras animadas ANTES (gris violáceo) y DESPUÉS (dorado) de Conocimiento (trivia 0-7), Cómo reaccionas (situaciones 0-7) y Cómo te sientes (escala 2-10) con un texto cálido (si baja, un mensaje neutro y amable), una sección por emoción (estado final, marcas de trivia antes/después, opción elegida en la situación, respuesta correcta y explicación), el resumen de la partida y los botones Exportar mis resultados, Ver créditos, Jugar de nuevo (nueva partida, va al onboarding) y Salir. `Resultados.ultimo_destino` dice a dónde se fue. ESC/TAB/habilidad no hacen nada; flechas arriba/abajo desplazan.
- **Exportación** (`Scripts/Sistemas/Exportacion.gd`, SOLO con `consentimiento_guardar`): al terminar el "post" (`Evaluacion.fase_terminada`) se agrega una fila a `user://ecos_resultados.csv` (UTF-8, comas, encabezado solo si el archivo no existe; con otras columnas va a `ecos_resultados_v2.csv`, `_v3`...) y se escribe `user://sesiones/<id>.json`. Columnas: id_participante, fecha_iso, duracion_min, final, integradas, atacadas, ignoradas, pendientes, fragmentos, habilidades, pre_/post_ trivia, situaciones, escala y, por cada pregunta, `pre_<id>`, `post_<id>` (índice original; en escala, el valor 1-5) y `pre_ok_<id>`, `post_ok_<id>` (1 si correcta o sana; solo trivia y situaciones). "Exportar mis resultados" copia el CSV a Documentos como `ECOS_resultados.csv` (si no se puede, muestra la ruta de `user://` y un botón "Abrir carpeta"). Sin consentimiento no se escribe ningún archivo y el botón lo dice.
- **Créditos** (`Scenes/UI/Creditos.tscn`, capa 13): desplazamiento suave sobre el fondo del título; el texto está en `Resources/creditos.txt` (secciones con `# `, nota final con `> `; los `[COMPLETAR]` están por rellenar). Se cierra con ENTER, ESC o clic; flecha abajo acelera.
- **Pruebas:** `Dialogo.respuesta_de_prueba` (-99 = desactivado) hace que `mostrar_texto` devuelva al instante esa opción sin abrir nada; solo para pruebas automáticas. `Final.modo_prueba` evita los cambios de escena y las esperas largas.

## Audio

- **Dónde están:** `Assets/Audio/Efectos/` (54 `.wav`, 44.1 kHz, 16 bits), `Assets/Audio/Ambiente/` (4 `.ogg`: `amb_pasado`, `amb_presente`, `amb_lluvia`, `portal_activo`) y `Assets/Audio/Musica/` (6 `.ogg`: `musica_titulo`, `musica_pasado`, `musica_presente`, `final_bueno`, `final_neutro`, `final_dificil`). El nombre del archivo es el identificador del sonido. Los originales (`.mp3` de ElevenLabs, sin procesar) están en `audio_originales/`, fuera de `Assets` y en `.gitignore`.
- **Lista de efectos:** `dialogo_blip`, `dialogo_blip_guia`, `dialogo_abrir`, `dialogo_cerrar`, `dialogo_opciones`, `ui_mover`, `ui_aceptar`, `ui_elegir`, `ui_cancelar`, `diario_abrir`, `diario_cerrar`, `guardar`; `emo_<emoción>` y `emo_<emoción>_integrada` (las 7); `integrar_exito`, `atacar_ignorar`, `habilidad_desbloqueada`, `fragmento_recogido`, `viaje_epoca`, `bloqueo_abre`; `hab_impulso`, `hab_vision`, `hab_calma`, `hab_vinculo`, `hab_reparar`, `hab_pausa`, `hab_revelar`, `hab_denegada`; `paso`, `paso_piedra`; `roca_rompe`, `planta_florece`, `placa_activa`, `porton_repara`, `puente_aparece`, `niebla_disipa`, `titulo_comenzar`, `luz_blanca`, `cofre_abre` (abrir un cofre de memoria), `mejora_habilidad` (suena 0.9 s después, con el aviso de la mejora), `compuerta_abre` (al abrirse cualquier compuerta) y `pista` (`Sonido.pista()`: -6 dB, tono +-5 %, como mucho una vez cada 5 s; lo llaman el aviso de AyudaPistas, la pista al interactuar con una compuerta cerrada sin la habilidad y la respuesta "¿Qué hago ahora?" de la Guía).
- **Cómo se procesaron** (`tools/procesar_audio.py CARPETA_CON_LOS_MP3`; necesita ffmpeg, en el PATH o con `pip install imageio-ffmpeg` en un entorno virtual): efectos con el silencio inicial recortado (se dejan 10 ms), el final recortado por debajo de -45 dB, pico a -3 dB y fundido de salida de 50 ms. Ambientes: solo el silencio inicial, a ~ -26 LUFS. Música: a ~ -20 LUFS, con fundido de salida de 1.5 s solo en los tres finales. Cuando subir la ganancia no basta para llegar al volumen sin pasar de -1.5 dB de pico (`amb_pasado`, `musica_presente`), se usa `loudnorm` de dos pasadas (algo de compresión). El original `mo_miedo_integrada.mp3` es `emo_miedo_integrada` (le faltaba la "e").
- **Loop** (en el `.import`): activado en `amb_pasado`, `amb_presente`, `amb_lluvia`, `portal_activo`, `musica_titulo`, `musica_pasado` y `musica_presente`; el resto sin loop (los `.wav` con `edit/loop_mode=1`). Ojo: los ambientes de ElevenLabs no están hechos para repetirse sin costura; puede notarse un salto al reiniciar el bucle.
- **Buses:** música por `Musica`, efectos y ambientes por `Efectos` (ver `Opciones`).
- **Sistema de audio** (`Autoload/Sonido.gd`, autoload `Sonido`): `Sonido.efecto("nombre")` (14 voces a la vez; dos veces el mismo efecto en menos de 40 ms cuentan una; el volumen de cada uno está en la tabla `VOLUMEN_DB`, y los que no están usan `VOLUMEN_POR_DEFECTO`), `Sonido.musica("nombre", fundido)` y `Sonido.ambiente("nombre", fundido)` (fundido cruzado; pedir lo que ya suena no lo reinicia) y `detener_musica()` / `detener_ambiente()`. Busca el archivo por nombre en las tres carpetas (`.wav`, `.ogg` o `.mp3`); si falta, no rompe nada: avisa una vez en la consola y sale en el panel. Todo sigue sonando con el juego en pausa.
- **Qué suena y desde dónde:** por señales, `Sonido` escucha `GameState` (integrar: `integrar_exito` y `emo_<id>_integrada`; atacar o ignorar: `atacar_ignorar`; `habilidad_desbloqueada`; `fragmento_recogido`), `Habilidades` (`hab_*` al usar; `hab_denegada` con `uso_denegado`: bloqueada, o sin nada que hacer) y `Dialogo` (`dialogo_abrir`/`cerrar`/`opciones`, `ui_elegir`, `ui_cancelar` y un blip cada 2 letras, el del Guía distinto). Lo demás lo llama el propio script: pasos de `Player` (`paso` o `paso_piedra` según el suelo, que pregunta `Mundo.suelo_en()`), `emo_<id>` al hablar con una criatura, `bloqueo_abre`, los acertijos (`roca_rompe`, `planta_florece`, `placa_activa`, `porton_repara`, `puente_aparece`, `niebla_disipa`), los menús (`diario_abrir`/`cerrar`, `ui_mover` al mover el foco, `ui_aceptar`/`ui_cancelar`), `guardar`, el título (`musica_titulo`, `ui_mover`, `titulo_comenzar`), el onboarding (`luz_blanca`), `viaje_epoca` y la música del final (`final_<bueno|neutro|dificil>` al hablar con la Puerta del Reflejo, TEMPORAL como su texto).
- **Música y ambiente:** `Mundo.mostrar_epoca()` llama a `Sonido.ambientar_epoca()`: `musica_pasado` + `amb_pasado`, o `musica_presente` + `amb_presente`. `portal_activo` suena en bucle y más fuerte cuanto más cerca estás de un portal o una grieta (hasta 280 px). Al cerrar el juego (botón Salir o la ventana) `Sonido.salir()` para el audio y espera un instante antes de salir. `amb_lluvia` está cargado pero todavía no suena: falta la lluvia del bloqueo de Tristeza (ver "Bloqueos del Presente").
- **Panel de depuración:** la tecla **M** (solo en compilaciones de depuración) muestra cuántos de los 64 audios existen, cuáles faltan, la música y el ambiente actuales, el volumen de los buses, las voces en uso y los últimos efectos. La señal `Sonido.efecto_reproducido(nombre)` sirve para depurar y probar.

## Atribución en git

Los mensajes de commit nunca llevan líneas `Co-Authored-By`, `Claude-Session` ni "Generated with Claude Code", y los pull requests tampoco llevan texto de atribución. Solo debe aparecer el perfil del usuario como autor.

## Estado del proyecto

Al empezar una sesión lee también `ESTADO.md`: resume lo ya hecho, lo que falta y cómo ejecutar las herramientas.
