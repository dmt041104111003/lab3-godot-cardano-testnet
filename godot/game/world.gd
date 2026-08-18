extends Node2D
## Platformer level: run & jump, collect coins, activate terminals, reach the exit.
## Uses Kenney Platformer Art (Deluxe) / alien sprites (CC0).

signal coins_collected(count)
signal terminals_activated(count)
signal exit_reached
signal player_damaged

const WORLD_W := 3200.0
const GROUND_Y := 620.0
const TILE := 70.0
const COIN_TOTAL := 8
const TERMINAL_TOTAL := 2

var player: CharacterBody2D
var coins: Array[Area2D] = []
var terminals: Array[Area2D] = []
var enemies: Array[Area2D] = []
var goal: Area2D
var coins_left := COIN_TOTAL
var terminals_left := TERMINAL_TOTAL
var time := 0.0

var coin_tex: Texture2D
var grass_mid: Texture2D
var grass_half: Texture2D
var sign_tex: Texture2D
var slime1: Texture2D
var slime2: Texture2D
var cloud1: Texture2D
var cloud2: Texture2D
var cloud3: Texture2D
var bush: Texture2D

func _ready() -> void:
	coin_tex = load("res://assets/items/coinGold.png")
	grass_mid = load("res://assets/tiles/grassMid.png")
	grass_half = load("res://assets/tiles/grassHalfMid.png")
	sign_tex = load("res://assets/tiles/signExit.png")
	slime1 = load("res://assets/enemies/slimeWalk1.png")
	slime2 = load("res://assets/enemies/slimeWalk2.png")
	cloud1 = load("res://assets/background/cloud1.png")
	cloud2 = load("res://assets/background/cloud2.png")
	cloud3 = load("res://assets/background/cloud3.png")
	bush = load("res://assets/background/bush.png")
	_build_background()
	_build_ground()
	_build_platforms()
	_build_coins()
	_build_enemies()
	_build_terminals()
	_build_goal()
	player = load("res://game/player.gd").new()
	player.name = "Player"
	player.position = Vector2(120, GROUND_Y - 120)
	add_child(player)
	var cam := Camera2D.new()
	cam.limit_left = 0
	cam.limit_right = int(WORLD_W)
	cam.limit_top = 0
	cam.limit_bottom = 720
	cam.position_smoothing_enabled = true
	player.add_child(cam)

func _process(delta: float) -> void:
	time += delta
	_patrol_enemies(delta)
	_check_terminal_activation()

func _add_ground_segment(rect: Rect2) -> void:
	var body := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = rect.size
	shape.shape = rs
	shape.position = rect.position + rect.size / 2
	body.add_child(shape)
	add_child(body)
	var t := int(rect.size.x / TILE)
	for i in range(t):
		var s := Sprite2D.new()
		s.texture = grass_mid
		s.position = Vector2(rect.position.x + i * TILE + TILE / 2, rect.position.y + rect.size.y / 2)
		add_child(s)

func _build_ground() -> void:
	_add_ground_segment(Rect2(0, GROUND_Y, WORLD_W, 100))

func _build_platforms() -> void:
	_add_platform(Vector2(520, 470), 3)
	_add_platform(Vector2(940, 390), 3)
	_add_platform(Vector2(1330, 320), 4)
	_add_platform(Vector2(1850, 400), 3)
	_add_platform(Vector2(2350, 310), 4)
	_add_platform(Vector2(2860, 400), 3)

func _add_platform(center: Vector2, tiles: int) -> void:
	var w := tiles * TILE
	var body := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = Vector2(w, TILE)
	shape.shape = rs
	body.add_child(shape)
	body.position = center
	add_child(body)
	for i in range(tiles):
		var s := Sprite2D.new()
		s.texture = grass_mid
		s.position = Vector2(center.x + (i - (tiles - 1) / 2.0) * TILE, center.y)
		add_child(s)

func _build_coins() -> void:
	var positions := [
		Vector2(180, GROUND_Y - 90), Vector2(360, GROUND_Y - 90),
		Vector2(520, 470 - 70), Vector2(940, 390 - 70),
		Vector2(1330, 320 - 70), Vector2(1850, 400 - 70),
		Vector2(2350, 310 - 70), Vector2(3000, GROUND_Y - 90),
	]
	for p in positions:
		_add_coin(p)

func _add_coin(pos: Vector2) -> void:
	var a := Area2D.new()
	var c := CollisionShape2D.new()
	var cs := CircleShape2D.new()
	cs.radius = 24
	c.shape = cs
	c.position = Vector2(0, -20)
	a.add_child(c)
	var s := Sprite2D.new()
	s.texture = coin_tex
	s.scale = Vector2(0.6, 0.6)
	s.position = Vector2(0, -20)
	a.add_child(s)
	a.position = pos
	a.body_entered.connect(func(body):
		if body == player and coins.has(a):
			coins.erase(a)
			coins_left -= 1
			a.queue_free()
			coins_collected.emit(coins_left)
	)
	add_child(a)
	coins.append(a)

