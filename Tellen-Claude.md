# CLAUDE.md — Ruined Crossroads Tactics Prototype

You are building a **playable prototype** of a grid-based tactical RPG in **Godot 4 (GDScript only)**. The prototype exists to test a specific set of combat and progression mechanics, and to establish a **reusable tactics framework** that can power future games with different stats, rules and content.

**This prototype may ship as the final game.** Build everything to production quality from the first commit: no throwaway code, no "we'll fix it later" hacks, placeholder *assets* only (never placeholder *architecture*). See §2a.

Jake (the designer) will check in on your work regularly. Work in small, verifiable steps, keep `docs/PROGRESS.md` current, and stop at every **Checkpoint** to summarize what changed and what to test.

> This file supersedes any earlier project spec. Earlier drafts used "Break", "Engage", "Speed doubling", "Luck" and "Finesse". Those are replaced by **Stagger**, **Awakening**, **Skill-based follow-ups**, *(Luck removed)* and **Build**. If you find older code using the old terms, migrate it (see §17).

---

## 0. How to work in this repo (read first, every session)

1. **Start of every session:** read `docs/PROGRESS.md` and `docs/DECISIONS.md`, then continue from the first unchecked task in the current milestone.
2. **Work one task at a time.** A task is done when: the code exists, it is statically typed, tests for it pass, and `docs/PROGRESS.md` is updated with a checkmark and a one-line note.
3. **Run tests after every task:**
   `godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`
   Never mark a task done with failing tests. If a test is wrong, fix the test and log why in `DECISIONS.md`.
4. **Checkpoints:** at the end of each milestone, STOP. Write a short summary in `PROGRESS.md` under the milestone (what was built, how to try it in the editor, known issues, decisions made) and wait for Jake.
5. **Never hardcode tuning numbers in logic.** Every number in §4–§9 lives in a ruleset or data Resource (`.tres`). Logic reads from it.
6. **Ambiguity rule:** if the spec is silent and the choice is cheap to change, pick the default listed here (or the most FE-like option), implement it behind a ruleset flag, and log it in `DECISIONS.md` under "Defaults chosen — confirm with Jake". If the choice is expensive to reverse, ask.
7. **Don't add scope.** Anything in §16 "Out of scope" stays out unless Jake asks.
8. **Git:** commit after each completed task. Message format: `M{milestone}.{task}: short description`.
9. **Placeholder art is fine.** Use colored rectangles/letters or the existing Python/Pillow generators in `/tools`. Never block on art.

---

## 1. Tech baseline

- **Engine:** Godot 4.6+ (latest stable at time of writing is 4.7.x). Use `TileMapLayer` (not the deprecated `TileMap`), typed GDScript, `@export` resources.
- **Language:** GDScript only. Static typing everywhere (`var hp: int`, `func f(a: int) -> void`). Enable "untyped declaration" warnings as errors in project settings.
- **Resolution:** base 240×135, integer scaling (`display/window/stretch/mode = viewport`, `scale_mode = integer`). Default window 1920×1080. Tile size 16×16 (configurable in ruleset/map). Maps larger than the screen scroll with a camera that follows the cursor.
- **Testing:** GUT 9.x (Godot 4 branch) in `addons/gut`. If GUT does not support the installed engine version, use gdUnit4 and log it.
- **No other third-party addons** (no Dialogic, no LimboAI). The framework must stay self-contained and reusable.
- **Input:** keyboard, gamepad and mouse. Define actions in the Input Map: `confirm`, `cancel`, `menu`, `info`, `cursor_up/down/left/right`, `next_unit`, `prev_unit`, `toggle_threat`, `end_turn`, `speed_up`, `debug_overlay`.

---

## 2. Architecture principles (reusability is a hard requirement)

The repo has **two layers**:

| Layer | Path | Rule |
| --- | --- | --- |
| **Framework** | `res://addons/tactics_core/` | Game-agnostic. Must not reference Ruined Crossroads names, stats, classes or content. Could be copied into another project unchanged. |
| **Game** | `res://game/` | Ruined Crossroads data, rules subclasses, maps, dialogue, UI theme. |

Design rules:

1. **Data-driven.** Units, classes, weapons, items, skills, terrain, stats, factions, AI profiles and maps are `Resource`s or scenes authored in the editor. Logic never switches on specific content IDs.
2. **Rules are pluggable.** All formulas live behind abstract rule classes in the framework (`CombatRules`, `GrowthRules`, `ExpRules`, `AwakeningRule`, `EnemyStatRules`). The game provides concrete subclasses (`game/rules/crossroads_combat_rules.gd`, etc.) and one `Ruleset` resource that wires them together. A different game swaps the ruleset, not the engine.
3. **Stats are defined by data.** The framework has `StatDefinition` resources (id, name, abbreviation, growable, default cap). A `StatBlock` is a dictionary keyed by stat id. The framework never assumes "speed" exists; rule subclasses read the stats they need by id.
4. **Model/view separation.** `BattleState` (pure data, no Nodes) holds the whole battle: grid, units, turn, phase, flags, RNG state. Presentation nodes listen to signals and animate. This enables headless tests, AI simulation, replays and rewind.
5. **Command pattern for every state change.** `MoveCommand`, `AttackCommand`, `HealCommand`, `ItemCommand`, `TradeCommand`, `WaitCommand`, `AwakenCommand`, `TalkCommand`, `SeizeCommand`. Each has `execute(state)`, `can_execute(state)`, and `to_dict()`. Commands are appended to an action log.
6. **Deterministic RNG.** One `SeededRng` service with named streams (`combat`, `growth`, `ai`, `misc`), serializable state. Same seed + same commands = same battle. Required for rewind and tests.
7. **Event bus.** Autoload `TacticsEvents` with typed signals (`unit_moved`, `combat_resolved`, `unit_defeated`, `phase_started`, `turn_started`, `level_up`, `dialogue_requested`, `objective_completed`, etc.). Framework emits; game and UI listen.
8. **Minimal autoloads:** `TacticsEvents`, `TacticsRng`, `RulesetProvider` (holds the active ruleset), `SceneRouter`. Everything else is instanced.
9. **Composition over inheritance** for units: `UnitState` holds data references; behavior comes from rules, skills and AI profiles.
10. **Every public framework class gets a doc comment** (`##`) explaining purpose and extension points.

