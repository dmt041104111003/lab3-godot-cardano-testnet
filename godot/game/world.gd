extends Node2D
## Playable level: collect energy fragments, activate terminals, reach the exit.
## Uses Kenney CC0 tiles for the dungeon ground/walls.

signal fragments_collected(count)
signal terminals_activated(count)
signal exit_reached

const VIEW_W := 1152.0
const VIEW_H := 720.0
const TILE := 48.0
const SPEED := 300.0
const FRAGMENT_TOTAL := 5
const TERMINAL_TOTAL := 3

var player := Vector2(VIEW_W / 2, VIEW_H / 2)
var fragments: Array[Vector2] = []
var terminals: Array[Vector2] = []
var exit_pos := Vector2(VIEW_W - 72, VIEW_H - 60)
var show_exit := false
var wall_blocks: Array[Vector2] = []
var hud: Label
var time := 0.0

var floor_tex: Texture2D
var floor_tex2: Texture2D
var wall_tex: Texture2D
var wall_tex2: Texture2D

func _ready() -> void:
	floor_tex = load("res://assets/tiles/tile_0036.png")
	floor_tex2 = load("res://assets/tiles/tile_0038.png")
	wall_tex = load("res://assets/tiles/tile_0000.png")
	wall_tex2 = load("res://assets/tiles/tile_0012.png")
	fragments = [
		Vector2(140, 160), Vector2(VIEW_W - 140, 160), Vector2(140, VIEW_H - 160),
		Vector2(VIEW_W - 140, VIEW_H - 160), Vector2(VIEW_W / 2, 120),
	]
	terminals = [
		Vector2(320, 300), Vector2(VIEW_W - 320, 300), Vector2(VIEW_W / 2, VIEW_H - 160),
	]
	wall_blocks = [
		Vector2(500, 260), Vector2(620, 260), Vector2(560, 380),
		Vector2(380, 460), Vector2(740, 460),
	]
	hud = Label.new()
	hud.position = Vector2(16, 12)
	hud.add_theme_font_size_override("font_size", 18)
	add_child(hud)
	update_hud()

func set_show_exit(v: bool) -> void:
	show_exit = v
	update_hud()

func update_hud() -> void:
	hud.text = "Fragments %d/%d   Terminals %d/%d   |   Arrows/WASD move · ESC exit" % [
		FRAGMENT_TOTAL - fragments.size(), FRAGMENT_TOTAL,
		TERMINAL_TOTAL - terminals.size(), TERMINAL_TOTAL,
	]

func _process(delta: float) -> void:
	time += delta
	var dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	player += dir * SPEED * delta
	player.x = clampf(player.x, TILE, VIEW_W - TILE)
	player.y = clampf(player.y, TILE, VIEW_H - TILE)
	for f in fragments.duplicate():
		if player.distance_to(f) < 42.0:
			fragments.erase(f)
			fragments_collected.emit(FRAGMENT_TOTAL - fragments.size())
			update_hud()
	for t in terminals.duplicate():
		if player.distance_to(t) < 46.0:
			terminals.erase(t)
			terminals_activated.emit(TERMINAL_TOTAL - terminals.size())
			update_hud()
	for wb in wall_blocks:
		if player.distance_to(wb) < 34.0:
			player = Vector2(VIEW_W / 2, VIEW_H / 2)
			break
	if show_exit and player.distance_to(exit_pos) < 50.0:
		exit_reached.emit()
	queue_redraw()

func _draw() -> void:
	# dungeon floor (repeating tiles)
	for gx in range(0, int(VIEW_W / TILE)):
		for gy in range(0, int(VIEW_H / TILE)):
			var tex := floor_tex if (gx + gy) % 2 == 0 else floor_tex2
			draw_texture_rect(tex, Rect2(gx * TILE, gy * TILE, TILE, TILE), false)
	# wall border
	var cols := int(VIEW_W / TILE)
	var rows := int(VIEW_H / TILE)
	for gx in range(cols):
		draw_texture_rect(wall_tex, Rect2(gx * TILE, 0, TILE, TILE), false)
		draw_texture_rect(wall_tex2, Rect2(gx * TILE, (rows - 1) * TILE, TILE, TILE), false)
	for gy in range(rows):
		draw_texture_rect(wall_tex, Rect2(0, gy * TILE, TILE, TILE), false)
		draw_texture_rect(wall_tex2, Rect2((cols - 1) * TILE, gy * TILE, TILE, TILE), false)
	# inner wall blocks
	for wb in wall_blocks:
		draw_texture_rect(wall_tex, Rect2(wb - Vector2(TILE / 2, TILE / 2), Vector2(TILE, TILE)), false)
	# exit portal
	if show_exit:
		var pulse := 0.5 + 0.5 * sin(time * 3.0)
		draw_circle(exit_pos, 30 + pulse * 6, Color(0.3, 0.9, 0.45, 0.4))
		draw_circle(exit_pos, 20, Color(0.35, 0.95, 0.5))
		draw_circle(exit_pos, 10, Color(0.95, 1.0, 0.9))
	# terminals
	for t in terminals:
		draw_rect(Rect2(t - Vector2(22, 22), Vector2(44, 44)), Color(0.25, 0.55, 1.0))
		draw_rect(Rect2(t - Vector2(16, 16), Vector2(32, 32)), Color(0.6, 0.85, 1.0))
		draw_circle(t - Vector2(0, 6), 5, Color(0.15, 0.35, 0.9))
	# fragments (crystals)
	for f in fragments:
		draw_polygon(
			PackedVector2Array([f + Vector2(0, -14), f + Vector2(10, 0), f + Vector2(0, 14), f + Vector2(-10, 0)]),
			PackedColorArray([Color(0.98, 0.8, 0.2), Color(1.0, 0.9, 0.4), Color(0.95, 0.7, 0.1), Color(1.0, 0.85, 0.3)]),
		)
		draw_circle(f, 16, Color(0.98, 0.85, 0.3, 0.25))
	# player hero
	draw_circle(player + Vector2(0, 16), 16, Color(0, 0, 0, 0.3))
	draw_circle(player, 17, Color(0.1, 0.7, 0.6))
	draw_circle(player - Vector2(0, 10), 9, Color(0.95, 0.85, 0.7))
	draw_circle(player + Vector2(-4, -11), 2, Color(0.1, 0.1, 0.2))
	draw_circle(player + Vector2(4, -11), 2, Color(0.1, 0.1, 0.2))