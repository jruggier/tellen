class_name CombatFixtures
extends RefCounted
## In-code combat fixtures from spec §9.2 (weapons) and §13.2 (units).
##
## Used by rule tests so formulas can be checked independently of the
## authored .tres content.


static func weapon_type(type_id: StringName, staggers: Array[StringName] = [], exempt: bool = false) -> WeaponType:
	var result := WeaponType.new()
	result.id = type_id
	result.staggers = staggers
	result.stagger_exempt = exempt
	return result


static var SWORD: WeaponType = weapon_type(&"sword", [&"axe"])
static var AXE: WeaponType = weapon_type(&"axe", [&"lance"])
static var LANCE: WeaponType = weapon_type(&"lance", [&"sword"])
static var KNIFE: WeaponType = weapon_type(&"knife", [&"gauntlet"])
static var GAUNTLET: WeaponType = weapon_type(&"gauntlet", [&"tome"])
static var TOME: WeaponType = weapon_type(&"tome", [&"knife"])
static var BOW: WeaponType = weapon_type(&"bow", [], true)


static func weapon(weapon_id: StringName, type: WeaponType, might: int, hit: int, crit: int, crit_evade: int, weight: int,
		range_min: int = 1, range_max: int = 1, magic: bool = false) -> WeaponData:
	var result := WeaponData.new()
	result.id = weapon_id
	result.weapon_type = type
	result.might = might
	result.hit = hit
	result.crit = crit
	result.crit_evade = crit_evade
	result.weight = weight
	result.range_min = range_min
	result.range_max = range_max
	result.damage_type = WeaponData.DamageType.MAGIC if magic else WeaponData.DamageType.PHYSICAL
	return result


static func iron_sword() -> WeaponData: return weapon(&"iron_sword", SWORD, 5, 80, 0, 5, 5)
static func steel_sword() -> WeaponData: return weapon(&"steel_sword", SWORD, 8, 75, 0, 5, 9)
static func killing_edge() -> WeaponData: return weapon(&"killing_edge", SWORD, 9, 75, 30, 0, 7)
static func iron_lance() -> WeaponData: return weapon(&"iron_lance", LANCE, 6, 75, 0, 0, 7)
static func silver_lance() -> WeaponData: return weapon(&"silver_lance", LANCE, 14, 75, 0, 0, 10)
static func iron_axe() -> WeaponData: return weapon(&"iron_axe", AXE, 8, 65, 0, 0, 10)
static func steel_knife() -> WeaponData: return weapon(&"steel_knife", KNIFE, 7, 85, 10, 10, 4, 1, 2)
static func iron_bow() -> WeaponData:
	var bow: WeaponData = weapon(&"iron_bow", BOW, 6, 80, 0, 0, 5, 2, 2)
	bow.effective_against = [&"sky"]
	return bow
static func flux() -> WeaponData: return weapon(&"flux", TOME, 8, 75, 0, 0, 6, 1, 2, true)
static func bolt() -> WeaponData: return weapon(&"bolt", TOME, 10, 80, 5, 0, 7, 1, 2, true)
static func mend() -> WeaponData:
	var staff: WeaponData = weapon(&"mend", TOME, 0, 0, 0, 0, 3, 1, 1, true)
	staff.heals = true
	staff.heal_power = 10
	return staff


static func heavy() -> MovementType:
	var result := MovementType.new()
	result.id = &"heavy"
	result.stagger_immune = true
	return result


static func participant(stats: Dictionary, equipped: WeaponData, movement: MovementType = null) -> CombatParticipant:
	var result := CombatParticipant.new()
	result.stats = StatBlock.from_values(stats)
	result.weapon = equipped
	result.movement_type = movement
	result.current_hp = result.stat(&"hp")
	if movement != null:
		result.tags.append(movement.id)
	return result


# §13.2 units ---------------------------------------------------------------

static func swordsman() -> CombatParticipant:
	return participant({"hp": 22, "str": 7, "def": 5, "res": 2, "dex": 9, "spd": 9, "skl": 9, "bld": 6}, iron_sword())

static func brigand() -> CombatParticipant:
	return participant({"hp": 24, "str": 8, "def": 4, "res": 0, "dex": 4, "spd": 4, "skl": 4, "bld": 10}, iron_axe())

static func rogue() -> CombatParticipant:
	return participant({"hp": 30, "str": 11, "mag": 2, "def": 8, "res": 5, "dex": 14, "spd": 17, "skl": 13, "bld": 6}, steel_knife())

static func dark_mage() -> CombatParticipant:
	return participant({"hp": 27, "mag": 12, "def": 4, "res": 10, "dex": 10, "spd": 9, "skl": 8, "bld": 6}, flux())

static func swordmaster() -> CombatParticipant:
	return participant({"hp": 48, "str": 24, "def": 16, "res": 12, "dex": 28, "spd": 32, "skl": 26, "bld": 9}, killing_edge())

static func general() -> CombatParticipant:
	return participant({"hp": 60, "str": 28, "def": 30, "res": 12, "dex": 18, "spd": 10, "skl": 14, "bld": 14}, silver_lance(), heavy())

static func sage() -> CombatParticipant:
	return participant({"hp": 42, "mag": 26, "def": 12, "res": 22, "dex": 22, "spd": 18, "skl": 20, "bld": 7}, bolt())
