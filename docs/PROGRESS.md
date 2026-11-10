# Progress

Spec: `Tellen-Claude.md` (§15 milestones). One task at a time; each checked task has its code, typed GDScript, passing tests, and a one-line note.

Run tests: `tools/run_tests.sh` (set `GODOT=` to the Godot 4.7.2 binary; on Jake's Mac `~/Downloads/Godot 3.app/Contents/MacOS/Godot`).
It wraps the spec's command (`godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`) and also fails when a script doesn't parse, which plain GUT silently skips. `.gutconfig.json` makes GUT include subfolders.

---

## M0 — Bootstrap

- [x] **M0.1** Project settings, folder structure, `tactics_core` plugin skeleton, GUT installed. — 240×135 / 1920×1080, viewport stretch, integer scale, Forward+, full input map, untyped declarations are errors in `tactics_core` + `game`; GUT 9.7.1.
- [x] **M0.2** Autoloads `TacticsEvents`, `TacticsRng`, `RulesetProvider`, `SceneRouter`. — Plus `SeededRng`, `SaveMigrator`, `TacticsLog`, `Ruleset` base and a stub `crossroads_ruleset.tres`. 32 tests.
- [x] **M0.3** `docs/PROGRESS.md`, `docs/DECISIONS.md`, empty guides. — `RULES.md`, `DATA_GUIDE.md`, `LEVEL_DESIGN.md`, `DIALOGUE.md` created with outlines.
- [x] **M0.4** Audit of prior prototype in `DECISIONS.md`. — Audited `Fire Emblem Prototype/` (separate folder, nothing deleted). Waiting on Jake's calls.

### M0 Checkpoint summary

**Built**
- Godot project configured for the spec: 240×135 base resolution in a 1920×1080 window (exact 8×), integer scaling, nearest-neighbour textures, pixel snapping, Forward+ renderer, main scene `game/scenes/main.tscn` (a boot screen).
- Input map with every §1 action, bound to keyboard, gamepad and mouse (bindings table in `DECISIONS.md`).
- Typed GDScript enforced: an untyped `var` is a parse error in `addons/tactics_core/` and `game/`. Third-party addons (GUT, Godot MCP) are excluded.
- `addons/tactics_core/`: plugin that registers its autoloads and project settings when enabled, so it can be copied into another project.
  - `TacticsEvents`: typed event bus (battle/turn/phase/unit/dialogue/objective/ruleset/log signals).
  - `TacticsRng` + `SeededRng`: deterministic named streams (`combat`, `growth`, `ai`, `misc`), exact JSON round-trip.
  - `RulesetProvider` + `Ruleset`: loads `game/rules/crossroads_ruleset.tres` from a project setting.
  - `SceneRouter`: route ids, scene params.
  - `SaveMigrator` (versioned saves from day one) and `TacticsLog` (levelled logging).
- Localization: `game/localization/strings.csv` (keys → English); the boot screen text goes through translation keys.
- `tools/`: the Python/Pillow sprite and SFX generators copied from the old prototype (not yet repointed, see audit).
- 32 GUT tests passing (RNG determinism and serialization, migrator, logger, autoloads, display settings, input map).

**How to try it**
1. Open the project in Godot 4.7.2. Project → Project Settings → Plugins: Tactics Core, GUT and Godot MCP should be enabled.
2. Press F5: a dark screen with "Tellen / Tactics framework bootstrap" scaled crisply to the window.
3. Run the tests from the GUT panel (bottom dock) or with the command at the top of this file.

**Known issues**
- Old prototype not migrated yet: the sprite generators in `tools/` still write to the old folder layout. Decide on the audit items first.

**Decisions to confirm:** see `DECISIONS.md` → "Defaults chosen — confirm with Jake" and "Prior prototype audit".

---

## M1 — Data model and rules

- [x] **M1.1** Framework data resources (§3 `data/`), `StatDefinition` / `StatBlock`. — `TacticsData` base (id, name/description keys, `validate()`) + StatDefinition, StatBlock, MovementType, WeaponType, TerrainData, ItemData, WeaponData, ConsumableData, SkillData, ClassData, CharacterData, UnitData, FactionData. 54 tests.
- [x] **M1.2** `Ruleset` + abstract rules; Crossroads concrete rules implementing §5–§6. — Abstract CombatRules/GrowthRules/ExpRules/EnemyStatRules + ProficiencyRules; Crossroads implementations wired into the ruleset. All §13.2 formula values, follow-up edges, Stagger rules, true-hit modes, growth modes, EXP and enemy stats tested. 98 tests.
- [x] **M1.3** Sample data: 8 stats, 4 movement types, 8 weapon types with stagger links, ~11 Beginner + 3 Intermediate classes, weapon table, terrain table, consumables, 6 sample units (Tellen, Sable, Gid + 3 generic), enemy classes. — 88 `.tres` files under `game/data/` + 103 strings; `DataValidator` (tests, debug startup, editor script). 109 tests.
- [x] **M1.4** `CombatForecast` + `CombatResolver` (headless), all §13.2 fixtures passing. — Fixtures pass against the shipped weapon data; scripted-roll tests cover the §5.7 sequence, Stagger timing, kills, brave; 2,000 seeded combats confirm forecast = resolver. 130 tests.
- [x] **M1.5** Combat Lab scene. — `game/scenes/combat_lab.tscn` (framework script `addons/tactics_core/debug/combat_lab.gd`): units or generic classes at any level, editable stats, weapon, terrain, carried Stagger, distance, live forecast + details, seeded N-combat simulation. `UnitStats` (average stats at level, generics) and `CombatSimulation`. 138 tests.
- [x] **Checkpoint** (Jake tunes numbers in Combat Lab)

### M1 Checkpoint summary

**Built**
- **Data model** (`addons/tactics_core/data/`): every content type is a Resource with an id, translation-key name, and `validate()`: stats, stat blocks, movement types, weapon types (Stagger links), terrain, weapons, consumables, skills, classes, characters, units, factions.
- **Rules** (framework abstract, game concrete): `CombatRules`, `GrowthRules`, `ExpRules`, `EnemyStatRules`, plus `ProficiencyRules`. The Crossroads versions implement §5–§6 with every constant exported, wired into `game/rules/crossroads_ruleset.tres`.
- **Sample data** (`game/data/`, 88 files): the full weapon and terrain tables, 8 weapon types, 4 movement types, 15 classes (11 Beginner, 3 Intermediate, Brigand), consumables and stat boosters, Tellen/Sable/Gid + 3 recruits, 4 factions. All names are in `game/localization/strings.csv`.
- **Combat**: `CombatForecast` and `CombatResolver`, headless and deterministic. All §13.2 fixtures pass against the shipped data.
- **DataValidator**: catches broken content in tests, at debug startup, and from the editor.
- **Combat Lab** for tuning.

**How to try it**
1. Open `game/scenes/combat_lab.tscn` and press **F6** (Run Current Scene).
2. Pick a source for each side: a named unit, or "Generic: <class>". Set level, weapon and terrain; stats fill in and stay editable.
3. The forecast updates live. Press **Simulate** for 1,000 seeded combats (change the count/seed as needed).
4. To tune: edit `game/rules/crossroads_ruleset.tres` in the Inspector (expand *Combat Rules*, *Growth Rules*, ...) or any weapon/class `.tres`, then press F6 again.
5. Validate content anytime: open `addons/tactics_core/debug/validate_data.gd` → File → Run.

**Known issues**
- ~~At 240×135, Inter at small sizes is soft.~~ Resolved: the game is now native 1920×1080 (see `DECISIONS.md` → M1 Checkpoint).
- In the Combat Lab, the "Staggered from previous combat" checkboxes draw without a visible box (clicking the text works). Cosmetic; debug tool only.
- The Lab simulates the active ruleset as saved. Switching hit mode (1RN/2RN/hybrid) or growth mode means editing the ruleset `.tres`.
- `CombatForecast.build(state, ...)` from battle state comes in M3, when battle state exists (see `DECISIONS.md`).

**Decisions to confirm:** `DECISIONS.md` → "Added during M1" (#14–24).

## M2 — Grid and movement

_Post-M1 change: the game is native 1920×1080 with 64 px cells (16 px art at 4×)._

- [x] **M2.1** Prototype tileset with `terrain_id` custom data; `BattleGrid` reading `TileMapLayer`. — `tools/gen_prototype_terrain.py` → 9 placeholder tiles (pattern + color); `game/tilesets/prototype_terrain.tres`; terrain added to the ruleset catalog; `BattleGrid` (pure data). 143 tests.
- [ ] **M2.2** Range calculator, path preview, threat map; tests.
- [ ] **M2.3** Cursor, camera, placeholder unit sprites, select/move/cancel, `MoveCommand`.
- [ ] **M2.4** Debug overlay showing terrain costs.
- [ ] **M2.5** `test_arena.tscn` with every terrain type.
- [ ] **Checkpoint**

## M3 — Combat on the map

- [ ] **M3.1** Action menu, attack targeting, full combat forecast panel (§14) with forecast = resolver tests.
- [ ] **M3.2** `AttackCommand` → resolver → presentation replay (bump, numbers, popups, HP drain).
- [ ] **M3.3** Stagger state + markers, follow-ups, crits, effectiveness, healing.
- [ ] **M3.4** Retreat/defeat handling, EXP, level-up popup, proficiency gains.
- [ ] **M3.5** Inventory: equip, use consumable, trade, enemy drops.
- [ ] **Checkpoint**

## M4 — Turn loop, AI, objectives

- [ ] **M4.1** `TurnManager` phases, end turn, phase banners, per-phase cleanup.
- [ ] **M4.2** AI controller, scorer and all §10 behaviors; AI debug scores.
- [ ] **M4.3** Objectives + defeat conditions; victory/defeat screens.
- [ ] **M4.4** Reinforcements with telegraph; trigger regions; group aggro.
- [ ] **M4.5** Enemy stat generation (§6.6) with difficulty setting.
- [ ] **Checkpoint** (first fully playable map; profile performance)

## M5 — Skills, awakening, chain attacks, classes

- [ ] **M5.1** Skill hook system + 5 slots + class abilities + sample skills.
- [ ] **M5.2** Both awakening rules, signature attack action, UI meter/cooldown.
- [ ] **M5.3** Chain attacks (§9.4).
- [ ] **M5.4** Class change via proficiency requirements; per-character class trees.
- [ ] **Checkpoint**

## M6 — Dialogue

- [ ] **M6.1** Parser + tests, `DialogueScript`, `DialoguePlayer` UI (portraits, bg, music, sfx, item overlay, choices, flags, backlog, skip).
- [ ] **M6.2** Map event triggers (§8.6), Talk command, battle quotes.
- [ ] **M6.3** `docs/DIALOGUE.md` with full syntax and examples.
- [ ] **Checkpoint**

## M7 — Level authoring

- [ ] **M7.1** All `@tool` markers with gizmos and Inspector exports; `MapDefinition`.
- [ ] **M7.2** Map template scene; "run current scene" test roster.
- [ ] **M7.3** Map validator (editor + test).
- [ ] **M7.4** `docs/LEVEL_DESIGN.md` and `docs/DATA_GUIDE.md`.
- [ ] **M7.5** `ch00_ruined_crossroads.tscn` and `ch01_the_bridge_deal.tscn` built only from template + markers.
- [ ] **Checkpoint**

## M8 — Rewind, campaign state, polish

- [ ] **M8.1** `RewindService` + UI + tests.
- [ ] **M8.2** `CampaignState` carried ch00 → ch01; save/load to `user://` as JSON.
- [ ] **M8.3** Title screen → map flow; settings.
- [ ] **M8.4** Bug pass; performance check (40×40 map, 30–40 units); export presets tested.
- [ ] **Checkpoint**
