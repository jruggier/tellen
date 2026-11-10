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
- [x] **M2.2** Range calculator, path preview, threat map; tests. — `Pathfinder` (bucket-queue Dijkstra), `MoveRange` (cheapest paths), `RangeCalculator` (ally pass-through, enemy blocking, ZOC flag, attack cells), cached `ThreatMap`; minimal `UnitState`/`BattleState`. 40×40 / 20-enemy threat map in ~8 ms. 159 tests.
- [x] **M2.3** Cursor, camera, placeholder unit sprites, select/move/cancel, `MoveCommand`. — `Command`/`ActionLog`, `MoveCommand` (undoable), `WaitCommand`; `BattleController`; `BattleMap` + `UnitPlacement`; `BattleScene` (world, camera, HUD with terrain panel and hints); `PlayerInputController` state machine; cursor (hold-repeat, mouse), range overlays with patterns, path arrow, placeholder `UnitView`. 172 tests.
- [x] **M2.4** Debug overlay showing terrain costs. — `DebugOverlay` (F3, debug builds only): per-cell coordinates and movement cost (× = impassable) for the inspected unit's movement type; seed/cursor/terrain/turn info; `set_cell_notes()` hook for M4 AI scores. 173 tests.
- [x] **M2.5** `test_arena.tscn` with every terrain type. — 36×22 map (scrolls): river + bridge, walled fortress with doorway and fort, forests, hills, ruins, pond; 6 player units vs 8 enemies covering all four movement types. Runs directly with F6. 177 tests.
- [x] **Checkpoint**

### M2 Checkpoint summary

**Built**
- **Grid**: `BattleGrid` reads any `TileMapLayer` whose TileSet has a `terrain_id` custom data layer; placeholder tileset with all 9 terrain types (`tools/gen_prototype_terrain.py`).
- **Movement**: Dijkstra ranges with per-movement-type terrain costs; allies passable but not stoppable, enemies block; optional zone of control; cheapest-path preview; attack ranges from every reachable tile; cached threat map (20 enemies on 40×40 in ~8 ms).
- **Battle model**: `BattleState` / `UnitState` (pure data), `Command` + `ActionLog`, `MoveCommand` (undoable), `WaitCommand`, `BattleController`.
- **On screen**: native 1080p with 64 px cells (camera zoom 4×), placeholder unit blocks (faction color + class initial + HP strip), cursor with hold-to-repeat and mouse hover, scrolling camera, movement/attack/threat overlays with distinct patterns, path arrow, terrain info panel, hint line.
- **Debug overlay (F3)**: per-cell coordinates and movement costs, seed and state info.
- **Maps**: `BattleMap` root + `UnitPlacement`s; any map scene runs directly with F6.

**How to try it**
1. Open `game/maps/test_arena.tscn` and press **F6**.
2. Move the cursor with arrows/WASD/D-pad or the mouse. **Z/Enter/Space/left-click** selects your unit (blue), showing movement (blue, dotted) and attack range (red, striped); the arrow previews the path.
3. Confirm on a blue tile to move. Then **confirm = Wait** (unit greys out) or **cancel (X/Esc/right-click) = undo the move**.
4. Confirm on an enemy to see its ranges. **T** toggles the combined enemy threat (orange). **Q/E** jump between your ready units. **F3** shows the debug overlay.
5. Things to check: Wingrider (W) flies over the river but not the walls; Outrider (O) is slowed by forest; the Bulwark (B in the fortress) pays 3 on hills/ruins; only foot/armored units fit through the doorway.

**Known issues / not yet built**
- No action menu, combat or end turn yet (M3/M4). After every unit has waited, restart the scene (F6) to play again.
- Class initials can collide (Sellsword/Spearhand both "S", Hexcaller/Hunter both "H"); placeholders until art or a unit info panel (M3).
- The debug overlay's coordinate text is small and crowded; fine for a debug tool.
- The path preview always takes the cheapest path; tracing your own path with the cursor isn't supported yet.
- Hint line key names are fixed text; they'll follow remapping when settings arrive (M8).

## M3 — Combat on the map

