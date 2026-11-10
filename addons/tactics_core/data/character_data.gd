@tool
class_name CharacterData
extends TacticsData
## A named character's identity for dialogue and UI: name, portraits by
## expression, name color. Gameplay stats live on [UnitData].
##
## [member TacticsData.id] is the speaker id used in dialogue scripts
## (e.g. TELLEN).

## Expression → portrait. Expected keys include neutral, happy, angry, sad
## and surprised; any other expression name is allowed.
@export var portraits: Dictionary[StringName, Texture2D] = {}

## Color of the speaker name in dialogue boxes.
@export var name_color: Color = Color.WHITE


## The portrait for [param expression], falling back to neutral, or null.
func get_portrait(expression: StringName) -> Texture2D:
	if portraits.has(expression):
		return portraits[expression]
	return portraits.get(&"neutral", null)
