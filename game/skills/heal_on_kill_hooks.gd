extends SkillHooks
## After defeating the opponent, restore params.pct percent of max HP.


func on_combat_end(ctx: SkillContext) -> void:
	if ctx.opponent == null or ctx.opponent.is_alive() or not ctx.owner.is_alive():
		return
	var max_hp: int = ctx.owner.max_hp(ctx.state.ruleset)
	var before: int = ctx.owner.current_hp
	ctx.owner.current_hp = mini(max_hp, before + maxi(1, floori(max_hp * int(ctx.param("pct", 20)) / 100.0)))
	if ctx.owner.current_hp > before:
		ctx.effects.append({"unit": ctx.owner.id, "heal": ctx.owner.current_hp - before, "text": ctx.skill.display_name})
