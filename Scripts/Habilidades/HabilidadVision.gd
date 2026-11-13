class_name HabilidadVision
extends HabilidadBase
## Visión: ver en la oscuridad. Se implementa en las tareas 4.2 y 4.3; por ahora solo destello y aviso.


func _init() -> void:
	id = "vision"
	cooldown = 3.0
	duracion = 4.0
