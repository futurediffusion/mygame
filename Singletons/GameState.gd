extends Node

signal paused_changed(paused: bool)
signal cinematic_changed(in_cinematic: bool)

var is_paused := false
var is_in_cinematic := false

const LOCAL_GROUP: StringName = SimClock.GROUP_LOCAL

func set_paused(paused: bool) -> void:
	if is_paused == paused:
		return
	is_paused = paused
	paused_changed.emit(paused)
	_update_sim_clock_pause() # R3→R4 MIGRATION

func set_cinematic(in_cinematic: bool) -> void:
	if is_in_cinematic == in_cinematic:
		return
	is_in_cinematic = in_cinematic
	cinematic_changed.emit(in_cinematic)
	_update_sim_clock_pause() # R3→R4 MIGRATION

func _update_sim_clock_pause() -> void:
	var sim_clock := _get_sim_clock() # R3→R4 MIGRATION
	if sim_clock == null:
		return
	var should_pause := is_paused or is_in_cinematic
	sim_clock.pause_group(LOCAL_GROUP, should_pause)
	if Engine.is_editor_hint():
		print_verbose("GameState -> SimClock.pause_group(%s)" % should_pause) # R3→R4 MIGRATION

func _get_sim_clock() -> SimClock:
	var root := get_tree()
	if root == null:
		return null
	var autoload := root.get_root().get_node_or_null("/root/SimClock")
	if autoload == null:
		return null
	return autoload as SimClock
