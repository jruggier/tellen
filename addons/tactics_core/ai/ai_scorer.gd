class_name AIScorer
extends RefCounted
## Scores attack options for the AI (spec §10.2):
## [codeblock]
## score = w_damage * expected_damage_dealt
##       + w_kill * kill_probability
##       + w_stagger * (stagger_on_hit ? hit chance : 0)
##       + w_priority * target_priority
##       - w_risk * expected_damage_taken
##       + w_terrain * terrain_value(destination)
## [/codeblock]
## Uses [CombatForecast] so the AI sees exactly what the player sees.


## One scored option.
class Option:
	extends RefCounted
	var destination: Vector2i
	var target_id: StringName
	var slot: int
	var score: float
	var kill_chance: float
	var forecast: CombatForecast


## Scores [param unit] attacking [param target] from [param cell] with the
## weapon in [param slot].
static func score_attack(state: BattleState, unit: UnitState, cell: Vector2i, target: UnitState, slot: int, profile: AIProfile) -> Option:
	var weapon: WeaponData = unit.inventory[slot].weapon()
	var forecast: CombatForecast = CombatContext.forecast(state, unit, target, cell, weapon)
	var rules: CombatRules = state.ruleset.combat_rules
	var option := Option.new()
	option.destination = cell
	option.target_id = target.id
	option.slot = slot
	option.forecast = forecast
	option.kill_chance = kill_probability(forecast, rules)
	var stagger_value: float = rules.true_hit_chance(forecast.attacker.hit) / 100.0 if forecast.stagger_on_hit else 0.0
	var chain: int = ChainAttacks.preview(state, unit, target).x if forecast.defender.hp_after_all_hits > 0 else 0
	option.score = profile.w_damage * (forecast.defender.expected_damage_taken + chain) \
		+ profile.w_kill * option.kill_chance \
		+ profile.w_stagger * stagger_value \
		+ profile.w_priority * target_priority(state, unit, target, weapon) \
		- profile.w_risk * forecast.attacker.expected_damage_taken \
		+ profile.w_terrain * terrain_value(state, cell)
	return option


## Chance the attacker's strikes (normal turn, then follow-up) defeat the
## defender, ignoring the counter. Exact over hit/crit outcomes.
static func kill_probability(forecast: CombatForecast, rules: CombatRules) -> float:
	var side: CombatForecast.SideForecast = forecast.attacker
	if not side.can_strike:
		return 0.0
	var hit: float = rules.true_hit_chance(side.hit) / 100.0
	var crit: float = side.crit / 100.0
	var strikes: Array[Vector2i] = []
	for i: int in side.strikes_per_turn:
		strikes.append(Vector2i(side.damage, side.crit_damage))
	if side.follow_up_percent > 0 and not forecast.defender.staggered:
		for i: int in side.strikes_per_turn:
			strikes.append(Vector2i(side.follow_up_damage, rules.crit_damage(side.follow_up_damage)))
	var hp_odds: Dictionary[int, float] = {forecast.defender.hp: 1.0}
	var dead: float = 0.0
	for strike: Vector2i in strikes:
		var next: Dictionary[int, float] = {}
		for hp: int in hp_odds:
			var p: float = hp_odds[hp]
			var outcomes: Array[Vector2] = [Vector2(hp, 1.0 - hit), Vector2(hp - strike.x, hit * (1.0 - crit)), Vector2(hp - strike.y, hit * crit)]
			for outcome: Vector2 in outcomes:
				if outcome.y <= 0.0:
					continue
				if outcome.x <= 0:
					dead += p * outcome.y
				else:
					next[int(outcome.x)] = next.get(int(outcome.x), 0.0) + p * outcome.y
		hp_odds = next
	return clampf(dead, 0.0, 1.0)


## How much the AI wants to hit [param target]: protagonists, healers,
## wounded units and units its weapon is effective against.
static func target_priority(state: BattleState, unit: UnitState, target: UnitState, weapon: WeaponData) -> float:
	var priority: float = 0.0
	if target.is_lord:
		priority += 3.0
	if not target.heal_slot_indices().is_empty():
		priority += 2.0
	priority += 2.0 * (1.0 - float(target.current_hp) / maxf(1.0, target.max_hp(state.ruleset)))
	if weapon != null and weapon.is_effective_against(target.get_tags()):
		priority += 1.0
	return priority


## How good a tile is to stand on (avoid, defense, healing).
static func terrain_value(state: BattleState, cell: Vector2i) -> float:
	var terrain: TerrainData = state.grid.terrain_at(cell)
	if terrain == null:
		return 0.0
	return terrain.avoid_bonus / 5.0 + terrain.defense_bonus * 2.0 + terrain.heal_percent / 10.0
