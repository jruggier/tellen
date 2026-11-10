class_name ObjectiveRules
extends RefCounted
## Decides whether a battle is won, lost or still going (spec §8.3).
##
## Defeat is checked first (a defeat condition met, or an objective failed).
## Victory needs every objective complete. Maps with no objectives default
## to Rout; maps with no defeat conditions default to "protagonist defeated"
## and "all units defeated".

enum Outcome { ONGOING, VICTORY, DEFEAT }


static func evaluate(state: BattleState, objectives: Array[Objective], defeat_conditions: Array[DefeatCondition]) -> Outcome:
	for condition: DefeatCondition in effective_defeat_conditions(defeat_conditions):
		if condition.is_met(state):
			return Outcome.DEFEAT
	var goals: Array[Objective] = effective_objectives(objectives)
	for objective: Objective in goals:
		if objective.is_failed(state):
			return Outcome.DEFEAT
	for objective: Objective in goals:
		if not objective.is_complete(state):
			return Outcome.ONGOING
	return Outcome.VICTORY


static func effective_objectives(objectives: Array[Objective]) -> Array[Objective]:
	var result: Array[Objective] = []
	for objective: Objective in objectives:
		if objective != null:
			result.append(objective)
	if result.is_empty():
		result.append(RoutObjective.new())
	return result


static func effective_defeat_conditions(conditions: Array[DefeatCondition]) -> Array[DefeatCondition]:
	var result: Array[DefeatCondition] = []
	for condition: DefeatCondition in conditions:
		if condition != null:
			result.append(condition)
	if result.is_empty():
		result.append(DefeatCondition.make(DefeatCondition.Kind.LORD_DEFEATED))
		result.append(DefeatCondition.make(DefeatCondition.Kind.ALL_UNITS_DEFEATED))
	return result
