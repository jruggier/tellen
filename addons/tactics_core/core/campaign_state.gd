class_name CampaignState
extends Resource
## State that persists across maps: campaign flags now; roster, levels and
## inventory are added in M8 (spec §8.2/M8). Dialogue flags without the
## [code]map.[/code] prefix live here.

## Version for save migration (see [SaveMigrator]).
@export var save_version: int = TacticsIds.SAVE_VERSION
## Flag name → value.
@export var flags: Dictionary = {}
