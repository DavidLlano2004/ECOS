class_name HabilidadImpulso
extends HabilidadBase
## Impulso: un dash corto. Se implementa en las tareas 4.2 y 4.3; por ahora solo destello y aviso.


func _init() -> void:
	id = "impulso"
	cooldown = 1.5
	duracion = 0.2
