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

## Sound id of the "voice" blip played while this character's lines type out.
@export var voice: StringName = &"text_blip"
## Pitch of the voice blip (1 = as recorded; higher sounds younger/lighter).
@export_range(0.3, 3.0, 0.05) var voice_pitch: float = 1.0


## The portrait for [param expression], falling back to neutral, or null.
func get_portrait(expression: StringName) -> Texture2D:
	if portraits.has(expression):
		return portraits[expression]
	return portraits.get(&"neutral", null)
