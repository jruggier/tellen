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
