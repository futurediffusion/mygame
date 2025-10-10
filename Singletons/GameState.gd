extends Node

signal paused_changed(paused: bool)
signal cinematic_changed(in_cinematic: bool)

var is_paused := false
var is_in_cinematic := false

func set_paused(paused: bool) -> void:
	if is_paused == paused:
		return
	is_paused = paused
	paused_changed.emit(paused)

func set_cinematic(in_cinematic: bool) -> void:
	if is_in_cinematic == in_cinematic:
		return
	is_in_cinematic = in_cinematic
	cinematic_changed.emit(in_cinematic)
