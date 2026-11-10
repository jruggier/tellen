@tool
class_name WeaponType
extends TacticsData
## A category of weapon (e.g. sword, tome, bow) and its Stagger relationships.
##
## Stagger links are stored as weapon type ids, not resource references,
## because they form loops (A staggers B staggers C staggers A) and circular
## references between resource files cannot load reliably. Ids resolve
## through the active [Ruleset].
##
## The weapon type id doubles as the proficiency id for that weapon type.

## Ids of weapon types that this type Staggers when its wielder attacks.
@export var staggers: Array[StringName] = []

## If true, wielders of this type can neither be Staggered nor inflict Stagger.
@export var stagger_exempt: bool = false

## Icon shown in menus and the forecast.
@export var icon: Texture2D


## True if an attacker wielding this type Staggers a defender wielding [param target].
func staggers_type(target: WeaponType) -> bool:
	if target == null or stagger_exempt or target.stagger_exempt:
		return false
	return staggers.has(target.id)


func validate() -> PackedStringArray:
	var problems: PackedStringArray = super()
	if stagger_exempt and not staggers.is_empty():
		problems.append("%s: stagger_exempt but lists staggers %s" % [_label(), staggers])
	if staggers.has(id):
		problems.append("%s: staggers itself" % _label())
	return problems
