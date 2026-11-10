class_name CombatForecast
extends RefCounted
## Predicted numbers for a combat, for the UI forecast panel and the AI.
##
## Built only from [CombatRules] calls, the same ones [CombatResolver] uses,
## so the forecast always matches what actually happens. Building a
## forecast never changes any participant.
##
## [method build] creates participants from battle state (spec §5.9);
## [method calculate] works on participants directly (tests, Combat Lab).


## Forecast numbers for one side.
class SideForecast:
	extends RefCounted
	## Damage per normal strike (0 if this side cannot strike).
	var damage: int = 0
	## Displayed hit chance.
	var hit: int = 0
	## Displayed crit chance.
	var crit: int = 0
	## Damage of a critical normal strike.
	var crit_damage: int = 0
	## True if this side can strike at all (attacker attacks, defender counters).
	var can_strike: bool = false
	## Strikes per attack turn (2 with a brave weapon).
	var strikes_per_turn: int = 0
	## Follow-up strength in percent (0 = none). Already 0 if Staggered.
	var follow_up_percent: int = 0
	## Damage of one follow-up strike.
	var follow_up_damage: int = 0
	## The follow-up only happens if the attacker's first strikes miss
	## (a hit would Stagger this side). Defender side only.
	var follow_up_cancelled_by_stagger: bool = false
	## Total strikes if nothing is cancelled (normal + follow-up).
	var total_strikes: int = 0
	## Weapon is effective against the other side.
	var effective: bool = false
	## Unit is Staggered from an earlier combat (cannot follow up).
	var staggered: bool = false
	## HP at the start.
	var hp: int = 0
	## HP if every strike against this side hits (no crits), with Stagger applied.
	var hp_after_all_hits: int = 0
	## Expected damage this side receives (hit chance, crits, follow-ups).
	var expected_damage_taken: float = 0.0


## Attacker (initiator) numbers.
var attacker: SideForecast = SideForecast.new()
## Defender numbers.
var defender: SideForecast = SideForecast.new()
## A hit from the attacker will Stagger the defender (if it survives).
var stagger_on_hit: bool = false
## Distance between the two units.
var distance: int = 1


## Forecast for [param attacker] attacking [param defender] from
## [param attacker_tile] with its equipped weapon (spec §5.9).
static func build(state: BattleState, attacker: UnitState, defender: UnitState, attacker_tile: Vector2i) -> CombatForecast:
	return CombatContext.forecast(state, attacker, defender, attacker_tile, attacker.equipped_weapon())


## Computes a forecast for [param attacker_p] attacking [param defender_p]
## from [param attack_distance] tiles away.
static func calculate(rules: CombatRules, attacker_p: CombatParticipant, defender_p: CombatParticipant, attack_distance: int) -> CombatForecast:
	var forecast := CombatForecast.new()
	forecast.distance = attack_distance
	forecast.stagger_on_hit = rules.can_strike_at(attacker_p, attack_distance) and rules.inflicts_stagger(attacker_p, defender_p)
	_fill_side(forecast.attacker, rules, attacker_p, defender_p, rules.can_strike_at(attacker_p, attack_distance))
	_fill_side(forecast.defender, rules, defender_p, attacker_p, rules.can_counter(defender_p, attacker_p, attack_distance))
	if not rules.defender_can_follow_up():
		forecast.defender.follow_up_percent = 0
		forecast.defender.follow_up_damage = 0
	forecast.defender.follow_up_cancelled_by_stagger = forecast.stagger_on_hit and forecast.defender.follow_up_percent > 0
	for side: SideForecast in [forecast.attacker, forecast.defender]:
		side.total_strikes = side.strikes_per_turn * (2 if side.follow_up_percent > 0 else 1) if side.can_strike else 0
	_predict(forecast, rules)
	return forecast


static func _fill_side(side: SideForecast, rules: CombatRules, actor: CombatParticipant, target: CombatParticipant, can_strike: bool) -> void:
	side.hp = actor.current_hp
	side.staggered = actor.staggered
	side.can_strike = can_strike
	if not can_strike:
		return
	side.damage = rules.damage(actor, target)
	side.hit = rules.displayed_hit(actor, target)
	side.crit = rules.displayed_crit(actor, target)
	side.crit_damage = rules.crit_damage(side.damage)
	side.strikes_per_turn = rules.strikes_per_turn(actor)
	side.follow_up_percent = rules.follow_up_percent(actor, target)
	side.follow_up_damage = rules.follow_up_damage(side.damage, side.follow_up_percent)
	side.effective = rules.is_effective(actor, target)


## Fills HP predictions: all-hits HP (with Stagger cancelling the defender's
## follow-up) and expected damage taken.
static func _predict(forecast: CombatForecast, rules: CombatRules) -> void:
	var a: SideForecast = forecast.attacker
	var d: SideForecast = forecast.defender
	var a_hp: int = a.hp
	var d_hp: int = d.hp
	# Order: attacker turn, defender counter, follow-up (only one side can lead).
	if a.can_strike:
		d_hp -= a.damage * a.strikes_per_turn
	if d.can_strike and d_hp > 0:
		a_hp -= d.damage * d.strikes_per_turn
	if a_hp > 0 and d_hp > 0:
		if a.follow_up_percent > 0:
			d_hp -= a.follow_up_damage * a.strikes_per_turn
		elif d.follow_up_percent > 0 and not forecast.stagger_on_hit:
			a_hp -= d.follow_up_damage * d.strikes_per_turn
	a.hp_after_all_hits = maxi(0, a_hp)
	d.hp_after_all_hits = maxi(0, d_hp)
	d.expected_damage_taken = _expected(a, rules)
	a.expected_damage_taken = _expected(d, rules)


## Expected damage a side deals, ignoring kills cutting combat short.
static func _expected(side: SideForecast, rules: CombatRules) -> float:
	if not side.can_strike:
		return 0.0
	var hit_chance: float = rules.true_hit_chance(side.hit) / 100.0
	var crit_chance: float = side.crit / 100.0
	var per_strike: float = hit_chance * (side.damage + crit_chance * (side.crit_damage - side.damage))
	var follow_crit: int = rules.crit_damage(side.follow_up_damage)
	var per_follow: float = hit_chance * (side.follow_up_damage + crit_chance * (follow_crit - side.follow_up_damage))
	return side.strikes_per_turn * (per_strike + (per_follow if side.follow_up_percent > 0 else 0.0))
