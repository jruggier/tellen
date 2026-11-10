# Decisions

Newest entries at the bottom of each section. Never rewrite a past entry; add a correction below it.

---

## Defaults chosen — confirm with Jake

From spec §18. Each is a ruleset flag or value, so changing one is a data edit, not a code change.

| # | Default | Ruleset field (added in M1/M5) | Confirmed? |
| --- | --- | --- | --- |
| 1 | Weight penalty applies to Speed (avoid, crit) **and** Skill (follow-up comparison) | `weight_affects_speed`, `weight_affects_skill_for_followups` | ✅ 2026-11-10 |
| 2 | Effective weapons multiply might ×3 | `effective_might_multiplier` | ✅ 2026-11-10 |
| 3 | Hit rolls use 1RN (shown = real) | `true_hit_mode = ONE_RN` | ✅ 2026-11-10 |
| 4 | Growth mode RANDOM; FIXED and HYBRID available | `growth_mode` | ✅ 2026-11-10 |
| 5 | Stagger blocks follow-ups for the current combat and the Staggered unit's next combat only; never blocks counters | `stagger_duration = NEXT_COMBAT` | ✅ 2026-11-10 |
| 6 | Chain attacks ON, 10% max HP, can kill | `chain_attacks_enabled`, `chain_damage_pct`, `chain_can_kill` | ✅ 2026-11-10 |
| 7 | Awakening = cooldown rule (3-turn duration, 3-turn cooldown, 3 uses per map, army-wide) | `awakening_rule` | ✅ 2026-11-10 |
| 8 | Canto on Ground classes only; zone of control off | class abilities; `zone_of_control` | ✅ 2026-11-10 |
| 9 | Single continuous level track (cap 40); class change gated by proficiency | `level_cap` | ✅ 2026-11-10 |
| 10 | Defeated player units retreat; protagonist defeat = game over | `defeat_mode` | ✅ 2026-11-10 |

### Added during M0

| # | Default | Where | Confirmed? |
| --- | --- | --- | --- |
| 11 | Input bindings (table below) | Project Settings → Input Map | ✅ 2026-11-10 |
| 12 | Added a `debug_console` input action (F4) for the §14 debug console; §1's action list didn't include one | Input Map | ✅ 2026-11-10 |
| 13 | Mouse left = `confirm`, mouse right = `cancel` | Input Map | ✅ 2026-11-10 |

### Added during M1

