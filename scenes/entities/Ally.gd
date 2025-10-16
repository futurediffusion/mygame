extends CharacterBody3D
class_name Ally
const SIMCLOCK_SCRIPT := preload("res://Singletons/SimClock.gd")
const GAME_CONSTANTS := preload("res://scripts/core/GameConstants.gd")
const LOGGER_CONTEXT := "Ally"

enum State {
	IDLE,
	MOVE,
	COMBAT_MELEE,
	COMBAT_RANGED,
	BUILD,
	SNEAK,
	SWIM,
	TALK,
	SIT
}

@export var state: State = State.IDLE
@export var stats: AllyStats
@export var capabilities: Capabilities
@export var move_speed_base: float = 5.0
@export var walk_speed: float = 3.5
@export var run_speed: float = 5.0
@export var sprint_speed: float = 6.5
@export var accel_ground: float = GAME_CONSTANTS.DEFAULT_ACCEL_GROUND
@export var accel_air: float = GAME_CONSTANTS.DEFAULT_ACCEL_AIR
@export var decel: float = GAME_CONSTANTS.DEFAULT_DECEL
@export var max_slope_deg: float = 45.0
@export var fast_fall_speed_multiplier: float = GAME_CONSTANTS.DEFAULT_FAST_FALL_MULT
@export var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
@export var snap_len: float = 0.3
@export var sprint_enabled: bool = true
@export var face_lerp: float = 0.18
@export var model_forward_correction_deg: float = 0.0
@export_enum("sword", "unarmed", "ranged") var weapon_kind: String = "sword"
@export var player_visual_preset: PackedScene

@export var sim_group: StringName = Flags.ALLY_TICK_GROUP
@export var priority: int = 20

@export var anim_idle: String = "idle"
@export var anim_walk: String = "walk"
@export var anim_run: String = "run"
@export var anim_sneak: String = "sneak"
@export var anim_swim: String = "swim"
@export var anim_talk_loop: String = "talk_loop"
@export var anim_sit_down: String = "sit_down"
@export var anim_sit_loop: String = "sit_loop"
@export var anim_stand_up: String = "stand_up"
@export var anim_attack_melee: String = "attack_melee"
@export var anim_aim_ranged: String = "aim_ranged"
@export var anim_build: String = "build"

@export var sit_offset: Vector3 = Vector3.ZERO

var anim_tree: AnimationTree

@onready var anim_player: AnimationPlayer = null
@onready var seat_anchor: Node3D = $SeatAnchor
@onready var model: Node3D = $Model
@onready var combo: PerfectJumpCombo = $PerfectJumpCombo
@onready var brain: AllyBrain = $AllyBrain
@onready var m_movement: MovementModule = $Modules/Movement
@onready var m_orientation: OrientationModule = $Modules/Orientation
@onready var m_dodge: DodgeModule = $Modules/Dodge
@onready var m_anim: AnimationCtrlModule = $Modules/AnimationCtrl
@onready var m_fsm: StateMachineModule = $Modules/StateMachine

var _target_dir: Vector3 = Vector3.ZERO
var _combat_target: Node3D
var _pending_dodge: bool = false
var _pending_attack: bool = false
var _pending_jump: bool = false
var _is_crouched: bool = false
var _is_in_water: bool = false
var _is_sprinting: bool = false
var _stamina_ratio_min: float = 1.0
var _stamina_ratio_max_since_min: float = 1.0
var _stamina_cycle_window: float = 10.0
var _t_stamina_window: float = 0.0
var _current_seat: Node3D
var _talk_timer: SceneTreeTimer
var _input_cache: Dictionary = {}
var _air_time: float = 0.0
var _model_root: Node3D = null
var _skip_module_updates := false
var _block_animation_updates := false
var _talk_active := false
var _is_sitting := false
var invulnerable := false

func _ready() -> void:
	if stats == null:
		stats = AllyStats.new()
	if capabilities == null:
		capabilities = Capabilities.new()
	_model_root = model
	anim_tree = get_node_or_null(^"AnimationTree") as AnimationTree
	if player_visual_preset != null and _model_root != null:
		_swap_visual(player_visual_preset)
		if anim_player == null:
			_bind_anim_player_from(self)
	else:
		_bind_anim_player_from(self)
	floor_snap_length = snap_len
	for module in [m_movement, m_orientation, m_anim]:
		if module != null and is_instance_valid(module):
			module.setup(self)
	if m_dodge != null and is_instance_valid(m_dodge):
		m_dodge.setup(self, m_anim)
	if m_fsm != null and is_instance_valid(m_fsm):
		m_fsm.setup(self)
	if brain != null and is_instance_valid(brain):
		brain.set_ally(self)
	var clock := _get_simclock()
	if clock:
		clock.register_module(self, sim_group, priority)
	else:
		push_warning("SimClock autoload no disponible; Ally no se registró en el scheduler.")

