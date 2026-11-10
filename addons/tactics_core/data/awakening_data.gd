@tool
class_name AwakeningData
extends TacticsData
## What a unit gains while awakened (spec §9.5): stat modifiers, extra
## skills and a signature attack usable once per awakening.
##
## Kept on [UnitData] so it can later come from a god's sigil
## ([code]SigilData[/code], data stub) without code changes.

## Added to the unit's stats while awakened.
@export var stat_modifiers: StatBlock
## Skills active only while awakened (they use no skill slots).
@export var skills: Array[SkillData] = []
## Signature attack: a skill whose params describe the special attack
## (might, hit, crit, no_counter...). Usable once per awakening.
@export var signature: SkillData
## Tint for the awakened map marker and UI.
@export var color: Color = Color(0.55, 0.85, 1.0)


func validate() -> PackedStringArray:
	var problems: PackedStringArray = super()
	if signature == null:
		problems.append("%s: no signature attack" % _label())
	if skills.has(null):
		problems.append("%s: skills contains an empty entry" % _label())
	return problems
