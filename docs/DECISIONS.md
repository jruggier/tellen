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
- **Pixel settings:** nearest-neighbour texture filter, 2D transforms snapped to pixels, font antialiasing off. 1920×1080 is exactly 8× the 240×135 base.
- **Autoload registration:** written into `project.godot` and also done by the plugin's `_enable_plugin`, so copying `tactics_core` into another project and enabling it is enough.
- **Event payloads use ids, not Node references** (`unit_id: StringName`, cells as `Vector2i`). This keeps the model/view split (§2.4) and makes events loggable. Signals for combat results, level-ups and awakening are added in the milestone that creates their types (M1/M3/M5) rather than declared early with loose types.
- **RNG streams are derived as `hash("<master_seed>:<stream>")`** and their 64-bit states are saved as strings, because JSON numbers are doubles and would corrupt them. A test round-trips through JSON.
- **`SaveMigrator` exists from M0** (§2a.2). It rejects data newer than the current version or with a missing step instead of loading it half-migrated.
- **Log level** is a project setting (`tactics_core/log/level`). DEBUG/INFO are always off in release builds. WARN and above are forwarded to `TacticsEvents.log_emitted` for the future debug console.
- **M0.1 and M0.2 share one commit.** The project settings register the autoloads, so committing the settings without the autoload scripts would leave a broken project.

---

### M0 Checkpoint (2026-11-10)

- All §18 defaults and the M0 additions (input bindings, `debug_console` action, mouse confirm/cancel) confirmed by Jake.
- UI font: **Inter** (SIL OFL). *(Jake)* Readability check: the whole game renders at 240×135, so text is drawn at that resolution too. Check Inter's legibility at small sizes in the Combat Lab (M1.5). If it's too soft or blocky, the options are: render UI text at full window resolution (switch stretch mode to `canvas_items`, which keeps sprites crisp but changes how pixel snapping works), or use larger text sizes.

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
- **The weapon type id is also its proficiency id**; movement tactics (`ground`, `sky`, `heavy`) use the movement type id.

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