- [x] **M3.1** Action menu, attack targeting, full combat forecast panel (§14) with forecast = resolver tests. — `MenuList`, `ForecastPanel` (HP→after, damage ×brave, !effective, hit, crit, follow-up "+N (P%)", Stagger notes, terrain, R = details); `CombatForecast.build(state, …)`; 60-seed forecast-vs-attack test.
- [x] **M3.2** `AttackCommand` → resolver → presentation replay. — `CombatPresenter`: bump, damage/MISS/CRIT/STAGGER/follow-up popups, flash, HP drain, defeat fade; hold Shift to fast-forward.
- [x] **M3.3** Stagger state + markers, follow-ups, crits, effectiveness, healing. — Stagger counter on units (consumed by the next combat, cleared at phase end), spinning map marker + info panel note; `HealCommand` with heal preview.
- [x] **M3.4** Retreat/defeat handling, EXP, level-up popup, proficiency gains. — `DefeatRules` (player units retreat), `ProgressionService` (EXP, multi-level-ups, caps, proficiency points → levels), `LevelUpPanel`, proficiency toasts, boss marker.
- [x] **M3.5** Inventory: equip, use consumable, trade, enemy drops. — Inventory slots with uses; `InventoryCommands` (Use/Equip/Discard/Trade); items menu, two-column `TradePanel`; drops to the killer (lost if full). 203 tests.
- [x] **Checkpoint**

### M3 Checkpoint summary

