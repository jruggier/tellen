class_name SkillHooks
extends RefCounted
## Base class for skill behavior (spec §9.3). A [SkillData] points at a
## script extending this; the script overrides only the hooks it needs.
## Hooks must be stateless (one instance is shared by every unit with the
## skill); per-skill numbers come from [member SkillData.params].
##
## Hooks (spec names in brackets):
## [br]- [method modify_participant] [modify_forecast]: change the owner's own
##   combat numbers. Runs for the forecast, the resolver and the AI alike.
## [br]- [method modify_ally_participant]: auras; change an ally's numbers
##   when that ally fights near the owner.
## [br]- [method on_combat_end]: react after a combat (heal on kill...).
## [br]- [method on_phase_start]: start of the owner's faction phase.
## [br]- [method grants_canto] [grants_action]: may move again after acting.
## [br]- [method modify_move_cost]: change terrain costs for the owner.


## Adjust [member SkillContext.subject] (the owner's participant).
func modify_participant(_ctx: SkillContext) -> void:
	pass


## Adjust [member SkillContext.subject], an ally of the owner in combat.
## [member SkillContext.distance] is the ally's distance from the owner.
func modify_ally_participant(_ctx: SkillContext) -> void:
	pass


## After a combat the owner took part in ([member SkillContext.result] set).
## Record visible effects in [member SkillContext.effects].
func on_combat_end(_ctx: SkillContext) -> void:
	pass


## At the start of the owner's faction phase.
func on_phase_start(_ctx: SkillContext) -> void:
	pass


## True if the owner may use leftover movement after acting.
func grants_canto(_ctx: SkillContext) -> bool:
	return false


## Movement cost of [param cell] for the owner (default: unchanged).
func modify_move_cost(_ctx: SkillContext, _cell: Vector2i, cost: int) -> int:
	return cost
