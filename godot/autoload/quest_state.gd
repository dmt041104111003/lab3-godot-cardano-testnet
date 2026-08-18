extends Node
## Autoload singleton: quest milestone state shared between scenes.

var milestone_reached := false
var quest_id := "quest_001"

func reset() -> void:
	milestone_reached = false