class_name DataCatalog
extends RefCounted
## Finds content resources by type and id in the configured data folders
## (see [DataValidator]). Results are cached per type.

static var _cache: Dictionary[String, Dictionary] = {}


## Every resource under the data folders whose script is [param type_name]
## (or a subclass), keyed by id.
static func all_of(type_name: String) -> Dictionary:
	if _cache.has(type_name):
		return _cache[type_name]
	var found: Dictionary = {}
	var directories: PackedStringArray = ProjectSettings.get_setting(DataValidator.SETTING_DATA_DIRECTORIES, DataValidator.DEFAULT_DATA_DIRECTORIES)
	for directory: String in directories:
		_scan(directory, type_name, found)
	_cache[type_name] = found
	return found


## The [CharacterData] whose id matches [param speaker] (case-insensitive), or null.
static func character(speaker: String) -> CharacterData:
	return all_of("CharacterData").get(StringName(speaker.to_lower()), null) as CharacterData


## The [ItemData] with [param item_id], or null.
static func item(item_id: String) -> ItemData:
	for type_name: String in ["WeaponData", "ConsumableData", "ItemData"]:
		var found: Variant = all_of(type_name).get(StringName(item_id), null)
		if found != null:
			return found as ItemData
	return null


## Forgets cached lookups (after content changes in the editor).
static func clear_cache() -> void:
	_cache.clear()


static func _scan(directory: String, type_name: String, found: Dictionary) -> void:
	var dir := DirAccess.open(directory)
	if dir == null:
		return
	for sub: String in dir.get_directories():
		_scan(directory.path_join(sub), type_name, found)
	for file: String in dir.get_files():
		var path: String = directory.path_join(file.trim_suffix(".remap"))
		if not path.ends_with(".tres"):
			continue
		var resource: Resource = load(path)
		if resource is TacticsData and _is_type(resource.get_script() as Script, type_name):
			found[(resource as TacticsData).id] = resource


static func _is_type(script: Script, type_name: String) -> bool:
	var current: Script = script
	while current != null:
		if current.get_global_name() == StringName(type_name):
			return true
		current = current.get_base_script()
	return false
