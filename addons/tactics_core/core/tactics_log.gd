class_name TacticsLog
extends RefCounted
## Small leveled logger for framework and game code.
##
## Use [method warn] for recoverable content errors (bad data, missing
## references): the game keeps running and the problem shows up in the
## debugger. Use [method error] for programming errors. In release builds
## DEBUG and INFO messages are suppressed regardless of [member min_level].
##
## Extension point: connect to [signal TacticsEvents.log_emitted] to route
## messages to an in-game console or a file.

enum Level { DEBUG, INFO, WARN, ERROR, NONE }

const _LEVEL_NAMES: Array[String] = ["DEBUG", "INFO", "WARN", "ERROR", "NONE"]

## Messages below this level are dropped.
static var min_level: Level = Level.DEBUG


## Logs a developer diagnostic (debug builds only).
static func debug(category: String, message: String) -> void:
	_emit(Level.DEBUG, category, message)


## Logs a notable event (debug builds only).
static func info(category: String, message: String) -> void:
	_emit(Level.INFO, category, message)


## Logs a recoverable problem, e.g. invalid content data.
static func warn(category: String, message: String) -> void:
	_emit(Level.WARN, category, message)


## Logs a programming or unrecoverable error.
static func error(category: String, message: String) -> void:
	_emit(Level.ERROR, category, message)


## Returns true if a message at [param level] would be emitted.
static func is_enabled(level: Level) -> bool:
	if level == Level.NONE or level < min_level:
		return false
	if level < Level.WARN and not OS.is_debug_build():
		return false
	return true


## Formats a log line. Exposed for tests and custom sinks.
static func format_line(level: Level, category: String, message: String) -> String:
	return "[%s][%s] %s" % [_LEVEL_NAMES[level], category, message]


## Reads [member min_level] from the project setting in [TacticsIds].
## Called once by the [code]TacticsEvents[/code] autoload at startup.
static func configure_from_project_settings() -> void:
	var level: int = int(ProjectSettings.get_setting(TacticsIds.SETTING_LOG_LEVEL, Level.DEBUG))
	min_level = clampi(level, Level.DEBUG, Level.NONE) as Level


static func _emit(level: Level, category: String, message: String) -> void:
	if not is_enabled(level):
		return
	var line: String = format_line(level, category, message)
	match level:
		Level.WARN:
			push_warning(line)
		Level.ERROR:
			push_error(line)
		_:
			print(line)
	if level >= Level.WARN:
		_forward_to_event_bus(level, line)


static func _forward_to_event_bus(level: Level, line: String) -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return
	var bus: Node = tree.root.get_node_or_null(^"TacticsEvents")
	if bus != null and bus.has_signal(&"log_emitted"):
		bus.emit_signal(&"log_emitted", level, line)
