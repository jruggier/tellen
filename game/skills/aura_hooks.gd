extends SkillHooks
## Aura: allies within params.radius get params.amount added to the combat
## modifier params.modifier (e.g. "defense", "avoid").


func modify_ally_participant(ctx: SkillContext) -> void:
	if ctx.distance <= int(ctx.param("radius", 1)):
		ctx.subject.add_modifier(StringName(str(ctx.param("modifier", "defense"))), int(ctx.param("amount", 2)))
