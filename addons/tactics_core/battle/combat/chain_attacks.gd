class_name ChainAttacks
extends RefCounted
## Chain attacks (spec §9.4): after the main combat, every ally of the
## attacker that could hit the defender from its current tile with its
## equipped weapon (and is not Staggered) adds one strike for a fixed
## [code]chain_damage_pct[/code]% of the defender's max HP (at least 1).
## Chain strikes always land, cannot be countered, cannot crit and cannot
## Stagger. With [code]chain_can_kill[/code] off they stop at 1 HP.


## Allies that would join a chain attack on [param defender].
static func contributors(state: BattleState, attacker: UnitState, defender: UnitState) -> Array[UnitState]:
	var result: Array[UnitState] = []
	if state.ruleset == null or not state.ruleset.chain_attacks_enabled:
		return result
	for ally: UnitState in state.all_units():
		if ally == attacker or not ally.is_alive() or ally.faction_id != attacker.faction_id or ally.is_staggered():
			continue
		var weapon: WeaponData = ally.equipped_weapon()
		if weapon != null and weapon.is_in_range(BattleGrid.distance(ally.cell, defender.cell)):
			result.append(ally)
	return result


## Damage of one chain strike against [param defender].
static func strike_damage(state: BattleState, defender: UnitState) -> int:
	return maxi(1, floori(defender.max_hp(state.ruleset) * state.ruleset.chain_damage_pct / 100.0))


## Total chain damage and contributor count, if every strike lands in full.
static func preview(state: BattleState, attacker: UnitState, defender: UnitState) -> Vector2i:
	var allies: Array[UnitState] = contributors(state, attacker, defender)
	return Vector2i(strike_damage(state, defender) * allies.size(), allies.size())


## Appends chain strikes to [param result] (if the defender survived the
## main combat) and returns the contributors. Changes only [param result].
static func apply(state: BattleState, attacker: UnitState, defender: UnitState, result: CombatResult) -> Array[UnitState]:
	var joined: Array[UnitState] = []
	if result.defender_hp_after <= 0:
		return joined
	var per_strike: int = strike_damage(state, defender)
	for ally: UnitState in contributors(state, attacker, defender):
		if result.defender_hp_after <= 0:
			break
		var dealt: int = mini(per_strike, result.defender_hp_after)
		if not state.ruleset.chain_can_kill:
			dealt = mini(dealt, result.defender_hp_after - 1)
		if dealt <= 0:
			break
		var strike := Strike.new()
		strike.actor = Strike.Role.ATTACKER
		strike.kind = Strike.Kind.CHAIN
		strike.chain_unit_id = ally.id
		strike.hit = true
		strike.damage = dealt
		result.defender_hp_after -= dealt
		strike.target_hp_after = result.defender_hp_after
		strike.lethal = result.defender_hp_after <= 0
		result.strikes.append(strike)
		result.attacker_dealt_damage = true
		joined.append(ally)
	return joined