func _on_clock_tick(group: StringName, dt: float) -> void:
	if group == sim_group:
		physics_tick(dt)

func physics_tick(dt: float) -> void:
	if combo != null and is_instance_valid(combo):
		combo.physics_tick(dt)
	_update_vertical_motion(dt)
	_update_air_time(dt)
	_update_input_cache()
	if brain != null and is_instance_valid(brain):
		brain.update_intents(dt)
	if m_anim != null and is_instance_valid(m_anim):
		m_anim.set_frame_anim_inputs(_is_sprinting and sprint_enabled, _air_time)
	if m_fsm != null and is_instance_valid(m_fsm):
		m_fsm.physics_tick(dt)
	if m_movement != null and is_instance_valid(m_movement):
		m_movement.physics_tick(dt)
	if m_dodge != null and is_instance_valid(m_dodge):
		m_dodge.physics_tick(dt)
	if m_orientation != null and is_instance_valid(m_orientation):
		m_orientation.physics_tick(dt)
	if m_anim != null and is_instance_valid(m_anim) and not _block_animation_updates:
		m_anim.physics_tick(dt)
	move_and_slide()
	_track_stamina_cycle(dt)

func _update_vertical_motion(dt: float) -> void:
	if _is_in_water:
		velocity.y = lerpf(velocity.y, 0.0, dt * 2.0)
	else:
		velocity.y -= gravity * dt

func _update_air_time(dt: float) -> void:
	if is_on_floor():
		_air_time = 0.0
	else:
		_air_time += dt

func _update_input_cache() -> void:
	var flat := _flat_dir(_target_dir)
	_input_cache = {
		"move": {
			"camera": flat,
			"raw": Vector2(flat.x, flat.z)
		}
	}

func get_brain_intents() -> Dictionary:
	return {
		"move_dir": _flat_dir(_target_dir),
		"is_sprinting": _is_sprinting and sprint_enabled,
		"want_dodge": _pending_dodge,
		"want_attack": _pending_attack,
		"want_jump": _pending_jump
	}

func clear_brain_triggers() -> void:
	_pending_dodge = false
	_pending_attack = false
	_pending_jump = false

func request_dodge() -> void:
	_pending_dodge = true

func request_jump() -> void:
	_pending_jump = true

func request_attack() -> void:
	_pending_attack = true

func register_ranged_attack() -> void:
	if not stats:
		return
	stats.gain_skill("war", "ranged", 1.0, {"action_hash": "ranged_shot"})

func notify_jump_started() -> void:
	_play_anim("jump")

func set_move_dir(dir: Vector3) -> void:
	if state == State.SIT or state == State.TALK:
		return
	_target_dir = _flat_dir(dir)
	if _target_dir == Vector3.ZERO:
		if state in [State.MOVE, State.SNEAK, State.SWIM]:
			state = State.IDLE
		return
	if _is_in_water:
		state = State.SWIM
	elif _is_crouched:
		state = State.SNEAK
	else:
		state = State.MOVE

func engage_melee(target: Node3D) -> void:
	_combat_target = target
	state = State.COMBAT_MELEE
	request_attack()

func engage_ranged(target: Node3D) -> void:
	_combat_target = target
	state = State.COMBAT_RANGED
	request_attack()

func set_crouched(on: bool) -> void:
	_is_crouched = on
	if on:
		if _target_dir != Vector3.ZERO and state != State.SIT and state != State.TALK:
			state = State.SNEAK
	else:
		if state == State.SNEAK:
			if _is_in_water:
				state = State.SWIM
			elif _target_dir != Vector3.ZERO:
				state = State.MOVE
			else:
				state = State.IDLE

func set_sprinting(on: bool) -> void:
	if sprint_enabled:
		_is_sprinting = on
	else:
		_is_sprinting = false

func set_in_water(on: bool) -> void:
	_is_in_water = on
	if on:
		if _target_dir != Vector3.ZERO:
			state = State.SWIM
	else:
		if state == State.SWIM:
			if _is_crouched and _target_dir != Vector3.ZERO:
				state = State.SNEAK
			elif _target_dir != Vector3.ZERO:
				state = State.MOVE
			else:
				state = State.IDLE

