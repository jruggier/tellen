class_name SkillContext
extends RefCounted
## Everything a [SkillHooks] call can see. Fields not relevant to a hook
## are left at their defaults.

var state: BattleState
var skill: SkillData
## The unit that has the skill.
var owner: UnitState
## The participant being modified (owner's own, or an ally's for auras).
var subject: CombatParticipant
## The unit [member subject] belongs to.
var subject_unit: UnitState
## The other side of the combat, if any.
var opponent: UnitState
## True if [member subject_unit] started the combat.
var is_initiator: bool = false
## Distance between owner and subject unit (auras).
var distance: int = 0
## Cell the subject unit fights from (may be a hypothetical destination).
var cell: Vector2i = Vector2i.ZERO
## The finished combat (on_combat_end).
var result: CombatResult
## The owner's side in [member result].
var role: Strike.Role = Strike.Role.ATTACKER
## Visible effects recorded by hooks: {"unit": id, "heal": n, "text": key}.
var effects: Array[Dictionary] = []


## A skill parameter with a default.
func param(key: String, default_value: Variant) -> Variant:
	return skill.params.get(key, default_value) if skill != null else default_value


## True if the combat is happening during the owner's opponent's phase.
func is_enemy_phase() -> bool:
	var current: FactionData = state.current_faction()
	return current != null and owner != null and current.id != owner.faction_id
