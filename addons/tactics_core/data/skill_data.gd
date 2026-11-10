@tool
class_name SkillData
extends TacticsData
## A skill: a passive or active effect implemented by a hooks script.
##
## Behavior lives in [member hooks_script], a script extending
## [code]SkillHooks[/code] (added in M5) that overrides only the hooks it
## needs. Skills with no script are flavor-only.

## Script extending SkillHooks that implements this skill.
@export var hooks_script: Script

## Menu/forecast icon.
@export var icon: Texture2D

## Free-form tags (e.g. "personality", "awakened_only").
@export var tags: Array[StringName] = []

## Numbers the hooks script reads (e.g. {"radius": 1, "amount": 2}), so one
## script can serve several tuned variants.
@export var params: Dictionary = {}


func validate() -> PackedStringArray:
	var problems: PackedStringArray = super()
	if hooks_script != null and not _extends_skill_hooks(hooks_script):
		problems.append("%s: hooks_script must extend SkillHooks" % _label())
	return problems


static func _extends_skill_hooks(script: Script) -> bool:
	var current: Script = script
	while current != null:
		if current.get_global_name() == &"SkillHooks":
			return true
		current = current.get_base_script()
	return false
