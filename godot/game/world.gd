extends Node2D
## Platformer level: run & jump, collect coins, activate terminals, reach the exit.
## Kenney CC0 art. Effects: particles, parallax, coin spin, screen shake.

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
var cam: Camera2D
var bg: Node2D
var coins: Array[Area2D] = []
var terminals: Array[Area2D] = []
var enemies: Array[Area2D] = []
var coins_left := COIN_TOTAL
var terminals_left := TERMINAL_TOTAL
var time := 0.0
var shake_time := 0.0

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

func _safe_tex(path: String) -> Texture2D:
	var t = load(path)
	if t == null:
		var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
		img.fill(Color(0.5, 0.5, 0.5))
		t = ImageTexture.create_from_image(img)
	return t

func _ready() -> void:
	coin_tex = _safe_tex("res://assets/items/coinGold.png")
	grass_mid = _safe_tex("res://assets/tiles/grassMid.png")
	grass_half = _safe_tex("res://assets/tiles/grassHalfMid.png")
	sign_tex = _safe_tex("res://assets/tiles/signExit.png")
	slime1 = _safe_tex("res://assets/enemies/slimeWalk1.png")
	slime2 = _safe_tex("res://assets/enemies/slimeWalk2.png")
	cloud1 = _safe_tex("res://assets/background/cloud1.png")
	cloud2 = _safe_tex("res://assets/background/cloud2.png")
	cloud3 = _safe_tex("res://assets/background/cloud3.png")
	bush = _safe_tex("res://assets/background/bush.png")
	bg = Node2D.new()
	add_child(bg)
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
	player.jumped.connect(func(): _spawn_dust(player.position + Vector2(0, 30)))
	player.landed.connect(func(): _spawn_dust(player.position + Vector2(0, 30), 6))
	cam = Camera2D.new()
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
	_spin_coins()
	if bg != null and cam != null:
		bg.position.x = -cam.position.x * 0.25
		bg.position.y = -cam.position.y * 0.15
	if shake_time > 0.0:
		shake_time -= delta
		cam.offset = Vector2(randf_range(-10, 10), randf_range(-10, 10))
	else:
		cam.offset = Vector2.ZERO

func shake() -> void:
	shake_time = 0.35

# ---------------------------------------------------------------------------
# Building
# ---------------------------------------------------------------------------
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
	a.set_meta("sprite", s)
	a.position = pos
	a.body_entered.connect(func(body):
		if body == player and coins.has(a):
			coins.erase(a)
			coins_left -= 1
			_spawn_burst(a.global_position, Color(1.0, 0.85, 0.3))
			_spawn_popup(a.global_position, "+1", Color(1.0, 0.9, 0.4))
			a.queue_free()
			coins_collected.emit(coins_left)
	)
	add_child(a)
	coins.append(a)

func _spin_coins() -> void:
	for a in coins:
		if is_instance_valid(a):
			var s: Sprite2D = a.get_meta("sprite")
			s.scale.x = (absf(sin(time * 3.0 + a.position.x)) * 0.6 + 0.3)

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
				_spawn_burst(e.global_position, Color(0.6, 1.0, 0.4))
				_spawn_popup(e.global_position, "+50", Color(0.6, 1.0, 0.4))
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
		if e.position.x > base_x + span / 2 or e.position.x < base_x - span / 2:
			d = -d
			e.set_meta("dir", d)
		e.position.x += d * 60.0 * delta
		var s: Sprite2D = e.get_meta("sprite")
		s.texture = slime1 if int(time * 4.0) % 2 == 0 else slime2
		s.flip_h = d < 0

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
			_spawn_burst(a.global_position, Color(0.4, 0.7, 1.0))
			_spawn_popup(a.global_position, "TERMINAL OK", Color(0.6, 0.9, 1.0))
			terminals_activated.emit(terminals_left)
	)
	add_child(a)
	terminals.append(a)

func _check_terminal_activation() -> void:
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

func _build_background() -> void:
	for i in range(0, int(WORLD_W / 400)):
		var c := Sprite2D.new()
		c.texture = cloud1 if i % 3 == 0 else (cloud2 if i % 3 == 1 else cloud3)
		c.scale = Vector2(0.8, 0.8)
		c.position = Vector2(i * 400 + 120, 90 + (i % 3) * 30)
		bg.add_child(c)
	for i in range(0, int(WORLD_W / 320)):
		var b := Sprite2D.new()
		b.texture = bush
		b.position = Vector2(i * 320 + 60, GROUND_Y + 4)
		bg.add_child(b)

# ---------------------------------------------------------------------------
# Effects
# ---------------------------------------------------------------------------
func _spawn_particles(pos: Vector2, color: Color, amount := 12, spread := 180.0) -> void:
	var p := CPUParticles2D.new()
	p.position = pos
	p.emitting = true
	p.one_shot = true
	p.amount = amount
	p.lifetime = 0.5
	p.direction = Vector2(0, -1)
	p.spread = spread
	p.initial_velocity_min = 60
	p.initial_velocity_max = 180
	p.gravity = Vector2(0, 320)
	p.scale_amount_min = 2
	p.scale_amount_max = 4
	p.color = color
	add_child(p)
	get_tree().create_timer(1.0).timeout.connect(func(): p.queue_free())

func _spawn_burst(pos: Vector2, color: Color) -> void:
	_spawn_particles(pos, color, 14)

func _spawn_dust(pos: Vector2, amount := 8) -> void:
	_spawn_particles(pos, Color(0.8, 0.75, 0.7), amount, 120.0)

func _spawn_popup(pos: Vector2, text: String, color: Color) -> void:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.add_theme_font_size_override("font_size", 20)
	l.add_theme_color_override("font_color", color)
	add_child(l)
	var tw := create_tween()
	tw.tween_property(l, "position:y", l.position.y - 42, 0.8)
	tw.tween_property(l, "modulate:a", 0.0, 0.3)
	tw.tween_callback(func(): l.queue_free())

func reset_player() -> void:
	player.position = Vector2(120, GROUND_Y - 120)
	player.velocity = Vector2.ZERO
	shake()