extends SkillHooks
## While the owner's HP is at or below params.hp_pct percent, add
## params.amount to the combat modifier params.modifier.


func modify_participant(ctx: SkillContext) -> void:
	var max_hp: int = ctx.owner.max_hp(ctx.state.ruleset)
	if ctx.owner.current_hp * 100 <= max_hp * int(ctx.param("hp_pct", 50)):
		ctx.subject.add_modifier(StringName(str(ctx.param("modifier", "avoid"))), int(ctx.param("amount", 20)))
