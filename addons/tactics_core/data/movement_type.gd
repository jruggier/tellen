@tool
class_name MovementType
extends TacticsData
## A way of moving across terrain (e.g. on foot, mounted, flying, armored).
##
## Terrain costs per movement type live on [TerrainData]. Movement types also
## act as unit tags (a flying unit is tagged with its movement type id) so
## weapons can be effective against them.

## If true, units of this movement type can never be Staggered.
@export var stagger_immune: bool = false

## Extra tags granted to units of this movement type.
@export var tags: Array[StringName] = []
