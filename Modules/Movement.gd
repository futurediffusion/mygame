extends Node
class_name MovementModule

var player: CharacterBody3D

func setup(p: CharacterBody3D) -> void:
player = p

func physics_tick(_delta: float) -> void:
# se llenará en pasos siguientes
pass
