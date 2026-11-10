class_name UnitState
extends RefCounted
## A unit's state during a battle: stats, HP, position, inventory, flags.
##
## Pure data, owned by [BattleState]. Created from authored [UnitData]
## (named units) or from a class + level (generic units). Visual nodes read
## it; only commands change it.
##
## Extension points: Stagger, awakening, skills and EXP fields are added in
## M3/M5 as their systems arrive.

## Unique id within the battle (e.g. "tellen", "brigand_2").
var id: StringName = &""
## Authored data for named units; null for generic units.
var unit_data: UnitData = null
var class_data: ClassData = null
var faction_id: StringName = &""
var level: int = 1
## Stat values including maximum HP.
var stats: StatBlock = StatBlock.new()
var current_hp: int = 0
var cell: Vector2i = Vector2i.ZERO
## Inventory in slot order (first equippable weapon is the equipped one).
var inventory: Array[ItemData] = []
## Proficiency id → level.
var proficiencies: Dictionary[StringName, int] = {}
## Extra unit tags (class and movement tags are added by [method get_tags]).
var tags: Array[StringName] = []
var is_lord: bool = false
var is_boss: bool = false
## Moved this phase (can still act).
var has_moved: bool = false
## Finished acting this phase.
var has_acted: bool = false


## Creates a named unit from [param data] at its authored level.
static func from_unit_data(unit_id: StringName, data: UnitData, ruleset: Ruleset, faction: StringName, at_cell: Vector2i) -> UnitState:
	var unit := UnitState.new()
	unit.id = unit_id
	unit.unit_data = data
	unit.class_data = data.class_data
	unit.faction_id = faction
	unit.level = data.level
	unit.stats = UnitStats.starting_stats(data, ruleset)
	unit.current_hp = unit.stats.get_value(ruleset.hp_stat)
	unit.cell = at_cell
	unit.inventory = data.inventory.duplicate()
	unit.proficiencies = data.proficiencies.duplicate()
	unit.tags = data.tags.duplicate()
	unit.is_lord = data.is_lord
	return unit


## Creates a generic unit of [param class_data] at [param unit_level].
## Generic units count as fully proficient in their class's weapons.
static func generic(unit_id: StringName, class_data: ClassData, unit_level: int, ruleset: Ruleset, faction: StringName,
		at_cell: Vector2i, items: Array[ItemData], difficulty_id: StringName = &"normal") -> UnitState:
	var unit := UnitState.new()
	unit.id = unit_id
	unit.class_data = class_data
	unit.faction_id = faction
	unit.level = unit_level
	unit.stats = UnitStats.generic(class_data, ruleset, unit_level, difficulty_id)
	unit.current_hp = unit.stats.get_value(ruleset.hp_stat)
	unit.cell = at_cell
	unit.inventory = items.duplicate()
	var max_level: int = ruleset.proficiency_rules.max_level() if ruleset.proficiency_rules != null else 99
	for weapon_type: WeaponType in class_data.usable_weapon_types:
		unit.proficiencies[weapon_type.id] = max_level
	return unit


## Display name for UI (character/unit name, else class name).
func get_display_name() -> String:
	if unit_data != null:
		return unit_data.get_display_name()
	return class_data.get_display_name() if class_data != null else String(id)


func max_hp(ruleset: Ruleset) -> int:
	return stats.get_value(ruleset.hp_stat)


func mov(ruleset: Ruleset) -> int:
	return stats.get_value(ruleset.mov_stat)


func movement_type_id() -> StringName:
	return class_data.movement_type.id if class_data != null and class_data.movement_type != null else &""


func is_alive() -> bool:
	return current_hp > 0


## True if this unit can still act this phase.
func is_ready() -> bool:
	return is_alive() and not has_acted


## Unit tags: movement type, class tags and the unit's own tags.
func get_tags() -> Array[StringName]:
	return UnitStats.tags_for(class_data, tags)


## True if the unit may equip [param weapon] (class permission and proficiency).
func can_equip(weapon: WeaponData) -> bool:
	if weapon == null or class_data == null or not class_data.can_use_weapon_type(weapon.weapon_type):
		return false
	return int(proficiencies.get(weapon.weapon_type.id, 0)) >= weapon.required_proficiency


## Weapons the unit could attack with, in inventory order.
func attack_weapons() -> Array[WeaponData]:
	var result: Array[WeaponData] = []
	for item: ItemData in inventory:
		if item is WeaponData and not (item as WeaponData).heals and can_equip(item as WeaponData):
			result.append(item as WeaponData)
	return result


## The equipped weapon: the first attack weapon in the inventory, or null.
func equipped_weapon() -> WeaponData:
	var weapons: Array[WeaponData] = attack_weapons()
	return weapons[0] if not weapons.is_empty() else null


## Distinct (min, max) ranges of every attack weapon.
func attack_ranges() -> Array[Vector2i]:
	var ranges: Array[Vector2i] = []
	for weapon: WeaponData in attack_weapons():
		var weapon_range := Vector2i(weapon.range_min, weapon.range_max)
		if not ranges.has(weapon_range):
			ranges.append(weapon_range)
	return ranges


## An independent copy (for snapshots and AI simulation).
func copy() -> UnitState:
	var other := UnitState.new()
	other.id = id
	other.unit_data = unit_data
	other.class_data = class_data
	other.faction_id = faction_id
	other.level = level
	other.stats = stats.copy()
	other.current_hp = current_hp
	other.cell = cell
	other.inventory = inventory.duplicate()
	other.proficiencies = proficiencies.duplicate()
	other.tags = tags.duplicate()
	other.is_lord = is_lord
	other.is_boss = is_boss
	other.has_moved = has_moved
	other.has_acted = has_acted
	return other
