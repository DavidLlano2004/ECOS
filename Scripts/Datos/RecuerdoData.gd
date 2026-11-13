class_name RecuerdoData
extends Resource
## Un recuerdo de infancia que se abre al recoger un fragmento de memoria. Se edita en
## Resources/Recuerdos.tres sin tocar código.

## El id de la emoción a la que pertenece ("rabia", "miedo"...). Es también el id del fragmento.
@export var id: String = ""
@export var titulo: String = ""
## Cada elemento es una página del globo de diálogo. Evita los signos ":" , "[ ]" y "{{ }}".
@export var lineas: PackedStringArray = PackedStringArray()
