class_name HealCommand
extends Command
## Heals an injured ally with a healing weapon (spec §5.8), then awards
## heal EXP and proficiency. Ends the healer's action.

var healer_id: StringName
var target_id: StringName
var slot_index: int
## HP actually restored.
var amount: int = 0
var report: ProgressionService.Report


func _init(healing_unit: StringName = &"", target_unit: StringName = &"", staff_slot: int = 0) -> void:
	healer_id = healing_unit
	target_id = target_unit
	slot_index = staff_slot


func get_type() -> StringName:
	return &"heal"


func can_execute(state: BattleState) -> bool:
	var healer: UnitState = state.get_unit(healer_id)
	var target: UnitState = state.get_unit(target_id)
	if healer == null or target == null or not healer.is_ready() or not healer.heal_slot_indices().has(slot_index):
		return false
	if state.current_faction() != null and state.current_faction().id != healer.faction_id:
		return false
	return CombatContext.heal_targets(state, healer, healer.cell, healer.inventory[slot_index].weapon()).has(target)


func execute(state: BattleState) -> void:
	var healer: UnitState = state.get_unit(healer_id)
	var target: UnitState = state.get_unit(target_id)
	var staff: WeaponData = healer.inventory[slot_index].weapon()
	var power: int = state.ruleset.combat_rules.heal_amount(CombatContext.participant(state, healer, healer.cell, staff))
	var before: int = target.current_hp
	target.current_hp = mini(target.max_hp(state.ruleset), target.current_hp + power)
	amount = target.current_hp - before
	report = ProgressionService.Report.new()
	if ProgressionService.gains_experience(state, healer):
		var tier: int = healer.class_data.tier if healer.class_data != null else 0
		ProgressionService.award_exp(state, healer, state.ruleset.exp_rules.heal_exp(healer.level, tier), report)
		ProgressionService.train_proficiency(state, healer, staff.weapon_type.id, report)
	healer.has_moved = true
	healer.has_acted = true
	state.mark_changed()


func emit_events(events: Node) -> void:
	events.emit_signal(&"unit_healed", target_id, amount)
	for i: int in report.level_gains.size():
		events.emit_signal(&"level_up", healer_id, report.old_level + i + 1, report.level_gains[i])


func to_dict() -> Dictionary:
	return {"type": "heal", "healer": String(healer_id), "target": String(target_id), "slot": slot_index, "amount": amount}
