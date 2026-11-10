class_name CombatResolver
extends RefCounted
## Resolves a combat into a [CombatResult] (spec §5.7). Headless and
## deterministic: the same participants and RNG state give the same result.
##
## Sequence:
## [br]0. A defender with [member CombatParticipant.strikes_first] (Vantage)
##    counters first; the attacker then strikes and step 3 is skipped.
## [br]1. Attacker strikes (twice with a brave weapon).
## [br]2. Stagger check: a hit that the defender survives Staggers it if the
##    rules say the attacker's weapon staggers the defender's.
## [br]3. Defender counters if alive and able (Stagger never blocks counters).
## [br]4. Follow-up for whichever side has the Skill lead, if both are alive,
##    it can strike, and it is not Staggered (this combat or carried over).
## [br]Chain attacks (§9.4) are added in M5 after step 4.
##
## Each strike rolls hit, then crit only if it hit. The resolver does not
## modify participants; battle state applies the result.


## Resolves [param attacker] attacking [param defender] at [param distance].
static func resolve(rules: CombatRules, attacker: CombatParticipant, defender: CombatParticipant, distance: int, rng: SeededRng) -> CombatResult:
	var result := CombatResult.new()
	result.attacker_hp_start = attacker.current_hp
	result.defender_hp_start = defender.current_hp
	var hp: Dictionary[Strike.Role, int] = {Strike.Role.ATTACKER: attacker.current_hp, Strike.Role.DEFENDER: defender.current_hp}
	var units: Dictionary[Strike.Role, CombatParticipant] = {Strike.Role.ATTACKER: attacker, Strike.Role.DEFENDER: defender}

	var attacker_can_strike: bool = rules.can_strike_at(attacker, distance)
	var defender_can_counter: bool = rules.can_counter(defender, attacker, distance)
	var defender_staggered_now: bool = false
	var defender_first: bool = defender_can_counter and defender.strikes_first and not attacker.strikes_first

	# 0. Vantage: the defender strikes first.
	if defender_first:
		_strike_turn(result, rules, units, hp, Strike.Role.DEFENDER, Strike.Kind.COUNTER, 100, rng)

	# 1-2. Attacker strikes, then Stagger check.
	if attacker_can_strike and _both_alive(hp):
		var landed: bool = _strike_turn(result, rules, units, hp, Strike.Role.ATTACKER, Strike.Kind.INITIAL, 100, rng)
		if landed and hp[Strike.Role.DEFENDER] > 0 and rules.inflicts_stagger(attacker, defender):
			defender_staggered_now = true
			result.defender_staggered = true
			_last_strike_by(result, Strike.Role.ATTACKER).staggered = true

	# 3. Counter.
	if defender_can_counter and not defender_first and _both_alive(hp):
		_strike_turn(result, rules, units, hp, Strike.Role.DEFENDER, Strike.Kind.COUNTER, 100, rng)

	# 4. Follow-up (the rules guarantee at most one side has the lead).
	if _both_alive(hp):
		var attacker_pct: int = rules.follow_up_percent(attacker, defender) if attacker_can_strike else 0
		var defender_pct: int = 0
		if defender_can_counter and rules.defender_can_follow_up() and not defender_staggered_now:
			defender_pct = rules.follow_up_percent(defender, attacker)
		if attacker_pct > 0:
			_strike_turn(result, rules, units, hp, Strike.Role.ATTACKER, Strike.Kind.FOLLOW_UP, attacker_pct, rng)
		elif defender_pct > 0:
			_strike_turn(result, rules, units, hp, Strike.Role.DEFENDER, Strike.Kind.FOLLOW_UP, defender_pct, rng)

	result.attacker_hp_after = hp[Strike.Role.ATTACKER]
	result.defender_hp_after = hp[Strike.Role.DEFENDER]
	for strike: Strike in result.strikes:
		if strike.damage > 0:
			if strike.actor == Strike.Role.ATTACKER:
				result.attacker_dealt_damage = true
			else:
				result.defender_dealt_damage = true
	return result


## Performs one attack turn (1 strike, or 2 with a brave weapon). Returns
## true if any strike hit.
static func _strike_turn(result: CombatResult, rules: CombatRules, units: Dictionary, hp: Dictionary,
		actor_side: Strike.Role, kind: Strike.Kind, percent: int, rng: SeededRng) -> bool:
	var actor: CombatParticipant = units[actor_side]
	var target_side: Strike.Role = Strike.Role.DEFENDER if actor_side == Strike.Role.ATTACKER else Strike.Role.ATTACKER
	var target: CombatParticipant = units[target_side]
	var base_damage: int = rules.damage(actor, target)
	if kind == Strike.Kind.FOLLOW_UP:
		base_damage = rules.follow_up_damage(base_damage, percent)
	var hit_chance: int = rules.displayed_hit(actor, target)
	var crit_chance: int = rules.displayed_crit(actor, target)
	var effective: bool = rules.is_effective(actor, target)
	var any_hit: bool = false
	for i: int in rules.strikes_per_turn(actor):
		if hp[target_side] <= 0 or hp[actor_side] <= 0:
			break
		var strike := Strike.new()
		strike.actor = actor_side
		strike.kind = kind
		strike.effective = effective
		strike.hit = rules.roll_hit(rng, hit_chance)
		if strike.hit:
			any_hit = true
			strike.crit = rules.roll_crit(rng, crit_chance)
			var dealt: int = rules.crit_damage(base_damage) if strike.crit else base_damage
			strike.damage = mini(dealt, hp[target_side])
			hp[target_side] -= strike.damage
			strike.lethal = hp[target_side] <= 0
		strike.target_hp_after = hp[target_side]
		result.strikes.append(strike)
	return any_hit


static func _both_alive(hp: Dictionary) -> bool:
	return hp[Strike.Role.ATTACKER] > 0 and hp[Strike.Role.DEFENDER] > 0


static func _last_strike_by(result: CombatResult, side: Strike.Role) -> Strike:
	for i: int in range(result.strikes.size() - 1, -1, -1):
		if result.strikes[i].actor == side:
			return result.strikes[i]
	return null