| # | Default | Where | Confirmed? |
| --- | --- | --- | --- |
| 14 | FIXED/HYBRID growth counters start at 0 (a 40% stat first rises at the 3rd level-up) | `CrossroadsGrowthRules.fixed_counter_start` | ☐ |
| 15 | Enemy tier bonus levels: Beginner 0, Intermediate 5, Advanced 10, Master 15 | `CrossroadsEnemyStatRules.tier_bonus_levels` | ☐ |
| 16 | Difficulty bonus levels: normal 0, hard 3, maddening 6 | `CrossroadsEnemyStatRules.difficulty_bonus_levels` | ☐ |
| 17 | EXP tier level offset 0 (levels are one continuous track, so a level-20 Intermediate is simply level 20) | `CrossroadsExpRules.tier_level_offset` | ☐ |
| 18 | Proficiency: levels 1–5 at 10/25/45/70/100 total points; gains per combat as §6.4 (Beginner +1 each, Intermediate+ +2 primary/+1 secondary) | `ProficiencyRules` | ☐ |
| 20 | Weapon proficiency requirements: Iron/Light/Mend/Flux 0; Steel, Javelin, Hand Axe, Steel Knife, Bolt 1; Killing Edge 2; Silver Lance 3 | `game/data/weapons/*.tres` | ☐ |
| 21 | Class stat bonuses for named units: Beginner +0; each tier above adds +2 to Str/Mag/Skl/Dex/Spd and +3 to HP/Def/Res | `ClassData.base_stats` | ☐ |
| 22 | Class caps: Beginner HP 45, other stats 22; +15 HP / +8 others per tier; armored classes +4 Def, −4 Spd | `ClassData.caps` | ☐ |
| 23 | Intermediate movement: Duelist 5, Warlock 5, Vanguard (mounted) 6 | `ClassData.mov` | ☐ |
| 24 | Stat boosters: +7 HP, +2 to other stats, +1 Mov, +2 Build | `game/data/items/*.tres` | ☐ |
| 25 | Stat boosters respect class caps (a capped stat doesn't rise) | `InventoryCommands.Use` | ☐ |
| 26 | Dropped items are lost if the killer's inventory is full (no convoy yet) | `DefeatRules` | ☐ |
| 27 | Player units gain EXP and proficiency when defending, as in FE | `AttackCommand` | ☐ |
| 28 | Each combat in which a unit strikes trains its weapon type's proficiency, plus its movement tactic (ground/sky/heavy) if its class trains it | `ProgressionService.train_proficiency` | ☐ |
| 29 | The player's phase ends automatically once every unit has acted | `BattleFlow.auto_end_turn` | ☐ |
| 30 | Phases of factions with no units (and none arriving) are skipped; the player's never is | `TurnManager` | ☐ |
| 31 | Healing terrain (fort) heals 20% of max HP (at least 1) at the start of the occupant's own phase | `TurnManager`, terrain data | ☐ |
| 32 | A reinforcement whose tile is occupied waits and retries next phase | `ReinforcementRules` | ☐ |
| 33 | Telegraph markers show during the player phase within one round before arrival | `ReinforcementRules.telegraphed_cells` | ☐ |
| 34 | AI weights: damage 1, kill 30, Stagger 6, priority 4, risk 0.6, terrain 0.15 | `AIProfile` | ☐ |
| 35 | Only the protagonist (`is_lord`) can Seize | `SeizeCommand` | ☐ |
| 36 | Victory needs every listed objective; maps with none default to Rout; defeat defaults to protagonist or all units | `ObjectiveRules` | ☐ |
| 37 | Trigger regions fire when a unit stops in them; cancelling that move undoes the trigger | `MoveCommand`, `TriggerRules` | ☐ |
| 38 | Canto applies after Attack, Heal or Use Item (not after Wait), once per phase, using the movement left this phase | `CantoMoveCommand` | ☐ |
| 39 | Sample skill assignments: Second Wind → Tellen, Fleetfoot → Sable, Vigil → recruit Spearhand, Shield Wall → Bulwark class, Canto → Outrider/Vanguard | `game/data` | ☐ |
| 40 | Awaken is a free action (the unit can still attack the same turn; its move is locked in), as in FE Engage | `AwakenCommand` | ☐ |
| 41 | Action-charge rule: no phase-start charge on turn 1, so the meter really starts at 3 | `ActionChargeAwakeningRule` | ☐ |
| 42 | Sample awakenings: Tellen "Crossroads Pact" (+3 Str/Spd/Skl, +2 Def, Vigil; Gambit Strike +8 might +30 hit, no counter), Sable "Moonlit Veil" (+4 Mag, +3 Res, +2 Dex; Night Hex +6 might +20 hit +20 crit), Gid "Iron Resolve" (+4 Str, +3 Def, +2 Bld; Cleaver +10 might +15 hit, no counter) | `game/data/awakenings` | ☐ |
| 43 | Chain strikes always land (no hit roll), happen only if the defender survives the main combat, work for every faction (enemies chain too), and allies join whether or not they've acted this turn | `ChainAttacks` | ☐ |
| 44 | Changing class ends the unit's action and is available from the action menu whenever requirements are met (no seal items) | `ClassChangeCommand` | ☐ |
| 45 | A unit with an empty class tree may change to any catalog class whose requirements it meets; `enemy_only` classes are never offered | `ClassChangeRules` | ☐ |
| 46 | Class change keeps damage taken (current HP shifts with max HP) and swaps class base bonuses, Build bonus and Mov | `ClassChangeRules.apply` | ☐ |
| 47 | Dialogue controls: confirm next, X skip to the next choice, R backlog, C auto, hold Shift fast-forward | `DialoguePlayer` | ☐ |
| 48 | Dialogue text speed 45 characters/second by default; Slow 25 / Normal 45 / Fast 80 / Instant in Settings | `GameSettings.text_speed` | ☐ |
| 49 | Nintendo controllers use A (right) = confirm, B (bottom) = cancel, detected automatically; Xbox/PlayStation keep bottom = confirm. Override with project setting `tactics_core/input/nintendo_layout` (0 auto, 1 always, 2 never) | `ControllerLayout` | ✅ 2026-11-10 (Jake) |
| 50 | Ending the turn counts as a rewind point (so a bad enemy phase can be rewound) | `RewindService` | ☐ |
| 51 | One save slot; the game saves automatically at the start of every chapter, and a defeat retries the chapter from that save | `CampaignFlow`, `SaveSystem` | ☐ |
| 52 | Units carry class, level, EXP, stats, inventory, proficiencies and skills between maps; HP refills; retreated units return | `UnitState.to_record` | ☐ |
| 53 | Recruits join the roster when their chapter starts (ch01 brings the Spearhand, Acolyte and Hunter recruits) | `crossroads_campaign.tres` | ☐ |
| 54 | Animation speed: Normal ×1, Fast ×0.5, Instant (no move/strike animation; phase banner kept at 35% so phases stay readable). Holding fast-forward still speeds up on top | `GameSettings.animation_scale` | ☐ |
| 55 | Remapping covers keyboard keys (each action's main key; extra keys like Enter/Space stay). Picking a key already used by another action swaps the two. Gamepad confirm/cancel follow the Gamepad buttons setting | `GameSettings.remap_key` | ☐ |
| 56 | Colorblind-safe ranges use Okabe-Ito colors (blue move, orange attack, purple threat); the patterns are always on | `RangeOverlay` | ☐ |
| 57 | Default volumes 80%; settings apply at once and save when the panel closes | `GameSettings` | ☐ |
| 58 | The pause menu offers Return to title (with a warning that progress on the map is lost) | `BattleScene` | ☐ |
| 59 | Dialogue voice: a blip every 2 letters (min 50 ms apart, ±6% pitch wobble), none for spaces/punctuation or while fast-forwarding; per-character pitch | `DialoguePlayer`, `CharacterData.voice_pitch` | ☐ |
| 60 | EXP bar fills at 1.1 s per full level (min 0.2 s), ticks every 2 EXP with rising pitch, chimes and wraps at 100; replaces the "+N EXP" popup | `ExpPanel` | ☐ |
| 61 | Level-up panel reveals each stat gain one at a time (0.16 s apart) with a chime | `LevelUpPanel.reveal` | ☐ |
| 62 | HP bars: unit panel (plus a thin EXP bar for player units), forecast (pulsing red = predicted loss, green = heal) and a combat bar panel at the bottom during fights; bars go green > 50%, yellow > 25%, red below | `StatBar`, `CombatHud` | ☐ |
| 63 | Sounds come from a sound bank by id; missing ids are silent. Placeholder sounds generated by `tools/gen_sfx.py` | `Sfx`, `SoundBank` | ☐ |
| 64 | Menus move one step per press; holding a direction waits 0.5 s, then steps every 0.1 s (Settings → Menu scrolling: Slow 0.75 s / 0.16 s, Normal, Fast 0.35 s / 0.07 s). A direction still held when a menu opens is ignored until released. Applies to battle menus, targets, trade, title, settings and dialogue choices; the map cursor keeps its quicker 0.22 s / 0.06 s | `DirectionRepeat` | ☐ |
| 19 | 2RN: hit if the average of two 0–99 rolls is below the displayed hit. HYBRID: below 50 uses 1RN | `CrossroadsCombatRules.roll_hit` | ☐ |

**Input bindings (M0)**

| Action | Keyboard | Gamepad | Mouse |
| --- | --- | --- | --- |
| `confirm` | Z, Enter, Space | A (bottom) | Left click |
| `cancel` | X, Esc, Backspace | B (right) | Right click |
| `menu` | C, Tab | Start | |
| `info` | R | Y (top) | |
| `cursor_up/down/left/right` | Arrows, WASD | D-pad, left stick | (cursor follows mouse, M2) |
| `next_unit` / `prev_unit` | E / Q | RB / LB | |
| `toggle_threat` | T | X (left) | |
| `end_turn` | F | Back/Select | |
| `speed_up` | Shift (hold) | Right trigger | |
| `debug_overlay` | F3 | | |
| `debug_console` | F4 | | |

---

## Decisions made

### M0 (2026-11-10)

- **Engine version: Godot 4.7.2** (`~/Downloads/Godot 3.app`). The project was created with 4.7, so 4.6 (`/Applications/Godot 2.app`) is too old to open it safely. *(Jake)*
- **Renderer: Forward+** instead of the Mobile renderer the project was created with. Desktop is the target (§16 rules out mobile). *(Jake)*
- **Git: commit after every task, push only at Checkpoints.** *(Jake)*
- **`CLAUDE.md` imports `Tellen-Claude.md`** so the spec loads automatically each session; the spec keeps its filename. *(Jake)*
- **Test framework: GUT 9.7.1**, the release for Godot 4.7 (`godot_4_7` branch). A `.gutconfig.json` adds subfolder scanning so the spec's test command finds `tests/unit/...`.
- **Typed-GDScript enforcement:** `untyped_declaration` is an error. Godot's `directory_rules` excludes `res://addons` (third-party code we don't control) but re-includes `res://addons/tactics_core`. `game/` and `tests/` are covered by default.
- **Pixel settings:** nearest-neighbour texture filter, 2D transforms snapped to pixels, font antialiasing off. 1920×1080 is exactly 8× the 240×135 base. *(Superseded at the M1 checkpoint: native 1920×1080, font antialiasing back on.)*
- **Autoload registration:** written into `project.godot` and also done by the plugin's `_enable_plugin`, so copying `tactics_core` into another project and enabling it is enough.
- **Event payloads use ids, not Node references** (`unit_id: StringName`, cells as `Vector2i`). This keeps the model/view split (§2.4) and makes events loggable. Signals for combat results, level-ups and awakening are added in the milestone that creates their types (M1/M3/M5) rather than declared early with loose types.
- **RNG streams are derived as `hash("<master_seed>:<stream>")`** and their 64-bit states are saved as strings, because JSON numbers are doubles and would corrupt them. A test round-trips through JSON.
- **`SaveMigrator` exists from M0** (§2a.2). It rejects data newer than the current version or with a missing step instead of loading it half-migrated.
- **Log level** is a project setting (`tactics_core/log/level`). DEBUG/INFO are always off in release builds. WARN and above are forwarded to `TacticsEvents.log_emitted` for the future debug console.
- **M0.1 and M0.2 share one commit.** The project settings register the autoloads, so committing the settings without the autoload scripts would leave a broken project.

---

### M0 Checkpoint (2026-11-10)

- All §18 defaults and the M0 additions (input bindings, `debug_console` action, mouse confirm/cancel) confirmed by Jake.
- UI font: **Inter** (SIL OFL). *(Jake)* *(Readability concern resolved at the M1 checkpoint by going native 1080p.)* Readability check: the whole game renders at 240×135, so text is drawn at that resolution too. Check Inter's legibility at small sizes in the Combat Lab (M1.5). If it's too soft or blocky, the options are: render UI text at full window resolution (switch stretch mode to `canvas_items`, which keeps sprites crisp but changes how pixel snapping works), or use larger text sizes.

### M1 (2026-11-10)

- **Stagger links are weapon type ids** (`WeaponType.staggers: Array[StringName]`), not `Array[WeaponType]` as §5.5 suggests. The loops are circular (sword → axe → lance → sword), and circular references between resource files don't load reliably in Godot. Ids resolve through the ruleset.
- **Bows' Stagger exemption is a `WeaponType.stagger_exempt` flag**, and heavy units' immunity is a `MovementType.stagger_immune` flag. The framework never checks for "bow" or "heavy" by name.
- **Classes have two stat sets.** `base_stats` / `growth_modifiers` are the small bonuses added to a named unit's personal stats (§4.4). `generic_base_stats` / `generic_growths` are full stat lines for generating generic enemies (§6.6), whose formula uses the class's base and growth as complete values.
- **Class tier is an integer** (0 = Beginner). Tier names come from game data, so another game can use a different number of tiers.
- **`StatBlock` is a Resource** holding `Dictionary[StringName, int]`, so it can be edited inline in the Inspector and saved inside `.tres` files. Missing stats read as 0.
- **All content shares a `TacticsData` base**: `id`, `display_name` / `description` as translation keys, and `validate()`, which the data validator will call.
- **Second Stagger loop is Knife > Gauntlet > Tome > Knife** exactly as §5.5 states: knife staggers gauntlet, gauntlet staggers tome, tome staggers knife. The §13.2 mid fixture's "Knife staggers tome" was a typo, corrected in the spec. *(Jake)*
- **Rules are sub-resources of the ruleset.** Each concrete rule class (`CrossroadsCombatRules`, ...) is a Resource whose exported properties are its tuning numbers, embedded in `crossroads_ruleset.tres`. Every §5–§6 constant is editable in the Inspector.
- **Combat rules work on `CombatParticipant` snapshots** (stats, weapon, terrain, tags, Stagger flag, modifiers), not on battle state. The forecast and resolver build snapshots; rules stay pure and testable. Skill effects plug in through the `modifiers` dictionary (`hit`, `avoid`, `crit`, `crit_evade`, `might`, `damage`, `defense`, `resistance`).
- **The framework provides FE-standard defaults** in the abstract `CombatRules` (counter eligibility, brave strikes, effectiveness by tag, follow-up damage floor). The game overrides only what differs.
- **Proficiency rules are a concrete framework class** (`ProficiencyRules`): thresholds and per-tier gains are generic numbers, not game formulas.
- **8 weapon types: sword, axe, lance, knife, gauntlet, dark, white, bow.** §5.5's "Tome = dark AND white magic" fills the Tome slot of the loop with two types: gauntlet staggers both, and both stagger knife. Separate types give Hexcaller and Acolyte separate proficiencies.
- **Sample data was generated once by a script, then the files took over.** The `.tres` files under `game/data/` are the source of truth; edit them in the Inspector. Player-facing names are translation keys in `game/localization/strings.csv`.
- **Sample classes:** 11 Beginner (the §6.5 names), 3 Intermediate examples (Duelist: sword 2; Warlock: dark 2; Vanguard: axe 2, mounted) and an enemy-only Brigand (tagged `enemy_only`). Tellen → Sellsword/Duelist, Sable → Hexcaller/Warlock, Gid → Hatchetman/Vanguard; the three recruits have open class trees.
- **Generic enemy stat lines** are built from the §6.2 baseline unit plus per-class adjustments, so a level-1 generic is roughly the baseline unit flavored by class.
- **Character ids are lowercase** (`tellen`). The dialogue parser (M6) will match speaker names like `TELLEN` case-insensitively.
- **`DataValidator`** checks every content file against the ruleset: unknown stats, weapon/movement types missing from the catalog, unknown proficiency ids, slot limits, level cap, duplicate ids, and starting weapons the unit can't equip (class or proficiency). It runs in the tests, at startup in debug builds (logs loudly), and from the editor (`addons/tactics_core/debug/validate_data.gd`, File → Run).
- **Forecast and resolver take two `CombatParticipant`s and a distance.** The §5.9 `CombatForecast.build(state, attacker, defender, attacker_tile)` becomes a thin wrapper in M3, once battle state exists; it builds participants and calls `CombatForecast.calculate()`. Both call the same `CombatRules` methods, and a test runs 2,000 seeded combats to confirm every strike matches the forecast.
- **Forecast HP:** each side shows `hp_after_all_hits` (every strike lands, no crits; for the §14 panel) and `expected_damage_taken` (hit chance, crits, follow-ups; for the AI). If a hit would Stagger the defender, its follow-up is excluded from the all-hits prediction and flagged `follow_up_cancelled_by_stagger`. The awakening-charge field is added with awakening in M5.
- **Resolver details:** a brave weapon strikes twice in every attack turn, including follow-ups. Stagger is checked once after the attacker's first turn (any hit that the defender survives). Each strike rolls hit, then crit only on a hit. Damage is capped at the target's remaining HP, and a kill ends the combat.
- **`Strike.Role`, not `Strike.Side`**: Godot has a built-in global `Side` enum that silently shadowed the name.
- **`tools/run_tests.sh`** wraps the spec's test command because GUT reports "All tests passed" when a test file fails to parse (it skips the file). The wrapper fails the run on any script error.
- **Combat Lab renders at native window resolution** (it turns off viewport scaling while open and restores it on exit), because a tuning tool with dozens of fields can't fit in 240×135. *(Superseded: the game is now native 1080p, so no switch is needed.)* It is a debug tool: it refuses to run in release builds, and M8's export presets will exclude `game/scenes/combat_lab.tscn` and `addons/tactics_core/debug/`.
- **Average stats at a level** (`UnitStats.average_at_level`): personal base + class base + round(combined growth × levels gained / 100), clamped to class caps; Build gets the class bonus, Mov comes from the class. Generic units use the enemy stat rules.
- **`CombatRules.debug_details()`** exposes intermediate values (weight penalty, effective Spd/Skl, Skill lead, hit/avoid/crit totals) for the Lab and the M3 forecast "details" toggle, without the framework knowing game formulas.
- **The weapon type id is also its proficiency id**; movement tactics (`ground`, `sky`, `heavy`) use the movement type id.

### M1 Checkpoint (2026-11-10)

- **Native 1920×1080 replaces the 240×135 base.** *(Jake)* Stretch mode `canvas_items` with `keep` aspect and fractional scaling, so smaller windows scale down smoothly. Text and UI render at full resolution with Inter (antialiased). Pixel art keeps nearest-neighbour filtering. Spec §1, §2a.6 and §14 updated.
- **Map tiles: 16×16 source art at 4× = 64 px cells** (about 30×17 tiles on screen). *(Jake)* `Ruleset.tile_source_size` and `tile_display_scale`; `Ruleset.cell_size()` returns 64.
- UI font sizes rescaled for 1080p: theme default 28 px.
- The Combat Lab no longer switches scaling modes; it fits the 1080p canvas directly.
- Defaults #14–24 still to confirm.

### M2 (2026-11-10)

- **World space is in source pixels** (16 px per cell); the battle camera zooms by `Ruleset.tile_display_scale` (4). Units, overlays and the cursor all live in the same 16 px space, and pixel art stays crisp through nearest filtering.
- **Terrain is part of the ruleset catalog** (`Ruleset.terrains`), and `BattleGrid` resolves each tile's `terrain_id` custom data through it. The custom data layer name is `Ruleset.terrain_id_layer` (default `terrain_id`).
- **Void and unknown cells are impassable for everyone.** Unknown terrain ids are logged as one warning per id (content error, degrade gracefully).
- **Fixed neighbor order (up, right, down, left)** so pathfinding ties always break the same way.
- **Placeholder terrain art** comes from `tools/gen_prototype_terrain.py`; each tile has its own pattern so terrain is readable without color. Keep the atlas order stable, because tiles are referenced by atlas coordinate.
- **Zone of control** (§7.4) is a ruleset flag (`zone_of_control`, default off) with a `zoc_tag` unit tag.
- **The pathfinder takes occupancy as callables** (`can_pass`, `can_stop`, `must_stop`), so the grid module never references units or factions. `RangeCalculator` supplies the battle rules: allied factions are passable but not stoppable, non-allied units block, and zone of control ends movement next to a ZOC-tagged enemy.
- **Path preview uses the cheapest path** (Dijkstra parents, fixed tie order), per §7.3. FE's "remember the path the cursor traced" behavior is not implemented; it can be added in the cursor layer later without touching the pathfinder.
- **Attack ranges ignore terrain** (you can attack across water and walls), measured from every cell the unit can stop on, over all of its equippable attack weapons.
- **Threat map caching** is keyed on `BattleState.version`, which every state change increments.
- **Generic units are fully proficient** with their class's weapon types, so their equipped weapon is simply the first usable weapon in their inventory.
- **Until the M3 action menu exists, after moving: confirm = Wait, cancel = undo the move.** Confirming on the unit's own cell is "stay here". The M3 action menu replaces the MOVED state's confirm behavior.
- **Undo is limited to moves.** `MoveCommand` supports undo (cancel before acting); every other command clears the undo stack. Rewind (M8) uses state snapshots, not undo.
- **`MoveCommand` recomputes the path when it executes** from the current state, rather than trusting the UI's preview path, so a stale command can't teleport a unit.
- **Battle node tree is built in code** by `BattleScene` (documented in its header); `game/scenes/battle_scene.tscn` is just the root with the script. Running a `BattleMap` scene directly (F6) hosts it in the battle scene (project setting `tactics_core/battle/scene`).
- **Generic unit ids** are `<class id>_<n>` in placement order; named units use their unit id.
- **Placeholder unit art** is drawn in code (faction-colored block, class initial, HP strip). If a class has `map_sprite` set, that texture is used instead, so art drops in through data.
- **World text is drawn at screen size under an inverse scale** (`WorldText`) so letters stay crisp under the 4× camera without changing the font import.
- **The HUD hint line names keys directly** (e.g. "T: enemy threat"). These become remap-aware labels when settings and remapping arrive (M8).
- **`tools/run_tests.sh` runs `--import` first**, so newly added `class_name` scripts and assets are registered before tests load.

---

### M3 (2026-11-10)

- **Inventory entries are `InventorySlot`s** (item, remaining uses, drop flag). Weapons have unlimited uses; consumables count down and vanish at 0. Placements list `drops`, which are appended as drop-flagged slots.
- **Stagger is a per-unit counter** (`stagger_combats`): 1 under NEXT_COMBAT (decremented by the unit's next combat), effectively unlimited under REST_OF_PHASE. `BattleState.clear_staggers()` runs at every phase end (wired in M4).
- **Factions decide who earns EXP** (`FactionData.gains_experience`, on for the player). Defeated units of human-controlled factions retreat; all others are simply defeated.
- **Attacking equips the chosen weapon** (moves it to the top slot), as in FE. The weapon menu only appears when more than one weapon has a target.
- **Free actions (equip, discard, trade) lock in the unit's move**, whether or not it moved, so it can't trade and then go somewhere else. It still has to act (attack, heal, use or wait).
- **Healing needs an injured target**; a Vulnerary can't be used at full HP; HP boosters raise current HP too.
- **One input owner:** `PlayerInputController` handles every battle key press and forwards directions to menus, targets or the trade screen, so menus and the map never fight over input. Menus still handle the mouse directly.
- **Presentation never drives logic:** commands change the state instantly; `CombatPresenter` replays the recorded strikes. Animation durations come from `BattleScene` exports (0 = instant, used by tests).

### M4 (2026-11-10)

- **Phase changes are commands** (`EndPhaseCommand`), so they're validated, logged and replayable like any other action.
- **Units refresh when their own phase ends** (not only when their next phase begins), so the other side never looks greyed out.
- **`BattleFlow` owns sequencing** (banners, the player's phase, AI phases, objective checks after every action); `AIController` animates AI turns; `AIPlanner` is pure and is also used by the debug overlay.
- **AI behaviors live in one planner** (`ai/ai_planner.gd`) rather than separate `behaviors/*.gd` files. Each behavior is a small branch (allowed tiles + fallback move), and keeping them together keeps them consistent. Splitting into files is easy if they grow.
- **The AI approaches distant targets** by flooding the map with an unlimited movement budget (same blocking rules), then walking the cheapest path as far as this turn allows.
- **Kill chance is exact** over hit/miss/crit outcomes of the attacker's strikes (counters ignored), using the active hit mode's true hit rate.
- **Maps carry objectives, defeat conditions, reinforcements and trigger regions** (`BattleMap` exports) until M7's `MapDefinition` takes them over.
- **Seize and Escape are commands** that appear in the action menu only when they apply.
- **Unit creation is centralized** in `UnitFactory` (map start and reinforcements), which also applies difficulty and AI settings. Unit ids are generated by `BattleState.next_unit_id`.

### M5 (2026-11-10)

- **Skills are a hooks script + data.** `SkillData.hooks_script` (extends `SkillHooks`) holds behavior; `SkillData.params` holds the numbers, so one script serves tuned variants (e.g. `aura_hooks.gd` for any "+N to X within R" aura). Hook instances are shared and must be stateless.
- **Skills modify combatants where they are built** (`CombatContext.participant` → `SkillRunner.apply_to_participant`), including auras from allies near the (possibly hypothetical) cell. Forecast, resolver and AI therefore always agree.
- **Spec hook names map as:** `modify_forecast` → `modify_participant` / `modify_ally_participant`; `grants_action` → `grants_canto` (signature attacks come from awakening data in M5.2); `on_strike_resolved` isn't needed by any sample skill yet and isn't implemented.
- **Vantage is a participant flag** (`strikes_first`); when the defender has it, it counters before the attacker's first strike and doesn't counter again.
- **Awakening lives in data + one ruleset slot.** `AwakeningData` (on `UnitData`) says what a unit gains; `Ruleset.awakening_rule` says how awakening is earned and how long it lasts. Swapping cooldown ↔ action charge is a single field in `crossroads_ruleset.tres`. A future `SigilData` can fill `UnitData.awakening` without code changes.
- **Cooldown rule timing:** "lasts 3 turns" = the turn it starts plus the next two of the unit's turns; it ends at the start of the unit's 4th phase, then cooldown counts down at each of its phase starts.
- **Signature attacks are `AttackCommand`s with a hook** (`_customize_attacker`) that adds the signature's `params` (might, hit, crit, damage, no_counter). Any new kind of special attack can subclass the same way.
- **Awakening stat bonuses go through `UnitState.effective_stats()`**; max HP always comes from base stats, so awakening never changes current/max HP bookkeeping.

### M6 (2026-11-10)

- **Dialogue is parsed at load from plain text** (`DialogueLibrary` reads every `<name>.<locale>.dlg`), not imported as Godot resources, so writers edit text files directly. Export presets must include `*.dlg` (M8).
- **Parser extensions beyond §11.2:** `@if !flag -> label` (negated), `@music stop`, scene ids unique across files, and text values for `@set`. Narration without a speaker is an error (use a speaker such as `NARRATOR`).
- **The runner is pure** (`DialogueRunner`), so dialogue logic, flags and branching are unit-tested without UI. `DialoguePlayer` only presents steps.
- **Missing assets never block:** backgrounds, portraits and music fall back to labelled placeholders, with an info log naming the expected file path.
- **Campaign flags live in `CampaignState`** (held by `BattleState.campaign`, passed in by `BattleScene.campaign`). M8 adds the roster and saving to the same resource.
- **One `MapEvent` resource covers all §8.6 triggers.** M4's `TriggerRegion` stays as a lightweight "wake groups / set flags" region; `MapEvent` REGION triggers add dialogue and other actions. Event firings go through commands (`EventCommands.Trigger`, `Talk`, `Visit`) and are logged.
- **Battle quotes play before the attack command executes** (for player and AI attacks), so the state is unchanged while characters talk.
- **Talk and Visit end the unit's action.** Recruiting by Talk moves the listener to the talker's faction (it can't act until the next player phase).

### M7 (2026-11-10)

- **Maps = `BattleMap` + `MapDefinition` + markers.** The definition holds everything not tied to a tile; markers hold everything that is. `BattleMap.get_*()` merges both with the older plain lists, so the M2–M6 test arena keeps working unchanged.
- **Markers are plain `@tool` `Node2D` scripts with `class_name`,** so they appear in Add Child Node without plugin registration. They snap to the grid on every move, draw gizmos only in the editor, and hide at runtime.
- **Range preview for unit markers** builds a throwaway battle state from the map's terrain in the editor; it uses the editor selection via `Engine.get_singleton("EditorInterface")`, so the script still compiles in exported builds.
- **Reinforcement groups own their unit markers** (children on the arrival tiles); unit markers inside a group never spawn at map start.
- **Deployment:** spawn slots fill in slot order. Forced units (slot-specific first, then the definition's list) go first, then the roster, up to `deploy_count` (0 = all slots). Without a campaign, the roster is `game/data/units/test_roster.tres` (project setting `tactics_core/maps/test_roster`).
- **Escape tiles combine** into one Escape objective (count = the highest count on any escape tile).
- **Event flags accept `!flag`** ("only while not set"), used for branching on story choices.

### M8 (2026-11-10)

- **Rewind points are taken before the first command of each player action** (move, or acting in place, or a free action) and before ending the turn, never during other factions' phases. A cancelled move drops its point. Each point is a full `BattleState.copy()` (RNG included) plus campaign flags and the map's objectives.
- **Rewinding drops every later point** and spends one charge; charges are not restored by rewinding.

## GDScript gotchas (read before writing code)

- **Ternaries drop typed-array types.** `x if cond else [] as Array[Vector2i]` produces an untyped `Array` at runtime and fails when passed to a typed parameter. Use if/else and a typed local.
- **Global enums can shadow your names.** Godot's global scope has an enum `Side` (and others); a class enum with the same name silently resolves to the global one. Hence `Strike.Role`.
- **Lambdas typed with class-local enums** sometimes fail to resolve; prefer plain loops in tests.
- **New `class_name` scripts need an import pass** before headless runs; `tools/run_tests.sh` does this.
- **Don't name members after built-in Object properties** (`script`, `name`): `var script` on a RefCounted fails to parse ("Member redefined").
- **Comparing Variants of different types errors** (`true != 0` is a runtime error); test types first (see `DialogueRunner.is_truthy`).
- **`--check-only` cannot see autoloads**, so "Identifier not found: TacticsEvents/RulesetProvider/TacticsRng" from it is a false alarm; trust the test run.

---

## Prior prototype audit (M0.4)

**Source:** `GAME DESIGN/2026/Fire Emblem Prototype/Fire Emblem Prototype/`, a separate Godot 4.6 project (30 sessions, May 2026, ~12.8k lines). It is **not inside this repo**, so nothing will be deleted. The question is what to bring in. Nothing is copied yet except `tools/` (the spec says to keep the generators).

**Why most code doesn't carry over:** its design predates this spec (Luck, Break, Speed doubling, Engage/Sigils, letter weapon ranks, 4-slot inventory). Its architecture also conflicts with §2: game data lives in GDScript dictionaries rather than Resources, combat math is one autoload mixing rules with formulas, `battle.gd` is a 1,945-line scene script that holds state and presentation together, there are no tests or commands, and RNG isn't seeded. Porting code would cost more than rebuilding it to spec. Its value is **assets, tools, and proven UX ideas**.

| Item | Old location | Recommendation |
| --- | --- | --- |
| Sprite/SFX generators | `tools/*.py`, `palette.py` | **Kept** (copied in M0). Repoint output paths to `game/` asset folders when first used (M2), and drop the legacy `gen_unit_sprites.py` once v2 covers everything. |
| Pixelify Sans font (OFL) | `Pixelify_Sans/` | **Keep.** Copy to `game/ui/fonts/` in M2/M3 when the theme is built, if it reads well at 240×135. |
| Terrain tiles PNG + tileset | `assets/tilesets/` | **Migrate** in M2.1: reuse the art, but rebuild the TileSet with a `terrain_id` custom data layer for the §7.2 terrain list (Ruins, Hill, Fort, Road and Doorway are new). |
| Unit sprites (player/enemy pairs) | `assets/sprites/*.png` | **Keep as placeholders** in M2.3. The class names are FE-flavoured (Swordmaster, Halberdier, Wyvern); map them to the new class ids through data. |
| SFX (20 wav) + battle BGM | `assets/audio/` | **Keep as placeholders** (regenerable with `gen_sfx.py`). Rename `engage.wav` → awaken. |
| Combat math | `autoloads/combat_calc.gd` | **Rebuild.** Formulas differ (Luck, triangle ±15, Speed doubling). Replaced by `CombatRules` + the §13.2 fixtures in M1. |
| Grid/pathfinding | `scripts/battle/grid.gd` (BFS + A*) | **Rebuild.** The spec requires Dijkstra with per-movement-type costs and a cached threat map (M2.2). |
| Cursor with hold-to-repeat, path arrow, phase banner, damage popups, EXP bar | `scripts/battle/cursor.gd`, `path_arrow.gd`, `scripts/ui/*.gd` | **Reference for UX feel only.** Rewrite as framework widgets in M2–M4 driven by events. Their feel was already playtested, so match it. |
| Dialogue box with branching choices and cutscenes | `scripts/ui/dialog_box.gd`, `data/dialog_data.gd` | **Rebuild** on the `.dlg` format in M6. Old scene text could be converted to `.dlg` if you want to keep any of it. |
| Battle prep, shop, convoy, map select overworld | `scripts/ui/battle_prep.gd`, `shop.gd`, `convoy.gd`, `map_select.gd` | **Leave out** (§16: shops, convoy, overworld are out of scope). Battle prep may come back later. |
| Sigils / Engage attacks (Astra Storm, Galeforce, ...) | `data/sigil_data.gd` | **Leave out the code.** The designs can seed `UnitData.awakening` signature attacks and the future `SigilData` stub (M5). |
| Maps 01–06 layouts | `maps/`, `scripts/maps/` | **Leave out.** ch00/ch01 are new maps built with the M7 template. |

**Jake's answers (2026-11-10)**
1. Approved: rebuild the code; keep assets and tools as listed.
2. Start fresh: no old characters or dialogue carry over (Tellen, Sable, Gid cast only).
3. UI font is **Inter**, not Pixelify Sans (see M1 decisions).