---

## 2a. Production readiness (this may become the shipped game)

1. **No throwaway systems.** Every system is written as if it ships: typed, documented, tested, error-handled. Prototype shortcuts are allowed only for *content* (placeholder art, sounds, test maps), and every placeholder is referenced through a resource path so it can be swapped without code changes.
2. **Saves are versioned.** Every save file and serialized state includes a `save_version`. Write a migration hook (`SaveMigrator`) from day one, even if it does nothing yet. Never break old saves silently.
3. **Data is versioned and validated.** A `DataValidator` (run in tests and from the editor) checks every class, weapon, unit, skill and map for missing references, out-of-range numbers and broken links. Content errors must fail loudly in debug and degrade gracefully in release.
4. **Localization-ready.** All player-facing strings go through `tr()` with keys (`UI_END_TURN`, `WEAPON_IRON_SWORD_NAME`). Dialogue files support a locale suffix (`ch01_intro.en.dlg`). Only English is written now, but nothing should need refactoring to add a language.
5. **Settings persist** to `user://settings.cfg`: animation speed, text speed, volume (master/music/sfx), window mode, control remapping, colorblind-safe range overlays, forecast detail level.
6. **Accessibility basics:** remappable controls, text speed, never rely on color alone (range overlays also use patterns/icons), readable fonts at 240×135.
7. **Debug vs. release.** Debug overlay, console and Combat Lab are compiled in only when `OS.is_debug_build()` or a `debug` feature tag is set. No debug code paths in release builds.
8. **Logging.** A small `Log` utility with levels; framework systems log warnings for recoverable content errors instead of crashing.
9. **Performance budget:** 60 FPS on a 40×40 map with 40 units; enemy phase AI completes each unit's decision in under 50 ms. Profile at M4 and M8.
10. **Export presets** for Windows, macOS and Linux exist by M8 and are tested.
11. **Out-of-scope features (§16) must still have a home.** Leave clean extension points (signals, abstract classes, data fields) so permadeath, supports, shops, convoy, fog of war and battle scenes can be added without rewriting core systems. Note each extension point in `docs/RULES.md`.

---

## 3. Folder structure

```
res://
  addons/
    tactics_core/
      plugin.cfg, plugin.gd                 # registers custom types + editor tools
      core/          events.gd, seeded_rng.gd, command.gd, action_log.gd, state_machine.gd, ids.gd
      data/          stat_definition.gd, stat_block.gd, unit_data.gd, class_data.gd, item_data.gd,
                     weapon_data.gd, weapon_type.gd, consumable_data.gd, skill_data.gd,
                     terrain_data.gd, movement_type.gd, faction_data.gd, character_data.gd
      grid/          battle_grid.gd, pathfinder.gd, range_calculator.gd, threat_map.gd
      battle/        battle_state.gd, unit_state.gd, turn_manager.gd, battle_controller.gd
        combat/      combat_rules.gd (abstract), combat_forecast.gd, combat_resolver.gd, strike.gd
        commands/    move_command.gd, attack_command.gd, heal_command.gd, item_command.gd, ...
        objectives/  objective.gd (abstract), rout.gd, seize.gd, defeat_boss.gd, survive.gd,
                     defend_tile.gd, escape.gd, defeat_condition.gd
        events/      reinforcement.gd, map_event.gd, trigger_region.gd
      ai/            ai_controller.gd, ai_profile.gd, ai_scorer.gd, behaviors/*.gd
      progression/   exp_rules.gd, growth_rules.gd, proficiency.gd, enemy_stat_rules.gd
      skills/        skill_hooks.gd, skill_context.gd
      awakening/     awakening_rule.gd (abstract), cooldown_awakening_rule.gd, action_charge_awakening_rule.gd
      rewind/        rewind_service.gd
      dialogue/      dialogue_parser.gd, dialogue_script.gd, dialogue_command.gd, dialogue_player.gd,
                     dialogue_trigger.gd
      map_authoring/ map_definition.gd, markers/*.gd (@tool), map_validator.gd (EditorScript)
      ui/            base widgets: cursor, panel_base, menu_list, forecast_view_base, hp_bar
      debug/         debug_overlay.gd, debug_console.gd, combat_lab.gd
    gut/
  game/
    rules/           crossroads_ruleset.tres, crossroads_combat_rules.gd, crossroads_growth_rules.gd, ...
    data/            stats/, movement_types/, weapon_types/, classes/, weapons/, items/, skills/,
                     terrain/, units/, characters/, factions/, ai_profiles/
    maps/            _template/map_template.tscn, test_arena.tscn, ch00_ruined_crossroads.tscn,
                     ch01_the_bridge_deal.tscn
    tilesets/        prototype_terrain.tres
    dialogue/        *.dlg
    ui/              theme.tres, fonts/, game-specific panels
    scenes/          main.tscn, title.tscn, battle_scene.tscn, combat_lab.tscn
  tests/             unit/, integration/, fixtures/
  tools/             (existing Python/Pillow sprite generators)
  docs/              PROGRESS.md, DECISIONS.md, LEVEL_DESIGN.md, DIALOGUE.md, DATA_GUIDE.md, RULES.md
```

---

## 4. Stats

### 4.1 Growable unit stats (8)

| ID | Name | Effect |
| --- | --- | --- |
| `hp` | HP | Health |
| `str` | Strength | Physical attack |
| `mag` | Magic | Magic attack (dark and white magic) and healing power |
| `def` | Defense | Reduces physical damage |
| `res` | Resilience | Reduces magic damage |
| `spd` | Speed | +2 avoid per point; +¼ crit per point |
| `skl` | Skill | Follow-up attacks (§5.4); +½ hit per point; +¼ crit evade per point |
| `dex` | Dexterity | +2 hit per point; +½ avoid per point |

Str, Mag, Def and Res have **no secondary effects**. Keep damage math readable.

### 4.2 Non-growing stats

| ID | Name | Source | Effect |
| --- | --- | --- | --- |
| `mov` | Movement | Class | Movement points per turn. Never grows. |
| `bld` | Build | Personal base + class bonus | Offsets weapon weight (FE "Constitution"). Does not grow on level-up; changes only with class change or items. |

