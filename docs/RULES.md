# Rules reference

How Ruined Crossroads plays, with the numbers that live in `game/rules/crossroads_ruleset.tres`. Written alongside the code from M1. The spec (`Tellen-Claude.md` §4–§10) is the source of truth until this file is filled in.

## Stats
_M1: the 8 growable stats, Mov and Build, caps._

## Combat formulas
_M1: weight, damage, hit/avoid/crit, follow-ups, Stagger, bows, combat sequence, healing._

## Progression
_M1/M3: levels, growth modes, the baseline unit table (§6.2), EXP, proficiency, enemy stat generation._

## Movement and terrain
_M2: movement types, terrain table, optional movement rules._

## Extension points (§2a.11)
Where out-of-scope features plug in later without rewriting core systems. Each system adds its entry when it's built.

| Future feature | Extension point | Added in |
| --- | --- | --- |
| Save format changes | `SaveMigrator.register_step()` | M0 |
| Skill/aura/support bonuses in combat | `CombatParticipant.modifiers` (hit, avoid, crit, crit_evade, might, damage, defense, resistance) | M1 |
| A different game's formulas | Subclass `CombatRules` / `GrowthRules` / `ExpRules` / `EnemyStatRules`, point the ruleset at it | M1 |
| Permadeath | `DefeatRules.apply` (replace the retreat flag) | M3 |
| Convoy | `DefeatRules` items_lost; inventory-full branches | M3 |
| New objectives / defeat rules | Subclass `Objective`; add a `DefeatCondition.Kind` | M4 |
| Map events (dialogue, items) | `MapEvent` (triggers + actions), `MapEventRules`; new triggers = new enum value + match | M6 |
| Support conversations | `MapEvent` TALK with flags; dialogue `@set` flags carried in `CampaignState` | M6 |
| Fog of war | `ThreatMap` / `RangeCalculator` visibility filter; AI target lists | M4 |
| New skills | Script extending `SkillHooks` + `SkillData.params`; no engine changes | M5 |
| Gods' sigils | Fill `UnitData.awakening` from a future `SigilData`; awakening rules unchanged | M5 |
| Supports / support bonuses | `SkillHooks.modify_ally_participant` (same path as auras) | M5 |
