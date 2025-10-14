extends Node

class StatsSpy:
	extends AllyStats

	var warnings: Array = []

	func push_warning(message: String) -> void:
		warnings.append(message)
		super.push_warning(message)

func _ready() -> void:
	var stats := StatsSpy.new()
	var invalid_result := stats.gain_base_stat("invalid", 10.0)
	assert(not invalid_result, "Invalid stats must be rejected.")
	assert(stats.warnings.size() > 0, "Invalid keys should trigger a warning message.")
	var warning_text := String(stats.warnings.back())
	assert(warning_text.find("invalid") != -1, "Warning should mention the rejected key.")

	stats.move_speed = 95.0
	var applied := stats.gain_base_stat("move_speed", 10.0)
	assert(applied, "Valid stat changes should succeed.")
	assert(is_equal_approx(stats.move_speed, 100.0), "Move speed should clamp to the configured maximum.")

	print("ALLY_STATS_OK", stats.move_speed)
	get_tree().quit()
