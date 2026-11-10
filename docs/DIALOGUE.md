# Dialogue guide

How to write scenes for Tellen. Scenes are plain text files in `game/dialogue/`, written like a screenplay. You don't need to touch code or the Godot editor to write or change dialogue; save the file and run the map.

---

## 1. Files and scenes

- Put files in `game/dialogue/` (subfolders are fine).
- Name them `<name>.<language>.dlg`, e.g. `ch01_bridge.en.dlg`. English is `en`. A future French version would be `ch01_bridge.fr.dlg` next to it; the game picks the player's language and falls back to English.
- One file can hold many scenes. Each scene starts with a header line:

```
=== ch01_intro ===
```

The scene id (`ch01_intro`) is how maps refer to it. Use letters, numbers and underscores; ids must be unique across all files.

## 2. Lines

```
TELLEN: Gentlemen.
TELLEN (smirk): You look like men who appreciate a fair price.
```

- `NAME: text`: the speaker's id in CAPITALS, a colon, then what they say.
- `NAME (expression): text`: also changes their expression (portrait). Without one, the expression is `neutral`.
- The speaker id matches a character's id (`tellen` → `TELLEN`). Characters live in `game/data/characters/` and give the name, its color and the portraits. A speaker with no character file (e.g. `ELDER`) still works and is shown as "Elder".
- Long lines wrap; keep a line to what fits in about two lines of the text box.
- Lines starting with `#` are comments and are ignored. Blank lines are ignored.

## 3. Commands

Commands start with `@` and sit on their own line.

| Command | What it does | Example |
| --- | --- | --- |
| `@bg id` | Background image | `@bg bridge_dusk` |
| `@music id` | Start music (`@music stop` stops it) | `@music tension_low` |
| `@sfx id` | Play a sound once | `@sfx gulls` |
| `@show NAME position [expression]` | Put a character on stage: `left`, `center` or `right` | `@show SABLE right annoyed` |
| `@hide NAME` | Remove a character | `@hide SABLE` |
| `@expr NAME expression` | Change expression without a line | `@expr GID sad` |
| `@item id` | Show an item in the middle of the screen (one at a time) | `@item stolen_crate` |
| `@hide_item` | Remove it | `@hide_item` |
| `@choice` + options | Let the player choose (see below) | |
| `@label name` | A place to jump to | `@label pay` |
| `@goto name` | Jump to a label | `@goto end` |
| `@if flag -> name` | Jump if a flag is set | `@if paid_toll -> end` |
| `@if !flag -> name` | Jump if a flag is **not** set | `@if !map.door_open -> locked` |
| `@set flag = value` | Set a flag (`true`, `false`, a number or text) | `@set paid_toll = true` |
| `@wait seconds` | Pause | `@wait 0.5` |
| `@end` | End the scene here | `@end` |

The speaker of a line is highlighted; other characters on stage dim.

### Choices

```
@choice
- "Name your price." -> pay
- "Walk away." -> walk
```

Each option is `- "text" -> label`. The scene jumps to that label. Every label used must exist in the same scene.

## 4. Flags

Flags remember decisions.

- `map.something` flags belong to the current map and are forgotten when it ends.
- Any other flag (`paid_toll`) is a **campaign flag** and carries over between maps (saved from M8).
- A flag counts as set unless it's missing, `false`, `0` or empty.

Map events can also require a flag (`required_flag`) and set flags (`set_flags`), with the same naming rule.

## 5. Assets and placeholders

Ids are looked up by file name. If a file doesn't exist yet, a labelled placeholder is shown, so you can write scenes before any art exists.

| Kind | Looked up at |
| --- | --- |
| Background | `game/dialogue/backgrounds/<id>.png` |
| Portrait | the character's portrait for that expression; otherwise `game/dialogue/portraits/<speaker>_<expression>.png` (e.g. `tellen_smirk.png`) |
| Music | `game/audio/music/<id>.ogg` |
| Sound | `game/audio/sfx/<id>.wav` |
| Item | an item in `game/data/items` or `weapons` with that id (its icon and name) |

The path patterns are project settings (`tactics_core/dialogue/*_path`) if you want a different folder layout.

## 6. Playing a scene (controls)

| Input | Effect |
| --- | --- |
| Confirm (Z / Enter / click) | Show the rest of the line, then the next line; picks the highlighted choice |
| Cancel (X / Esc) | Skip to the next choice (or the end) |
| R | Backlog: every line so far |
| C | Auto-advance on/off |
| Hold Shift | Fast-forward |
| Arrows | Move between choices |

## 7. When scenes play: map events

Scenes play from **map events**. A map lists its events in the `events` property of its root (`BattleMap`) in the Inspector (M7 adds markers for this). Each event has a trigger, optional conditions, and actions:

| Trigger | When | Settings |
| --- | --- | --- |
| Map Start | Before the first turn (pre-battle scene) | |
| Map End | On victory, before the results (post-battle scene) | |
| Turn | Start of a phase on a given turn | `turn`, `faction_id` (empty = player) |
| Region | A unit stops inside an area | `region`, `faction_id` |
| Unit Defeated | A unit falls | `unit_id` |
| Battle Quote | Before a fight involving a boss or a pair | `unit_id` (empty = any boss), `other_unit_id` (empty = anyone) |
| Talk | The player chooses **Talk** between two adjacent units | `unit_id` (talker), `other_unit_id` (listener) |
| Visit | The player chooses **Visit** on a tile (village, chest) | `cell`, `action_label` |
| Reinforcement | Reinforcements arrive on a turn | `turn` |

Actions (any combination): `dialogue_id` (the scene), `give_items`, `wake_groups`, `set_flags`, `add_objectives`, `spawn` (new units), `recruit` (Talk: the listener joins). Events fire once unless `once` is off, and only while `required_flag` (if any) is set.

Unit ids: named units use their id (`tellen`, `sable`); generic units are `<class>_<number>` in placement order (`brigand_1`, `hexcaller_1`).

## 8. Errors

Mistakes are reported with the file and line number, for example:

```
res://game/dialogue/ch01.en.dlg: line 14: unknown command @shwo
res://game/dialogue/ch01.en.dlg: line 22: unknown label 'ennd'
```

They show as warnings when a battle starts (and in the test run). A scene with a mistake still plays as far as it can.

## 9. Full example

The spec example, which ships in `game/dialogue/ch01_the_bridge_deal.en.dlg`:

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

More examples, wired to events in the test arena: `game/dialogue/arena.en.dlg` (intro, boss quote, recruit-by-talk with a choice, village visit, reinforcement warning, victory).
