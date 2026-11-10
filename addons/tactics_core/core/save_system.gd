class_name SaveSystem
extends RefCounted
## Campaign saves as versioned JSON in [code]user://saves/[/code]
## (spec §2a.2). Writes go to a temporary file first, so a crash mid-save
## never corrupts an existing save. Loading runs [SaveMigrator]; data that
## can't be migrated is refused instead of loaded half-broken.

const SAVE_DIR: String = "user://saves"


## Path of save [param slot].
static func path_for(slot: int) -> String:
	return "%s/slot_%d.json" % [SAVE_DIR, slot]


static func has_save(slot: int) -> bool:
	return FileAccess.file_exists(path_for(slot))


## Writes [param campaign] to [param slot]. Returns OK or an error.
static func save(campaign: CampaignState, slot: int) -> Error:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAVE_DIR))
	var final_path: String = path_for(slot)
	var temp_path: String = final_path + ".tmp"
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		TacticsLog.error("SaveSystem", "Cannot write %s (%d)" % [temp_path, FileAccess.get_open_error()])
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(campaign.to_dict(), "\t"))
	file.close()
	var dir := DirAccess.open(SAVE_DIR)
	if dir.file_exists(final_path.get_file()):
		dir.remove(final_path.get_file())
	var result: Error = dir.rename(temp_path.get_file(), final_path.get_file())
	if result != OK:
		TacticsLog.error("SaveSystem", "Cannot finish saving %s (%d)" % [final_path, result])
	return result


## Reads [param slot], or null if missing, unreadable or unmigratable.
static func load_save(slot: int, migrator: SaveMigrator = null) -> CampaignState:
	var path: String = path_for(slot)
	if not FileAccess.file_exists(path):
		return null
	var json := JSON.new()
	var parsed: Variant = json.data if json.parse(FileAccess.get_file_as_string(path)) == OK else null
	if not (parsed is Dictionary):
		TacticsLog.warn("SaveSystem", "%s is not a valid save" % path)
		return null
	var data: Dictionary = (migrator if migrator != null else SaveMigrator.new()).migrate(parsed)
	if data.is_empty():
		return null
	return CampaignState.from_dict(data)


static func delete_save(slot: int) -> void:
	if has_save(slot):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path_for(slot)))