func start_talking(seconds: float = -1.0) -> void:
	if state == State.SIT:
		return
	_cleanup_talk_timer()
	_target_dir = Vector3.ZERO
	state = State.TALK
	_talk_active = true
	_play_anim(anim_talk_loop)
	if seconds > 0.0:
		var timer := get_tree().create_timer(seconds)
		if timer:
			timer.timeout.connect(_on_talk_timer_timeout)
			_talk_timer = timer

func stop_talking() -> void:
	_cleanup_talk_timer()
	if state == State.TALK:
		state = State.IDLE
	_talk_active = false

func sit_on(seat: Node3D) -> void:
	_current_seat = seat
	_target_dir = Vector3.ZERO
	_snap_to_seat()
	_play_anim(anim_sit_down)
	state = State.SIT
	_is_sitting = true

func stand_up() -> void:
	if state != State.SIT:
		return
	_current_seat = null
	_play_anim(anim_stand_up)
	state = State.IDLE
	_is_sitting = false

func _flat_dir(vector: Vector3) -> Vector3:
	var result := Vector3(vector.x, 0.0, vector.z)
	if result.length_squared() > 0.0:
		result = result.normalized()
	return result

func _play_anim(anim_name: String) -> void:
	if anim_name == "":
		return
	if anim_player == null:
		return
	if not is_instance_valid(anim_player):
		anim_player = null
		return
	if not anim_player.has_animation(anim_name):
		return
	if anim_player.current_animation != anim_name:
		anim_player.play(anim_name)

func _snap_to_seat() -> void:
	if _current_seat == null or not is_instance_valid(_current_seat):
		return
	var seat_transform := _current_seat.global_transform
	seat_transform.origin += seat_transform.basis * sit_offset
	var anchor_transform := Transform3D.IDENTITY
	if seat_anchor:
		anchor_transform = seat_anchor.transform
	var inverse_anchor := anchor_transform.affine_inverse()
	global_transform = seat_transform * inverse_anchor

func _track_stamina_cycle(dt: float) -> void:
	_t_stamina_window += dt
	var ratio := 0.9
	if _is_sprinting and sprint_enabled:
		ratio = 0.5
	if ratio < _stamina_ratio_min:
		_stamina_ratio_min = ratio
	if ratio > _stamina_ratio_max_since_min:
		_stamina_ratio_max_since_min = ratio
	if not (_is_sprinting and sprint_enabled):
		_stamina_ratio_max_since_min = clampf(_stamina_ratio_max_since_min + (dt * 0.02), 0.0, 1.0)
	if _t_stamina_window >= _stamina_cycle_window:
		var consumed := 1.0 - _stamina_ratio_min
		var recovered := _stamina_ratio_max_since_min
		if consumed >= 0.4 and recovered >= 0.95 and stats:
			stats.note_stamina_cycle(consumed, recovered, _t_stamina_window)
		_stamina_ratio_min = 1.0
		_stamina_ratio_max_since_min = 1.0
		_t_stamina_window = 0.0

func should_skip_module_updates() -> bool:
	return _skip_module_updates

func should_block_animation_update() -> bool:
	return _block_animation_updates

func get_input_cache() -> Dictionary:
	return _input_cache.duplicate(true)

func is_sneaking() -> bool:
	return _is_crouched

func _cleanup_talk_timer() -> void:
	if _talk_timer and is_instance_valid(_talk_timer):
		if _talk_timer.timeout.is_connected(_on_talk_timer_timeout):
			_talk_timer.timeout.disconnect(_on_talk_timer_timeout)
		_talk_timer = null

func _on_talk_timer_timeout() -> void:
	_talk_timer = null
	stop_talking()

func _bind_anim_player_from(root: Node) -> void:
	anim_player = null
	if root == null:
		return
	var stack: Array[Node] = []
	stack.push_back(root)
	while stack.size() > 0:
		var n: Node = stack.pop_back()
		if n is AnimationPlayer:
			anim_player = n
			break
		for c in n.get_children():
			stack.push_back(c)

