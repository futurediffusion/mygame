extends RefCounted
class_name AllyState

const AllyScript := preload("res://scenes/entities/Ally.gd")

var ally: AllyScript

func _init(ally_ref: AllyScript) -> void:
	ally = ally_ref

func enter(_previous: AllyState) -> void:
	pass

func update(_dt: float) -> void:
	pass

func exit(_next: AllyState) -> void:
	pass

class IdleState:
	extends AllyState

	func update(_dt: float) -> void:
		ally.velocity.x = 0.0
		ally.velocity.z = 0.0
		ally._play_anim(ally.anim_idle)

class MoveState:
	extends AllyState

	func enter(_previous: AllyState) -> void:
		ally._t_move_accum = 0.0

	func update(dt: float) -> void:
		var flat_dir := ally._flat_dir(ally._target_dir)
		if flat_dir == Vector3.ZERO:
			ally.state = AllyScript.State.IDLE
			return
		var speed := ally.move_speed_base
		if ally._is_sprinting and ally.sprint_enabled:
			if ally.stats:
				speed = ally.stats.sprint_speed(ally.move_speed_base)
			else:
				speed = ally.move_speed_base * 1.2
		var desired_velocity := flat_dir * speed
		ally.velocity.x = desired_velocity.x
		ally.velocity.z = desired_velocity.z
		if ally._is_sprinting and ally.sprint_enabled:
			ally._play_anim(ally.anim_run)
		else:
			ally._play_anim(ally.anim_walk)
		ally._t_move_accum += dt
		if ally._t_move_accum >= 3.0:
			ally._t_move_accum = 0.0
			if ally.stats:
				ally.stats.gain_base_stat("athletics", 0.5)

class CombatMeleeState:
	extends AllyState

	func update(_dt: float) -> void:
		var target := ally._combat_target
		if target == null or not is_instance_valid(target):
			ally.state = AllyScript.State.IDLE
			return
		var to_target := target.global_transform.origin - ally.global_transform.origin
		var flat := ally._flat_dir(to_target)
		var speed := ally.move_speed_base * 0.8
		ally.velocity.x = flat.x * speed
		ally.velocity.z = flat.z * speed
		ally._play_anim(ally.anim_attack_melee)
		if ally.stats:
			if ally.weapon_kind == "unarmed":
				ally.stats.gain_skill("war", "unarmed", 1.0, {"action_hash": "melee_unarmed"})
			else:
				ally.stats.gain_skill("war", "swords", 1.0, {"action_hash": "melee_sword"})

	func exit(_next: AllyState) -> void:
		ally._combat_target = null

class CombatRangedState:
	extends AllyState

	func update(_dt: float) -> void:
		ally.velocity.x = 0.0
		ally.velocity.z = 0.0
		ally._play_anim(ally.anim_aim_ranged)

class BuildState:
	extends AllyState

	func enter(_previous: AllyState) -> void:
		ally._t_build_accum = 0.0

	func update(dt: float) -> void:
		ally.velocity.x = 0.0
		ally.velocity.z = 0.0
		ally._play_anim(ally.anim_build)
		ally._t_build_accum += dt
		if ally._t_build_accum >= 2.0:
			ally._t_build_accum = 0.0
			if ally.stats:
				ally.stats.gain_skill("science", "engineering", 1.0, {"action_hash": "build"})

class SneakState:
	extends AllyState

	func enter(_previous: AllyState) -> void:
		ally._t_stealth_accum = 0.0

	func update(dt: float) -> void:
		var flat_dir := ally._flat_dir(ally._target_dir)
		var speed := ally.move_speed_base * 0.6
		ally.velocity.x = flat_dir.x * speed
		ally.velocity.z = flat_dir.z * speed
		ally._play_anim(ally.anim_sneak)
		ally._t_stealth_accum += dt
		if ally._t_stealth_accum >= 4.0:
			ally._t_stealth_accum = 0.0
			if ally.stats:
				ally.stats.gain_skill("stealth", "stealth", 1.0, {"action_hash": "sneak"})

class SwimState:
	extends AllyState

	func enter(_previous: AllyState) -> void:
		ally._t_swim_accum = 0.0

	func update(dt: float) -> void:
		var flat_dir := ally._flat_dir(ally._target_dir)
		var swim_factor := 0.0
		if ally.stats:
			swim_factor = clampf(float(ally.stats.swimming) / 100.0, 0.0, 1.0)
		var speed_multiplier := lerpf(0.5, 1.8, swim_factor)
		var speed := ally.move_speed_base * speed_multiplier
		ally.velocity.x = flat_dir.x * speed
		ally.velocity.z = flat_dir.z * speed
		ally._play_anim(ally.anim_swim)
		ally._t_swim_accum += dt
		if ally._t_swim_accum >= 3.0:
			ally._t_swim_accum = 0.0
			if ally.stats:
				ally.stats.gain_base_stat("swimming", 1.0)

class TalkState:
	extends AllyState

	func enter(_previous: AllyState) -> void:
		ally.velocity = Vector3.ZERO

	func update(_dt: float) -> void:
		ally.velocity.x = 0.0
		ally.velocity.z = 0.0
		ally._play_anim(ally.anim_talk_loop)

class SitState:
	extends AllyState

	func enter(_previous: AllyState) -> void:
		ally._snap_to_seat()

	func update(_dt: float) -> void:
		ally.velocity = Vector3.ZERO
		ally._play_anim(ally.anim_sit_loop)
