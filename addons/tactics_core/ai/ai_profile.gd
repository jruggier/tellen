@tool
class_name AIProfile
extends Resource
## How an AI unit behaves and what it values (spec §10).
##
## The behavior picks where the unit may go and when it engages; the
## weights rank every (destination, target) option through [AIScorer].

enum Behavior {
	## Moves toward and attacks the best target anywhere.
	CHARGE,
	## Attacks only targets reachable this turn; otherwise stays.
	HOLD,
	## Never moves; attacks targets in range of its tile.
	STATIONARY,
	## Waits (as STATIONARY) until a hostile unit enters its region or it is
	## attacked, then charges. Wakes its whole [code]ai_group[/code].
	AGGRO_REGION,
	## Stays within [member guard_radius] of [member guard_cell]; attacks
	## anything it can reach from there.
	GUARD,
	## Charges, but below [member flee_hp_pct] retreats from danger.
	COWARD,
	## Heals the most valuable wounded ally in reach; otherwise keeps away
	## from danger near its allies.
	HEALER,
}

@export var behavior: Behavior = Behavior.CHARGE

@export_group("Weights")
## Per point of expected damage dealt.
@export var w_damage: float = 1.0
## Per 100% chance to defeat the target.
@export var w_kill: float = 30.0
## Per 100% chance to Stagger the target.
@export var w_stagger: float = 6.0
## Per point of target priority (lord, healers, low HP, effectiveness).
@export var w_priority: float = 4.0
## Per point of expected damage taken.
@export var w_risk: float = 0.6
## Per point of terrain value at the destination.
@export var w_terrain: float = 0.15

@export_group("Behavior settings")
## AGGRO_REGION: cells that wake this unit when a hostile unit enters.
@export var trigger_region: Rect2i = Rect2i()
## GUARD: tile to guard.
@export var guard_cell: Vector2i = Vector2i.ZERO
## GUARD: how far from the guard tile the unit may go.
@export_range(0, 30) var guard_radius: int = 3
## COWARD: retreat below this HP percent.
@export_range(0, 100) var flee_hp_pct: int = 40
## COWARD: tile to flee toward; (-1, -1) = simply away from danger.
@export var flee_cell: Vector2i = Vector2i(-1, -1)


## The behavior used when a unit has no profile.
static func default_profile() -> AIProfile:
	return AIProfile.new()