### 4.3 Removed stats

Luck and Charisma are removed. Crit and crit evade come from weapons plus the Speed/Skill spills above.

### 4.4 Caps

Each class defines caps per stat. Stat totals = personal base + class base + level-up gains + permanent boosts, clamped to class caps.

---

## 5. Combat rules (implement exactly; all constants in the ruleset)

All fractional results **round down** (`floori`). Displayed percentages clamp to 0–100.

### 5.1 Weight

```
weight_penalty = max(0, weapon.weight - unit.bld)
effective_spd  = spd - weight_penalty          # ruleset flag: weight_affects_speed (default true)
effective_skl  = skl - weight_penalty          # ruleset flag: weight_affects_skill_for_followups (default true)
```
Effective Speed is used for avoid and the crit spill. Effective Skill is used only for the follow-up comparison. (FE weight slows both dodging and attack tempo; this mirrors it. Log as a default to confirm.)

### 5.2 Damage

```
attack  = (weapon.damage_type == PHYSICAL ? str : mag) + weapon.might * effectiveness_multiplier
damage  = max(0, attack - (weapon.damage_type == PHYSICAL ? target.def : target.res))
```
- `effectiveness_multiplier` = `ruleset.effective_might_multiplier` (default **3**) if the weapon is effective against any of the target's tags (e.g. bows vs `sky`), else 1.
- Terrain defense bonus adds to Def/Res if the terrain has one.
- **Crit damage** = `damage * ruleset.crit_multiplier` (default **3.0**, floored). Test 2.5 later.

### 5.3 Hit, avoid, crit

```
hit_total   = weapon.hit + 2*dex + floor(skl/2) + modifiers
avoid_total = 2*effective_spd + floor(dex/2) + terrain.avoid + modifiers
displayed_hit = clamp(hit_total - target.avoid_total, 0, 100)

crit_total  = weapon.crit + floor(effective_spd/4) + modifiers
crit_evade  = target_weapon.crit_evade + floor(target.skl/4) + modifiers
displayed_crit = clamp(crit_total - target.crit_evade, 0, 100)
```
- **Hit roll mode:** `ruleset.true_hit_mode` ∈ `ONE_RN` (default), `TWO_RN`, `HYBRID`. 1RN = roll 0–99, hit if `< displayed_hit`. 2RN = average of two rolls. HYBRID = Fates/Engage curve: for hit ≥ 50, use `hit*100 + (40/3)*hit*sin((0.02*hit - 1)*180°)` compared to a roll of 0–9999.
- **Crit roll** is always a single roll and happens only if the strike hits.
- If a unit has no weapon equipped, it cannot attack or counter.

### 5.4 Follow-ups (Skill)

```
lead = attacker.effective_skl - defender.effective_skl
if lead >= follow_up_threshold (5):
    pct = min(100, follow_up_base_pct (50) + follow_up_step_pct (10) * (lead - follow_up_threshold))
```
| Skill lead | Follow-up damage |
| --- | --- |
| 0–4 | none |
| 5 | 50% |
| 6 | 60% |
| 7 | 70% |
| 8 | 80% |
| 9 | 90% |
| 10+ | 100% |

Easy rule for players: **"Lead by 5 to follow up at half damage; every point after adds 10%."**

- The percentage applies to **final damage** (after Def/Res), floored: `followup_damage = floor(damage * pct / 100)`.
- Follow-ups roll **hit and crit separately**. A crit follow-up deals `floor(followup_damage * crit_multiplier)`.
- **Defenders can follow up** (`ruleset.defender_can_follow_up = true`) using the same rule, as long as the attacker is within the defender's weapon range.
- A **Staggered** unit never follows up.

### 5.5 Stagger (replaces FE "Break")

Two loops. Bows are outside both.
```
Sword > Axe > Lance > Sword
Knife > Gauntlet > Tome > Knife      # "Tome" = dark AND white magic
```
- **Trigger:** only the **attacker** (the unit that initiated combat) can inflict Stagger. It triggers when the attacker's strike **hits**, the attacker's weapon type staggers the defender's weapon type, and the defender **survives**.
- **Effect:** the Staggered unit **cannot follow up** in the combat where it was Staggered **and in its next combat only**. It can still make normal counters in both. Stagger clears after that next combat, or at the end of the current phase if no further combat happens, whichever comes first. (`ruleset.stagger_duration = NEXT_COMBAT`; keep `REST_OF_PHASE` available as an option.)
- **Immunity:** units of movement type `heavy` cannot be Staggered. Units wielding bows cannot be Staggered and cannot inflict Stagger.
- **Attacker's own follow-up** still happens if the Skill lead allows it.
- Stagger relationships are data: each `WeaponType` resource lists `staggers: Array[WeaponType]`. The framework knows nothing about swords.
- The forecast always shows a Stagger icon when the attack will Stagger on hit. The map shows a stagger marker on Staggered units until the Stagger clears.

### 5.6 Bows

- Range 2 only (cannot counter at range 1).
- Effective against units tagged `sky`.
- Outside both Stagger loops (§5.5).

### 5.7 Combat sequence

```
1. Attacker strike (x2 if brave weapon)
2. Stagger check (§5.5)
3. Defender counter, if: alive, has weapon, attacker within its range (Stagger does not block counters)
4. Follow-up for whichever side has lead >= threshold, if alive, in range, and not Staggered (from this combat or carried over from its previous combat)
5. Chain attacks (optional rule, §9.4)
6. Post-combat: EXP, proficiency, awakening charge, defeat handling
```
`CombatResolver` returns a `CombatResult` with an ordered list of `Strike` records (actor, target, hit, crit, damage, flags). Presentation replays the list; logic never waits on animation.

### 5.8 Healing

White magic heal spells target allies in range: `heal_amount = mag + spell.power` (FE Heal staff style). Gives EXP to the healer (§6.3).

### 5.9 Combat forecast

`CombatForecast.build(state, attacker, defender, attacker_tile)` returns, for both sides: damage, displayed hit, displayed crit, number of strikes, follow-up %, whether Stagger will trigger, effectiveness, predicted HP after expected outcomes, and awakening charge gain (if the action-charge rule is active). The UI and AI both use this. It must never mutate state.

