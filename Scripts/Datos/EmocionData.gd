class_name EmocionData
extends Resource
## Datos de una emoción. Se guarda como .tres en Resources/Emociones/.
## Para crear una emoción nueva basta con duplicar un .tres y cambiar estos campos.

## Cómo se mueve la criatura-emoción en el Pasado.
enum Comportamiento {
	PERSEGUIR,            # va hacia el jugador
	HUIR,                 # se aleja del jugador
	ERRAR,                # camina sin rumbo
	ACERCARSE_SI_QUIETO,  # solo se acerca si el jugador espera en calma
	SEGUIR_SOMBRA,        # sigue al jugador a la misma distancia
	ERRATICO,             # ráfagas cortas y rápidas en zigzag, con pausas de ~0.4 s; vibra si el jugador está cerca
	ESCONDERSE,           # deambula lento; se vuelve semitransparente y se aleja si el jugador la mira de frente a menos de 90 px
}

@export var id: String = ""
## Posición de la emoción en listas y menús (1 = primera). Se ordena de menor a mayor.
@export var orden: int = 0
@export var nombre: String = ""
@export_multiline var descripcion_corta: String = ""
@export var color: Color = Color.WHITE

@export_group("Habilidad")
@export var habilidad_id: String = ""
@export var habilidad_nombre: String = ""
@export var habilidad_descripcion: String = ""

@export_group("Comportamiento")
@export var comportamiento: Comportamiento = Comportamiento.ERRAR
@export var velocidad: float = 40.0

@export_group("Mensajes")
## Cómo se llama el bloqueo de esta emoción en el Presente (sale en la etiqueta de nombre del diálogo
## del bloqueo). Ejemplo: "La oscuridad" para Miedo.
@export var nombre_bloqueo: String = ""
@export_multiline var mensaje_integracion: String = ""
@export_multiline var mensaje_fallo: String = ""
@export_multiline var mensaje_presente_aliada: String = ""
@export_multiline var mensaje_presente_bloqueo: String = ""
## Frase breve que dice la criatura (en un globo pequeño) cuando cancelas la conversación con "Ahora no".
@export_multiline var frase_cierre: String = ""
## Lo que dice el bloqueo del Presente si atacaste a la emoción (refleja el daño causado).
@export_multiline var mensaje_presente_atacada: String = ""
## Lo que dice el bloqueo del Presente si la ignoraste (refleja el abandono).
@export_multiline var mensaje_presente_ignorada: String = ""

@export_group("Santuario")
## Lo que mejora el cofre de memoria de esta emoción (nivel 2 de su habilidad): se muestra en el aviso y en el diario.
@export_multiline var mejora_descripcion: String = ""
## El regalo del cofre: un objeto de memoria con nombre y un texto breve (sección "Regalos" del diario).
@export var regalo_nombre: String = ""
@export_multiline var regalo_texto: String = ""
## Lo que dice la forma aliada cuando se abre el cofre.
@export_multiline var frase_agradecimiento: String = ""

@export_group("Sprite")
## Animaciones de la criatura ("idle" y "calma"). Ver Resources/Emociones/frames_*.tres.
@export var frames: SpriteFrames
