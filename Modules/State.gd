extends Node
class_name StateModule

var player: CharacterBody3D

func setup(p: CharacterBody3D) -> void:
player = p

func physics_tick(_delta: float) -> void:
pass
