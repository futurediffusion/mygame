extends Node
class_name GameState

signal paused_changed(paused: bool)
signal cinematic_changed(in_cinematic: bool)

var is_paused := false
var is_in_cinematic := false

const LOCAL_GROUP: StringName = SimClockAutoload.GROUP_LOCAL

func set_paused(paused: bool) -> void:
	if is_paused == paused:
		return
	is_paused = paused
	paused_changed.emit(paused)
	_update_simclock_pause() # R3→R4 MIGRATION

func set_cinematic(in_cinematic: bool) -> void:
	if is_in_cinematic == in_cinematic:
		return
	is_in_cinematic = in_cinematic
	cinematic_changed.emit(in_cinematic)
	_update_simclock_pause() # R3→R4 MIGRATION

func _update_simclock_pause() -> void:
	var clock: SimClockAutoload = _get_simclock()
	if clock == null:
		return
	var should_pause: bool = is_paused or is_in_cinematic
	clock.pause_group(LOCAL_GROUP, should_pause)
	if Engine.is_editor_hint():
		print_verbose("GameState -> SimClock.pause_group(%s)" % should_pause) # R3→R4 MIGRATION

func _get_simclock() -> SimClockAutoload:
	var tree: SceneTree = get_tree()
	if tree == null:
		return null
	var root: Viewport = tree.get_root()
	if root == null:
		return null
	var autoload: Node = root.get_node_or_null(^"/root/SimClock")
	if autoload == null:
		return null
	return autoload as SimClockAutoload
