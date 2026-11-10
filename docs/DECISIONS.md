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
