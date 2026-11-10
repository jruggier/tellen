@tool
class_name Ruleset
extends Resource
## The complete set of rules and tuning numbers for one game.
##
## A game ships one Ruleset resource (.tres) that wires together its concrete
## rule classes and every tuning constant, plus the "system" content every
## battle needs (stats, movement types, weapon types). Framework logic reads
## numbers from here and never hardcodes them. A different game swaps the
## Ruleset, not the engine.
##
## Rule objects are sub-resources whose own exported properties hold their
## tuning numbers, so everything is editable in the Inspector.

## Stable identifier, e.g. [code]&"crossroads"[/code].
@export var ruleset_id: StringName = &""

## Human-readable name shown in debug tools.
@export var display_name: String = ""

@export_group("Catalog")
## Every stat the game uses.
@export var stats: Array[StatDefinition] = []
## Every movement type.
@export var movement_types: Array[MovementType] = []
## Every weapon type (resolves Stagger links by id).
@export var weapon_types: Array[WeaponType] = []
## Every terrain type (map tiles reference them by id).
@export var terrains: Array[TerrainData] = []
## Translation keys for class tier names, index = tier.
@export var tier_names: Array[String] = []

@export_group("Rules")
@export var combat_rules: CombatRules
@export var growth_rules: GrowthRules
@export var exp_rules: ExpRules
@export var enemy_stat_rules: EnemyStatRules
@export var proficiency_rules: ProficiencyRules
## Awakening rule (null = no awakening in this game).
@export var awakening_rule: AwakeningRule

@export_group("Progression")
## Highest unit level.
@export_range(1, 999) var level_cap: int = 40
## EXP needed per level.
@export_range(1, 10000) var exp_per_level: int = 100

@export_group("Grid")
## Size in pixels of one map tile in the source art.
@export_range(1, 256) var tile_source_size: int = 16
## On-screen scale of map art (16 px tiles × 4 = 64 px cells at 1920×1080).
@export_range(1, 16) var tile_display_scale: int = 4
## TileSet custom data layer holding each tile's terrain id.
@export var terrain_id_layer: String = "terrain_id"
## Optional rule (§7.4): units must stop when entering a tile adjacent to an
## enemy that has [member zoc_tag].
@export var zone_of_control: bool = false
## Unit tag that exerts zone of control.
@export var zoc_tag: StringName = &"zoc"

@export_group("Units")
## Inventory slots per unit.
@export_range(1, 20) var inventory_size: int = 5
## Equippable (non-class) skill slots per unit.
@export_range(0, 20) var skill_slots: int = 5
## Stat id holding max HP.
@export var hp_stat: StringName = &"hp"
## Stat id holding movement points.
@export var mov_stat: StringName = &"mov"
## Stat id holding Build (offsets weapon weight).
@export var build_stat: StringName = &"bld"


## On-screen size of one grid cell in pixels.
func cell_size() -> int:
	return tile_source_size * tile_display_scale


## The stat definition with [param stat_id], or null.
func get_stat(stat_id: StringName) -> StatDefinition:
	for definition: StatDefinition in stats:
		if definition != null and definition.id == stat_id:
			return definition
	return null


## Ids of stats that grow on level-up, in catalog order.
func growable_stat_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for definition: StatDefinition in stats:
		if definition != null and definition.growable:
			ids.append(definition.id)
	return ids


## The weapon type with [param type_id], or null.
func get_weapon_type(type_id: StringName) -> WeaponType:
	for weapon_type: WeaponType in weapon_types:
		if weapon_type != null and weapon_type.id == type_id:
			return weapon_type
	return null


## The terrain with [param terrain_id], or null.
func get_terrain(terrain_id: StringName) -> TerrainData:
	for terrain: TerrainData in terrains:
		if terrain != null and terrain.id == terrain_id:
			return terrain
	return null


## The movement type with [param type_id], or null.
func get_movement_type(type_id: StringName) -> MovementType:
	for movement_type: MovementType in movement_types:
		if movement_type != null and movement_type.id == type_id:
			return movement_type
	return null


## Localized name of class tier [param tier].
func get_tier_name(tier: int) -> String:
	if tier >= 0 and tier < tier_names.size():
		return tr(tier_names[tier])
	return str(tier)


## Returns a list of problems with this ruleset (empty when valid). Used by
## the data validator and when a ruleset is activated.
func validate() -> PackedStringArray:
	var problems := PackedStringArray()
	if ruleset_id == &"":
		problems.append("Ruleset has no ruleset_id")
	var rule_slots: Dictionary = {
		"combat_rules": combat_rules, "growth_rules": growth_rules, "exp_rules": exp_rules,
		"enemy_stat_rules": enemy_stat_rules, "proficiency_rules": proficiency_rules,
	}
	for slot: String in rule_slots:
		var rules: Resource = rule_slots[slot]
		if rules == null:
			problems.append("Ruleset '%s': %s is not set" % [ruleset_id, slot])
		else:
			problems.append_array(rules.call("validate"))
	if awakening_rule != null:
		problems.append_array(awakening_rule.validate())
	_check_catalog(problems, "stats", stats)
	_check_catalog(problems, "movement_types", movement_types)
	_check_catalog(problems, "weapon_types", weapon_types)
	_check_catalog(problems, "terrains", terrains)
	for stat_id: StringName in [hp_stat, mov_stat, build_stat]:
		if not stats.is_empty() and get_stat(stat_id) == null:
			problems.append("Ruleset '%s': stat '%s' is not in the stats catalog" % [ruleset_id, stat_id])
	for weapon_type: WeaponType in weapon_types:
		if weapon_type == null:
			continue
		for target_id: StringName in weapon_type.staggers:
			if get_weapon_type(target_id) == null:
				problems.append("WeaponType '%s' staggers unknown weapon type '%s'" % [weapon_type.id, target_id])
	return problems


func _check_catalog(problems: PackedStringArray, field: String, entries: Array) -> void:
	var seen: Dictionary = {}
	for entry: Variant in entries:
		if entry == null:
			problems.append("Ruleset '%s': %s contains an empty entry" % [ruleset_id, field])
			continue
		var data: TacticsData = entry as TacticsData
		problems.append_array(data.validate())
		if seen.has(data.id):
			problems.append("Ruleset '%s': duplicate id '%s' in %s" % [ruleset_id, data.id, field])
		seen[data.id] = true
