extends Node
class_name Data

const ARCHETYPE_JSON_PATH := "res://data/ally_archetypes.json"
const ALLY_STATS_RESOURCE := preload("res://Resources/AllyStats.gd")

# Mapeo de claves "base" del json → propiedades del Resource AllyStats
const BASE_PROPERTY_MAP: Dictionary = {
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
var allies: Dictionary = {} # alias público para compatibilidad previa

func _ready() -> void:
	var data: Dictionary = _load_json(ARCHETYPE_JSON_PATH)
	if data.is_empty():
		push_warning("Failed to load ally archetypes from %s." % ARCHETYPE_JSON_PATH)
		return

	_defaults = data.get("defaults", {}).duplicate(true)

	var archetype_array_any: Variant = data.get("archetypes", [])
	var archetype_array: Array = []
	if typeof(archetype_array_any) == TYPE_ARRAY:
		archetype_array = archetype_array_any

	_archetypes.clear()
	allies.clear()

	for entry_any in archetype_array:
		if typeof(entry_any) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_any
		if not entry.has("id"):
			continue
		var id: String = String(entry["id"])
		var copy: Dictionary = entry.duplicate(true)
		_archetypes[id] = copy
		allies[id] = copy

# ---------------------------
# Consultas de arquetipo
# ---------------------------
func archetype_exists(id: String) -> bool:
	return _archetypes.has(id)

func get_archetype_entry(id: String) -> Dictionary:
	if not archetype_exists(id):
		return {}
	return _archetypes[id].duplicate(true)

func get_capabilities(id: String) -> PackedStringArray:
	if not archetype_exists(id):
		return PackedStringArray()
	var entry: Dictionary = _archetypes[id]
	var capabilities_any: Variant = entry.get("capabilities", [])
	if typeof(capabilities_any) != TYPE_ARRAY:
		return PackedStringArray()
	var capabilities: Array = capabilities_any
	return PackedStringArray(capabilities)

func get_archetype_visual(id: String) -> Dictionary:
	if not archetype_exists(id):
		return {}
	var entry: Dictionary = _archetypes[id]
	var visual_any: Variant = entry.get("visual", {})
	if typeof(visual_any) != TYPE_DICTIONARY:
		return {}
	var visual: Dictionary = visual_any
	return visual.duplicate(true)

# ---------------------------
# Fábrica de Stats
# ---------------------------
func make_stats_from_archetype(id: String) -> AllyStats:
	# Devuelve SIEMPRE un AllyStats válido (si no existe el arquetipo, crea default y advierte).
	var stats: AllyStats = ALLY_STATS_RESOURCE.new()

	if not archetype_exists(id):
		push_warning("Archetype %s not found. Using default AllyStats." % id)
		return stats

	var entry: Dictionary = _archetypes[id]

	# --- BASE ---
	var base_defaults_any: Variant = _defaults.get("base", {})
	var base_overrides_any: Variant = entry.get("base", {})
	var base_defaults: Dictionary = {}
	var base_overrides: Dictionary = {}
	if typeof(base_defaults_any) == TYPE_DICTIONARY:
		base_defaults = base_defaults_any
	if typeof(base_overrides_any) == TYPE_DICTIONARY:
		base_overrides = base_overrides_any

	# Merge defaults + overrides
	var combined_base: Dictionary = base_defaults.duplicate(true)
	for key in base_overrides.keys():
		combined_base[key] = base_overrides[key]

	# Aplicar a propiedades del Resource usando el mapa BASE_PROPERTY_MAP
	for key in combined_base.keys():
		if not BASE_PROPERTY_MAP.has(key):
			continue
		var prop_name := String(BASE_PROPERTY_MAP[key])
		# set() es seguro; el Resource valida en sus setters si hace falta
		stats.set(prop_name, combined_base[key])

	# --- SKILLS ---
	var defaults_skills_any: Variant = _defaults.get("skills", {})
	var defaults_skills: Dictionary = {}
	if typeof(defaults_skills_any) == TYPE_DICTIONARY:
		defaults_skills = defaults_skills_any

	var skills_over_any: Variant = entry.get("skills", {})
	var skills_over: Dictionary = {}
	if typeof(skills_over_any) == TYPE_DICTIONARY:
		skills_over = skills_over_any

	# target skills = deep copy de defaults
	var skills: Dictionary = {}
	for tree_name in defaults_skills.keys():
		var tree_defaults: Variant = defaults_skills[tree_name]
		if typeof(tree_defaults) == TYPE_DICTIONARY:
			skills[tree_name] = tree_defaults.duplicate(true)

	# merge overrides encima
	_merge_skill_tree(skills, skills_over)

	# escribir cada árbol en el Resource (pasa por sanitisers del Resource)
	for tree_name in skills.keys():
		var tree_dict_any: Variant = skills[tree_name]
		if typeof(tree_dict_any) == TYPE_DICTIONARY:
			var tree_dict: Dictionary = tree_dict_any
			stats.set(tree_name, tree_dict.duplicate(true))

	# --- GROWTH ---
	var growth_defaults_any: Variant = _defaults.get("growth", {})
	var growth_overrides_any: Variant = entry.get("growth", {})
	var growth: Dictionary = {}
	if typeof(growth_defaults_any) == TYPE_DICTIONARY:
		growth = growth_defaults_any.duplicate(true)
	if typeof(growth_overrides_any) == TYPE_DICTIONARY:
		for k in growth_overrides_any.keys():
			growth[k] = growth_overrides_any[k]

	# Aplicar a stats (con tipos)
	if growth.has("skill_gain_multiplier"):
		stats.skill_gain_multiplier = float(growth["skill_gain_multiplier"])
	if growth.has("soft_cap"):
		stats.soft_cap = int(growth["soft_cap"])

	return stats

# Mezcla src dentro de target: target[tree][skill] = src[tree][skill]
func _merge_skill_tree(target: Dictionary, src: Dictionary) -> void:
	for tree_name in src.keys():
		var source_tree_any: Variant = src[tree_name]
		if typeof(source_tree_any) != TYPE_DICTIONARY:
			continue
		var source_tree: Dictionary = source_tree_any
		if not target.has(tree_name):
			target[tree_name] = {}
		var target_tree_any: Variant = target[tree_name]
		if typeof(target_tree_any) != TYPE_DICTIONARY:
			target[tree_name] = {}
			target_tree_any = target[tree_name]
		var target_tree: Dictionary = target_tree_any
		for skill_name in source_tree.keys():
			target_tree[skill_name] = source_tree[skill_name]

# ---------------------------
# Utilidades
# ---------------------------
func _load_json(path: String) -> Dictionary:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Unable to open %s: %s" % [path, FileAccess.get_open_error()])
		return {}
	var text: String = file.get_as_text()
	file.close()

	var json: JSON = JSON.new()
	var parse_error: int = json.parse(text)
	if parse_error != OK:
		push_error("Failed to parse %s: %s" % [path, json.get_error_message()])
		return {}

	var data_any: Variant = json.get_data()
	if typeof(data_any) != TYPE_DICTIONARY:
		push_error("JSON at %s is not a dictionary." % path)
		return {}

	var data_dict: Dictionary = data_any
	return data_dict
