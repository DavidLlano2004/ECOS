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
}

@export var id: String = ""
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
@export_multiline var mensaje_integracion: String = ""
@export_multiline var mensaje_fallo: String = ""
@export_multiline var mensaje_presente_aliada: String = ""
@export_multiline var mensaje_presente_bloqueo: String = ""
