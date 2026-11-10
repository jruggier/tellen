class_name CombatParticipant
extends RefCounted
## Everything combat rules need to know about one side of a combat.
##
## Built from a unit's battle state by the forecast/resolver (or directly in
## tests and the Combat Lab). Rules only read participants; they never touch
## battle state, which keeps every formula pure and testable.
##
## [member modifiers] carries flat bonuses from skills, auras and statuses,
## keyed by the [code]MOD_*[/code] constants. Games may add their own keys.

const MOD_HIT: StringName = &"hit"
const MOD_AVOID: StringName = &"avoid"
const MOD_CRIT: StringName = &"crit"
const MOD_CRIT_EVADE: StringName = &"crit_evade"
const MOD_MIGHT: StringName = &"might"
const MOD_DAMAGE: StringName = &"damage"
const MOD_DEFENSE: StringName = &"defense"
const MOD_RESISTANCE: StringName = &"resistance"

## Battle unit id, if this participant came from a battle.
var unit_id: StringName = &""

## Total stats after class, level and permanent boosts (before combat modifiers).
var stats: StatBlock = StatBlock.new()

## Equipped weapon, or null if unarmed.
var weapon: WeaponData = null

## Terrain the participant stands on, or null for none.
var terrain: TerrainData = null

## Movement type (for stagger immunity and effectiveness tags).
var movement_type: MovementType = null

## Unit tags (class, movement type and unit tags), used for effectiveness.
var tags: Array[StringName] = []

## Current HP at the start of the combat.
var current_hp: int = 0

## Level and class tier (for EXP and AI).
var level: int = 1
var tier: int = 0

## True if this participant cannot follow up (carried-over Stagger).
var staggered: bool = false

## True for bosses (EXP bonus, AI priority).
var is_boss: bool = false

## Flat combat modifiers, keyed by the MOD_* constants.
var modifiers: Dictionary[StringName, int] = {}


## Value of stat [param stat_id] (0 if missing).
func stat(stat_id: StringName) -> int:
	return stats.get_value(stat_id)


## Value of modifier [param key] (0 if missing).
func modifier(key: StringName) -> int:
	return modifiers.get(key, 0)


## True if this participant has a weapon it can attack with.
func has_attack_weapon() -> bool:
	return weapon != null and not weapon.heals


## Adds [param amount] to modifier [param key].
func add_modifier(key: StringName, amount: int) -> void:
	modifiers[key] = modifier(key) + amount
