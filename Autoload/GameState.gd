extends Node

signal epoca_cambiada(epoca: String)

var epoca := "pasado"
var estado := {"rabia": "pendiente", "miedo": "pendiente", "tristeza": "pendiente"}
var habilidades: Array[String] = []
var respuestas_inicio: Array[int] = []
var respuestas_final: Array[int] = []

const HABILIDAD := {"rabia": "impulso", "miedo": "vision", "tristeza": "calma"}

func cambiar_epoca() -> void:
	epoca = "presente" if epoca == "pasado" else "pasado"
	epoca_cambiada.emit(epoca)

# resultado: "integrada", "atacada" o "ignorada"
func resolver(id: String, resultado: String) -> void:
	estado[id] = resultado
	if resultado == "integrada" and not habilidades.has(HABILIDAD[id]):
		habilidades.append(HABILIDAD[id])
