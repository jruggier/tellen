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
