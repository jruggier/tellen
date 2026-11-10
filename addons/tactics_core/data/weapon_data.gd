@tool
class_name WeaponData
extends ItemData
## A weapon or spell. Healing spells are weapons with [member heals] set.
##
## There is no durability. Which stats [enum DamageType] reads from is
## decided by the game's combat rules, not by this class.

enum DamageType { PHYSICAL, MAGIC }

## Category, used for Stagger, proficiency and class weapon permissions.
@export var weapon_type: WeaponType

## Physical attacks use attack/defense stats; magic uses magic/resistance stats.
@export var damage_type: DamageType = DamageType.PHYSICAL

@export_group("Combat")
@export var might: int = 0
@export var hit: int = 0
@export var crit: int = 0
## Added to the wielder's crit evade.
@export var crit_evade: int = 0
## Offset by the wielder's Build (see the combat rules).
@export var weight: int = 0
@export_range(0, 20) var range_min: int = 1
@export_range(0, 20) var range_max: int = 1

@export_group("Requirements")
## Minimum proficiency level in [member weapon_type] needed to equip it.
@export var required_proficiency: int = 0

@export_group("Effects")
## Unit tags this weapon is effective against (e.g. "sky").
@export var effective_against: Array[StringName] = []
## Strikes twice whenever its wielder strikes.
@export var brave: bool = false
## Heals allies instead of attacking.
@export var heals: bool = false
## Wielder cannot counterattack.
@export var cannot_counter: bool = false
## Added to the healer's power when [member heals] is set.
@export var heal_power: int = 0


## True if a target at Manhattan [param distance] is in range.
func is_in_range(distance: int) -> bool:
	return distance >= range_min and distance <= range_max


## True if this weapon is effective against any of [param unit_tags].
func is_effective_against(unit_tags: Array[StringName]) -> bool:
	for tag: StringName in effective_against:
		if unit_tags.has(tag):
			return true
	return false


func validate() -> PackedStringArray:
	var problems: PackedStringArray = super()
	if weapon_type == null:
		problems.append("%s: no weapon_type" % _label())
	if range_min > range_max:
		problems.append("%s: range_min %d > range_max %d" % [_label(), range_min, range_max])
	if heals and heal_power <= 0:
		problems.append("%s: heals but heal_power is %d" % [_label(), heal_power])
	for value_name: String in ["might", "hit", "crit", "crit_evade", "weight", "required_proficiency"]:
		if int(get(value_name)) < 0:
			problems.append("%s: %s is negative" % [_label(), value_name])
	return problems
