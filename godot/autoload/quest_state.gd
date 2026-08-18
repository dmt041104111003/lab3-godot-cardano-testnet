extends Node
## Runtime quest state (autoload) - one play session.

var fragments_collected := 0
var terminals_activated := 0
var exit_reached := false
var quest_1_done := false
var quest_2_done := false
var quest_3_done := false
var milestone_reached := false

func reset_run() -> void:
	fragments_collected = 0
	terminals_activated = 0
	exit_reached = false
	quest_1_done = false
	quest_2_done = false
	quest_3_done = false
	milestone_reached = false