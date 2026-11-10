@tool
class_name UnitData
extends TacticsData
## A named unit as authored: personal stats and growths, starting class,
## level, inventory, skills and proficiencies.
##
## This is the template a battle unit is created from; battle-time state
## (current HP, position, statuses) lives in [code]UnitState[/code].
## Extension points: supports, sigils and permadeath flags add fields here.

## Dialogue/UI identity. May be null for generic units.
@export var character: CharacterData

@export var class_data: ClassData

@export_range(1, 99) var level: int = 1

## Personal base stats (including Build); class base stats are added on top.
@export var personal_base: StatBlock

## Personal growth rates in percent; class growth modifiers are added on top.
@export var personal_growths: StatBlock

## Starting inventory, in slot order.
@export var inventory: Array[ItemData] = []

## Equipped (slotted) skills. Class abilities are separate and always on.
@export var skills: Array[SkillData] = []

## Proficiency id → level.
@export var proficiencies: Dictionary[StringName, int] = {}

## Classes this unit may change into. Empty = any class whose requirements are met.
@export var class_tree: Array[ClassData] = []

## The protagonist: defeat means game over.
@export var is_lord: bool = false

## What awakening grants this unit (null = cannot awaken).
@export var awakening: AwakeningData

## Extra unit tags (movement type and class tags are added automatically).
@export var tags: Array[StringName] = []


func validate() -> PackedStringArray:
	var problems: PackedStringArray = super()
	if class_data == null:
		problems.append("%s: no class_data" % _label())
	if personal_base == null:
		problems.append("%s: no personal_base" % _label())
	if personal_growths == null:
		problems.append("%s: no personal_growths" % _label())
	if inventory.has(null):
		problems.append("%s: inventory contains an empty slot entry" % _label())
	if skills.has(null):
		problems.append("%s: skills contains an empty entry" % _label())
	if class_tree.has(null):
		problems.append("%s: class_tree contains an empty entry" % _label())
	return problems
