extends GutTest
## Dialogue parser (with line-numbered errors) and runner (§11).

const SPEC_EXAMPLE: String = """=== ch01_intro ===
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
"""


func _parse(text: String) -> DialogueParser.Result:
	return DialogueParser.parse(text, "test.dlg")


func test_spec_example_parses() -> void:
	var result: DialogueParser.Result = _parse(SPEC_EXAMPLE)
	assert_true(result.ok(), "\n".join(result.errors))
	var script: DialogueScript = result.scripts[&"ch01_intro"]
	assert_eq(script.labels.keys(), ["pay", "walk", "end"])
	var first_line: DialogueCommand = script.commands[5]
	assert_eq(first_line.type, DialogueCommand.Type.LINE)
	assert_eq([first_line.speaker, first_line.expression], ["TELLEN", "smirk"])
	assert_eq(script.speakers(), PackedStringArray(["TELLEN", "SABLE", "GID"]))


func test_default_expression_and_comments() -> void:
	var result: DialogueParser.Result = _parse("=== a ===\n# a comment\nGID: Hello.\n")
	assert_true(result.ok())
	var line: DialogueCommand = result.scripts[&"a"].commands[0]
	assert_eq(line.expression, "neutral")
	assert_eq(result.scripts[&"a"].commands.size(), 1, "comment skipped")


func test_errors_have_line_numbers() -> void:
	var result: DialogueParser.Result = _parse("=== a ===\nGID: ok\n@shwo GID left\n@show GID middle\n@goto nowhere\njust narration\n@choice\n@end\n")
	assert_eq(result.errors.size(), 5, "\n".join(result.errors))
	assert_string_contains(result.errors[0], "line 3: unknown command @shwo")
	assert_string_contains(result.errors[1], "line 4: position must be left, center or right")
	assert_string_contains(result.errors[2], "line 6: expected 'NAME: text'")
	assert_string_contains("\n".join(result.errors), "line 7: @choice has no options")
	assert_string_contains("\n".join(result.errors), "line 5: unknown label 'nowhere'")
	assert_true(result.scripts.has(&"a"), "the scene is still returned")


func test_multiple_scenes_and_duplicates() -> void:
	var result: DialogueParser.Result = _parse("=== a ===\nGID: one\n=== b ===\nGID: two\n=== a ===\nGID: three\n")
	assert_eq(result.scripts.size(), 2)
	assert_eq(result.errors.size(), 1)
	assert_string_contains(result.errors[0], "scene 'a' is defined twice")


func test_text_before_header() -> void:
	assert_eq(_parse("GID: hi\n").errors.size(), 1)


func test_set_values() -> void:
	var result: DialogueParser.Result = _parse("=== a ===\n@set x = true\n@set map.y = 3\n@set z = \"words\"\n")
	var commands: Array[DialogueCommand] = result.scripts[&"a"].commands
	assert_eq([commands[0].value, commands[1].value, commands[2].value], [true, 3, "words"])


# Runner ----------------------------------------------------------------------------

func _runner(text: String, map_flags: Dictionary = {}, campaign: Dictionary = {}) -> DialogueRunner:
	var result: DialogueParser.Result = _parse(text)
	assert_true(result.ok(), "\n".join(result.errors))
	return DialogueRunner.new(result.scripts.values()[0], map_flags, campaign)


func test_runner_lines_stage_and_choice() -> void:
	var runner: DialogueRunner = _runner(SPEC_EXAMPLE)
	var step: DialogueRunner.Step = runner.advance()
	assert_eq(step.kind, DialogueRunner.Step.Kind.LINE)
	assert_eq(step.sfx, PackedStringArray(["gulls"]))
	assert_true(step.stage_changed)
	assert_eq(runner.stage.background, "bridge_dusk")
	assert_eq(runner.stage.music, "tension_low")
	assert_eq(runner.stage.actors["left"]["speaker"], "TELLEN")
	assert_eq(runner.advance().speaker, "SABLE")
	step = runner.advance()
	assert_eq([step.speaker, step.text], ["GID", "That crate's ours."])
	assert_eq(runner.stage.item, "stolen_crate")
	step = runner.advance()
	assert_eq(step.kind, DialogueRunner.Step.Kind.CHOICE)
	assert_eq(runner.stage.item, "", "item hidden before the choice")
	assert_eq(step.options, PackedStringArray(["Name your price.", "Walk away."]))
	step = runner.choose(0)
	assert_eq(step.text, "Consider it an investment.")
	assert_eq(runner.campaign_flags["paid_toll"], true)
	assert_eq(runner.advance().kind, DialogueRunner.Step.Kind.END)
	assert_true(runner.is_finished())


func test_runner_if_skips_when_flag_set() -> void:
	var runner: DialogueRunner = _runner(SPEC_EXAMPLE, {}, {"paid_toll": true})
	for i: int in 3:
		runner.advance()
	runner.advance()
	var step: DialogueRunner.Step = runner.choose(1)
	assert_eq(step.kind, DialogueRunner.Step.Kind.END, "@if paid_toll -> end")


func test_map_flags_and_negated_if() -> void:
	var map_flags: Dictionary = {}
	var runner: DialogueRunner = _runner("=== a ===\n@set map.door = true\n@if !map.door -> closed\nGID: Open.\n@end\n@label closed\nGID: Shut.\n", map_flags)
	assert_eq(runner.advance().text, "Open.")
	assert_eq(map_flags["door"], true, "map.* flags go to the map")


func test_expression_change_and_history() -> void:
	var runner: DialogueRunner = _runner("=== a ===\n@show GID left\nGID (angry): Hey!\n@expr GID sad\nGID (sad): Oh.\n")
	assert_true(runner.advance().stage_changed)
	assert_eq(runner.stage.actors["left"]["expression"], "angry")
	runner.advance()
	assert_eq(runner.history.size(), 2)


func test_skip_stops_at_choice() -> void:
	var runner: DialogueRunner = _runner(SPEC_EXAMPLE)
	assert_eq(runner.skip().kind, DialogueRunner.Step.Kind.CHOICE)


func test_endless_goto_is_stopped() -> void:
	var runner: DialogueRunner = _runner("=== a ===\n@label top\n@goto top\n")
	assert_eq(runner.advance().kind, DialogueRunner.Step.Kind.END)
	assert_push_warning_count(1)


func test_library_loads_game_dialogue() -> void:
	var library: DialogueLibrary = DialogueLibrary.load_project("en")
	assert_eq(library.errors.size(), 0, "\n".join(library.errors))
	assert_true(library.has_scene(&"ch01_intro"))
