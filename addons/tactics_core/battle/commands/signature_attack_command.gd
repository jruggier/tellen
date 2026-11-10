class_name SignatureAttackCommand
extends AttackCommand
## An awakened unit's signature attack: a normal attack with the bonuses in
## its signature skill's params ([code]might[/code], [code]hit[/code],
## [code]crit[/code], [code]damage[/code], [code]no_counter[/code]).
## Usable once per awakening.


func get_type() -> StringName:
	return &"signature_attack"


## True if [param unit] can use its signature attack now (ignoring targets).
static func available(unit: UnitState) -> bool:
	return unit != null and unit.awakened and not unit.signature_used and unit.awakening != null and unit.awakening.signature != null


## Applies [param unit]'s signature bonuses to [param participant].
static func apply_signature(unit: UnitState, participant: CombatParticipant) -> void:
	var params: Dictionary = unit.awakening.signature.params
	for key: String in ["might", "hit", "crit", "damage"]:
		if params.has(key):
			participant.add_modifier(StringName(key), int(params[key]))
	if bool(params.get("no_counter", false)):
		participant.prevents_counter = true


func can_execute(state: BattleState) -> bool:
	return available(state.get_unit(attacker_id)) and super(state)


func _customize_attacker(state: BattleState, participant: CombatParticipant) -> void:
	var unit: UnitState = state.get_unit(attacker_id)
	apply_signature(unit, participant)
	unit.signature_used = true


func to_dict() -> Dictionary:
	var data: Dictionary = super()
	data["type"] = "signature_attack"
	return data
