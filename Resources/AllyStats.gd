extends Resource
class_name AllyStats

const SKILL_TREE_DEFAULTS := {
	"war": {
		"swords": 0.0,
		"unarmed": 0.0,
		"ranged": 0.0
	},
	"stealth": {
		"stealth": 0.0,
		"lockpicking": 0.0,
		"theft": 0.0,
		"assassination": 0.0
	},
	"science": {
		"medicine": 0.0,
		"engineering": 0.0,
		"research": 0.0
	},
	"craft": {
		"forging": 0.0,
		"farming": 0.0,
		"cooking": 0.0,
		"lumberjack": 0.0,
		"mining": 0.0,
		"masonry": 0.0,
		"tanning": 0.0,
		"herbalism": 0.0
	},
	"social": {
		"charisma": 0.0
	}
}

var _hp_store := 80.0
@export_range(0, 100, 1) var hp_max := 80:
	get:
		return int(_hp_store)
	set(value):
		_hp_store = clampf(float(value), 0.0, 100.0)

var _stamina_store := 100.0
@export_range(0, 100, 1) var stamina_max := 100:
	get:
		return int(_stamina_store)
	set(value):
		_stamina_store = clampf(float(value), 0.0, 100.0)

var _vitality_store := 10.0
@export_range(0, 100, 1) var vitality := 10:
	get:
		return int(_vitality_store)
	set(value):
		_vitality_store = clampf(float(value), 0.0, 100.0)

var _strength_store := 10.0
@export_range(0, 100, 1) var strength := 10:
	get:
		return int(_strength_store)
	set(value):
		_strength_store = clampf(float(value), 0.0, 100.0)

var _athletics_store := 10.0
@export_range(0, 100, 1) var athletics := 10:
	get:
		return int(_athletics_store)
	set(value):
		_athletics_store = clampf(float(value), 0.0, 100.0)

var _swimming_store := 0.0
@export_range(0, 100, 1) var swimming := 0:
	get:
		return int(_swimming_store)
	set(value):
		_swimming_store = clampf(float(value), 0.0, 100.0)

var _move_speed_store := 5.0
@export_range(0.0, 100.0, 0.1) var move_speed := 5.0:
        get:
                return _move_speed_store
        set(value):
                _move_speed_store = clampf(float(value), 0.0, 100.0)

var _defense_hint_store := 0.0
@export_range(0, 100, 1) var defense_hint := 0:
	get:
		return int(_defense_hint_store)
	set(value):
		_defense_hint_store = clampf(float(value), 0.0, 100.0)

var _war_store: Dictionary = {}
@export var war: Dictionary = {}:
        get:
                return _war_store
        set(value):
                _war_store = _sanitize_skill_tree("war", value)

var _stealth_store: Dictionary = {}
@export var stealth: Dictionary = {}:
        get:
                return _stealth_store
        set(value):
                _stealth_store = _sanitize_skill_tree("stealth", value)

var _science_store: Dictionary = {}
@export var science: Dictionary = {}:
        get:
                return _science_store
        set(value):
                _science_store = _sanitize_skill_tree("science", value)

var _craft_store: Dictionary = {}
@export var craft: Dictionary = {}:
        get:
                return _craft_store
        set(value):
                _craft_store = _sanitize_skill_tree("craft", value)

var _social_store: Dictionary = {}
@export var social: Dictionary = {}:
        get:
                return _social_store
        set(value):
                _social_store = _sanitize_skill_tree("social", value)

var _skill_gain_multiplier_store := 1.0
@export_range(0.0, 5.0, 0.01) var skill_gain_multiplier := 1.0:
        get:
                return _skill_gain_multiplier_store
        set(value):
                _skill_gain_multiplier_store = clampf(float(value), 0.0, 5.0)

var _soft_cap_store := 80.0
@export_range(0, 100, 1) var soft_cap := 80:
	get:
		return int(_soft_cap_store)
	set(value):
		_soft_cap_store = clampf(float(value), 0.0, 100.0)

