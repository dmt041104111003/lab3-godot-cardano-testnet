extends Node
## Player profile with local persistence (user://profile.json).

const PATH := "user://profile.json"
const XP_PER_LEVEL := 100

var player_name := ""
var address := ""
var xp := 0
var level := 1
var fragments := 0
var terminals := 0
var quests := { "quest_1": false, "quest_2": false, "quest_3": false }
var verified := { "quest_1": false, "quest_2": false, "quest_3": false }

func _ready() -> void:
	load_profile()

func load_profile() -> void:
	if not FileAccess.file_exists(PATH):
		return
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return
	var data = JSON.parse_string(f.get_as_text())
	if data is Dictionary:
		player_name = str(data.get("name", ""))
		address = str(data.get("address", ""))
		xp = int(data.get("xp", 0))
		level = int(data.get("level", 1))
		fragments = int(data.get("fragments", 0))
		terminals = int(data.get("terminals", 0))
		var q = data.get("quests", {})
		if q is Dictionary:
			for k in quests.keys():
				quests[k] = bool(q.get(k, false))
		var v = data.get("verified", {})
		if v is Dictionary:
			for k in verified.keys():
				verified[k] = bool(v.get(k, false))

func save_profile() -> void:
	var data := {
		"name": player_name,
		"address": address,
		"xp": xp,
		"level": level,
		"fragments": fragments,
		"terminals": terminals,
		"quests": quests,
		"verified": verified,
	}
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(data))

func add_xp(amount: int) -> void:
	xp += amount
	while xp >= level * XP_PER_LEVEL:
		xp -= level * XP_PER_LEVEL
		level += 1

func xp_to_next() -> int:
	return level * XP_PER_LEVEL - xp

func complete_quest(id: String) -> void:
	quests[id] = true
	save_profile()
