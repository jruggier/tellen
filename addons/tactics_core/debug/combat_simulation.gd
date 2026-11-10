class_name CombatSimulation
extends RefCounted
## Runs many seeded combats between two participants and summarizes them.
## Headless; used by the Combat Lab and by balance tests.

## Results of a simulation batch.
class Summary:
	extends RefCounted
	var combats: int = 0
	var attacker_kills: int = 0
	var defender_kills: int = 0
	var attacker_damage_total: int = 0
	var defender_damage_total: int = 0
	var attacker_hits: int = 0
	var attacker_crits: int = 0
	var defender_hits: int = 0
	var defender_crits: int = 0
	var staggers: int = 0
	var attacker_follow_ups: int = 0
	var defender_follow_ups: int = 0

	func pct(count: int, total: int) -> float:
		return 100.0 * count / total if total > 0 else 0.0

	func attacker_win_pct() -> float: return pct(attacker_kills, combats)
	func defender_win_pct() -> float: return pct(defender_kills, combats)
	func both_survive_pct() -> float: return pct(combats - attacker_kills - defender_kills, combats)
	func attacker_avg_damage() -> float: return float(attacker_damage_total) / combats if combats > 0 else 0.0
	func defender_avg_damage() -> float: return float(defender_damage_total) / combats if combats > 0 else 0.0
	## Crits as a percent of hits.
	func attacker_crit_pct() -> float: return pct(attacker_crits, attacker_hits)
	func defender_crit_pct() -> float: return pct(defender_crits, defender_hits)
	func stagger_pct() -> float: return pct(staggers, combats)
	## Combats in which the side made at least one follow-up strike.
	func attacker_follow_up_pct() -> float: return pct(attacker_follow_ups, combats)
	func defender_follow_up_pct() -> float: return pct(defender_follow_ups, combats)


## Simulates [param count] combats. Combat i uses seed [param base_seed] + i.
static func run(rules: CombatRules, attacker: CombatParticipant, defender: CombatParticipant, distance: int, count: int, base_seed: int) -> Summary:
	var summary := Summary.new()
	var rng := SeededRng.new(base_seed)
	for i: int in count:
		rng.reseed(base_seed + i)
		var result: CombatResult = CombatResolver.resolve(rules, attacker, defender, distance, rng)
		summary.combats += 1
		if result.defender_defeated():
			summary.attacker_kills += 1
		if result.attacker_defeated():
			summary.defender_kills += 1
		if result.defender_staggered:
			summary.staggers += 1
		var attacker_followed: bool = false
		var defender_followed: bool = false
		for strike: Strike in result.strikes:
			var by_attacker: bool = strike.actor == Strike.Role.ATTACKER
			if by_attacker:
				summary.attacker_damage_total += strike.damage
				summary.attacker_hits += 1 if strike.hit else 0
				summary.attacker_crits += 1 if strike.crit else 0
				attacker_followed = attacker_followed or strike.kind == Strike.Kind.FOLLOW_UP
			else:
				summary.defender_damage_total += strike.damage
				summary.defender_hits += 1 if strike.hit else 0
				summary.defender_crits += 1 if strike.crit else 0
				defender_followed = defender_followed or strike.kind == Strike.Kind.FOLLOW_UP
		summary.attacker_follow_ups += 1 if attacker_followed else 0
		summary.defender_follow_ups += 1 if defender_followed else 0
	return summary
