extends Node

const DATA_SCRIPT := preload("res://Singletons/Data.gd")
const ARCHER_ID := "archer"
const ARCHER_LABEL := "Frontier Archer"
const ARCHER_PRESET := "res://models/human_skins/skin_citizen_a.tscn"

func _ready() -> void:
	var data := DATA_SCRIPT.new()
	add_child(data)
	await get_tree().process_frame

	var entry_first := data.get_archetype_entry(ARCHER_ID)
	assert(not entry_first.is_empty(), "Archer archetype should be available for tests.")
	entry_first["label"] = "Mutated"
	var base_first_any: Variant = entry_first.get("base", {})
	if typeof(base_first_any) == TYPE_DICTIONARY:
		var base_first: Dictionary = base_first_any
		base_first["hp"] = -1

	var entry_second := data.get_archetype_entry(ARCHER_ID)
	assert(entry_second.get("label", "") == ARCHER_LABEL, "Archetype label mutations must not persist across calls.")
	var base_second_any: Variant = entry_second.get("base", {})
	if typeof(base_second_any) == TYPE_DICTIONARY:
		var base_second: Dictionary = base_second_any
		assert(int(base_second.get("hp", 0)) == 72, "Nested base dictionaries should be cloned defensively.")

	var visual_first := data.get_archetype_visual(ARCHER_ID)
	assert(not visual_first.is_empty(), "Visual descriptor should not be empty.")
	visual_first["preset"] = "res://fake_preset.tscn"
	var gear_first_any: Variant = visual_first.get("gear", {})
	if typeof(gear_first_any) == TYPE_DICTIONARY:
		var gear_first: Dictionary = gear_first_any
		gear_first["head"] = "res://fake_head.tscn"

	var visual_second := data.get_archetype_visual(ARCHER_ID)
	assert(visual_second.get("preset", "") == ARCHER_PRESET, "Visual data should remain immutable for callers.")
	var gear_second_any: Variant = visual_second.get("gear", {})
	if typeof(gear_second_any) == TYPE_DICTIONARY:
		var gear_second: Dictionary = gear_second_any
		assert(gear_second.get("head", "") == "res://models/gear/hood_a.tscn", "Nested visual dictionaries must also be cloned.")

	print("DATA_ISOLATION_OK")
	get_tree().quit()