func apply_visual_from_archetype(id: String) -> void:
	var data_singleton := _get_data_singleton()
	if data_singleton == null:
		return
	var archetype := data_singleton.get_archetype_entry(id)
	if archetype.is_empty():
		archetype = data_singleton.allies.get(id, {})
	var visual_any: Variant = archetype.get("visual", {})
	if typeof(visual_any) != TYPE_DICTIONARY:
		return
	var visual: Dictionary = visual_any
	if visual.has("preset"):
		var preset := load(String(visual["preset"])) as PackedScene
		_swap_visual(preset)
	if visual.has("materials"):
		var material_overrides_any: Variant = visual["materials"]
		if typeof(material_overrides_any) == TYPE_DICTIONARY:
			var material_overrides: Dictionary = material_overrides_any
			_apply_material_overrides(material_overrides)
	if visual.has("gear"):
		var gear_any: Variant = visual["gear"]
		if typeof(gear_any) == TYPE_DICTIONARY:
			var gear: Dictionary = gear_any
			_attach_gear(gear)
	if visual.has("tint"):
		var tint_value_any: Variant = visual["tint"]
		if typeof(tint_value_any) == TYPE_ARRAY:
			var tint_value: Array = tint_value_any
			if tint_value.size() >= 3:
				var color := Color(float(tint_value[0]), float(tint_value[1]), float(tint_value[2]))
				if tint_value.size() >= 4:
					color.a = float(tint_value[3])
				_tint_meshes(color)

func _swap_visual(preset: PackedScene) -> void:
	if _model_root == null or preset == null:
		return
	for child in _model_root.get_children():
		child.queue_free()
	var inst: Node = preset.instantiate()
	_model_root.add_child(inst)
	_bind_anim_player_from(_model_root)
	if anim_player == null:
		_bind_anim_player_from(self)

func _apply_material_overrides(dict_paths: Dictionary) -> void:
	if _model_root == null or dict_paths.is_empty():
		return
	var queue: Array[Node] = []
	queue.push_back(_model_root)
	while queue.size() > 0:
		var node: Node = queue.pop_back()
		if node is MeshInstance3D:
			var mesh_instance := node as MeshInstance3D
			if dict_paths.has(mesh_instance.name):
				var resource_path := String(dict_paths[mesh_instance.name])
				var material := load(resource_path) as Material
				if material != null:
					mesh_instance.set_surface_override_material(0, material)
		for child in node.get_children():
			queue.push_back(child)

func _attach_gear(gear: Dictionary) -> void:
	if _model_root == null:
		return
	var skeleton := _find_skeleton(_model_root)
	if skeleton == null:
		return
	for slot in gear.keys():
		var bone_name := _slot_to_bone(slot)
		if bone_name == "":
			continue
		var scene_path := String(gear[slot])
		var scene := load(scene_path) as PackedScene
		if scene == null:
			continue
		var inst := scene.instantiate()
		var attachment := BoneAttachment3D.new()
		attachment.bone_name = bone_name
		attachment.name = "%s_attachment" % bone_name
		for child in skeleton.get_children():
			if child is BoneAttachment3D and (child as BoneAttachment3D).bone_name == bone_name:
				child.queue_free()
		skeleton.add_child(attachment)
		attachment.add_child(inst)

func _get_data_singleton() -> Data:
	var tree := get_tree()
	if tree == null:
		return null
	var autoload := tree.get_root().get_node_or_null(^"/root/Data")
	if autoload == null:
		return null
	if autoload is Data:
		return autoload as Data
	return null

func _slot_to_bone(slot: String) -> String:
	match slot:
		"head":
			return "mixamorig_Head"
		"back":
			return "mixamorig_Spine2"
		"right_hand":
			return "mixamorig_RightHand"
		"left_hand":
			return "mixamorig_LeftHand"
		_:
			return ""

func _tint_meshes(color: Color) -> void:
	if _model_root == null:
		return
	var queue: Array[Node] = []
	queue.push_back(_model_root)
	while queue.size() > 0:
		var node: Node = queue.pop_back()
		if node is MeshInstance3D:
			var mesh_instance := node as MeshInstance3D
			var material := mesh_instance.get_active_material(0)
			if material is StandardMaterial3D:
				var standard := material.duplicate() as StandardMaterial3D
				standard.albedo_color = color
				mesh_instance.set_surface_override_material(0, standard)
		for child in node.get_children():
			queue.push_back(child)

func _find_skeleton(root: Node) -> Skeleton3D:
	if root == null:
		return null
	var queue: Array[Node] = []
	queue.push_back(root)
	while queue.size() > 0:
		var node: Node = queue.pop_back()
		if node is Skeleton3D:
			return node as Skeleton3D
		for child in node.get_children():
			queue.push_back(child)
	return null

func _get_simclock() -> SimClockAutoload:
	var tree: SceneTree = get_tree()
	if tree == null:
		return null
	var autoload: Node = tree.get_root().get_node_or_null(^"/root/SimClock")
	if autoload == null:
		return null
	if autoload is SIMCLOCK_SCRIPT:
		return autoload as SimClockAutoload
	return null

func set_roll_collider_override(_active: bool) -> void:
	pass
