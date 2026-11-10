extends Node
## Main-scene entry point: the autoloads have applied the player's settings,
## so go straight to the title screen ([CampaignFlow.go_to_title]).


func _ready() -> void:
	CampaignFlow.go_to_title.call_deferred()
