class_name Strike
extends RefCounted
## One resolved strike within a combat. Presentation replays these in order.

## Which side acted.
enum Role { ATTACKER, DEFENDER }

## Why the strike happened.
enum Kind { INITIAL, COUNTER, FOLLOW_UP, CHAIN }

var actor: Role = Role.ATTACKER
var kind: Kind = Kind.INITIAL
var hit: bool = false
var crit: bool = false
## HP removed from the target (0 on a miss; already capped at remaining HP).
var damage: int = 0
## Target HP after this strike.
var target_hp_after: int = 0
## This strike Staggered the target.
var staggered: bool = false
## The weapon was effective against the target.
var effective: bool = false
## This strike defeated the target.
var lethal: bool = false
## For CHAIN strikes: the ally who struck.
var chain_unit_id: StringName = &""


## The side receiving the strike.
func target() -> Role:
	return Role.DEFENDER if actor == Role.ATTACKER else Role.ATTACKER


## Serializable form for logs, replays and tests.
func to_dict() -> Dictionary:
	return {
		"actor": Role.keys()[actor], "kind": Kind.keys()[kind], "hit": hit, "crit": crit, "damage": damage,
		"target_hp_after": target_hp_after, "staggered": staggered, "effective": effective, "lethal": lethal,
		"chain_unit": String(chain_unit_id),
	}
