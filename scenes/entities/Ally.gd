extends CharacterBody3D

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
@export var move_speed_base: float = 5.0
@export var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
@export var sprint_enabled: bool = true
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

@export var sit_offset: Vector3 = Vector3(0, 0, 0)

@onready var anim_player: AnimationPlayer = null
@onready var seat_anchor: Node3D = $SeatAnchor
@onready var _model_root: Node3D = $Model

var _target_dir: Vector3 = Vector3.ZERO
var _combat_target: Node3D
var _is_crouched: bool = false
var _is_in_water: bool = false
var _is_sprinting: bool = false
var _t_stealth_accum: float = 0.0
var _t_swim_accum: float = 0.0
var _t_build_accum: float = 0.0
var _t_move_accum: float = 0.0
var _stamina_ratio_min: float = 1.0
var _stamina_ratio_max_since_min: float = 1.0
var _stamina_cycle_window: float = 10.0
var _t_stamina_window: float = 0.0
var _current_seat: Node3D
var _talk_timer: SceneTreeTimer
var _last_state: State = State.IDLE
var _fsm_tick_ran: bool = false
var _moved_this_tick: bool = false

func _ready() -> void:
	if stats == null:
		stats = AllyStats.new()
	_last_state = state
	if player_visual_preset != null and _model_root != null:
		_swap_visual(player_visual_preset)
		if anim_player == null:
			_bind_anim_player_from(self)
	else:
		_bind_anim_player_from(self)
	var clock := _get_simclock()
	if clock:
		clock.register_module(self, sim_group, priority)
	else:
		push_warning("SimClock autoload no disponible; Ally no se registró en el scheduler.")

func _on_clock_tick(group: StringName, dt: float) -> void:
	if group == sim_group:
		physics_tick(dt)

func fsm_step(dt: float) -> void:
	# Lee sensores y decide velocidad deseada; no llames move_and_slide() aquí.
	if state != _last_state:
		_on_state_changed(_last_state, state)
		_last_state = state
	if _is_in_water:
		velocity.y = lerpf(velocity.y, 0.0, dt * 2.0)
	else:
		velocity.y -= gravity * dt
	match state:
		State.IDLE:
			_do_idle(dt)
		State.MOVE:
			_do_move(dt)
		State.COMBAT_MELEE:
			_do_combat_melee(dt)
		State.COMBAT_RANGED:
			_do_combat_ranged(dt)
		State.BUILD:
			_do_build(dt)
		State.SNEAK:
			_do_sneak(dt)
		State.SWIM:
			_do_swim(dt)
		State.TALK:
			_do_talk(dt)
		State.SIT:
			_do_sit(dt)

func physics_tick(dt: float) -> void:
	if OS.is_debug_build():
		assert(!_moved_this_tick, "Ally movido dos veces en el mismo tick")
	if not _fsm_tick_ran and has_method("fsm_step"):
		fsm_step(dt)
	_fsm_tick_ran = false

	_ally_physics_update(dt)
	move_and_slide()
	if OS.is_debug_build():
		_moved_this_tick = true
		await get_tree().process_frame
		_moved_this_tick = false

func _do_idle(_dt: float) -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	_play_anim(anim_idle)

func _do_move(dt: float) -> void:
	var flat_dir := _flat_dir(_target_dir)
	if flat_dir == Vector3.ZERO:
		state = State.IDLE
		return
	var speed := move_speed_base
	if _is_sprinting and sprint_enabled:
		if stats:
			speed = stats.sprint_speed(move_speed_base)
		else:
			speed = move_speed_base * 1.2
	var desired_velocity := flat_dir * speed
	velocity.x = desired_velocity.x
	velocity.z = desired_velocity.z
	if _is_sprinting and sprint_enabled:
		_play_anim(anim_run)
	else:
		_play_anim(anim_walk)
	_t_move_accum += dt
	if _t_move_accum >= 3.0:
		_t_move_accum = 0.0
		if stats:
			stats.gain_base_stat("athletics", 0.5)

