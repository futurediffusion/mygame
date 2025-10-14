extends Node
class_name Logger

enum Level {
	DEBUG,
	INFO,
	WARN,
	ERROR,
}

@export var min_level: int = Level.INFO

static var _instance: Logger = null

func _ready() -> void:
	_instance = self

func _exit_tree() -> void:
	if _instance == self:
		_instance = null

func log(level: int, context: String, message: String) -> void:
	if level < min_level:
		return
	var formatted := _format_message(level, context, message)
	match level:
		Level.ERROR:
			push_error(formatted)
		Level.WARN:
			push_warning(formatted)
		_:
			print(formatted)

static func debug(context: String, message: String) -> void:
	_log_static(Level.DEBUG, context, message)

static func info(context: String, message: String) -> void:
	_log_static(Level.INFO, context, message)

static func warn(context: String, message: String) -> void:
	_log_static(Level.WARN, context, message)

static func error(context: String, message: String) -> void:
	_log_static(Level.ERROR, context, message)

static func _log_static(level: int, context: String, message: String) -> void:
	var instance := _instance
	if instance:
		instance.log(level, context, message)
	else:
		_static_fallback(level, message)

static func _static_fallback(level: int, message: String) -> void:
	match level:
		Level.ERROR:
			push_error(message)
		Level.WARN:
			push_warning(message)
		_:
			print(message)

func _format_message(level: int, context: String, message: String) -> String:
	var label := _get_level_label(level)
	var trimmed_context := context.strip_edges()
	if trimmed_context.is_empty():
		return "[%s] %s" % [label, message]
	return "[%s][%s] %s" % [label, trimmed_context, message]

func _get_level_label(level: int) -> String:
	match level:
		Level.DEBUG:
			return "DEBUG"
		Level.INFO:
			return "INFO"
		Level.WARN:
			return "WARN"
		Level.ERROR:
			return "ERROR"
	return "INFO"
