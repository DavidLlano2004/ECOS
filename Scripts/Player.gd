class_name Player
extends CharacterBody2D

@export var speed := 70.0
var can_move := true
var cercano: Node = null

func _ready() -> void:
	add_to_group("player")

func _physics_process(_delta: float) -> void:
	if not can_move:
		velocity = Vector2.ZERO
		return

	var direction := Input.get_vector("IZQUIERDA", "DERECHA", "ARRIBA", "ABAJO")
	velocity = direction * speed
	move_and_slide()

	if Input.is_action_just_pressed("INTERACTUAR") and cercano != null:
		cercano.interactuar()

func _on_zona_interaccion_area_entered(area: Area2D) -> void:
	if area.get_parent().has_method("interactuar"):
		cercano = area.get_parent()

func _on_zona_interaccion_area_exited(area: Area2D) -> void:
	if area.get_parent() == cercano:
		cercano = null
