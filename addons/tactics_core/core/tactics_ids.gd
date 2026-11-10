class_name TacticsIds
extends RefCounted
## Shared identifiers and project-setting keys used across the framework.
##
## Only framework-level ids live here (RNG streams, setting paths, versions).
## Game content ids (stats, classes, weapons) are defined by data resources,
## never by constants in this file.

## Named RNG streams. Keeping streams separate means, for example, that
## changing how many growth rolls happen never shifts combat results.
const STREAM_COMBAT: StringName = &"combat"
const STREAM_GROWTH: StringName = &"growth"
const STREAM_AI: StringName = &"ai"
const STREAM_MISC: StringName = &"misc"

## Every stream a fresh [SeededRng] creates up front.
const DEFAULT_STREAMS: Array[StringName] = [STREAM_COMBAT, STREAM_GROWTH, STREAM_AI, STREAM_MISC]

## Project setting holding the resource path of the default [Ruleset].
const SETTING_DEFAULT_RULESET: String = "tactics_core/ruleset/default_path"

## Project setting holding the minimum [TacticsLog] level (see [enum TacticsLog.Level]).
const SETTING_LOG_LEVEL: String = "tactics_core/log/level"

## Version stamped into every serialized framework structure.
## Bump it and register a [SaveMigrator] step whenever a format changes.
const SAVE_VERSION: int = 1
