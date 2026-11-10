@tool
class_name FactionData
extends TacticsData
## A side in battle (player, enemy, allied NPCs...). Phases run in faction order.

enum Controller { HUMAN, AI }

## Who issues this faction's commands.
@export var controller: Controller = Controller.AI

## Tint for unit sprites, range overlays and the phase banner.
@export var color: Color = Color.WHITE

## Ids of factions this one never attacks (and that never attack it).
@export var allied_with: Array[StringName] = []

## Units of this faction earn EXP, level up and train proficiencies.
@export var gains_experience: bool = false


## True if this faction is allied with (or is) [param faction_id].
func is_allied_with(faction_id: StringName) -> bool:
	return faction_id == id or allied_with.has(faction_id)