**Built**
- **Action menu** after moving (or confirming on the unit's own tile): Attack, Heal, Items, Trade, Wait, each listed only when usable.
- **Attack targeting** with weapon choice (when more than one weapon has a target), arrows/mouse to switch targets, and the **combat forecast panel**: HP before → after if everything hits, damage (×2 brave, ! effective), hit, crit, follow-up "+N (P%)", STAGGER on hit / no follow-up notes, terrain. **R** toggles details (Skill lead, weight penalty, attack).
- **Combat on the map**: bump, damage numbers, MISS / CRIT / STAGGER popups, HP drain, defeat fade; hold **Shift** to speed up.
- **Stagger**: map marker (spinning ring) and unit-panel note; blocks follow-ups in the inflicted combat and the unit's next combat; cleared at phase end (the turn loop calls it in M4).
- **Healing** with a preview; **items** (equip, use, discard); **trading** with adjacent allies; equip/trade/discard lock in the move.
- **Progression**: EXP for player units (attacking and defending), level-ups with a stat panel, proficiency points and level-up toasts; player units retreat when defeated; enemy item drops go to whoever defeats them.
- **Unit info panel** on hover (R expands it to full stats, inventory and proficiencies); boss marker.

**How to try it** (`game/maps/test_arena.tscn`, F6)
1. Select a unit, move next to an enemy, choose **Attack**: read the forecast, press **R** for details, confirm.
2. Watch the Brigand get Staggered by a sword hit (marker on the map, note in its info panel).
3. Enemies with drops: the first Brigand (Elixir), the Hexcaller (Might Tonic), the Duelist boss in the fortress (Killing Edge). Defeat them to receive the item.
4. Use Gid (hand axe) to attack from 2 tiles away; trade between adjacent units; open **Items** to equip or use a Vulnerary.
5. Hover any unit and press **R** for full stats.

**Known issues / not yet built**
- Enemies never act and there is no end turn yet (M4). Restart the scene (F6) once your units have acted.
- Popups can overlap neighboring unit letters; info/forecast panels can cover units near the top corners.
- Clicking the map while a menu is open accepts the highlighted option (mouse only).
- No sound yet (old prototype SFX can be wired in later).

**Decisions to confirm:** `DECISIONS.md` → "Added during M3" (#25–28).## M4 — Turn loop, AI, objectives

- [x] **M4.1** `TurnManager` phases, end turn, phase banners, per-phase cleanup. — Pure `TurnManager` + `EndPhaseCommand`; `BattleFlow` sequences phases; Stagger clears and units refresh at phase end; fort healing at phase start; End Turn (F / pause menu C), auto end turn; `PhaseBanner`; turn + objective line.
- [x] **M4.2** AI controller, scorer and all §10 behaviors; AI debug scores. — `AIProfile` (7 behaviors + weights), `AIScorer` (forecast-based, exact kill chance), `AIPlanner` (pure, deterministic, §10 turn order), `AIController` (animated). F3 + inspect an enemy shows its scores (★ = its choice). Profiles in `game/data/ai_profiles/`.
- [x] **M4.3** Objectives + defeat conditions; victory/defeat screens. — Rout, Seize, Defeat Boss, Survive, Defend Tile, Escape; protagonist / all units / protected unit / turn limit; Seize and Escape actions; objective panel; result screen (confirm restarts).
- [x] **M4.4** Reinforcements with telegraph; trigger regions; group aggro. — `Reinforcement` + `ReinforcementRules` (never act on arrival, wait if blocked, warning markers the player phase before); `TriggerRegion` (wake groups, set flags; undone by cancelling the move); AGGRO_REGION groups wake together, also when attacked.
- [x] **M4.5** Enemy stat generation (§6.6) with difficulty setting. — `BattleScene.difficulty` → generic units via `UnitFactory`; named units unaffected. 239 tests.
- [x] **Checkpoint** (first fully playable map; profile performance)

### M4 Checkpoint summary

**Built**
- **A full turn loop**: Player Phase → Enemy Phase banners, turn counter and objective at the top, End Turn (**F**, or **C** → End Turn), automatic end of turn once every unit has acted. Units on forts heal 20% at the start of their phase. Stagger clears at every phase end.
- **Enemy AI** with all seven §10 behaviors, scoring each (tile, target) with the real forecast: expected damage, exact chance to kill, Stagger chance, target priority (protagonist, healers, wounded, effectiveness), risk from counters, terrain. Units act in §10 order. Plans are deterministic.
- **Objectives**: Rout (default), Seize, Defeat Boss, Survive, Defend Tile, Escape; defeat if the protagonist falls or all units fall (defaults), a protected unit falls, or a turn limit passes. Pause menu → **Objective** lists them. Victory/defeat screen; confirm plays again.
- **Reinforcements** with red "!" warnings on their arrival tiles during the player phase before they come; **trigger regions** that wake AI groups; **difficulty** for generic enemy stats.
- **Arena content**: Charge brigand, Hold brigand, a sleeping Hexcaller that wakes when you reach the bridge (or attack it), a Coward outrider, a Guard archer, a Stationary armor at the fortress door, a Guard boss and a Healer inside, and two reinforcements arriving from the east on turn 3.

**How to try it** (`game/maps/test_arena.tscn`, F6)
1. Play turns: move, attack, then **F** to end your turn and watch the enemy phase.
2. Cross the bridge to wake the Hexcaller's group. Watch the east edge on turn 3 for the red "!" warnings.
3. Hurt the Outrider (O) below 40% HP: it runs away. The archer (H, south of the river) only fights near its post.
4. **F3**, then confirm on an enemy: green numbers are its attack scores from each tile; ★ marks its choice.
5. **C** → Objective. Defeat every enemy to win; lose Tellen and it's over.
6. Difficulty: select the BattleScene root in `battle_scene.tscn` → Inspector → *Difficulty* (`normal` / `hard` / `maddening`). Hosting a map with F6 uses `normal` until settings exist (M8).

**Performance (§2a.9)**: 40×40 map, 40 units, threat overlay on: 8.3 ms per frame (~120 fps, 9.8 ms p95). A full 20-unit enemy phase takes ~390 ms of logic (~20 ms per unit; budget 50 ms). Slowest single AI decision in tests: 14 ms.

**Known issues / not yet built**
- AI units don't use items (Vulneraries) or trade, and healers only heal (no attacking).
- Level-ups that happen during the enemy phase wait for a confirm press.
- Restart after victory/defeat replays the same map; title/flow comes in M8.
- Class initials still collide on placeholder units.

**Decisions to confirm:** `DECISIONS.md` → "Added during M4" (#29–37).## M5 — Skills, awakening, chain attacks, classes

- [x] **M5.1** Skill hook system + 5 slots + class abilities + sample skills. — `SkillHooks`/`SkillContext`/`SkillRunner`; skills apply where combatants are built (forecast = resolver = AI); Vantage (`strikes_first`); Canto (`CantoMoveCommand`, CANTO input state). Samples: Canto (mounted), Shield Wall (Bulwark aura), Fleetfoot (Sable), Vigil (Spearhand recruit), Second Wind (Tellen). 249 tests.
- [x] **M5.2** Both awakening rules, signature attack action, UI meter/cooldown. — `AwakeningRule` + `CooldownAwakeningRule` (default) + `ActionChargeAwakeningRule`; `AwakeningData` on units (stat mods, skills, signature); `AwakenCommand` (free action), `SignatureAttackCommand` (once per awakening, params-driven); glowing map outline, status in the unit panel, forecast charge row; AI awakens before attacking. Awakenings for Tellen, Sable, Gid. 258 tests.
- [x] **M5.3** Chain attacks (§9.4). — `ChainAttacks` (contributors, damage, preview, apply); ruleset toggle/percent/can-kill; CHAIN strikes in the replay; forecast chain row; AI counts chain damage; +1 awakening charge per contributor. 265 tests.
- [x] **M5.4** Class change via proficiency requirements; per-character class trees. — `ClassChangeRules` (tree or full catalog, proficiency gates, enemy-only excluded, stat swap with level kept), `ClassChangeCommand`, "Change Class" action menu; ruleset class catalog; placement proficiency overrides (arena Tellen has sword 2 to try Duelist). 271 tests.
- [x] **Checkpoint**

### M5 Checkpoint summary

**Built**
- **Skills**: a hook system (`SkillHooks` scripts + `SkillData.params`) applied wherever combatants are built, so the forecast, the resolver and the AI always agree. Five sample skills: **Canto** (mounted classes move again with leftover movement after acting), **Shield Wall** (Bulwark class ability: +2 Def to adjacent allies), **Fleetfoot** (Sable: +20 Avoid at ≤50% HP), **Vigil** (recruit Spearhand: strikes first when attacked on the enemy phase), **Second Wind** (Tellen: heal 20% after a kill). Skills show in the unit panel.
- **Awakening**: cooldown rule (default: 3 turns, 3-turn cooldown, 3 uses per map for the army) and action-charge rule (meter 6, starts 3; Stagger +2, kill/chain/heal/phase +1), selectable in the ruleset. **Awaken** is a free action; awakened units glow and get stat boosts, extra skills and a once-per-awakening **signature attack** (forecast includes it). Tellen, Sable and Gid each have one. The AI awakens before attacking when it can.
- **Chain attacks**: allies in reach add a fixed 10%-of-max-HP strike after each attack (no counter, crit or Stagger; can kill), for both sides; previewed in the forecast and counted by the AI.
- **Class change**: "Change Class" when proficiency requirements are met, within the unit's class tree; level carries over, stats swap class bonuses.

**How to try it** (`game/maps/test_arena.tscn`, F6)
1. Select Tellen: the unit panel shows "Crossroads Pact: ready (3/3 left)". Move next to an enemy, choose **Awaken** (free), then **Gambit Strike**: the forecast shows no counter. Note the awakened glow and the turns left in the unit panel.
2. Attack an enemy that another ally can also reach (e.g. the Hunter 2 tiles away): the forecast shows **Chain +N**, and the ally hits too.
3. **Change Class** with Tellen → Duelist (sword proficiency 2 is set for testing): Mov becomes 5, offense +2, defense +3.
4. Let the enemy attack the recruit Spearhand during its phase: **Vigil** strikes first.
5. Bring Sable below half HP and check enemy hit chances (+20 avoid). Kill with Tellen at low HP: **Second Wind** heals.
6. To try the action-charge awakening rule: open `game/rules/crossroads_ruleset.tres` → *Awakening Rule* → New `ActionChargeAwakeningRule`.

**Known issues / not yet built**
- No player unit in the arena has Canto (only enemy Outrider); tested headlessly. Add a player Outrider to the arena if you want to try it by hand.
- AI doesn't use signature attacks or Canto.
- The awakened glow is subtle on greyed-out (acted) units.

**Decisions to confirm:** `DECISIONS.md` → #38–46.## M6 — Dialogue

- [x] **M6.1** Parser + tests, `DialogueScript`, `DialoguePlayer` UI (portraits, bg, music, sfx, item overlay, choices, flags, backlog, skip). — `DialogueParser` (multi-scene files, line-numbered errors, label checks), `DialogueRunner` (pure stepping, stage, flags), `DialogueLibrary` (locale files), `DialoguePlayer` (typewriter, placeholders for missing art, backlog R, auto C, skip X, fast-forward Shift), `CampaignState` (campaign flags).
- [x] **M6.2** Map event triggers (§8.6), Talk command, battle quotes. — `MapEvent` (9 triggers; dialogue, items, wake, flags, objectives, spawn, recruit), `MapEventRules`, `EventCommands` (Trigger/Talk/Visit), BattleFlow hooks (map start/end, turn, reinforcements, defeats, regions, quotes before attacks for both sides); Talk/Visit in the action menu. Arena: intro, boss quote, recruit the Hexcaller, village, reinforcement line, victory scene.
- [x] **M6.3** `docs/DIALOGUE.md` with full syntax and examples. 296 tests.
- [x] **Checkpoint**

### M6 Checkpoint summary

**Built**
- **Dialogue scripts** (`.dlg`, screenplay style): lines with expressions, backgrounds, music, sounds, three portrait positions, one item overlay, choices, labels/goto, `@if` on flags, `@set`, waits. Map flags (`map.*`) vs campaign flags. Errors name the file and line.
- **Dialogue player**: typewriter text, speaker names in character colors, highlighted speaker, placeholder art for anything missing (backgrounds, portraits, music), backlog, auto-advance, skip, fast-forward, mouse support.
- **Map events**: pre-battle and post-battle scenes, turn and reinforcement scenes, region and defeat triggers, battle quotes (before player or enemy attacks), **Talk** (can recruit) and **Visit** (villages/chests: give items). Events can wake AI groups, set flags, add objectives and spawn units.
- **Writer's guide**: `docs/DIALOGUE.md`.

**How to try it** (`game/maps/test_arena.tscn`, F6)
1. The intro scene plays first: Z/click to advance, R for the backlog, C for auto, hold Shift to fast-forward, X to skip.
2. Move Tellen next to the Hexcaller (H, middle of the map) and choose **Talk**: pick an answer; it joins your army.
3. Move a unit onto the small fort southwest of the start (3,12) and choose **Visit**: the elder gives a Vulnerary.
4. Attack the Duelist boss in the fortress (or let it attack you): its quote plays first.
5. Turn 3: a line plays when the reinforcements arrive. Win to see the victory scene before the results.
6. Edit `game/dialogue/arena.en.dlg` (any text editor), save, press F6 again.

**Known issues / not yet built**
- No real portraits, backgrounds or music yet: placeholders show the ids you'll need to draw (e.g. `tellen_smirk.png`).
- `.dlg` files must be added to the export include filter when exporting (M8 export presets).
- Map validation of dialogue ids used by events comes with the map validator (M7).
- The talk/recruit choice in the arena doesn't change anything except a map flag (sample content).## M7 — Level authoring

- [x] **M7.1** All `@tool` markers with gizmos and Inspector exports; `MapDefinition`. — `MapMarker` base (grid snap, editor gizmo, hidden in game); EnemyUnit/AllyUnit (selected = range preview, stat/proficiency overrides), PlayerSpawn (slots, forced unit), ReinforcementGroup (child unit markers), RegionMarker (MapEvent), SeizeTile/DefendTile/EscapeTile, VillageMarker/ChestMarker; `MapDefinition`; `BattleMap` accessors merge definition + markers + legacy lists; deployment; `UnitRoster` + test roster; `!flag` event conditions. 306 tests.
- [x] **M7.2** Map template scene; "run current scene" test roster. — `game/maps/_template/map_template.tscn` (definition, 30×17 Terrain, Decoration, Markers groups with 4 spawn slots and an example enemy); F6 plays it with `game/data/units/test_roster.tres`. 308 tests.
- [x] **M7.3** Map validator (editor + test). — `MapValidator`: terrain ids, markers off-grid/off-map/void/impassable/shared cells, factions, unarmed enemies, spawns and deploy count, blocked reinforcement tiles, unreachable objective and visit tiles, boss objective without a boss, dialogue parse errors, unknown dialogue ids, events naming missing units. Editor: `addons/tactics_core/debug/validate_map.gd` (File → Run with the map open). 317 tests.
- [x] **M7.4** `docs/LEVEL_DESIGN.md` and `docs/DATA_GUIDE.md`. — Step-by-step map building (template → terrain → markers → definition → validate → F6) with design rules; how to add stats, weapon types, weapons, items, classes, units, characters, skills, awakenings, terrain and AI profiles.
- [x] **Checkpoint**

### M7 Checkpoint summary

**Built**
- **Markers**: PlayerSpawn, EnemyUnit, AllyUnit, ReinforcementGroup, RegionMarker, SeizeTile, DefendTile, EscapeTile, VillageMarker, ChestMarker. All snap to tiles, draw editor previews (unit markers show their range when selected) and are configured in the Inspector.
- **MapDefinition**: name, factions, objectives, defeat conditions, turn limit, deployment (count, forced units), pre/post-battle scenes, events, music, notes.
- **Map template** with the full marker structure; any map runs with F6 using the test roster.
- **Map validator** (editor script + tests) for terrain, markers, units, reinforcements, objectives, dialogue and events.
- **Guides**: `docs/LEVEL_DESIGN.md`, `docs/DATA_GUIDE.md`.
- **Two chapters**, built only from the template and markers:
  - **ch00 Ruined Crossroads**: a tutorial Rout map with Tellen, Sable and Gid; each encounter teaches one thing (forecast and Stagger, a slow thug for follow-ups, a lance raider, a guarding boss), with short in-character scenes as you reach them.
  - **ch01 The Bridge Deal**: seize the toll camp across one bridge. The opening scene's choice matters (pay the toll and the bridge guards wait; walk away and they attack). Armored gate captain and a healer, a loot chest (Stolen Crate, Steel Sword, Elixir), a village, and telegraphed riders on turn 4.

**How to try it**
1. Open `game/maps/ch00_ruined_crossroads.tscn` → F6. Then `game/maps/ch01_the_bridge_deal.tscn` → F6 (try both answers in the intro).
2. Open either map in the editor: select enemies to see their ranges; select the root to see the MapDefinition.
3. Follow `docs/LEVEL_DESIGN.md` to make a small map from the template; run the validator; F6.

**Known issues / not yet built**
- ch00 → ch01 aren't linked yet; levels, items and flags don't carry over (M8 campaign state). Each map uses the test roster at level 1.
- Marker gizmos are simple shapes and letters; range previews only show for unit markers.
- Generic enemy names use their class name; there is no per-marker display name yet.

**Decisions to confirm:** none new beyond the M7 notes in `DECISIONS.md`.

## M8 — Rewind, campaign state, polish

- [x] **M8.1** `RewindService` + UI + tests. — Snapshots (state incl. RNG, campaign flags, objectives) before each player action and End Turn; rewind restores exactly, truncates the log, drops later points, uses a charge (ruleset `rewind_charges_per_map` = 3); pause menu → Rewind (N) → list of points; views rebuilt, blue flash. 327 tests.
- [x] **M8.2** `CampaignState` carried ch00 → ch01; save/load to `user://` as JSON. — `CampaignData`/`ChapterData` (`game/data/campaign/crossroads_campaign.tres`: start with Tellen, Sable, Gid; three recruits join at ch01); `UnitState.to_record()`/`apply_record()` (class, level, EXP, stats, inventory, proficiencies, skills; HP refills); `SaveSystem` (versioned JSON, temp-file write, corrupt saves refused); `CampaignFlow` (new game, continue, victory → next chapter, defeat → retry from the chapter's save). 335 tests.
- [x] **M8.3** Title screen → map flow; settings. — `main.tscn` boots to `title.tscn` (`TitleScreen`: Continue, New Game with overwrite check, Settings, Quit; "campaign complete" message). `GameSettings` (`user://settings.cfg`): animation speed Normal/Fast/Instant, text speed, master/music/sfx volume (buses created on demand), window mode, gamepad layout, colorblind-safe ranges, forecast details default, keyboard remapping (swap on conflict, reset). `SettingsPanel` from the title and the pause menu (plus Return to title). Hint lines follow remapped keys (`InputHints`). 346 tests.
- [x] **M8.4** Bug pass; performance check (40×40 map, 30–40 units); export presets tested. — Fixes: confirm on the Objective panel also reached the map (input now pauses), the dialogue typewriter crashed if the scene changed mid-line, unit panel didn't refresh after outside changes, finishing the campaign wasn't saved. Added the §14 debug console (F4, debug builds). Performance: 40×40, 30 units, threat on: 8.5 ms/frame (117 fps, p95 11.4 ms); 15-unit enemy phase 288 ms (~19 ms per unit). `export_presets.cfg` for Windows, macOS, Linux (includes `*.dlg`; excludes tests, GUT, MCP, tools, docs, Combat Lab); `.pck` export verified by running New Game from it. 348 tests.
- [x] **Checkpoint**

### M8 Checkpoint summary

**Built**
- **Rewind** (Tellen's ability): pause menu → Rewind (3 charges per map) → pick any earlier player action or turn end; the battle returns exactly to that moment, RNG included.
- **Campaign**: New Game starts ch00 with Tellen, Sable and Gid. Winning carries every unit's class, level, EXP, stats, items, proficiencies and skills into ch01 (HP refills; retreated units come back), where the three recruits join. Story flags carry too, so the ch01 toll choice is remembered. Finishing ch01 returns to the title with a "campaign complete" message.
- **Saving**: one autosave slot, written at the start of every chapter (`user://saves/slot_1.json`, versioned JSON, crash-safe write). Losing a map retries it from that save; Continue on the title screen resumes there.
- **Title screen**: Continue, New Game (asks before replacing a save), Settings, Quit. The game now starts here (`main.tscn` boots straight to `title.tscn`).
- **Settings** (title screen or pause menu, saved to `user://settings.cfg`): animation speed (Normal / Fast / Instant), text speed, master / music / sound volume, windowed or fullscreen, gamepad buttons (Automatic / Nintendo / Xbox-PlayStation), colorblind-safe range colors, forecast details on by default, and keyboard remapping (Controls page). On-screen hints show the keys you picked.
- **Pause menu**: adds Settings and Return to title.
- **Debug console** (F4, debug builds only): `kill`, `heal all`, `level`, `give`, `win`, `lose`, `seed`, `awaken`, `units`.
- **Exports**: presets for Windows, macOS and Linux.

**How to try it**
1. Press **F5** (Run Project): title screen → New Game → play ch00. (F4 → `win` skips a map.) Check that ch01 starts with your levels, then lose it on purpose and see it retry.
2. Quit, run again → **Continue** resumes at the chapter start.
3. Pause (C) → **Settings**: try Instant animations, colorblind ranges, rebind a key on the Controls page and watch the hint line change.
4. Maps still run alone with F6 using the test roster, as before.

**Known issues / not yet built**
- **Export templates for Godot 4.7.2 aren't installed**, so the Windows/macOS/Linux builds can't be produced yet: Editor → *Manage Export Templates* → Download and Install, then Project → Export. The game data was verified by exporting and running a `.pck`. The macOS preset is ad-hoc signed (no notarization); Windows has no icon yet.
- One save slot; no mid-map saves (a quit mid-map restarts that map).
- Remapping is keyboard-only; gamepad buttons follow the layout setting.
- No music or sound assets yet, so the volume settings have nothing to play (the buses are wired).
- Carried over from earlier: AI doesn't use items, enemy-phase level-ups wait for confirm, placeholder class letters collide.

**Decisions to confirm:** `DECISIONS.md` #51–58.


## After M8 — Feedback pass (sound and bars), 2026-11-10

- [x] Sound effects by id through `Sfx` + `SoundBank` (`game/audio/sound_bank.tres`, placeholders from `tools/gen_sfx.py`, 34 sounds on the SFX bus): cursor, menus, confirm/cancel/error, per-weapon-type hits, miss, crit, Stagger, chain, defeat, heal, awaken, rewind, item get, phase banners, victory, game over.
- [x] Dialogue voice blips while text types, pitched per character (`CharacterData.voice`, `voice_pitch`).
- [x] EXP bar after gains (`ExpPanel`): fills with rising ticks, chimes and wraps on level-up; level-up panel reveals each stat gain with a chime.
- [x] HP bars (`StatBar`): unit panel (HP + EXP), forecast (predicted loss/heal pulses), combat HUD with both sides' bars draining in step with strikes. 357 tests.
- [x] Menu hold-to-scroll (`DirectionRepeat`): one step per press, repeat only after a 0.5 s hold, at 10 steps/s; ignores keyboard auto-repeat and analog-stick event floods; Menu scrolling speed in Settings. 361 tests.
