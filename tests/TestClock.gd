extends Node
class TestMod := preload("res://Modules/ModuleBase.gd")

var log: Array = []

class A:
	extends TestMod
	@export var sim_group: StringName = &"local"
	@export var priority: int = 0
	func physics_tick(dt: float) -> void:
		get_parent().log.append("A")

class B:
	extends TestMod
	@export var sim_group: StringName = &"local"
	@export var priority: int = 10
	func physics_tick(dt: float) -> void:
		get_parent().log.append("B")

func _ready() -> void:
	add_child(A.new())
	add_child(B.new())
	await get_tree().process_frame
	await get_tree().process_frame
	print(log)
