@tool
class_name TriggerRegion
extends Resource
## A rectangle of cells that fires when a unit of [member faction_id] ends a
## move inside it (spec §8.6): wakes AI groups and sets map flags. Dialogue
## and other event actions hook in at M6 through [member event_id].

## Cells covered (position = top-left cell, size in cells).
@export var rect: Rect2i = Rect2i(0, 0, 1, 1)
## Faction whose units trigger it (empty = the human faction).
@export var faction_id: StringName = &""
## Fire only the first time.
@export var once: bool = true
## AI groups woken when it fires.
@export var wake_groups: Array[StringName] = []
## Map flags set to true when it fires.
@export var set_flags: Array[String] = []
## Event to run (dialogue etc., M6).
@export var event_id: StringName = &""


func validate() -> PackedStringArray:
	return PackedStringArray(["TriggerRegion has an empty rect"]) if rect.size.x <= 0 or rect.size.y <= 0 else PackedStringArray()
