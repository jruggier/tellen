class_name DialogueScript
extends RefCounted
## A parsed dialogue scene: commands in order plus label positions.

var id: StringName = &""
## File the scene came from (for error messages).
var source: String = ""
var commands: Array[DialogueCommand] = []
## Label name → index of the label command.
var labels: Dictionary[String, int] = {}


## Speaker ids used in the scene (lines and @show), upper case.
func speakers() -> PackedStringArray:
	var result := PackedStringArray()
	for command: DialogueCommand in commands:
		if not command.speaker.is_empty() and not result.has(command.speaker):
			result.append(command.speaker)
	return result
