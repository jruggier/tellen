@tool
class_name CrossroadsGrowthRules
extends GrowthRules
## Ruined Crossroads level-up rules (spec §6.2).
##
## Modes:
## [br]- RANDOM: each stat gains ⌊g/100⌋ guaranteed points plus one roll at g mod 100.
## [br]- FIXED: g is added to a hidden counter; every full 100 is +1. Exact.
## [br]- HYBRID: [member hybrid_fixed_pct]% of g goes to the counter; the
##   rest is one random roll.

enum GrowthMode { RANDOM, FIXED, HYBRID }

@export var growth_mode: GrowthMode = GrowthMode.RANDOM

## Counter value a stat starts at in FIXED/HYBRID mode.
@export_range(0, 99) var fixed_counter_start: int = 0

## Share of each growth that accumulates deterministically in HYBRID mode.
@export_range(0, 100) var hybrid_fixed_pct: int = 80


func roll_level_up(growths: StatBlock, growable_stats: Array[StringName], rng: SeededRng, counters: Dictionary) -> StatBlock:
	var gains := StatBlock.new()
	for stat_id: StringName in growable_stats:
		var growth: int = maxi(0, growths.get_value(stat_id))
		var gain: int = 0
		match growth_mode:
			GrowthMode.FIXED:
				gain = _accumulate(counters, stat_id, growth)
			GrowthMode.HYBRID:
				var fixed_part: int = floori(growth * hybrid_fixed_pct / 100.0)
				gain = _accumulate(counters, stat_id, fixed_part)
				gain += _roll(growth - fixed_part, rng)
			_:
				gain = _roll(growth, rng)
		if gain != 0:
			gains.set_value(stat_id, gain)
	return gains


## Guaranteed points plus one roll for the remainder.
func _roll(percent: int, rng: SeededRng) -> int:
	var gain: int = floori(percent / 100.0)
	var remainder: int = percent % 100
	if remainder > 0 and rng.roll_100(TacticsIds.STREAM_GROWTH) < remainder:
		gain += 1
	return gain


func _accumulate(counters: Dictionary, stat_id: StringName, percent: int) -> int:
	var total: int = int(counters.get(stat_id, fixed_counter_start)) + percent
	counters[stat_id] = total % 100
	return floori(total / 100.0)
