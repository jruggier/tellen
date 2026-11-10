extends SkillHooks
## Strikes first when attacked during the enemy's phase.


func modify_participant(ctx: SkillContext) -> void:
	if not ctx.is_initiator and ctx.is_enemy_phase():
		ctx.subject.strikes_first = true
