# Level design guide

How to build a playable map in the Godot editor without writing code. The two shipped chapters (`game/maps/ch00_ruined_crossroads.tscn`, `game/maps/ch01_the_bridge_deal.tscn`) were made exactly this way; open them alongside this guide.

---

## 1. Copy the template

1. In the **FileSystem** dock (bottom left), open `game/maps/_template/`.
2. Right-click `map_template.tscn` → **Duplicate…** → name it like `ch02_the_mill.tscn` and save it in `game/maps/`.
3. Double-click the new file. The **Scene** dock (top left) shows:

```
MapTemplate (BattleMap)        ← select this to edit the map's settings
├── Terrain (TileMapLayer)     ← what the ground IS (costs, bonuses)
├── Decoration (TileMapLayer)  ← looks only; never affects play
└── Markers
    ├── PlayerSlots            ← where the player's units start
    ├── Enemies                ← enemy units
    ├── Allies                 ← allied NPC units
    ├── Reinforcements         ← units that arrive later
    ├── Objectives             ← seize / defend / escape tiles
    ├── Regions                ← areas that trigger events
    └── EventTiles             ← villages and chests
```

4. Rename the root node (double-click it) to match the map, e.g. `Ch02TheMill`.

## 2. Paint the terrain

1. Select **Terrain**. The **TileMap** panel opens at the bottom with the tileset: plains, road, forest, ruins, hill, fort, water, wall, doorway (left to right).
2. Pick a tile, then click or drag on the map to paint (rectangle tool: the square icon; eraser: right-click).
3. The map's playable area is the rectangle covering every painted tile. Paint every cell inside it: unpainted cells inside the rectangle are impassable.
4. Paint **Decoration** for visuals only (it never changes movement or combat).

What each terrain does is listed in `docs/RULES.md` (costs per movement type, avoid, defense, healing). One screen is 30 × 17 tiles; bigger maps scroll.

## 3. Place units and tiles (markers)

Every marker is added the same way: select the group node (e.g. **Enemies**), press **Ctrl/Cmd + A** (Add Child Node), type the marker name, press Enter, then drag it on the map. Markers snap to tiles. Everything else is set in the **Inspector** (right side).

| Marker | Put it under | Set in the Inspector |
| --- | --- | --- |
| **PlayerSpawn** | PlayerSlots | `slot` (fill order); optional `forced_unit` (always deploys here) |
| **EnemyUnit** | Enemies | `class_data` + `level` (generic) **or** `unit_data` (named); `items` (first usable weapon is equipped); `ai_profile`; `ai_group`; `is_boss`; `drops`; optional `stat_overrides`; `unit_id` (name it so events can refer to it) |
| **AllyUnit** | Allies | same as EnemyUnit; faction `ally` |
| **ReinforcementGroup** | Reinforcements | `turn`, `faction_id`, `telegraph`. Then add **EnemyUnit** children *inside the group* on the arrival tiles |
| **SeizeTile** | Objectives | optional `label` (e.g. a translation key for "Seize the mill") |
| **DefendTile** | Objectives | `turns`, optional `label` |
| **EscapeTile** | Objectives | `count` (how many units must escape; all escape tiles form one objective) |
| **RegionMarker** | Regions | `size_cells`, and an `event` (New MapEvent): fill `dialogue_id`, `wake_groups`, `set_flags`, `give_items`... (trigger and area are set automatically) |
| **VillageMarker** | EventTiles | `dialogue_id`, `give_items`, `set_flags`; optional `required_flag` |
| **ChestMarker** | EventTiles | like a village; the menu says "Open" |

**Previews:** select an EnemyUnit or AllyUnit to see its movement (blue) and attack (red) range on the map. The letter is the class (or unit), the small number its level; a crown marks a boss.

**Unit ids:** named units use their own id (`tellen`). Give important enemies a `unit_id` (e.g. `bandit_chief`) so events and objectives can name them; otherwise they get `<class>_<number>`.

**AI:** pick an `ai_profile` from `game/data/ai_profiles/` (charge, hold, stationary, coward, healer) or click **New AIProfile** for guard or wake-on-approach units (set `guard_cell` / `trigger_region` there). Units with the same `ai_group` wake together.

## 4. Fill in the MapDefinition

Select the root node. In the Inspector, expand **Definition**:

- **Map Id** (`ch02_the_mill`), **Display Name**, **Chapter Id**.
- **Factions**: player first (`game/data/factions/player.tres`), then enemy (and ally if used).
- **Victory and defeat**: leave **Objectives** empty for Rout, or add objectives here (Defeat Boss, Survive...) in addition to objective tiles. **Defeat Conditions** default to "protagonist falls" and "everyone falls". **Turn Limit** adds a defeat after that turn.
- **Deployment**: **Deploy Count** (0 = one unit per PlayerSpawn), **Forced Units**.
- **Story**: **Pre Battle Dialogue** and **Post Battle Dialogue** (scene ids from `game/dialogue/`), plus other **Events** (turn scenes, defeat scenes, battle quotes, Talk). See `docs/DIALOGUE.md`.
- **Presentation and tuning**: music id, recommended level, notes for yourself.

## 5. Validate

1. Keep the map open.
2. Open `addons/tactics_core/debug/validate_map.gd` in the **Script** tab.
3. **File → Run** (Ctrl/Cmd + Shift + X).
4. Read the **Output** panel: "no problems found", or one warning per problem, e.g. *"Objective tile (28, 2) cannot be reached from the player's start"*, *"'bandit_chief' at (20, 7) has no weapon it can use"*, *"Event 'quote' uses unknown dialogue 'ch02_bos'"*.

The automated tests also validate every shipped map.

## 6. Play

Press **F6** (Run Current Scene) with the map open. It plays with the test roster (`game/data/units/test_roster.tres`) on your PlayerSpawn slots. Edit, save, F6 again.

---

## Design rules

From Jake's research; check each map against them.

- **One new mechanic per map.** ch00 teaches movement, the forecast, Stagger and follow-ups one encounter at a time; ch01 adds a choke point, a seize goal and an armored (Stagger-immune) gatekeeper.
- **Rout maps are at most 40%** of the campaign. Vary goals: seize, defeat boss, survive, defend, escape.
- **Telegraph reinforcements.** Leave `telegraph` on; the player sees red "!" warnings the phase before. Reinforcements never act on the phase they appear.
- **Bosses should teach something** and move or threaten an area rather than sit on a throne: give them a GUARD profile around a key area, a battle quote, and a matchup worth thinking about (ch00's chief uses hand axes at range; ch01's captain can't be Staggered).
- Give the player a reason to explore: villages, chests, Talk recruits, optional objectives.
- Put healing forts and defensive terrain where you want the player to hold.
