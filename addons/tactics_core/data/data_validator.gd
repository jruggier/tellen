class_name DataValidator
extends RefCounted
## Checks content data for missing references, unknown ids, out-of-range
## numbers and broken links (spec §2a.3).
##
## Runs each resource's own [method TacticsData.validate], then cross-checks
## it against the [Ruleset] catalog (known stats, weapon types, movement
## types, proficiency ids, slot limits). Used by tests, by the editor script
## [code]debug/validate_data.gd[/code], and at startup in debug builds.
##
## Extension point: map validation (M7) adds its own checks on top.

## Project setting listing the content folders to scan.
const SETTING_DATA_DIRECTORIES: String = "tactics_core/data/directories"
const DEFAULT_DATA_DIRECTORIES: PackedStringArray = ["res://game/data"]

var _ruleset: Ruleset
var _problems := PackedStringArray()
var _ids_by_type: Dictionary = {}


func _init(ruleset: Ruleset) -> void:
	_ruleset = ruleset


## Validates the ruleset and every resource under the configured folders.
static func validate_project(ruleset: Ruleset) -> PackedStringArray:
	var validator := DataValidator.new(ruleset)
	var directories: PackedStringArray = ProjectSettings.get_setting(SETTING_DATA_DIRECTORIES, DEFAULT_DATA_DIRECTORIES)
	validator.check_ruleset()
	for directory: String in directories:
		validator.check_directory(directory)
	return validator.get_problems()


## Problems found so far.
func get_problems() -> PackedStringArray:
	return _problems


## Checks the ruleset itself.
func check_ruleset() -> void:
	if _ruleset == null:
		_problems.append("DataValidator: no ruleset")
		return
	_problems.append_array(_ruleset.validate())


## Loads and checks every .tres/.res file under [param directory].
func check_directory(directory: String) -> void:
	var dir := DirAccess.open(directory)
	if dir == null:
		_problems.append("DataValidator: cannot open %s" % directory)
		return
	for sub: String in dir.get_directories():
		check_directory(directory.path_join(sub))
	for file: String in dir.get_files():
		var path: String = directory.path_join(file.trim_suffix(".remap"))
		if path.ends_with(".tres") or path.ends_with(".res"):
			var resource: Resource = ResourceLoader.load(path)
			if resource == null:
				_problems.append("DataValidator: failed to load %s" % path)
			else:
				check_resource(resource)


## Checks one resource (its own rules plus catalog cross-checks).
func check_resource(resource: Resource) -> void:
	if not (resource is TacticsData):
		return
	var data: TacticsData = resource as TacticsData
	_problems.append_array(data.validate())
	_check_duplicate_id(data)
	if _ruleset == null:
		return
	if data is ClassData:
		_check_class(data as ClassData)
	elif data is UnitData:
		_check_unit(data as UnitData)
	elif data is WeaponData:
		_check_weapon_type_known((data as WeaponData).weapon_type, data)
	elif data is AwakeningData:
		_check_stat_block((data as AwakeningData).stat_modifiers, data, "stat_modifiers")
	elif data is ConsumableData:
		_check_stat_block((data as ConsumableData).permanent_boosts, data, "permanent_boosts")
	elif data is TerrainData:
		for movement_id: StringName in (data as TerrainData).move_costs:
			if _ruleset.get_movement_type(movement_id) == null:
				_problems.append("%s: move cost for unknown movement type '%s'" % [_label(data), movement_id])


func _check_class(class_data: ClassData) -> void:
	if class_data.movement_type != null and _ruleset.get_movement_type(class_data.movement_type.id) == null:
		_problems.append("%s: movement type '%s' is not in the ruleset" % [_label(class_data), class_data.movement_type.id])
	for weapon_type: WeaponType in class_data.usable_weapon_types:
		_check_weapon_type_known(weapon_type, class_data)
	for block_name: String in ["base_stats", "growth_modifiers", "caps", "generic_base_stats", "generic_growths"]:
		_check_stat_block(class_data.get(block_name) as StatBlock, class_data, block_name)
	for proficiency_id: StringName in class_data.trained_proficiencies():
		_check_proficiency_id(proficiency_id, class_data)
	for proficiency_id: StringName in class_data.requirements:
		_check_proficiency_id(proficiency_id, class_data)


func _check_unit(unit: UnitData) -> void:
	_check_stat_block(unit.personal_base, unit, "personal_base")
	_check_stat_block(unit.personal_growths, unit, "personal_growths")
	if unit.level > _ruleset.level_cap:
		_problems.append("%s: level %d is above the level cap %d" % [_label(unit), unit.level, _ruleset.level_cap])
	if unit.inventory.size() > _ruleset.inventory_size:
		_problems.append("%s: %d items but only %d inventory slots" % [_label(unit), unit.inventory.size(), _ruleset.inventory_size])
	if unit.skills.size() > _ruleset.skill_slots:
		_problems.append("%s: %d skills but only %d skill slots" % [_label(unit), unit.skills.size(), _ruleset.skill_slots])
	for proficiency_id: StringName in unit.proficiencies:
		_check_proficiency_id(proficiency_id, unit)
	if unit.class_data == null:
		return
	for item: ItemData in unit.inventory:
		if not (item is WeaponData):
			continue
		var weapon: WeaponData = item as WeaponData
		if not unit.class_data.can_use_weapon_type(weapon.weapon_type):
			_problems.append("%s: starting weapon '%s' cannot be used by class '%s'" % [_label(unit), weapon.id, unit.class_data.id])
		elif weapon.weapon_type != null and int(unit.proficiencies.get(weapon.weapon_type.id, 0)) < weapon.required_proficiency:
			_problems.append("%s: starting weapon '%s' needs %s proficiency %d" % [_label(unit), weapon.id, weapon.weapon_type.id, weapon.required_proficiency])


func _check_weapon_type_known(weapon_type: WeaponType, owner: TacticsData) -> void:
	if weapon_type != null and _ruleset.get_weapon_type(weapon_type.id) == null:
		_problems.append("%s: weapon type '%s' is not in the ruleset" % [_label(owner), weapon_type.id])


func _check_stat_block(block: StatBlock, owner: TacticsData, field: String) -> void:
	if block == null:
		return
	for stat_id: StringName in block.values:
		if _ruleset.get_stat(stat_id) == null:
			_problems.append("%s: %s uses unknown stat '%s'" % [_label(owner), field, stat_id])


func _check_proficiency_id(proficiency_id: StringName, owner: TacticsData) -> void:
	if _ruleset.get_weapon_type(proficiency_id) == null and _ruleset.get_movement_type(proficiency_id) == null:
		_problems.append("%s: unknown proficiency '%s' (must be a weapon or movement type id)" % [_label(owner), proficiency_id])


func _check_duplicate_id(data: TacticsData) -> void:
	var type_name: String = (data.get_script() as Script).get_global_name()
	if not _ids_by_type.has(type_name):
		_ids_by_type[type_name] = {}
	var seen: Dictionary = _ids_by_type[type_name]
	if data.id != &"" and seen.has(data.id) and seen[data.id] != data.resource_path:
		_problems.append("%s: duplicate id, also used by %s" % [_label(data), seen[data.id]])
	seen[data.id] = data.resource_path


static func _label(data: TacticsData) -> String:
	return "%s '%s' (%s)" % [(data.get_script() as Script).get_global_name(), data.id, data.resource_path]