func _do_combat_melee(_dt: float) -> void:
	if _combat_target == null or not is_instance_valid(_combat_target):
		state = State.IDLE
		return
	var to_target := _combat_target.global_transform.origin - global_transform.origin
	var flat := _flat_dir(to_target)
	var speed := move_speed_base * 0.8
	velocity.x = flat.x * speed
	velocity.z = flat.z * speed
	_play_anim(anim_attack_melee)
	if stats:
		if weapon_kind == "unarmed":
			stats.gain_skill("war", "unarmed", 1.0, {"action_hash": "melee_unarmed"})
		else:
			stats.gain_skill("war", "swords", 1.0, {"action_hash": "melee_sword"})

func _do_combat_ranged(_dt: float) -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	_play_anim(anim_aim_ranged)

func register_ranged_attack() -> void:
	if not stats:
		return
	stats.gain_skill("war", "ranged", 1.0, {"action_hash": "ranged_shot"})

func notify_jump_started() -> void:
	_play_anim("jump")

func _do_build(dt: float) -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	_play_anim(anim_build)
	_t_build_accum += dt
	if _t_build_accum >= 2.0:
		_t_build_accum = 0.0
		if stats:
			stats.gain_skill("science", "engineering", 1.0, {"action_hash": "build"})

func _do_sneak(dt: float) -> void:
	var flat_dir := _flat_dir(_target_dir)
	var speed := move_speed_base * 0.6
	velocity.x = flat_dir.x * speed
	velocity.z = flat_dir.z * speed
	_play_anim(anim_sneak)
	_t_stealth_accum += dt
	if _t_stealth_accum >= 4.0:
		_t_stealth_accum = 0.0
		if stats:
			stats.gain_skill("stealth", "stealth", 1.0, {"action_hash": "sneak"})

func _do_swim(dt: float) -> void:
	var flat_dir := _flat_dir(_target_dir)
	var swim_factor := 0.0
	if stats:
		swim_factor = clampf(float(stats.swimming) / 100.0, 0.0, 1.0)
	var speed_multiplier := lerpf(0.5, 1.8, swim_factor)
	var speed := move_speed_base * speed_multiplier
	velocity.x = flat_dir.x * speed
	velocity.z = flat_dir.z * speed
	_play_anim(anim_swim)
	_t_swim_accum += dt
	if _t_swim_accum >= 3.0:
		_t_swim_accum = 0.0
		if stats:
			stats.gain_base_stat("swimming", 1.0)

func _do_talk(_dt: float) -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	_play_anim(anim_talk_loop)

func _do_sit(_dt: float) -> void:
	velocity = Vector3.ZERO
	_snap_to_seat()
	_play_anim(anim_sit_loop)

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

func engage_ranged(target: Node3D) -> void:
	_combat_target = target
	state = State.COMBAT_RANGED

func set_crouched(on: bool) -> void:
	_is_crouched = on
	if on:
		if _target_dir != Vector3.ZERO and state != State.SIT and state != State.TALK:
			state = State.SNEAK
	else:
		if state == State.SNEAK:
			if _is_in_water:
				if _target_dir != Vector3.ZERO:
					state = State.SWIM
				else:
					state = State.IDLE
			else:
				if _target_dir != Vector3.ZERO:
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
	state = State.TALK
	if seconds > 0.0:
		var timer := get_tree().create_timer(seconds)
		if timer:
			timer.timeout.connect(_on_talk_timer_timeout)
			_talk_timer = timer

func stop_talking() -> void:
	_cleanup_talk_timer()
	if state == State.TALK:
		state = State.IDLE

func sit_on(seat: Node3D) -> void:
	_current_seat = seat
	_snap_to_seat()
	_play_anim(anim_sit_down)
	state = State.SIT

func stand_up() -> void:
	if state != State.SIT:
		return
	_current_seat = null
	_play_anim(anim_stand_up)
	state = State.IDLE

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