---

## 6. Progression

### 6.1 Levels

- Single continuous level track, `level_cap` in ruleset (default 40). Class changes do not reset level.
- 100 EXP per level.

### 6.2 Growths

- Final growth = personal growth + class growth modifier (both in data).
- `ruleset.growth_mode` ∈ `RANDOM` (default), `FIXED` (deterministic accumulation: add growth% to a hidden counter each level, gain +1 per 100), `HYBRID` (fixed accumulation at 80% of growth + one random roll at the remaining 20%). Growths may exceed 100% (guaranteed +1, remainder rolled).
- Baseline average unit for tuning (put this in `docs/RULES.md` and the sample data):

| Stat | Base (Lv 1) | Growth |
| --- | --- | --- |
| HP | 20 | 65% |
| Str | 6 | 40% |
| Mag (physical unit) | 1 | 10% |
| Dex | 7 | 40% |
| Spd | 6 | 35% |
| Skl | 6 | 30% |
| Def | 5 | 30% |
| Res | 3 | 20% |

Total growth budget ≈ 270%. Keep most Skill growths in 20–40% (it controls follow-ups). Lords may go up to ~300%.

### 6.3 EXP (FE-like, all constants in `ExpRules`)

```
level_diff  = enemy.level - unit.level   (use effective level incl. class tier offset, ruleset: tier_level_offset)
combat_exp  = max(1, 10 + level_diff)                       # survived combat, dealt damage
kill_exp    = combat_exp + max(0, 20 + level_diff * 3) + (boss ? 40 : 0)
miss_exp    = 1                                              # no damage dealt
heal_exp    = 12
```
Clamp to 1–100 per action.

### 6.4 Proficiency (replaces weapon letter ranks)

- Each unit has numbered proficiency levels per weapon type (and per movement tactic: `ground`, `sky`, `heavy`).
- Gains: using a weapon in combat gives proficiency points. Class data defines a **primary** proficiency and **secondaries**: Beginner classes +1 to each listed proficiency; Intermediate+ classes +2 primary / +1 secondaries. Points per level and level thresholds are in the ruleset.
- Weapons have `required_proficiency: int`. A unit cannot equip a weapon above its proficiency level.
- Class changes are gated by proficiency levels (not unit level). `ClassData.requirements` lists `{proficiency_id: min_level}`.
- Class progression may be free choice or per-character: `UnitData.class_tree: Array[ClassData]` (empty = any class whose requirements are met). Default to per-character lists in sample data.

### 6.5 Classes

