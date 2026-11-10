@tool
class_name ChapterData
extends Resource
## One chapter of a campaign: its map and who joins before it.

## The chapter's map scene.
@export_file("*.tscn") var map_path: String = ""
## Translation key or text for the chapter title.
@export var display_name: String = ""
## Units that join the roster before this chapter.
@export var joins: Array[UnitData] = []
