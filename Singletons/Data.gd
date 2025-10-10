extends Node
class_name Data

const ARCHETYPE_JSON_PATH := "res://data/ally_archetypes.json"
const ALLY_STATS_RESOURCE := preload("res://Resources/AllyStats.gd")
const BASE_PROPERTY_MAP := {
	"hp": "hp_max",
	"stamina": "stamina_max",
	"vitality": "vitality",
	"strength": "strength",
	"athletics": "athletics",
	"swimming": "swimming",
	"move_speed": "move_speed",
	"defense_hint": "defense_hint"
}

var _defaults: Dictionary = {}
var _archetypes: Dictionary = {}
var allies: Dictionary = {}

func _ready() -> void:
	var data := _load_json(ARCHETYPE_JSON_PATH)
	if data.is_empty():
		push_warning("Failed to load ally archetypes from %s." % ARCHETYPE_JSON_PATH)
		return
	_defaults = data.get("defaults", {}).duplicate(true)
	var archetype_array: Array = data.get("archetypes", [])
	_archetypes.clear()
	allies.clear()
	for entry in archetype_array:
                if not entry.has("id"):
                        continue
                var copy: Dictionary = entry.duplicate(true)
                _archetypes[entry["id"]] = copy
                allies[entry["id"]] = copy

func archetype_exists(id: String) -> bool:
	return _archetypes.has(id)

func get_capabilities(id: String) -> PackedStringArray:
	if not archetype_exists(id):
		return PackedStringArray()
	var entry: Dictionary = _archetypes[id]
	var capabilities: Array = entry.get("capabilities", [])
	return PackedStringArray(capabilities)

func make_stats_from_archetype(id: String) -> AllyStats:
	if not archetype_exists(id):
		push_warning("Archetype %s not found." % id)
		return null
	var entry: Dictionary = _archetypes[id]
	var stats: AllyStats = ALLY_STATS_RESOURCE.new()
	# Combine default base stats with archetype overrides before assigning them to the resource.
	var base_defaults: Dictionary = _defaults.get("base", {})
	var base_overrides: Dictionary = entry.get("base", {})
	var combined_base: Dictionary = base_defaults.duplicate(true)
	for key in base_overrides.keys():
		combined_base[key] = base_overrides[key]
	for key in combined_base.keys():
		if not BASE_PROPERTY_MAP.has(key):
			continue
		var property_name := BASE_PROPERTY_MAP[key]
		stats.set(property_name, combined_base[key])
	# Merge each skill tree to keep data-driven defaults while allowing archetype specialization.
	var defaults_skills: Dictionary = _defaults.get("skills", {})
	var skills: Dictionary = {}
	for tree_name in defaults_skills.keys():
		skills[tree_name] = defaults_skills[tree_name].duplicate(true)
	_merge_skill_tree(skills, entry.get("skills", {}))
	for tree_name in skills.keys():
		stats.set(tree_name, skills[tree_name].duplicate(true))
	# Growth rules follow the same pattern: start from defaults and apply overrides so future edits stay centralized in data.
	var growth_defaults: Dictionary = _defaults.get("growth", {})
	var growth_overrides: Dictionary = entry.get("growth", {})
	var growth: Dictionary = growth_defaults.duplicate(true)
	for key in growth_overrides.keys():
		growth[key] = growth_overrides[key]
	stats.skill_gain_multiplier = float(growth.get("skill_gain_multiplier", stats.skill_gain_multiplier))
	stats.soft_cap = int(growth.get("soft_cap", stats.soft_cap))
	return stats

func _merge_skill_tree(target: Dictionary, src: Dictionary) -> void:
	for tree_name in src.keys():
		var source_tree = src[tree_name]
		if not target.has(tree_name):
			target[tree_name] = {}
		var target_tree: Dictionary = target[tree_name]
		for skill_name in source_tree.keys():
			target_tree[skill_name] = source_tree[skill_name]

func _load_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Unable to open %s: %s" % [path, FileAccess.get_open_error()])
		return {}
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	var parse_error := json.parse(text)
	if parse_error != OK:
		push_error("Failed to parse %s: %s" % [path, json.get_error_message()])
		return {}
	var data = json.get_data()
	if typeof(data) != TYPE_DICTIONARY:
		push_error("JSON at %s is not a dictionary." % path)
		return {}
	return data
