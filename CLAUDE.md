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

- `Autoload/`: singletons (`GameState`, `Dialogo`).
- `Scenes/{Personajes,Emociones,Mundo,UI,Objetos}`: escenas.
- `Scripts/{Personajes,Emociones,Mundo,UI,Datos,Sistemas}`: scripts.
- `Assets/{Personajes,Emociones,Mundo,UI,Audio,Fuentes,Efectos}`: arte, audio y fuentes.
- `Resources/Emociones`: datos de cada emoción en `.tres`.
- `Dialogos/`: contenido de los diálogos.
- `addons/`: plugins (solo con permiso del usuario).

## Reglas de trabajo

- Todos los textos del juego van **en español**.
- Código GDScript **tipado, simple y comentado en español**.
- Los datos van en **Resources (`.tres`)**, no escritos en el código.
- Usar **señales** en vez de referencias directas entre nodos.
- **Un commit por tarea.**
- Explicar cada cambio **en español sencillo**.
- **Pedir confirmación** antes de: instalar addons, borrar archivos o editar una escena que pueda estar abierta en el editor de Godot.
- No borrar ni mover archivos existentes sin permiso.
