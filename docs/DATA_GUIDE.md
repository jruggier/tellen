# Data guide

How to add or change game content without code. All content lives in `game/data/` as resource files (`.tres`) edited in the **Inspector**. Player-facing names are translation keys whose English text lives in `game/localization/strings.csv` (open it in any text editor or spreadsheet).

**The quickest way to add something is to duplicate an existing file:** right-click it in the FileSystem dock → **Duplicate…**, rename it, then change its fields. Every content file has an **Id** (unique per kind, lowercase, underscores) and a **Display Name** (a translation key such as `WEAPON_IRON_SWORD_NAME`; add the key and its English text to `strings.csv`).

After changing data, run the **data validator**: open `addons/tactics_core/debug/validate_data.gd` → **File → Run**. It reports unknown stats, missing references, weapons a unit can't use, and more. Debug runs of the game also print these problems at startup.

---

## Numbers that apply to everything: the ruleset

`game/rules/crossroads_ruleset.tres` holds every formula setting: combat (hit/avoid/crit per stat, follow-up threshold and steps, crit multiplier, effectiveness, weight), growth mode, EXP, enemy stat scaling by tier and difficulty, proficiency thresholds, awakening rule, chain attacks, inventory and skill slots, level cap, tile size. Expand each section (*Combat Rules*, *Growth Rules*...) to edit. The Combat Lab (`game/scenes/combat_lab.tscn`, F6) shows the effect immediately.

The ruleset also lists the **catalogs** (stats, movement types, weapon types, terrain, classes). When you add one of those, add it to the matching list in the ruleset too.

## Adding a stat

`game/data/stats/` → duplicate e.g. `skl.tres`. Set **Id**, **Display Name**, **Abbreviation**, **Growable**, **Default Cap**. Add it to the ruleset's **Stats** list. A new stat does nothing in combat until a rule reads it (that part is code).

## Adding a weapon type

`game/data/weapon_types/` → duplicate. Set **Staggers**: ids of the types this one Staggers (e.g. sword → `axe`). **Stagger Exempt** for types outside the loops (bows). Add it to the ruleset's **Weapon Types**. The weapon type id is also its proficiency id.

## Adding a weapon

`game/data/weapons/` → duplicate e.g. `iron_sword.tres`. Fields: **Weapon Type**, **Damage Type** (physical/magic), **Might, Hit, Crit, Crit Evade, Weight**, **Range Min/Max**, **Required Proficiency**, **Effective Against** (unit tags such as `sky`), **Brave**, **Heals** + **Heal Power** (staves/white magic), **Cannot Counter**.

## Adding a consumable or booster

`game/data/items/` → duplicate `vulnerary.tres` (healing) or `might_tonic.tres` (permanent boost). Fields: **Uses**, **Heal Amount** / **Heal Full**, **Permanent Boosts** (a stat block: add the stat id and amount). Key items (like the Stolen Crate) are plain items with a `key` tag.

## Adding a class

`game/data/classes/` → duplicate a class of the same tier.

| Field | Meaning |
| --- | --- |
| Tier | 0 Beginner, 1 Intermediate, 2 Advanced, 3 Master |
| Movement Type, Mov | how it moves |
| Build Bonus | added to the unit's Build |
| Base Stats / Growth Modifiers | added to a named unit's own stats/growths |
| Caps | max per stat |
| Generic Base Stats / Generic Growths | full stat lines for generic enemies of this class |
| Usable Weapon Types | what it can equip |
| Primary / Secondary Proficiencies | what it trains (weapon type ids; `ground`/`sky`/`heavy` for movement) |
| Abilities | always-on skills (e.g. Canto, Shield Wall) |
| Requirements | proficiency id → level needed to change into it |
| Tags | `enemy_only` keeps it out of class changes |

Add it to the ruleset's **Classes** list so it can be offered as a class change.

## Adding a unit (named character)

1. **Character** (`game/data/characters/`): **Id** (the dialogue speaker id in lowercase, e.g. `tellen` for `TELLEN:`), **Display Name**, **Name Color**, **Portraits** (expression → image).
2. **Unit** (`game/data/units/`): **Character**, **Class Data**, **Level**, **Personal Base** (include `bld`), **Personal Growths** (keep totals around 270%, lords up to ~300%, Skill 20–40%), **Inventory**, **Skills** (up to 5), **Proficiencies**, **Class Tree** (classes it may change into; empty = any it qualifies for), **Is Lord**, **Awakening**.
3. To use it in test maps, add it to `game/data/units/test_roster.tres`.

## Adding a skill

1. Pick or write a behavior script in `game/skills/`. Existing scripts are reusable by changing **Params**:
   - `aura_hooks.gd`: allies within `radius` get `amount` added to `modifier` (`defense`, `avoid`, `hit`, `crit`, `might`, `damage`, `resistance`, `crit_evade`).
   - `low_hp_bonus_hooks.gd`: at or below `hp_pct`% HP, add `amount` to `modifier`.
   - `vantage_hooks.gd`: strike first when attacked on the enemy phase.
   - `heal_on_kill_hooks.gd`: heal `pct`% max HP after a kill.
   - `canto_hooks.gd`: move again after acting.
2. `game/data/skills/` → duplicate; set **Hooks Script**, **Params**, name and description keys.
3. Give it to a unit (**Skills**) or a class (**Abilities**).

New kinds of behavior need a new hooks script (code); see `addons/tactics_core/skills/skill_hooks.gd` for the available hooks.

## Adding an awakening or signature attack

`game/data/awakenings/` → duplicate. **Stat Modifiers**, **Skills** (active only while awakened), **Signature** (a skill whose **Params** describe the special attack: `might`, `hit`, `crit`, `damage`, `no_counter`), **Color**. Set it on the unit's **Awakening** field.

## Adding a terrain type

1. Add a tile to `game/tilesets/prototype_terrain.png` (new art at the end of the row; `tools/gen_prototype_terrain.py` makes placeholders).
2. Open `game/tilesets/prototype_terrain.tres`, select the new tile, set its **terrain_id** custom data.
3. `game/data/terrain/` → duplicate; set **Move Costs** (movement type id → cost; leave a type out to make it impassable), **Avoid Bonus**, **Defense Bonus**, **Resistance Bonus**, **Heal Percent**. Add it to the ruleset's **Terrains**.

## Adding an AI profile

`game/data/ai_profiles/` → duplicate. **Behavior** (charge, hold, stationary, wake on approach, guard, coward, healer) and **Weights** (how much the AI values damage, kills, Stagger, priority targets, safety, terrain). Map-specific settings (guard tile, wake region) are usually set in a new profile on the unit marker itself.