var _last_action_hash := ""
var _last_skill_key := ""
var _skill_repeat_decay: Dictionary = {}
var _session_repeat_factor := 1.0
var _stamina_cycle_factor := 1.0
var _vitality_recovery_factor := 1.0
var _allow_stamina_gain := false

func _init() -> void:
	_reset_skill_tree_defaults()

func gain_skill(tree: String, skill: String, amount := 1.0, context := {}) -> void:
	var skills_tree := _get_skill_tree(tree)
	if skills_tree.is_empty():
		return
	if not skills_tree.has(skill):
		return
	var sanitized_amount := float(amount)
	if is_zero_approx(sanitized_amount):
		return
	var current := float(skills_tree[skill])
	var gain := sanitized_amount * max(skill_gain_multiplier, 0.0)
	var phase_multiplier := _phase_multiplier_for(current)
	if current >= _soft_cap_store:
		phase_multiplier *= 0.5
	var action_hash := ""
	if typeof(context) == TYPE_DICTIONARY and context.has("action_hash"):
		action_hash = str(context["action_hash"])
	if action_hash != "":
		if action_hash == _last_action_hash:
			_session_repeat_factor = max(0.25, _session_repeat_factor * 0.7)
		else:
			_session_repeat_factor = min(1.0, _session_repeat_factor + 0.2)
		_last_action_hash = action_hash
	else:
		_session_repeat_factor = min(1.0, _session_repeat_factor + 0.05)
		_last_action_hash = ""
	var key := "%s/%s" % [tree, skill]
	var skill_decay := _skill_repeat_decay.get(key, 1.0)
	var final_gain := gain * phase_multiplier * _session_repeat_factor * skill_decay
	if final_gain <= 0.0:
		return
	var new_value := _clamp_skill_value(current + final_gain)
	skills_tree[skill] = new_value
	if _last_skill_key == key:
		skill_decay = max(0.3, skill_decay * 0.85)
	else:
		skill_decay = min(1.0, skill_decay + 0.1)
	_last_skill_key = key
	_skill_repeat_decay[key] = skill_decay

func gain_base_stat(stat: String, amount := 1.0) -> void:
	var sanitized := float(amount)
	if is_zero_approx(sanitized):
		return
	match stat:
		"hp_max":
			_hp_store = clampf(_hp_store + sanitized, 0.0, 100.0)
		"stamina_max":
			if not _allow_stamina_gain:
				return
			_stamina_store = clampf(_stamina_store + sanitized, 0.0, 100.0)
		"vitality":
			_vitality_store = clampf(_vitality_store + sanitized, 0.0, 100.0)
		"strength":
			_strength_store = clampf(_strength_store + sanitized, 0.0, 100.0)
		"athletics":
			_athletics_store = clampf(_athletics_store + sanitized, 0.0, 100.0)
		"swimming":
			_swimming_store = clampf(_swimming_store + sanitized, 0.0, 100.0)
		"move_speed":
			move_speed = clampf(move_speed + sanitized, 0.0, 100.0)
		"defense_hint":
			_defense_hint_store = clampf(_defense_hint_store + sanitized, 0.0, 100.0)
		_:
			return

func note_stamina_cycle(consumed_ratio: float, recovered_ratio: float, seconds_window: float) -> void:
	if consumed_ratio < 0.4 or recovered_ratio < 0.95:
		_stamina_cycle_factor = min(1.0, _stamina_cycle_factor + 0.05)
		return
	var normalized_window := clampf(seconds_window, 10.0, 240.0)
	var window_factor := clampf(90.0 / normalized_window, 0.5, 1.2)
	var base_gain := 0.35 * _stamina_cycle_factor * window_factor
	_allow_stamina_gain = true
	gain_base_stat("stamina_max", base_gain)
	_allow_stamina_gain = false
	_stamina_cycle_factor = max(0.25, _stamina_cycle_factor * 0.7)

