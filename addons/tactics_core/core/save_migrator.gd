class_name SaveMigrator
extends RefCounted
## Upgrades serialized data (saves, battle snapshots) to the current format.
##
## Every serialized dictionary carries a [code]save_version[/code]. Register
## one step per format change with [method register_step]; [method migrate]
## then applies the steps in order. Data newer than the current version, or
## with a gap in the registered steps, is rejected instead of being loaded
## silently in a broken state.
##
## Extension point: the game owns one migrator per save type and registers
## its own steps; the framework never deletes or rewrites old saves.

## Key holding the format version in every serialized dictionary.
const VERSION_KEY: String = "save_version"

var _current_version: int
var _steps: Dictionary[int, Callable] = {}


func _init(current_version: int = TacticsIds.SAVE_VERSION) -> void:
	_current_version = current_version


## The version [method migrate] upgrades data to.
func get_current_version() -> int:
	return _current_version


## Registers [param step], which converts data at [param from_version] to
## [code]from_version + 1[/code]. The callable takes and returns a Dictionary.
func register_step(from_version: int, step: Callable) -> void:
	if from_version < 1 or from_version >= _current_version:
		TacticsLog.error("SaveMigrator", "Step from version %d is outside 1..%d" % [from_version, _current_version - 1])
		return
	_steps[from_version] = step


## Returns [param data] upgraded to the current version, or an empty
## dictionary if it cannot be migrated. Data without a version is treated as
## version 1. The input dictionary is not modified.
func migrate(data: Dictionary) -> Dictionary:
	var version: int = int(data.get(VERSION_KEY, 1))
	if version > _current_version:
		TacticsLog.warn("SaveMigrator", "Data version %d is newer than supported %d" % [version, _current_version])
		return {}
	var result: Dictionary = data.duplicate(true)
	while version < _current_version:
		if not _steps.has(version):
			TacticsLog.warn("SaveMigrator", "No migration step registered from version %d" % version)
			return {}
		var migrated: Variant = _steps[version].call(result)
		if not (migrated is Dictionary):
			TacticsLog.error("SaveMigrator", "Step from version %d did not return a Dictionary" % version)
			return {}
		result = migrated
		version += 1
		result[VERSION_KEY] = version
	result[VERSION_KEY] = _current_version
	return result
