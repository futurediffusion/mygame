extends Node

@export var animation_player_path: NodePath = NodePath("Pivot/Model/AnimationPlayer")

func _ready() -> void:
	await get_tree().create_timer(0.5).timeout
	_verify_tracks()

func _verify_tracks() -> void:
	print("\n========== VERIFICACIÓN DE ANIMATION TRACKS ==========")
	var anim_player: AnimationPlayer = get_node_or_null(animation_player_path)
	if anim_player == null:
		print("❌ ERROR: No se encontró AnimationPlayer en: ", animation_player_path)
		return
	print("✓ AnimationPlayer encontrado: ", anim_player.get_path())
	var found_attacks: Array[String] = []
	var anim_list := anim_player.get_animation_list()
	print("\n--- Animaciones disponibles ---")
	for anim_name in anim_list:
		print("  - ", anim_name)
		var lower := String(anim_name).to_lower()
		if lower.contains("punch") or lower.contains("attack"):
			found_attacks.append(anim_name)
	if found_attacks.is_empty():
		print("\n⚠️ No se encontraron animaciones de ataque")
		print("========== FIN VERIFICACIÓN ==========")
		return
	print("\n--- Verificando tracks en animaciones de ataque ---")
	for anim_name in found_attacks:
		_check_animation_tracks(anim_player, anim_name)
	print("========== FIN VERIFICACIÓN ==========")

func _check_animation_tracks(anim_player: AnimationPlayer, anim_name: String) -> void:
	var anim: Animation = anim_player.get_animation(anim_name)
	if anim == null:
		print("  ❌ No se pudo obtener animación: ", anim_name)
		return
	print("\n📽️ Animación: ", anim_name)
	print("   Duración: ", anim.length, " segundos")
	print("   Tracks: ", anim.get_track_count())
	var has_method_track := false
	var has_start_hit := false
	var has_end_hit := false
	for track_idx in range(anim.get_track_count()):
		var track_type := anim.track_get_type(track_idx)
		var track_path := anim.track_get_path(track_idx)
		if track_type == Animation.TYPE_METHOD:
			has_method_track = true
			print("   ✓ Method Track encontrado: ", track_path)
			var key_count := anim.track_get_key_count(track_idx)
			print("     Keys: ", key_count)
			for key_idx in range(key_count):
				var key_time := anim.track_get_key_time(track_idx, key_idx)
				var key_value = anim.track_get_key_value(track_idx, key_idx)
				if key_value is Dictionary:
					var method_name: String = key_value.get("method", "")
					var args: Array = key_value.get("args", [])
					print("     [", key_time, "s] ", method_name, "(", args, ")")
					if method_name == "attack_start_hit":
						has_start_hit = true
					elif method_name == "attack_end_hit":
						has_end_hit = true
	if not has_method_track:
		print("   ❌ NO tiene Method Track - ¡Necesitas añadir uno!")
		print("      Guía: Botón '+' → Call Method Track → Seleccionar nodo raíz")
	elif not has_start_hit:
		print("   ❌ NO tiene attack_start_hit() - ¡Añade el keyframe!")
	elif not has_end_hit:
		print("   ❌ NO tiene attack_end_hit() - ¡Añade el keyframe!")
	else:
		print("   ✅ Configuración completa")

func attack_start_hit(attack_id: String) -> void:
	print("🎯 [TEST] attack_start_hit llamado: ", attack_id)

func attack_end_hit(attack_id: String) -> void:
	print("🎯 [TEST] attack_end_hit llamado: ", attack_id)