func note_low_hp_and_bed_recovery(went_below_15_percent: bool, recovered_in_bed: bool) -> void:
	if went_below_15_percent and recovered_in_bed:
		var vitality_gain := 0.15 * _vitality_recovery_factor
		gain_base_stat("vitality", vitality_gain)
		_vitality_recovery_factor = max(0.2, _vitality_recovery_factor * 0.6)
	else:
		_vitality_recovery_factor = min(1.0, _vitality_recovery_factor + 0.05)

func attack_power_for(weapon_kind: String, weapon_bonus: float = 0.0, situational_bonus: float = 0.0) -> float:
	var domain := 0.0
	match weapon_kind:
		"sword":
			domain = war.get("swords", 0.0)
		"unarmed":
			domain = war.get("unarmed", 0.0)
		"ranged":
			domain = war.get("ranged", 0.0)
		_:
			domain = 0.0
	var power := (_strength_store * 0.5) + (domain * 0.7) + weapon_bonus + situational_bonus
	return max(power, 0.0)

func unarmed_base_damage() -> float:
	return max((_strength_store * 0.35) + (war.get("unarmed", 0.0) * 0.6), 0.0)

func weight_capacity() -> float:
	return 20.0 + (0.8 * _strength_store)

func can_sprint_with(weight: float) -> bool:
	return weight <= weight_capacity()

func must_walk_with(weight: float) -> bool:
	return weight > weight_capacity() * 1.25

func sprint_speed(base_speed: float) -> float:
	return base_speed * (1.0 + (_athletics_store / 200.0))

func sprint_stamina_cost(base_cost: float) -> float:
	var modifier := 1.0 - (_athletics_store / 250.0)
	modifier = clampf(modifier, 0.2, 1.0)
	return base_cost * modifier

func _reset_skill_tree_defaults() -> void:
	for tree_name in SKILL_TREE_DEFAULTS.keys():
		var defaults := SKILL_TREE_DEFAULTS[tree_name]
		match tree_name:
			"war":
				war = defaults
			"stealth":
				stealth = defaults
			"science":
				science = defaults
			"craft":
				craft = defaults
			"social":
				social = defaults

func _sanitize_skill_tree(tree_name: String, values: Dictionary) -> Dictionary:
	var defaults := SKILL_TREE_DEFAULTS.get(tree_name, {})
	if typeof(values) != TYPE_DICTIONARY:
		values = {}
	var sanitized := defaults.duplicate(true)
	for skill_name in defaults.keys():
		if values.has(skill_name):
			sanitized[skill_name] = _clamp_skill_value(float(values[skill_name]))
	_forget_skill_decay(tree_name)
	return sanitized

func _forget_skill_decay(tree_name: String) -> void:
	var prefix := "%s/" % tree_name
	var keys_to_remove: Array = []
	for key in _skill_repeat_decay.keys():
		if key.begins_with(prefix):
			keys_to_remove.append(key)
	for key in keys_to_remove:
		_skill_repeat_decay.erase(key)
	if _last_skill_key.begins_with(prefix):
		_last_skill_key = ""

func _get_skill_tree(tree: String) -> Dictionary:
	match tree:
		"war":
			return war
		"stealth":
			return stealth
		"science":
			return science
		"craft":
			return craft
		"social":
			return social
		_:
			return {}

func _phase_multiplier_for(value: float) -> float:
	if value >= 80.0:
		return 0.1
	if value >= 40.0:
		return 0.5
	return 1.0

func _clamp_skill_value(value: float) -> float:
	return clampf(value, 0.0, 100.0)

# Defense is resolved elsewhere: equipment contributes ~90% of the total, this resource only offers the 10% baseline via defense_hint and relevant skills.

# Ejemplos de uso:
# var stats := AllyStats.new()
# var sword_power := stats.attack_power_for("sword")
# stats.note_stamina_cycle(0.5, 0.96, 45.0)
# stats.note_low_hp_and_bed_recovery(true, true)
