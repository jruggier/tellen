@tool
class_name ClassData
extends TacticsData
## A unit class (job): movement, stat bonuses and caps, weapon permissions,
## proficiency gains and class-change requirements.
##
## Two stat sets exist for two purposes:
## [br]- [member base_stats] / [member growth_modifiers] are added to a
## named unit's personal stats and growths.
## [br]- [member generic_base_stats] / [member generic_growths] are full stat
## lines used to generate generic enemies of this class (enemy stat rules).

## Class tier, 0 = first tier. Tier names come from the game's ruleset.
@export_range(0, 9) var tier: int = 0

@export var movement_type: MovementType

## Movement points per turn.
@export_range(0, 20) var mov: int = 4

## Added to the unit's personal Build.
@export var build_bonus: int = 0

@export_group("Stats")
## Added to a named unit's personal base stats.
@export var base_stats: StatBlock
## Added to a named unit's personal growth rates (percent).
@export var growth_modifiers: StatBlock
## Maximum value per stat for units of this class.
@export var caps: StatBlock

@export_group("Generic enemies")
## Full level-1 stat line for generic units of this class.
@export var generic_base_stats: StatBlock
## Growth rates (percent) used to scale generic units by level.
@export var generic_growths: StatBlock

@export_group("Weapons and proficiency")
## Weapon types units of this class may equip.
@export var usable_weapon_types: Array[WeaponType] = []
## Proficiency id that gains the most from using this class.
@export var primary_proficiency: StringName = &""
## Other proficiency ids this class trains.
@export var secondary_proficiencies: Array[StringName] = []

@export_group("Abilities and requirements")
## Always-active skills; they do not use skill slots.
@export var abilities: Array[SkillData] = []
## Proficiency id → minimum level needed to change into this class.
@export var requirements: Dictionary[StringName, int] = {}
## Unit tags granted by this class (e.g. "foot", "sky").
@export var tags: Array[StringName] = []

@export_group("Presentation")
## Placeholder or final map sprite.
@export var map_sprite: Texture2D


## True if units of this class may equip weapons of [param weapon_type].
func can_use_weapon_type(weapon_type: WeaponType) -> bool:
	if weapon_type == null:
		return false
	for usable: WeaponType in usable_weapon_types:
		if usable.id == weapon_type.id:
			return true
	return false


## Every proficiency id this class trains (primary first).
func trained_proficiencies() -> Array[StringName]:
	var result: Array[StringName] = []
	if primary_proficiency != &"":
		result.append(primary_proficiency)
	for proficiency_id: StringName in secondary_proficiencies:
		if not result.has(proficiency_id):
			result.append(proficiency_id)
	return result


## True if [param proficiencies] (id → level) meets every requirement.
func requirements_met(proficiencies: Dictionary) -> bool:
	for proficiency_id: StringName in requirements:
		if int(proficiencies.get(proficiency_id, 0)) < requirements[proficiency_id]:
			return false
	return true


func validate() -> PackedStringArray:
	var problems: PackedStringArray = super()
	if movement_type == null:
		problems.append("%s: no movement_type" % _label())
	if caps == null:
		problems.append("%s: no caps" % _label())
	if usable_weapon_types.has(null):
		problems.append("%s: usable_weapon_types contains an empty entry" % _label())
	if abilities.has(null):
		problems.append("%s: abilities contains an empty entry" % _label())
	return problems
