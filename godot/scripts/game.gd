extends Node2D
## Playable quest mini-game: collect gems, avoid obstacles.
## Completing the level sets quest_state.milestone_reached = true.

const GEMS_NEEDED := 5
const SPEED := 330.0
const VIEW_W := 1152.0
const VIEW_H := 720.0

var player := Vector2(576, 360)
var gems: Array[Vector2] = []
var obstacles: Array[Vector2] = []
var collected := 0
var won := false
var hud: Label

func _ready() -> void:
	gems = [
		Vector2(140, 140), Vector2(920, 120), Vector2(180, 560),
		Vector2(960, 600), Vector2(560, 110), Vector2(300, 360),
		Vector2(840, 360), Vector2(560, 620),
	]
	obstacles = [
		Vector2(576, 250), Vector2(300, 500), Vector2(850, 500),
		Vector2(210, 250), Vector2(950, 270),
	]
	hud = Label.new()
	hud.position = Vector2(16, 12)
	hud.add_theme_font_size_override("font_size", 18)
	add_child(hud)
	_show_hud()

func _process(delta: float) -> void:
	if won:
		return
	var dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	player += dir * SPEED * delta
	player.x = clampf(player.x, 30, VIEW_W - 30)
	player.y = clampf(player.y, 30, VIEW_H - 30)
	for g in gems.duplicate():
		if player.distance_to(g) < 38.0:
			gems.erase(g)
			collected += 1
			_show_hud()
	for o in obstacles:
		if player.distance_to(o) < 34.0:
			player = Vector2(576, 360)
			break
	if collected >= GEMS_NEEDED and not won:
		_finish()
	queue_redraw()

func _draw() -> void:
	draw_circle(player, 18, Color(0.13, 0.76, 0.65))
	for g in gems:
		draw_circle(g, 12, Color(0.98, 0.85, 0.25))
	for o in obstacles:
		draw_rect(Rect2(o - Vector2(22, 22), Vector2(44, 44)), Color(0.94, 0.32, 0.32))

func _show_hud() -> void:
	hud.text = "Collect %d/%d gems   |   Arrows/WASD move · ESC exit" % [collected, GEMS_NEEDED]

func _finish() -> void:
	won = true
	quest_state.milestone_reached = true
	hud.text = "QUEST COMPLETE (%d gems) — milestone reached, returning…" % collected
	await get_tree().create_timer(1.2).timeout
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file("res://scenes/main.tscn")