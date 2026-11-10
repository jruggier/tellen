class_name UnitState
extends RefCounted
## A unit's state during a battle: stats, HP, position, inventory,
## progression and status flags.
##
## Pure data, owned by [BattleState]. Created from authored [UnitData]
## (named units) or from a class + level (generic units). Visual nodes read
## it; only commands change it.
##
## Extension points: awakening and skill state are added in M5.

## Unique id within the battle (e.g. "tellen", "brigand_2").
var id: StringName = &""
## Authored data for named units; null for generic units.
var unit_data: UnitData = null
var class_data: ClassData = null
var faction_id: StringName = &""
var level: int = 1
## EXP toward the next level (0 to exp_per_level - 1).
var experience: int = 0
## Stat values including maximum HP.
var stats: StatBlock = StatBlock.new()
var current_hp: int = 0
var cell: Vector2i = Vector2i.ZERO
## Inventory in slot order; the first equippable weapon is the equipped one.
var inventory: Array[InventorySlot] = []
## Proficiency id → level (gates weapons and class changes).
var proficiencies: Dictionary[StringName, int] = {}
## Proficiency id → accumulated points (levels derive from these).
var proficiency_points: Dictionary[StringName, int] = {}
## Hidden per-stat counters used by deterministic growth modes.
var growth_counters: Dictionary = {}
## Extra unit tags (class and movement tags are added by [method get_tags]).
var tags: Array[StringName] = []
var is_lord: bool = false
var is_boss: bool = false
## Moved this phase (can still act).
var has_moved: bool = false
## Finished acting this phase.
var has_acted: bool = false
## Upcoming combats in which this unit cannot follow up (Stagger, §5.5).
## Cleared at the end of every phase.
var stagger_combats: int = 0
## Defeated player unit that left the map (back next map, spec §8.4).
var retreated: bool = false


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
	for item: ItemData in data.inventory:
		unit.inventory.append(InventorySlot.of(item))
	unit.proficiencies = data.proficiencies.duplicate()
	for proficiency_id: StringName in data.proficiencies:
		unit.proficiency_points[proficiency_id] = ruleset.proficiency_rules.points_for_level(data.proficiencies[proficiency_id]) if ruleset.proficiency_rules != null else 0
	unit.tags = data.tags.duplicate()
	unit.is_lord = data.is_lord
	return unit


## Creates a generic unit of [param class_data] at [param unit_level].
## Generic units count as fully proficient in their class's weapons;
## [param drop_items] are carried and dropped on defeat.
static func generic(unit_id: StringName, class_data: ClassData, unit_level: int, ruleset: Ruleset, faction: StringName,
		at_cell: Vector2i, items: Array[ItemData], difficulty_id: StringName = &"normal", drop_items: Array[ItemData] = []) -> UnitState:
	var unit := UnitState.new()
	unit.id = unit_id
	unit.class_data = class_data
	unit.faction_id = faction
	unit.level = unit_level
	unit.stats = UnitStats.generic(class_data, ruleset, unit_level, difficulty_id)
	unit.current_hp = unit.stats.get_value(ruleset.hp_stat)
	unit.cell = at_cell
	for item: ItemData in items:
		unit.inventory.append(InventorySlot.of(item))
	for item: ItemData in drop_items:
		unit.inventory.append(InventorySlot.of(item, true))
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


func is_staggered() -> bool:
	return stagger_combats > 0


## True if this unit can still act this phase.
func is_ready() -> bool:
	return is_alive() and not has_acted


## Unit tags: movement type, class tags and the unit's own tags.
func get_tags() -> Array[StringName]:
	return UnitStats.tags_for(class_data, tags)


## Growth rates used on level-up.
func growths(ruleset: Ruleset) -> StatBlock:
	if unit_data != null:
		return ruleset.growth_rules.effective_growths(unit_data.personal_growths, class_data)
	return class_data.generic_growths.copy() if class_data != null and class_data.generic_growths != null else StatBlock.new()


## True if the unit may equip [param weapon] (class permission and proficiency).
func can_equip(weapon: WeaponData) -> bool:
	if weapon == null or class_data == null or not class_data.can_use_weapon_type(weapon.weapon_type):
		return false
	return int(proficiencies.get(weapon.weapon_type.id, 0)) >= weapon.required_proficiency


## Indices of slots holding weapons the unit can attack with.
func attack_slot_indices() -> Array[int]:
	var result: Array[int] = []
	for i: int in inventory.size():
		var weapon: WeaponData = inventory[i].weapon()
		if weapon != null and not weapon.heals and can_equip(weapon):
			result.append(i)
	return result


## Indices of slots holding healing weapons the unit can use.
func heal_slot_indices() -> Array[int]:
	var result: Array[int] = []
	for i: int in inventory.size():
		var weapon: WeaponData = inventory[i].weapon()
		if weapon != null and weapon.heals and can_equip(weapon):
			result.append(i)
	return result


## Weapons the unit could attack with, in inventory order.
func attack_weapons() -> Array[WeaponData]:
	var result: Array[WeaponData] = []
	for i: int in attack_slot_indices():
		result.append(inventory[i].weapon())
	return result


## The equipped weapon: the first attack weapon in the inventory, or null.
func equipped_weapon() -> WeaponData:
	var slots: Array[int] = attack_slot_indices()
	return inventory[slots[0]].weapon() if not slots.is_empty() else null


## Moves slot [param index] to the top so it becomes the equipped weapon.
func equip_slot(index: int) -> void:
	if index <= 0 or index >= inventory.size():
		return
	var slot: InventorySlot = inventory[index]
	inventory.remove_at(index)
	inventory.insert(0, slot)


## Distinct (min, max) ranges of every attack weapon.
func attack_ranges() -> Array[Vector2i]:
	var ranges: Array[Vector2i] = []
	for weapon: WeaponData in attack_weapons():
		var weapon_range := Vector2i(weapon.range_min, weapon.range_max)
		if not ranges.has(weapon_range):
			ranges.append(weapon_range)
	return ranges


## True if another item fits.
func has_inventory_space(ruleset: Ruleset) -> bool:
	return inventory.size() < ruleset.inventory_size


## An independent copy (for snapshots and AI simulation).
func copy() -> UnitState:
	var other := UnitState.new()
	other.id = id
	other.unit_data = unit_data
	other.class_data = class_data
	other.faction_id = faction_id
	other.level = level
	other.experience = experience
	other.stats = stats.copy()
	other.current_hp = current_hp
	other.cell = cell
	for slot: InventorySlot in inventory:
		other.inventory.append(slot.copy())
	other.proficiencies = proficiencies.duplicate()
	other.proficiency_points = proficiency_points.duplicate()
	other.growth_counters = growth_counters.duplicate()
	other.tags = tags.duplicate()
	other.is_lord = is_lord
	other.is_boss = is_boss
	other.has_moved = has_moved
	other.has_acted = has_acted
	other.stagger_combats = stagger_combats
	other.retreated = retreated
	return other
