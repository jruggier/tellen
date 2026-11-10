@tool
class_name Reinforcement
extends Resource
## Units that arrive at the start of a faction's phase on a given turn
## (spec §8.5). Telegraphed reinforcements show warning markers on their
## tiles during the player phase before they arrive. Reinforcements never
## act on the phase they appear.

## Turn on which the units arrive.
@export_range(1, 999) var turn: int = 2
## Faction whose phase start brings them (also their faction).
@export var faction_id: StringName = &"enemy"
## Units and arrival cells. Each placement's faction is overridden by [member faction_id].
@export var placements: Array[UnitPlacement] = []
## Show warning markers on the arrival tiles beforehand.
@export var telegraph: bool = true


func validate() -> PackedStringArray:
	var problems := PackedStringArray()
	if placements.is_empty():
		problems.append("Reinforcement on turn %d has no units" % turn)
	for placement: UnitPlacement in placements:
		if placement == null:
			problems.append("Reinforcement on turn %d has an empty placement" % turn)
		else:
			problems.append_array(placement.validate())
	return problems
