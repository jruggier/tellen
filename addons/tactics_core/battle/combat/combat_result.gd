class_name CombatResult
extends RefCounted
## Outcome of one resolved combat: the ordered strikes and final state.
##
## The resolver fills this; battle state applies it (HP, Stagger, defeats,
## EXP) and presentation replays [member strikes]. Logic never waits on
## animation.

## Strikes in the order they happened.
var strikes: Array[Strike] = []

var attacker_hp_start: int = 0
var defender_hp_start: int = 0
var attacker_hp_after: int = 0
var defender_hp_after: int = 0

## The defender was newly Staggered in this combat.
var defender_staggered: bool = false

## True if the side dealt any damage (for EXP).
var attacker_dealt_damage: bool = false
var defender_dealt_damage: bool = false


func attacker_defeated() -> bool:
	return attacker_hp_after <= 0


func defender_defeated() -> bool:
	return defender_hp_after <= 0


## Strikes by [param side].
func strikes_by(side: Strike.Role) -> Array[Strike]:
	return strikes.filter(func(strike: Strike) -> bool: return strike.actor == side)


## Serializable form for logs, replays and tests.
func to_dict() -> Dictionary:
	var strike_dicts: Array[Dictionary] = []
	for strike: Strike in strikes:
		strike_dicts.append(strike.to_dict())
	return {
		"strikes": strike_dicts,
		"attacker_hp": [attacker_hp_start, attacker_hp_after],
		"defender_hp": [defender_hp_start, defender_hp_after],
		"defender_staggered": defender_staggered,
	}
