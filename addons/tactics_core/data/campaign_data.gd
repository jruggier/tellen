@tool
class_name CampaignData
extends TacticsData
## The campaign: starting roster and chapters in order.

@export var starting_units: Array[UnitData] = []
@export var chapters: Array[ChapterData] = []


func validate() -> PackedStringArray:
	var problems: PackedStringArray = super()
	if chapters.is_empty():
		problems.append("%s: no chapters" % _label())
	for i: int in chapters.size():
		var chapter: ChapterData = chapters[i]
		if chapter == null or chapter.map_path.is_empty():
			problems.append("%s: chapter %d has no map" % [_label(), i + 1])
		elif not ResourceLoader.exists(chapter.map_path):
			problems.append("%s: chapter %d map not found: %s" % [_label(), i + 1, chapter.map_path])
	return problems
