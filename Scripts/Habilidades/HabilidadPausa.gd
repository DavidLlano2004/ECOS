class_name HabilidadPausa
extends HabilidadBase
## Pausa: ralentiza el tiempo unos segundos. Se implementa en las tareas 4.2 y 4.3; por ahora solo destello y aviso.


func _init() -> void:
	id = "pausa"
	cooldown = 8.0
	duracion = 3.0