Tiers: Beginner, Intermediate, Advanced, Master. `ClassData` fields: id, display_name, tier, movement_type, mov, build_bonus, base stat bonuses (default flat offense +2, defense +3 per tier step, configurable), growth modifiers, stat caps, usable weapon types, primary/secondary proficiencies, class abilities (`Array[SkillData]`, always active, don't count against slots), requirements, tags (`foot`, `ground`, `sky`, `heavy`).

Beginner classes: Mov 4 (5 if mounted). Class names must be original (not Fire Emblem names). Use clearly placeholder names in sample data, e.g. "Sellsword", "Spearhand", "Hatchetman", "Cutpurse", "Brawler", "Hexcaller", "Acolyte", "Hunter", "Outrider" (ground), "Wingrider" (sky), "Bulwark" (heavy).

### 6.6 Enemy stats

Generic enemies are generated when the map loads (or when reinforcements spawn), deterministically:
```
stat = class.base[stat] + round(class.growth[stat]/100 * ((level-1) + tier_bonus_levels + difficulty_bonus_levels))
stat = min(stat, class.cap[stat])
```
- `tier_bonus_levels` per tier in ruleset (FE "promotion bonus" equivalent).
- `difficulty_bonus_levels` per difficulty in ruleset.
- Bosses and named enemies may use hand-authored stats or the formula + overrides.

---

## 7. Movement, terrain and the grid

### 7.1 Movement types

`MovementType` resources: `foot`, `ground` (mounted), `sky` (flying), `heavy` (armored). Each terrain defines a cost per movement type (or impassable).

### 7.2 Terrain (sample data)

| Terrain | Foot | Ground | Sky | Heavy | Avoid | Def | Heal |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Plains | 1 | 1 | 1 | 1 | 0 | 0 | 0 |
| Road | 1 | 1 | 1 | 1 | 0 | 0 | 0 |
| Forest | 2 | 3 | 1 | 2 | +20 | 0 | 0 |
| Ruins/Rubble | 2 | 3 | 1 | 3 | +10 | +1 | 0 |
| Hill | 2 | 3 | 1 | 3 | +10 | +1 | 0 |
| Fort | 1 | 1 | 1 | 1 | +20 | +2 | 20% |
| Water | — | — | 1 | — | 0 | 0 | 0 |
| Wall/Cliff | — | — | — | — | — | — | — |
| Doorway | 1 | — | — | 1 | 0 | 0 | 0 |

Terrain is assigned via a `TileSet` custom data layer `terrain_id: String` on the `TileMapLayer`; `BattleGrid` maps it to `TerrainData`.

### 7.3 Pathfinding and ranges

- Movement range: Dijkstra flood fill from the unit's tile using terrain costs for its movement type, limited by `mov`. Allies are passable but not stoppable; enemies block.
- Attack range: from every reachable tile, add tiles within the min–max range of every equippable weapon.
- Path preview follows the cursor; recompute the cheapest path to the hovered tile.
- `ThreatMap`: union of all enemy move+attack ranges (toggle all enemies / selected enemy). Cache and invalidate on unit movement.
- Use `AStarGrid2D` only for AI long-range pathing if useful; the movement range must use the custom Dijkstra (terrain costs per movement type).

### 7.4 Optional movement rules (flags, default off unless noted)

- `canto`: a skill granting leftover movement after acting. Assign to `ground` classes in sample data.
- `zone_of_control`: enemies must stop when entering a tile adjacent to a unit with the `zoc` tag. Default **off**.

---

## 8. Turn structure, objectives, events

### 8.1 Turn loop

`TurnManager` state machine: `MapStart → PhaseStart(faction) → PlayerInput / AIRunning → PhaseEnd → (next faction) → TurnEnd → ...`. Factions are data (`player`, `enemy`, `ally` NPC, `other`). Each faction has a controller (`HUMAN` or `AI`).

Per-phase cleanup: clear any remaining Stagger, tick awakening timers/cooldowns, apply terrain healing at phase start for that faction.

### 8.2 Player actions

Select unit → movement range → choose destination → action menu: **Attack, Heal (if staff/white magic), Awaken, Items, Trade, Talk (if a talk event exists), Seize (if on seize tile), Wait**. `cancel` undoes the move before an action is chosen.

### 8.3 Objectives (resources, combinable)

`Rout`, `Seize(tile)`, `DefeatBoss(unit_ref)`, `Survive(turns)`, `DefendTile(tile, turns)`, `Escape(tiles, count)`.
Defeat conditions: protagonist defeated, all player units defeated, protected NPC defeated, turn limit exceeded.

### 8.4 Defeat handling

Permadeath is out of scope. Defeated player units **retreat** (removed for the rest of the map, back next map). Protagonist (unit flagged `is_lord`) defeat = game over.

### 8.5 Reinforcements

`Reinforcement` marker: spawn tile(s), turn, faction, unit list, `telegraph = true`. Telegraphed spawns show a warning marker on their tiles during the preceding player phase. **Reinforcements never act on the phase they appear.**

### 8.6 Map events

Triggered by: map start, map end, turn N (phase start), unit enters region, unit defeated, boss engaged (pre-combat), talk command between specific units, village visit / chest open, reinforcement arrival. Events can: run dialogue, give items, change AI groups, add objectives, spawn units, set flags.

---

## 9. Systems

### 9.1 Inventory and items

- 5 slots per unit (`ruleset.inventory_size`). First equippable weapon = equipped weapon (FE style); player can reorder/equip from the Items menu.
- **No weapon durability.** Consumables have `uses`.
- Trade with adjacent allies (free action before acting).
- Sample consumables: Vulnerary (heal 10, 3 uses), Elixir (heal full, 1 use), one permanent stat booster per stat.
- Enemies can carry drop items (`drop: true`).
- Convoy is out of scope.

### 9.2 Weapon data (`WeaponData`)

Fields: id, display_name, weapon_type (`WeaponType` resource), damage_type (`PHYSICAL`/`MAGIC`), might, hit, crit, crit_evade, weight, range_min, range_max, required_proficiency, effective_against (tags), flags (`brave`, `heals`, `cannot_counter`), heal_power, description.

Sample set (numbers chosen to match the test fixtures in §13):

| Weapon | Type | Mt | Hit | Crit | CE | Wt | Rng |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Iron Sword | sword | 5 | 80 | 0 | 5 | 5 | 1 |
| Steel Sword | sword | 8 | 75 | 0 | 5 | 9 | 1 |
| Killing Edge | sword | 9 | 75 | 30 | 0 | 7 | 1 |
| Iron Lance | lance | 6 | 75 | 0 | 0 | 7 | 1 |
| Silver Lance | lance | 14 | 75 | 0 | 0 | 10 | 1 |
| Javelin | lance | 5 | 65 | 0 | 0 | 9 | 1–2 |
| Iron Axe | axe | 8 | 65 | 0 | 0 | 10 | 1 |
| Hand Axe | axe | 6 | 60 | 0 | 0 | 11 | 1–2 |
| Iron Knife | knife | 4 | 90 | 5 | 10 | 2 | 1–2 |
| Steel Knife | knife | 7 | 85 | 10 | 10 | 4 | 1–2 |
| Iron Gauntlets | gauntlet | 4 | 85 | 5 | 5 | 2 | 1 |
| Iron Bow | bow | 6 | 80 | 0 | 0 | 5 | 2 |
| Flux (dark) | tome | 8 | 75 | 0 | 0 | 6 | 1–2 |
| Bolt (dark) | tome | 10 | 80 | 5 | 0 | 7 | 1–2 |
| Light (white) | tome | 5 | 85 | 0 | 0 | 3 | 1–2 |
| Mend (white, heal) | tome | — | — | — | — | 3 | 1 (heal_power 10) |

### 9.3 Skills

- `SkillData` resource with an attached script extending `SkillHooks`, which exposes overridable hooks: `on_combat_start`, `modify_forecast(ctx)`, `on_strike_resolved`, `on_combat_end`, `on_phase_start`, `on_unit_moved`, `modify_move_cost`, `grants_action`.
- Units equip up to **5 skills** (`ruleset.skill_slots`). Class abilities are always on and don't count against slots.
- Personality skills are just skills with flavor; some get swapped across the time skip (design only, no system needed now).
- Implement 4–6 sample skills to prove the hooks: Canto, a stat-aura (+2 Def to adjacent allies), a conditional avoid buff, a "first strike on enemy phase" (vantage-like), a heal-on-kill.

### 9.4 Chain attacks (optional rule, default ON, confirm with Jake)

After the main combat, each ally of the attacker that could attack the defender from its current tile with its equipped weapon (and is not Staggered) adds one chain strike: fixed damage = `floor(target.max_hp * chain_damage_pct / 100)` (default 10%, min 1), cannot be countered, cannot crit, cannot Stagger. `chain_can_kill` flag default true. All values in the ruleset.

### 9.5 Awakening (Engage/Emblem equivalent)

- `AwakeningRule` is abstract; ship two implementations selectable in the ruleset:
  - **`CooldownAwakeningRule` (default):** awakening lasts `duration_turns` (3); after it ends the unit has a `cooldown_turns` (3) cooldown; `max_uses_per_map` (3) with `use_scope` ∈ `ARMY` (default) or `UNIT`.
  - **`ActionChargeAwakeningRule`:** per-unit meter `max_charge` (6), starts at `start_charge` (3); gains: Stagger +2, kill +1, chain attack +1, heal +1, +1 at own phase start; awakening lasts 3 turns, meter resets to 0; `max_uses_per_unit_per_map` (2).
- Awakening grants: stat modifiers, a set of skills active only while awakened, and a **signature attack usable once per awakening** (a `SkillData` that `grants_action`). Source of these is data on the unit (`UnitData.awakening`) so it can later come from gods' sigils without code changes.
- UI shows the meter/cooldown on the unit panel and forecast.
- Future hook (data only, no logic yet): `SigilData` (a god's sigil) with passive stat boosts that scale with a unit's faith level, awakened-state skills and a signature attack.

### 9.6 Rewind (Tellen's ability)

`RewindService` rewinds the battle to the start of any earlier player action this map, using the action log plus `BattleState` snapshots taken before each command. Limited by `ruleset.rewind_charges_per_map` (default 3). Enemy actions in between are replayed only if the player re-issues commands; RNG state is restored from the snapshot.

---

## 10. Enemy AI

`AIController` runs one unit at a time in a deterministic order (units that can attack this turn first, then by distance to nearest player unit, then by spawn order).

### 10.1 Behaviors (`AIProfile.behavior`)

| Behavior | Description |
| --- | --- |
| `CHARGE` | Moves toward and attacks the best target anywhere. |
| `HOLD` | Attacks only targets reachable from its current movement range; otherwise stays. |
| `STATIONARY` | Never moves; attacks targets in weapon range of its tile. |
| `AGGRO_REGION` | Waits until a player unit enters its trigger region or it is attacked, then switches to `CHARGE`. Supports group wake-up (`ai_group`). |
| `GUARD` | Stays within N tiles of a guard tile; attacks anything that comes in reach. |
| `COWARD` | Below `flee_hp_pct`, retreats toward a flee tile or away from threats. |
| `HEALER` | Heals the most valuable wounded ally in reach; otherwise keeps distance. |

Bosses use any behavior plus a `boss` flag. Prefer bosses that move or threaten an area over pure throne-sitters (design note from Jake's research).

### 10.2 Target scoring (`AIScorer`, weights in `AIProfile`)

For each (destination tile, target) pair, using `CombatForecast`:
```
score = w_damage * expected_damage_dealt
      + w_kill   * kill_probability
      + w_stagger * (stagger_on_hit ? displayed_hit/100 : 0)
      + w_priority * target_priority      # lord, healers, low HP, units it is effective against
      - w_risk   * expected_damage_taken  # from counters + follow-ups
      + w_terrain * terrain_value(destination)
```
Expected damage includes hit chance, follow-up %, and crit expected value. Pick the max; ties broken deterministically. If no attack is possible, move per behavior (toward nearest target via path cost, or hold).

`debug_overlay` can display AI scores per tile for the selected enemy.

---

## 11. Dialogue system

Self-contained, reusable, screenplay-style scripts. Jake writes scenes in a format close to a screenplay.

### 11.1 Constraints

Scenes use: a background image, music, sound effects, dialogue boxes with speaker name and portrait (≈5 expressions per character), and **one item overlay at a time**.

### 11.2 Script format (`.dlg` files, parsed at load)

```
=== ch01_intro ===
@bg bridge_dusk
@music tension_low
@sfx gulls
@show TELLEN left smirk
@show SABLE right neutral

TELLEN (smirk): Gentlemen. You look like men who appreciate a fair price.
SABLE (annoyed): He says that to everyone.
@item stolen_crate
GID: That crate's ours.
@hide_item

@choice
- "Name your price." -> pay
- "Walk away." -> walk

@label pay
@set paid_toll = true
TELLEN: Consider it an investment.
@goto end

@label walk
@if paid_toll -> end
TELLEN (neutral): Another time, then.

@label end
@end
```

Rules:
- `NAME (expression): text` — speaker line; expression optional (defaults to `neutral`). Long lines auto-paginate.
- `@` lines are commands: `bg`, `music`, `sfx`, `show NAME position expression`, `hide NAME`, `expr NAME expression`, `item id`, `hide_item`, `choice`, `label`, `goto`, `if flag -> label`, `set flag = value`, `wait seconds`, `end`.
- `#` starts a comment.
- `CharacterData` resources map speaker IDs to display name, portraits by expression (`neutral`, `happy`, `angry`, `sad`, `surprised`, extensible) and a name color.
- Flags live in a `CampaignState` resource (shared across maps) or `BattleState` (map-local) depending on prefix (`map.` for map-local).

### 11.3 Components

`DialogueParser` (text → `DialogueScript`, with line-numbered errors), `DialoguePlayer` (UI scene that plays a script, supports skip, fast-forward, auto-advance, log/backlog), `DialogueTrigger` (connects map events §8.6 to scripts). The parser must be unit-tested and report helpful errors ("line 14: unknown command @shwo").

Battle quotes: a `BattleQuote` map event plays a short scene before combat between specific units (boss + anyone, or a specific pair).

---

## 12. Level authoring (Jake must be able to build maps alone)

### 12.1 Map scene structure (`game/maps/_template/map_template.tscn`)

```
Map (Node2D, script: map_root.gd, exports: MapDefinition)
├── Terrain (TileMapLayer, tileset with custom data "terrain_id")
├── Decoration (TileMapLayer, visual only)
├── Markers (Node2D)
│   ├── PlayerSlots   (PlayerSpawn markers: slot index, optional forced unit)
│   ├── Enemies       (EnemyUnit markers)
│   ├── Allies        (AllyUnit markers)
│   ├── Reinforcements(Reinforcement markers)
│   ├── Objectives    (SeizeTile / DefendTile / EscapeTile markers)
│   ├── Regions       (TriggerRegion markers, rectangular cell areas)
│   └── EventTiles    (Village / Chest markers)
└── Camera bounds (auto from Terrain used rect)
```

### 12.2 Markers (all `@tool`, snap to grid, draw editor gizmos)

- `EnemyUnit`: `UnitData` or `ClassData` + level, `AIProfile`, `ai_group`, inventory override, `is_boss`, `drops`, custom stat overrides. Gizmo shows class letter + level + a faint move/attack range preview when selected.
- `PlayerSpawn`: deploy slot order, optional `forced_unit`.
- `Reinforcement`: turn, faction, list of unit entries, `telegraph`.
- `TriggerRegion`: size in cells, event list, `once` flag.
- `SeizeTile`/`DefendTile`/`EscapeTile`, `Village`/`Chest` (item, dialogue).
- Markers expose everything in the Inspector; no code needed to build a map.

### 12.3 `MapDefinition` resource

Name, chapter id, objectives, defeat conditions, deploy count, forced units, pre-battle dialogue, post-battle dialogue, map events list, music, turn limit, recommended level (for tuning notes).

### 12.4 Tools

- **Map validator** (`EditorScript`, run from the editor's script menu, also exposed as a test): flags markers off-grid or on impassable terrain, missing terrain ids, unreachable objectives, enemies without weapons, reinforcement tiles blocked, dialogue scripts that fail to parse, unknown dialogue ids.
- **Play from editor:** opening any map scene and pressing "Run Current Scene" launches it directly in battle with a default test roster (`game/data/units/test_roster.tres`).
- **Docs:** write `docs/LEVEL_DESIGN.md` — a step-by-step guide with screenshots-in-words: duplicate template → paint terrain → place markers → set MapDefinition → run validator → play. Include the design rules from Jake's research: one mechanic per map, ≤40% rout maps, telegraph reinforcements, bosses that teach something.

---

## 13. Testing

### 13.1 Unit tests (GUT) required for

Stat block math, weight penalty, every formula in §5, follow-up curve edges (lead 4, 5, 9, 10, 12), Stagger rules (attacker-only, survive requirement, heavy immunity, bow immunity, blocks follow-ups this combat and the next combat only, never blocks counters, clears after the next combat or at phase end), true-hit modes, growth modes (FIXED is exact), EXP formula, enemy stat generation, movement ranges with terrain costs per movement type, threat map, objectives, reinforcement telegraph timing, AI picks the obvious kill, dialogue parser, map validator, rewind restoring exact state.

### 13.2 Combat fixtures (must pass exactly, 1RN, crit ×3)

Builds are set so weight doesn't apply.

**Early — Swordsman (Lv 4) attacks Brigand (Lv 3)**
- Swordsman: HP 22, Str 7, Def 5, Res 2, Dex 9, Spd 9, Skl 9, Bld 6, Iron Sword.
- Brigand: HP 24, Str 8, Def 4, Res 0, Dex 4, Spd 4, Skl 4, Bld 10, Iron Axe.
- Expect: Swordsman dmg 8, hit 92 (102 − 10), crit 1 (0 + 2 − (0 + 1)), follow-up lead 5 → 50% → 4 dmg. Brigand dmg 11, hit 53 (75 − 22), crit 0. Sword staggers axe → Brigand Staggered on hit (still counters, cannot follow up this combat or in its next combat).

**Mid — Rogue (Lv 15) attacks Dark Mage (Lv 14)**
- Rogue: HP 30, Str 11, Mag 2, Def 8, Res 5, Dex 14, Spd 17, Skl 13, Bld 6, Steel Knife.
- Dark Mage: HP 27, Mag 12, Def 4, Res 10, Dex 10, Spd 9, Skl 8, Bld 6, Flux.
- Expect: Rogue dmg 14, hit 96 (119 − 23), crit 12 (10 + 4 − (0 + 2)), follow-up lead 5 → 50% → 7 dmg; crit first hit = 42. Mage dmg 15, hit 58 (99 − 41), crit 0. No Stagger: per §5.5 tome staggers knife, so the Rogue's knife does not stagger the Mage's tome (if the Mage initiates, it staggers the Rogue). *(Corrected 2026-11-10; this line originally said "Knife staggers tome".)*

**Late — Swordmaster attacks General (heavy)**
- Swordmaster: HP 48, Str 24, Def 16, Res 12, Dex 28, Spd 32, Skl 26, Bld 9, Killing Edge.
- General: HP 60, Str 28, Def 30, Res 12, Dex 18, Spd 10, Skl 14, Bld 14, Silver Lance, movement type heavy.
- Expect: Swordmaster dmg 3, hit 100 (capped), crit 35 (30 + 8 − (0 + 3)), follow-up lead 12 → 100% → 3. General dmg 26, hit 40 (118 − 78). No Stagger (heavy immune).

**Late — Sage attacks General**
- Sage: HP 42, Mag 26, Def 12, Res 22, Dex 22, Spd 18, Skl 20, Bld 7, Bolt.
- Expect: dmg 24, hit 100, crit 6 (5 + 4 − (0 + 3)), follow-up lead 6 → 60% → 14.

**Weight fixture:** Steel Sword (Wt 9) on a unit with Bld 6 → penalty 3 to effective Spd and effective Skl.

### 13.3 Combat Lab (debug scene, `game/scenes/combat_lab.tscn`)

Pick two units (data or ad-hoc stats), weapons, terrain and levels; show the full forecast; button to simulate N combats (default 1,000) and show win rate, average damage, crit rate, Stagger rate and follow-up frequency. This is Jake's main tool for tuning numbers.

---

## 14. UI (prototype quality, readable at 240×135)

- Grid cursor with smooth snap; terrain info panel (name, avoid, def).
- Unit info panel: name, class, level, HP bar, 8 stats + Mov + Bld, equipped weapon, inventory, skills, awakening meter/cooldown, Staggered status.
- Movement (blue) and attack (red) range overlays; path arrow; threat overlay toggle (orange).
- Action menu (§8.2) and Items submenu.
- **Combat forecast panel (required, ships in M3):** shown whenever a target is hovered during attack targeting and when hovering an enemy that can reach a selected unit. For both sides: current HP → predicted HP if every strike hits, damage per strike, hit %, crit %, number of strikes, follow-up damage as a % and as a number (e.g. "+7 (50%)"), effectiveness marker, Stagger icon (and a "can't follow up" note on a Staggered unit), terrain bonuses applied, and awakening charge gain. A "details" toggle expands it to show weapon, Skill lead and the weight penalty. The forecast reads only from `CombatForecast` so it always matches the resolver.
- Map combat presentation: bump animation, damage numbers, MISS / CRIT / STAGGER popups, HP bar drain. Animation speed toggle (1×/2×/instant). No separate battle scenes.
- Phase banner ("Player Phase" / "Enemy Phase"), turn counter, objective display (from `menu`).
- Level-up popup with stat gains; proficiency level-up toast.
- Victory/defeat screens; pause menu: End Turn, Objective, Rewind (if charges), Settings (anim speed, growth/hit mode display for debug).
- Telegraph markers on reinforcement tiles; boss icon on bosses.
- Debug overlay (F3 / `debug_overlay`): cell coords, terrain costs, AI scores, RNG seed. Debug console (F4): `kill <unit>`, `heal all`, `level <unit> <n>`, `give <unit> <item>`, `win`, `lose`, `seed <n>`, `awaken <unit>`.

All UI text comes from data or the dialogue system; theme lives in `game/ui/theme.tres`.

---

## 15. Milestones (stop at every Checkpoint)

**M0 — Bootstrap**
1. Project settings (resolution, stretch, input map, typed-GDScript warnings), folder structure, `tactics_core` plugin skeleton, GUT installed.
2. Autoloads (`TacticsEvents`, `TacticsRng`, `RulesetProvider`, `SceneRouter`).
3. Create `docs/PROGRESS.md` (all milestones/tasks as checkboxes), `docs/DECISIONS.md`, empty guides.
4. If prior prototype code exists, write an audit in `DECISIONS.md` (what to keep, migrate, delete) and wait for Jake before deleting anything.
→ **Checkpoint**

**M1 — Data model and rules**
1. Framework data resources (§3 data/), `StatDefinition`/`StatBlock`.
2. `Ruleset` + abstract rules; Crossroads concrete rules implementing §5–§6.
3. Sample data: 8 stats, 4 movement types, 8 weapon types with stagger links, ~11 Beginner classes + 3 Intermediate examples, the weapon table, terrain table, consumables, 6 sample units (Tellen, Sable, Gid + 3 generic) and enemy classes.
4. `CombatForecast` + `CombatResolver` (headless), all §13.2 fixtures passing.
5. Combat Lab scene.
→ **Checkpoint** (Jake tunes numbers in Combat Lab)

**M2 — Grid and movement**
1. Prototype tileset with `terrain_id` custom data; `BattleGrid` reading `TileMapLayer`.
2. Range calculator, path preview, threat map; tests.
3. Cursor, camera, unit sprites (placeholder), select/move/cancel, `MoveCommand`.
4. Debug overlay showing terrain costs.
5. `test_arena.tscn` with every terrain type.
→ **Checkpoint**

**M3 — Combat on the map**
1. Action menu, attack targeting, full combat forecast panel (§14) with tests that forecast numbers equal resolver numbers.
2. `AttackCommand` → resolver → presentation replay (bump, numbers, popups, HP drain).
3. Stagger state + markers, follow-ups, crits, effectiveness, healing.
4. Retreat/defeat handling, EXP, level-up popup, proficiency gains.
5. Inventory: equip, use consumable, trade, enemy drops.
→ **Checkpoint**

**M4 — Turn loop, AI, objectives**
1. `TurnManager` phases, end turn, phase banners, per-phase cleanup.
2. AI controller, scorer and all behaviors in §10; AI debug scores.
3. Objectives + defeat conditions; victory/defeat screens.
4. Reinforcements with telegraph; trigger regions; group aggro.
5. Enemy stat generation (§6.6) with difficulty setting.
→ **Checkpoint** (first fully playable map)

**M5 — Skills, awakening, chain attacks, classes**
1. Skill hook system + 5 slots + class abilities + sample skills.
2. Both awakening rules, signature attack action, UI meter/cooldown.
3. Chain attacks (§9.4).
4. Class change via proficiency requirements; per-character class trees.
→ **Checkpoint**

**M6 — Dialogue**
1. Parser + tests, `DialogueScript`, `DialoguePlayer` UI with portraits, bg, music, sfx, item overlay, choices, flags, backlog, skip.
2. Map event triggers (§8.6), Talk command, battle quotes.
3. `docs/DIALOGUE.md` with the full syntax and examples.
→ **Checkpoint**

**M7 — Level authoring**
1. All `@tool` markers with gizmos and Inspector exports; `MapDefinition`.
2. Map template scene; "run current scene" test roster.
3. Map validator (editor + test).
4. `docs/LEVEL_DESIGN.md` and `docs/DATA_GUIDE.md` (how to add a class, weapon, unit, skill, terrain).
5. Build `ch00_ruined_crossroads.tscn` (tutorial: teaches movement, combat, Stagger, follow-ups) and `ch01_the_bridge_deal.tscn` (stolen-shipment opening battle with a loot reward and a pre-battle scene) using only the template and markers — this proves the workflow.
→ **Checkpoint**

**M8 — Rewind, campaign state, polish**
1. `RewindService` + UI + tests.
2. `CampaignState` (roster, levels, inventory, flags) carried between ch00 and ch01; simple save/load to `user://` as JSON.
3. Title screen → map flow; settings (animation speed).
4. Bug pass, performance check on a 40×40 map with 30 units.
→ **Checkpoint**

---

## 16. Out of scope for now (but leave extension points, §2a.11)

Permadeath, weapon durability, shops, convoy, overworld/hub, support conversations and support bonuses, full battle animation scenes, gods/faith/sigil logic (data stub only), the once-per-map army gambit equivalent, fog of war, weather, translated languages (strings stay `tr()`-ready), mobile UI, final art and audio.

---

## 17. Migration notes (if older prototype code exists)

- "Break" → Stagger with the new loops and rules (§5.5).
- "Engage" / emblem logic → Awakening rules (§9.5).
- Speed-based doubling → Skill-based follow-ups (§5.4); Speed now only avoid + crit spill.
- Remove Luck and Charisma.
- "Finesse" → Build (§4.2, §5.1).
- Weapon letter ranks → numbered proficiency (§6.4).
- Keep the 240×135 resolution and the `/tools` sprite generators.

---

## 18. Defaults chosen — confirm with Jake (log these in DECISIONS.md at M0)

1. Weight penalty applies to both Speed (avoid, crit) and Skill (follow-up comparison).
2. Effective weapons multiply might ×3.
3. Hit rolls use 1RN (shown = real).
4. Growth mode RANDOM by default; FIXED and HYBRID available.
5. Stagger blocks follow-ups for the current combat and the Staggered unit's next combat only (never blocks counters).
6. Chain attacks ON, 10% max HP, can kill.
7. Awakening default = cooldown rule (3-turn duration, 3-turn cooldown, 3 uses per map, army-wide).
8. Canto on Ground classes only; zone of control off.
9. Single continuous level track (cap 40), class change gated by proficiency.
10. Defeated player units retreat; protagonist defeat = game over.
