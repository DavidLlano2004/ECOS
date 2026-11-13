class_name HabilidadRevelar
extends HabilidadBase
## Revelar: muestra caminos, puentes y puertas ocultos. Se implementa en las tareas 4.2 y 4.3; por ahora solo destello y aviso.


func _init() -> void:
	id = "revelar"
	cooldown = 6.0
	duracion = 4.0