func _on_state_changed(_previous: State, current: State) -> void:
	if Engine.is_editor_hint():
		var previous_name := _state_enum_name(_previous)
		var current_name := _state_enum_name(current)
		print_verbose("[FSM] Ally %s: %s → %s" % [name, previous_name, current_name]) # R3→R4 MIGRATION
	match current:
		State.MOVE:
			_t_move_accum = 0.0
		State.SNEAK:
			_t_stealth_accum = 0.0
		State.SWIM:
			_t_swim_accum = 0.0
		State.BUILD:
			_t_build_accum = 0.0
		State.SIT:
			_snap_to_seat()
		State.TALK:
			velocity = Vector3.ZERO
	if current != State.COMBAT_MELEE:
		_combat_target = null

func _ally_physics_update(dt: float) -> void:
	_track_stamina_cycle(dt)

# R3→R4 MIGRATION: Utilidad de logging para FSM Ally.
func _state_enum_name(value: State) -> String:
	for key in State.keys():
		if State[key] == value:
			return key
	return str(value)

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
				if material != null and mesh_instance.mesh != null:
					for surface in range(mesh_instance.mesh.get_surface_count()):
						mesh_instance.set_surface_override_material(surface, material)
		for child in node.get_children():
			queue.push_back(child)

func _attach_gear(gear: Dictionary) -> void:
	if _model_root == null or gear.is_empty():
		return
	var skeleton := _find_skeleton(_model_root)
	if skeleton == null:
		return
	for child in skeleton.get_children():
		if child is BoneAttachment3D and child.has_meta("gear_slot"):
			child.queue_free()
	for slot in gear.keys():
		var scene_path := String(gear[slot])
		var scene := load(scene_path) as PackedScene
		if scene == null:
			continue
		var attachment := BoneAttachment3D.new()
		attachment.bone_name = _slot_to_bone(slot)
		attachment.name = "Gear_%s" % slot
		attachment.set_meta("gear_slot", slot)
		skeleton.add_child(attachment)
		var inst: Node = scene.instantiate()
		attachment.add_child(inst)

func _get_data_singleton() -> Data:
	var tree: SceneTree = get_tree()
	if tree == null:
		return null
	var root: Node = tree.get_root()
	if root == null:
		return null
	var node: Node = root.get_node_or_null(^"Data")
	if node == null:
		return null
	return node as Data

func _slot_to_bone(slot: String) -> String:
	match slot:
		"head":
			return "Head"
		"back":
			return "Spine2"
		_:
			return "Spine"

func _tint_meshes(color: Color) -> void:
	if _model_root == null:
		return
	var queue: Array[Node] = []
	queue.push_back(_model_root)
	while queue.size() > 0:
		var node: Node = queue.pop_back()
		if node is MeshInstance3D:
			var mesh_instance := node as MeshInstance3D
			var mesh := mesh_instance.mesh
			if mesh == null:
				continue
			for surface in range(mesh.get_surface_count()):
				var material := mesh_instance.get_active_material(surface)
				if material is StandardMaterial3D:
					var duplicated := material.duplicate() as StandardMaterial3D
					duplicated.albedo_color = color
					mesh_instance.set_surface_override_material(surface, duplicated)
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
			return node
		for child in node.get_children():
			queue.push_back(child)
	return null

# ------------------------------------------------------------------------------
# Ejemplos de uso (comentados):
# ally.set_move_dir(Vector3.FORWARD)
# ally.set_crouched(true)
# ally.set_in_water(true)
# ally.sit_on(seat_node)
# ally.stand_up()
# ally.start_talking(3.0)
# ally.stop_talking()
# ally.player_visual_preset = load("res://scenes/entities/PlayerModel.tscn")
# jump_module.jump_started.connect(ally.notify_jump_started)

func _get_simclock() -> SimClockAutoload:
	var tree := get_tree()
	if tree == null:
		return null
	var autoload := tree.get_root().get_node_or_null("/root/SimClock")
	if autoload == null:
		return null
	return autoload as SimClockAutoload
