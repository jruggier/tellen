class_name BattleFixtures
extends RefCounted
## Builds small battles from text maps for grid/movement tests.
##
## Legend: . plains  R road  F forest  U ruins  H hill  T fort  ~ water
##         # wall  D doorway  (space) void

const DATA: String = "res://game/data/"
const LEGEND: Dictionary = {
	".": "plains", "R": "road", "F": "forest", "U": "ruins", "H": "hill",
	"T": "fort", "~": "water", "#": "wall", "D": "doorway",
}


static func ruleset() -> Ruleset:
	return load("res://game/rules/crossroads_ruleset.tres") as Ruleset


## A battle on [param rows] with player, enemy and ally factions.
static func state(rows: PackedStringArray, battle_ruleset: Ruleset = null) -> BattleState:
	var rules: Ruleset = battle_ruleset if battle_ruleset != null else ruleset()
	var legend: Dictionary = {}
	for key: String in LEGEND:
		legend[key] = rules.get_terrain(StringName(LEGEND[key]))
	var battle := BattleState.new(rules, BattleGrid.from_rows(rows, legend))
	for faction_id: String in ["player", "enemy", "ally"]:
		battle.factions.append(load(DATA + "factions/%s.tres" % faction_id) as FactionData)
	return battle


## Adds a generic unit of class [param class_id] carrying [param weapon_ids].
static func add(battle: BattleState, unit_id: StringName, class_id: String, faction: StringName, cell: Vector2i,
		weapon_ids: Array[String] = [], level: int = 1) -> UnitState:
	var class_data: ClassData = load(DATA + "classes/%s.tres" % class_id) as ClassData
	var items: Array[ItemData] = []
	for weapon_id: String in weapon_ids:
		items.append(load(DATA + "weapons/%s.tres" % weapon_id) as ItemData)
	var unit: UnitState = UnitState.generic(unit_id, class_data, level, battle.ruleset, faction, cell, items)
	battle.add_unit(unit)
	return unit
