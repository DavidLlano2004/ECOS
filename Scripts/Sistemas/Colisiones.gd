class_name Colisiones
extends RefCounted
## Apagar o encender la colisión de un objeto del mundo (una roca que se rompe, un portón que se abre).
##
## Mundo apaga las formas de la época oculta y, al volver a ella, restaura cada forma según la marca
## "ecos_apagada" (ver Mundo._activar_fisica). Por eso un objeto que cambia su colisión también tiene
## que actualizar esa marca; si no, al viajar y volver el obstáculo reaparecería.


static func apagar(forma: CollisionShape2D, apagada: bool) -> void:
	forma.set_meta("ecos_apagada", apagada)
	forma.set_deferred("disabled", apagada)
