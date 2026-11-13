class_name HabilidadReparacion
extends HabilidadBase
## Reparar: arreglar lo roto. Se implementa en las tareas 4.2 y 4.3; por ahora solo destello y aviso.


func _init() -> void:
	id = "reparacion"
	cooldown = 2.0
	duracion = 0.0
