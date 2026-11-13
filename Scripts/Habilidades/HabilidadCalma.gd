class_name HabilidadCalma
extends HabilidadBase
## Calma: devolver el agua y la vida. Se implementa en las tareas 4.2 y 4.3; por ahora solo destello y aviso.


func _init() -> void:
	id = "calma"
	cooldown = 4.0
	duracion = 0.0