func _build_enemies() -> void:
	_add_enemy(Vector2(700, GROUND_Y - 14), 260)
	_add_enemy(Vector2(1200, GROUND_Y - 14), 220)
	_add_enemy(Vector2(2100, GROUND_Y - 14), 320)
	_add_enemy(Vector2(2650, GROUND_Y - 14), 260)

func _add_enemy(pos: Vector2, span: float) -> void:
	var e := Area2D.new()
	var c := CollisionShape2D.new()
	var cs := CircleShape2D.new()
	cs.radius = 20
	c.shape = cs
	c.position = Vector2(0, -12)
	e.add_child(c)
	var s := Sprite2D.new()
	s.texture = slime1
	s.scale = Vector2(1.6, 1.6)
	s.position = Vector2(0, -14)
	e.add_child(s)
	e.position = pos
	e.set_meta("span", span)
	e.set_meta("base_x", pos.x)
	e.set_meta("dir", 1.0)
	e.set_meta("sprite", s)
	e.body_entered.connect(func(body):
		if body == player and enemies.has(e):
			if body.velocity.y > 120.0 and body.global_position.y < e.global_position.y - 10.0:
				enemies.erase(e)
				e.queue_free()
			else:
				player_damaged.emit()
	)
	add_child(e)
	enemies.append(e)

func _patrol_enemies(delta: float) -> void:
	for e in enemies:
		if not is_instance_valid(e):
			continue
		var span: float = e.get_meta("span")
		var base_x: float = e.get_meta("base_x")
		var d: float = e.get_meta("dir")
		var x: float = e.position.x
		if x > base_x + span / 2 or x < base_x - span / 2:
			d = -d
			e.set_meta("dir", d)
		e.position.x += d * 60.0 * delta
		var s: Sprite2D = e.get_meta("sprite")
		s.texture = slime1 if int(time * 4.0) % 2 == 0 else slime2
		e.position.y = GROUND_Y - 14

func _build_terminals() -> void:
	_add_terminal(Vector2(1600, GROUND_Y - 40))
	_add_terminal(Vector2(2550, GROUND_Y - 40))

func _add_terminal(pos: Vector2) -> void:
	var a := Area2D.new()
	var c := CollisionShape2D.new()
	var cs := CircleShape2D.new()
	cs.radius = 34
	c.shape = cs
	a.add_child(c)
	var poly := Polygon2D.new()
	poly.polygon = PackedVector2Array([
		Vector2(-22, 0), Vector2(22, 0), Vector2(16, 44), Vector2(-16, 44),
	])
	poly.color = Color(0.35, 0.6, 1.0)
	a.add_child(poly)
	var glow := Polygon2D.new()
	glow.polygon = PackedVector2Array([
		Vector2(-12, 4), Vector2(12, 4), Vector2(8, 28), Vector2(-8, 28),
	])
	glow.color = Color(0.8, 0.9, 1.0)
	a.add_child(glow)
	a.position = pos
	a.set_meta("active", false)
	a.body_entered.connect(func(body):
		if body == player and not a.get_meta("active") and terminals.has(a):
			a.set_meta("active", true)
			a.queue_free()
			terminals_left -= 1
			terminals_activated.emit(terminals_left)
	)
	add_child(a)
	terminals.append(a)

func _check_terminal_activation() -> void:
	# visual pulse for remaining terminals
	for t in terminals:
		if is_instance_valid(t):
			var pulse := 0.5 + 0.5 * sin(time * 3.0)
			t.get_child(1).color = Color(0.35 + 0.1 * pulse, 0.6, 1.0)

func _build_goal() -> void:
	var a := Area2D.new()
	var c := CollisionShape2D.new()
	var cs := CircleShape2D.new()
	cs.radius = 36
	c.shape = cs
	c.position = Vector2(0, -30)
	a.add_child(c)
	var s := Sprite2D.new()
	s.texture = sign_tex
	s.position = Vector2(0, -20)
	a.add_child(s)
	a.position = Vector2(WORLD_W - 100, GROUND_Y - 40)
	a.body_entered.connect(func(body):
		if body == player:
			exit_reached.emit()
	)
	add_child(a)
	goal = a

func _build_background() -> void:
	for i in range(0, int(WORLD_W / 400)):
		var c := Sprite2D.new()
		c.texture = cloud1 if i % 3 == 0 else (cloud2 if i % 3 == 1 else cloud3)
		c.scale = Vector2(0.8, 0.8)
		c.position = Vector2(i * 400 + 120, 90 + (i % 3) * 30)
		add_child(c)
	for i in range(0, int(WORLD_W / 320)):
		var b := Sprite2D.new()
		b.texture = bush
		b.position = Vector2(i * 320 + 60, GROUND_Y + 4)
		add_child(b)

func reset_player() -> void:
	player.position = Vector2(120, GROUND_Y - 120)
	player.velocity = Vector2.ZERO