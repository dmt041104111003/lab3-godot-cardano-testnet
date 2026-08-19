extends Node2D
## Top-down online village: coins, monsters, skills, lighting, chat presence.

signal coins_collected(count)
signal monsters_killed(count)
signal gate_reached
signal player_damaged
signal player_clicked(address, name)

const ARENA_W := 1600.0
const ARENA_H := 900.0
const COIN_TOTAL := 8
const MONSTER_TOTAL := 3
const CHUNK_SIZE := 512
const CHUNK_MARGIN := 128.0

var player: CharacterBody2D
var cam: Camera2D
var coins_left := COIN_TOTAL
var monsters_left := MONSTER_TOTAL
var monsters: Array[Dictionary] = []
var other_players := {}
var skill1_cd := 0.0
var skill2_cd := 0.0
var time := 0.0
var presence_t := 0.0
var projectiles: Array[Dictionary] = []
var enemy_projectiles: Array[Dictionary] = []
var dying_monsters: Array[Dictionary] = []

var coin_tex: Texture2D
var slime1: Texture2D
var slime2: Texture2D
var grass: Texture2D
var grass2: Texture2D
var bush_tex: Texture2D
var vfx_tex: Texture2D
var nature_tex: Texture2D
var terrain_tex: Texture2D
var props_tex: Texture2D
var enemy_tex: Texture2D
var fire_tex: Texture2D
var custom_slash_tex: Texture2D
var custom_fire_tex: Texture2D
var light_texture: Texture2D
var chest_tex: Texture2D
var slash_textures: Array[Texture2D] = []
var hero_idle_tex: Texture2D
var shake_strength := 0.0
var map_rng := RandomNumberGenerator.new()
var map_seed := 0
var coin_positions: Array[Vector2] = []
var monster_positions: Array[Vector2] = []
var tree_positions: Array[Vector2] = []
var pond_positions: Array[Vector2] = []
var road_polygon := PackedVector2Array()
var gate_position := Vector2.ZERO
var active_chunks := {}
var current_chunk_bounds := Rect2i(999999, 999999, 0, 0)
var sign_tex: Texture2D
var redraw_accum := 0.0
var projectile_particle_accum := 0.0
var player_hit_cd := 0.0
var local_hp := 100

func _safe_tex(path: String) -> Texture2D:
	var t = load(path)
	if t == null:
		var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
		img.fill(Color(0.5, 0.5, 0.5))
		t = ImageTexture.create_from_image(img)
	return t

func _ready() -> void:
	coin_tex = _safe_tex("res://assets/local_pack/ui/coin.png")
	nature_tex = _safe_tex("res://assets/local_pack/world/nature.png")
	terrain_tex = _safe_tex("res://assets/local_pack/world/terrain.png")
	props_tex = _safe_tex("res://assets/local_pack/world/props.png")
	enemy_tex = _safe_tex("res://assets/local_pack/characters/enemy_walk.png")
	fire_tex = _safe_tex("res://assets/local_pack/vfx/fire.png")
	custom_slash_tex = _safe_tex("res://assets/local_pack/skills/arc_slash.png")
	_build_cached_skill_resources()
	chest_tex = _safe_tex("res://assets/local_pack/world/chest.png")
	hero_idle_tex = _safe_tex("res://assets/local_pack/characters/hero_idle.png")
	for i in range(4):
		slash_textures.append(_safe_tex("res://assets/local_pack/vfx/slash_%d.png" % i))
	_generate_map()
	_build_arena()
	_build_coins()
	_build_monsters()
	_build_gate()
	player = load("res://game/player.gd").new()
	player.name = "Player"
	player.position = Vector2(ARENA_W / 2, ARENA_H / 2)
	add_child(player)
	_update_chunks(true)
	cam = Camera2D.new()
	# Direct camera tracking keeps keyboard movement crisp in the Web build.
	cam.position_smoothing_enabled = false
	player.add_child(cam)

func _process(delta: float) -> void:
	time += delta
	skill1_cd = maxf(skill1_cd - delta, 0.0)
	skill2_cd = maxf(skill2_cd - delta, 0.0)
	player_hit_cd = maxf(player_hit_cd - delta, 0.0)
	_wander_monsters(delta)
	_update_light()
	_handle_skills()
	_update_projectiles(delta)
	_update_enemy_projectiles(delta)
	_update_dying_monsters(delta)
	_poll_presence(delta)
	_update_camera_shake(delta)
	_update_chunks()
	redraw_accum += delta
	if redraw_accum >= 0.20:
		redraw_accum = 0.0
		queue_redraw()

# ---------------------------------------------------------------------------
# Arena
# ---------------------------------------------------------------------------
func _build_arena() -> void:
	# Endless world: no hard collision border and no camera limits.
	pass

func _update_chunks(force := false) -> void:
	if player == null:
		return
	var view_size := get_viewport_rect().size
	var half_view := view_size * 0.5 + Vector2.ONE * CHUNK_MARGIN
	var min_chunk := Vector2i(floori((player.position.x - half_view.x) / CHUNK_SIZE), floori((player.position.y - half_view.y) / CHUNK_SIZE))
	var max_chunk := Vector2i(floori((player.position.x + half_view.x) / CHUNK_SIZE), floori((player.position.y + half_view.y) / CHUNK_SIZE))
	var next_bounds := Rect2i(min_chunk, max_chunk - min_chunk + Vector2i.ONE)
	if not force and next_bounds == current_chunk_bounds:
		return
	current_chunk_bounds = next_bounds
	var needed := {}
	for x in range(min_chunk.x, max_chunk.x + 1):
		for y in range(min_chunk.y, max_chunk.y + 1):
			var coord := Vector2i(x, y)
			needed[coord] = true
			if not active_chunks.has(coord):
				active_chunks[coord] = _generate_chunk(coord)
	for coord in active_chunks.keys():
		if not needed.has(coord):
			active_chunks.erase(coord)
	queue_redraw()

func _generate_chunk(coord: Vector2i) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s:%s:%s" % [map_seed, coord.x, coord.y])
	var origin := Vector2(coord.x * CHUNK_SIZE, coord.y * CHUNK_SIZE)
	var trees: Array[Vector2] = []
	var flowers: Array[Vector2] = []
	var ponds: Array[Vector2] = []
	var ruins: Array[Vector2] = []
	var patches: Array[Vector2] = []
	for _i in range(rng.randi_range(1, 2)):
		var tree_pos := origin + Vector2(rng.randf_range(64, CHUNK_SIZE - 64), rng.randf_range(64, CHUNK_SIZE - 64))
		if tree_pos.distance_to(Vector2(ARENA_W * 0.5, ARENA_H * 0.5)) > 180.0:
			trees.append(tree_pos)
	for _i in range(rng.randi_range(2, 4)):
		flowers.append(origin + Vector2(rng.randf_range(20, CHUNK_SIZE - 20), rng.randf_range(20, CHUNK_SIZE - 20)))
	for _i in range(rng.randi_range(1, 2)):
		patches.append(origin + Vector2(rng.randf_range(60, CHUNK_SIZE - 60), rng.randf_range(60, CHUNK_SIZE - 60)))
	if rng.randf() < 0.12:
		ponds.append(origin + Vector2(rng.randf_range(100, CHUNK_SIZE - 100), rng.randf_range(100, CHUNK_SIZE - 100)))
	if rng.randf() < 0.05:
		ruins.append(origin + Vector2(rng.randf_range(120, CHUNK_SIZE - 120), rng.randf_range(110, CHUNK_SIZE - 110)))
	return { "origin": origin, "trees": trees, "flowers": flowers, "patches": patches, "ponds": ponds, "ruins": ruins }

func _generate_map() -> void:
	# A fresh deterministic layout is created every time World is instantiated.
	map_rng.randomize()
	map_seed = map_rng.seed
	var side := map_rng.randi_range(0, 3)
	match side:
		0: gate_position = Vector2(80, map_rng.randf_range(180, ARENA_H - 180))
		1: gate_position = Vector2(ARENA_W - 80, map_rng.randf_range(180, ARENA_H - 180))
		2: gate_position = Vector2(map_rng.randf_range(220, ARENA_W - 220), 80)
		_: gate_position = Vector2(map_rng.randf_range(220, ARENA_W - 220), ARENA_H - 80)
	var center := Vector2(ARENA_W * 0.5, ARENA_H * 0.5)
	var direction := (gate_position - center).normalized()
	var normal := Vector2(-direction.y, direction.x)
	var line: Array[Vector2] = []
	for i in range(6):
		var t := float(i) / 5.0
		var jitter := 0.0 if i == 0 or i == 5 else map_rng.randf_range(-55, 55)
		line.append(center.lerp(gate_position, t) + normal * jitter)
	for p in line:
		road_polygon.append(p + normal * 48)
	for i in range(line.size() - 1, -1, -1):
		road_polygon.append(line[i] - normal * 48)
	var occupied: Array[Vector2] = [center, gate_position]
	for i in range(COIN_TOTAL):
		var p := _random_open_point(occupied, 115.0)
		coin_positions.append(p)
		occupied.append(p)
	for i in range(MONSTER_TOTAL):
		var p := _random_open_point(occupied, 150.0)
		monster_positions.append(p)
		occupied.append(p)
	for i in range(13):
		tree_positions.append(_random_open_point(occupied, 75.0))
	for i in range(3):
		var p := _random_open_point(occupied, 170.0)
		pond_positions.append(p)
		occupied.append(p)

func _random_open_point(occupied: Array[Vector2], min_distance: float) -> Vector2:
	for _attempt in range(80):
		var candidate := Vector2(map_rng.randf_range(100, ARENA_W - 100), map_rng.randf_range(100, ARENA_H - 100))
		var valid := true
		for p in occupied:
			if candidate.distance_to(p) < min_distance:
				valid = false
				break
		if valid:
			return candidate
	return Vector2(map_rng.randf_range(100, ARENA_W - 100), map_rng.randf_range(100, ARENA_H - 100))

func _draw() -> void:
	# Only nearby chunks are retained and rendered; crossing a boundary generates more.
	for chunk in active_chunks.values():
		var origin: Vector2 = chunk.origin
		# Every chunk shares exactly the same base tone. Overlap by two pixels so
		# camera filtering and fractional scaling cannot reveal the joins.
		draw_rect(Rect2(origin - Vector2(2, 2), Vector2(CHUNK_SIZE + 4, CHUNK_SIZE + 4)), Color("#1b472a"))
		# Terrain atlas is used as sparse ground accents, never wallpapered.
		for p in chunk.patches:
			draw_texture_rect_region(terrain_tex, Rect2(p - Vector2(32, 32), Vector2(64, 64)), Rect2(112, 144, 48, 48))
		for p in chunk.ponds:
			draw_circle(p, 58, Color("#285b68"))
			draw_circle(p, 49, Color("#367b8a"))
		for p in chunk.ruins:
			draw_texture_rect_region(props_tex, Rect2(p - Vector2(72, 58), Vector2(144, 116)), Rect2(0, 0, 176, 144))
		for p in chunk.flowers:
			draw_circle(p, 2.5, Color("#d5e889") if int(p.x + p.y) % 2 == 0 else Color("#f2c879"))
		for p in chunk.trees:
			var sway := sin(time * 1.7 + p.x * 0.013) * 3.0
			draw_colored_polygon(PackedVector2Array([p + Vector2(-7, 18), p + Vector2(7, 18), p + Vector2(5 + sway, -30), p + Vector2(-5 + sway, -30)]), Color("#70482c"))
			draw_circle(p + Vector2(sway - 13, -35), 21, Color("#245d37"))
			draw_circle(p + Vector2(sway + 13, -38), 23, Color("#2d7542"))
			draw_circle(p + Vector2(sway, -55), 25, Color("#3a8a4b"))
			draw_circle(p + Vector2(sway - 5, -60), 9, Color(0.42, 0.76, 0.38, 0.34))
	# Quest actors use the actual repository sprites.
	for m in monsters:
		var frame := int(time * 8.0) % 6
		var row := 1 if m.dir.x >= 0 else 2
		if time < float(m.get("hit_until", 0.0)):
			draw_circle(m.pos - Vector2(0, 18), 25, Color(1.0, 0.92, 0.68, 0.72))
		draw_texture_rect_region(enemy_tex, Rect2(m.pos - Vector2(28, 46), Vector2(56, 56)), Rect2(frame * 32, row * 32, 32, 32))
	for m in dying_monsters:
		var alpha := clampf(m.life / 0.55, 0.0, 1.0)
		draw_set_transform(m.pos, PI * 0.5, Vector2.ONE)
		draw_texture_rect_region(enemy_tex, Rect2(Vector2(-28, -46), Vector2(56, 56)), Rect2(0, 32, 32, 32), Color(1, 1, 1, alpha))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# gate glow
	draw_circle(gate_position, 30, Color(0.3, 0.9, 0.45, 0.4))
	draw_circle(gate_position, 18, Color(0.35, 0.95, 0.5))
	draw_texture_rect_region(chest_tex, Rect2(gate_position - Vector2(28, 46), Vector2(56, 72)), Rect2(0, 0, 40, 48))

# ---------------------------------------------------------------------------
# Coins / monsters / gate
# ---------------------------------------------------------------------------
func _build_coins() -> void:
	for p in coin_positions:
		var a := Area2D.new()
		var c := CollisionShape2D.new()
		var cs := CircleShape2D.new(); cs.radius = 26
		c.shape = cs; c.position = Vector2(0, -16)
		a.add_child(c)
		var s := Sprite2D.new(); s.texture = coin_tex; s.scale = Vector2(0.6, 0.6); s.position = Vector2(0, -16)
		a.add_child(s)
		a.position = p
		a.body_entered.connect(func(body):
			if body == player:
				coins_left -= 1
				_spawn_particles(a.global_position, Color(1.0, 0.85, 0.3))
				_spawn_popup(a.global_position, "+1", Color(1.0, 0.9, 0.4))
				a.queue_free()
				coins_collected.emit(coins_left)
		)
		add_child(a)

func _build_monsters() -> void:
	for p in monster_positions:
		var angle := map_rng.randf_range(0, TAU)
		monsters.append({ "pos": p, "hp": 3, "dir": Vector2.from_angle(angle), "shoot_cd": map_rng.randf_range(0.4, 1.2), "sprite": null })

func _wander_monsters(delta: float) -> void:
	for m in monsters:
		m.pos += m.dir * 55.0 * delta
		m.shoot_cd -= delta
		var to_player: Vector2 = player.position - m.pos
		if m.shoot_cd <= 0.0 and to_player.length() < 650.0:
			m.shoot_cd = map_rng.randf_range(1.15, 1.7)
			_spawn_enemy_projectile(m.pos, to_player.normalized())
		if m.pos.x < 120 or m.pos.x > ARENA_W - 120:
			m.dir = Vector2(-m.dir.x, m.dir.y)
		if m.pos.y < 120 or m.pos.y > ARENA_H - 120:
			m.dir = Vector2(m.dir.x, -m.dir.y)
		if player.position.distance_to(m.pos) < 40 and player_hit_cd <= 0.0:
			player_hit_cd = 0.8
			player_damaged.emit()

func _build_gate() -> void:
	var a := Area2D.new()
	var c := CollisionShape2D.new()
	var cs := CircleShape2D.new(); cs.radius = 40
	c.shape = cs; a.add_child(c)
	a.position = gate_position
	a.body_entered.connect(func(body):
		if body == player:
			gate_reached.emit()
	)
	add_child(a)

func _update_light() -> void:
	# keep other players' sprites facing nothing; player light already follows
	pass

# ---------------------------------------------------------------------------
# Skills
# ---------------------------------------------------------------------------
func _handle_skills() -> void:
	if Input.is_action_just_pressed("skill_1"):
		try_cast_skill(1)
	if Input.is_action_just_pressed("skill_2"):
		try_cast_skill(2)

func try_cast_skill(index: int) -> bool:
	if index == 1 and skill1_cd <= 0.0:
		skill1_cd = 0.45
		player.show_attack(0.18)
		_cast_slash()
		return true
	if index == 2 and skill2_cd <= 0.0:
		skill2_cd = 0.85
		player.show_attack(0.24)
		_cast_fireball()
		return true
	return false

func _cast_slash() -> void:
	var dir: Vector2 = player.facing
	var start: Vector2 = player.position + dir * 40
	var end: Vector2 = player.position + dir * 430
	_spawn_ring(start, Color("#64efff"), 54.0, 0.24, 4.0)
	_spawn_direction_streak(player.position, dir, 440.0, Color(0.25, 0.92, 1.0, 0.72), 0.18)
	for i in range(2):
		var wave := _spawn_custom_vfx(custom_slash_tex, start + dir * (44 + i * 24), 0.22 + i * 0.035)
		wave.rotation = dir.angle()
		wave.modulate = Color(0.28 + i * 0.12, 0.78, 1.0, 0.92 - i * 0.18)
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(wave, "position", end + dir * (i * 18), 0.18 + i * 0.035).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		tw.tween_property(wave, "scale", Vector2(0.22 + i * 0.025, 0.22 + i * 0.025), 0.22)
		tw.tween_property(wave, "modulate:a", 0.0, 0.25 + i * 0.04)
		tw.chain().tween_callback(func(): wave.queue_free())
	_spawn_particles(start, Color(0.35, 0.92, 1.0), 8, 80.0)
	_damage_in_direction(player.position, dir, 445.0, 88.0, 1)
	_flash(Color(0.25, 0.9, 1.0, 0.075), 0.10)
	_shake(4.0)

func _cast_fireball() -> void:
	var dir: Vector2 = player.facing
	var node := Node2D.new()
	var aura := Sprite2D.new()
	aura.texture = light_texture
	aura.scale = Vector2(0.52, 0.52)
	aura.modulate = Color(1.0, 0.22, 0.03, 0.62)
	node.add_child(aura)
	var core := Sprite2D.new()
	core.texture = light_texture
	core.scale = Vector2(0.22, 0.22)
	core.modulate = Color(1.0, 0.88, 0.42, 1.0)
	node.add_child(core)
	var glow := PointLight2D.new()
	glow.texture = light_texture
	glow.color = Color("#ff8a24")
	glow.energy = 1.35
	glow.texture_scale = 0.75
	node.add_child(glow)
	var trail := Line2D.new()
	trail.width = 9
	trail.default_color = Color(1.0, 0.34, 0.04, 0.66)
	trail.begin_cap_mode = Line2D.LINE_CAP_ROUND
	trail.end_cap_mode = Line2D.LINE_CAP_ROUND
	trail.points = PackedVector2Array([-dir * 54, Vector2.ZERO])
	node.add_child(trail)
	node.position = player.position + dir * 36
	add_child(node)
	projectiles.append({ "node": node, "dir": dir, "speed": 620.0, "life": 2.4 })
	_spawn_ring(node.position, Color("#ff9a32"), 50.0, 0.30, 5.0)
	_spawn_particles(node.position, Color("#ffb13b"), 6, 70.0)
	_flash(Color(1.0, 0.35, 0.05, 0.055), 0.09)
	_shake(2.5)

func _update_projectiles(delta: float) -> void:
	projectile_particle_accum += delta
	for p in projectiles.duplicate():
		p.life -= delta
		if p.life <= 0.0:
			projectiles.erase(p)
			p.node.queue_free()
			continue
		var node: Node2D = p.node
		node.position += (p.dir as Vector2) * (p.speed as float) * delta
		var pulse := 1.0 + sin(time * 18.0) * 0.055
		node.scale = Vector2(pulse, pulse)
		for m in monsters.duplicate():
			if node.position.distance_to(m.pos) < 30:
				_damage_monster(m, 1)
				_spawn_impact(node.position, true)
				projectiles.erase(p)
				node.queue_free()
				break
	if projectile_particle_accum >= 0.08:
		projectile_particle_accum = 0.0

func _spawn_enemy_projectile(pos: Vector2, dir: Vector2) -> void:
	var orb := Node2D.new()
	orb.position = pos - Vector2(0, 20)
	var aura := Sprite2D.new()
	aura.texture = light_texture
	aura.scale = Vector2(0.28, 0.28)
	aura.modulate = Color(0.68, 0.18, 1.0, 0.78)
	orb.add_child(aura)
	var core := Sprite2D.new()
	core.texture = light_texture
	core.scale = Vector2(0.11, 0.11)
	core.modulate = Color(0.95, 0.72, 1.0, 1.0)
	orb.add_child(core)
	add_child(orb)
	enemy_projectiles.append({ "node": orb, "dir": dir, "life": 2.3 })

func _update_enemy_projectiles(delta: float) -> void:
	for shot in enemy_projectiles.duplicate():
		shot.life -= delta
		var orb: Node2D = shot.node
		orb.position += (shot.dir as Vector2) * 330.0 * delta
		var pulse := 1.0 + sin(time * 22.0) * 0.08
		orb.scale = Vector2(pulse, pulse)
		if shot.life <= 0.0:
			enemy_projectiles.erase(shot)
			orb.queue_free()
		elif orb.position.distance_to(player.position) < 27.0:
			enemy_projectiles.erase(shot)
			_spawn_impact(orb.position, false)
			orb.queue_free()
			if player_hit_cd <= 0.0:
				player_hit_cd = 0.8
				player_damaged.emit()

func _update_dying_monsters(delta: float) -> void:
	for corpse in dying_monsters.duplicate():
		corpse.life -= delta
		if corpse.life <= 0.0:
			dying_monsters.erase(corpse)

func _damage_in_rect(rect: Rect2, dmg: int) -> void:
	for m in monsters.duplicate():
		if rect.has_point(m.pos):
			_damage_monster(m, dmg)

func _damage_in_direction(origin: Vector2, dir: Vector2, reach: float, width: float, dmg: int) -> void:
	for m in monsters.duplicate():
		var offset: Vector2 = m.pos - origin
		var forward := offset.dot(dir)
		var sideways := absf(offset.cross(dir))
		if forward >= 0.0 and forward <= reach and sideways <= width:
			_damage_monster(m, dmg)

func _damage_monster(m: Dictionary, dmg: int) -> void:
	m.hp -= dmg
	m.hit_until = time + 0.13
	var away: Vector2 = (m.pos as Vector2 - player.position).normalized()
	m.pos += away * 18.0
	_spawn_particles(m.pos, Color(1.0, 0.4, 0.3), 8)
	_spawn_popup(m.pos, str(dmg), Color(1.0, 0.5, 0.4))
	var hit := _spawn_vfx(1, m.pos, 0.065)
	var hit_tw := create_tween()
	hit_tw.set_parallel(true)
	hit_tw.tween_property(hit, "scale", Vector2(0.12, 0.12), 0.18)
	hit_tw.tween_property(hit, "modulate:a", 0.0, 0.25)
	hit_tw.tween_callback(func(): hit.queue_free())
	if m.hp <= 0:
		dying_monsters.append({ "pos": m.pos, "life": 0.55 })
		monsters.erase(m)
		monsters_left -= 1
		_spawn_particles(m.pos, Color(0.6, 1.0, 0.4), 16)
		_spawn_popup(m.pos, "+50", Color(0.6, 1.0, 0.4))
		_spawn_impact(m.pos, true)
		_shake(5.0)
		monsters_killed.emit(monsters_left)

func _vfx_sprite(cell: int) -> Sprite2D:
	var sprite := Sprite2D.new()
	if cell == 2:
		var atlas := AtlasTexture.new()
		atlas.atlas = fire_tex
		atlas.region = Rect2((int(time * 10.0) % 4) * 32, 0, 32, 32)
		sprite.texture = atlas
	else:
		sprite.texture = slash_textures[clampi(cell, 0, 3)]
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return sprite

func _spawn_vfx(cell: int, pos: Vector2, effect_scale: float) -> Sprite2D:
	var sprite := _vfx_sprite(cell)
	sprite.position = pos
	sprite.scale = Vector2(effect_scale, effect_scale)
	add_child(sprite)
	return sprite

func _custom_vfx_sprite(texture: Texture2D) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	return sprite

func _spawn_custom_vfx(texture: Texture2D, pos: Vector2, effect_scale: float) -> Sprite2D:
	var sprite := _custom_vfx_sprite(texture)
	sprite.position = pos
	sprite.scale = Vector2(effect_scale, effect_scale)
	add_child(sprite)
	return sprite

func _spawn_impact(pos: Vector2, fiery: bool) -> void:
	var impact_color := Color("#ff8a22") if fiery else Color("#52e8ff")
	var fx: CanvasItem
	if fiery:
		fx = _spawn_energy_burst(pos, impact_color)
	else:
		fx = _spawn_vfx(1, pos, 0.055)
	_spawn_ring(pos, impact_color, 62.0 if fiery else 48.0, 0.34, 5.0)
	_spawn_ring(pos, Color(1, 1, 1, 0.82), 34.0, 0.20, 2.5)
	if not fiery:
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(fx, "scale", Vector2(0.13, 0.13), 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(fx, "modulate:a", 0.0, 0.42).set_delay(0.10)
		tw.tween_callback(func(): fx.queue_free()).set_delay(0.45)
	_spawn_particles(pos, impact_color, 8 if fiery else 7, 150.0)
	_flash(Color(impact_color, 0.035), 0.07)
	_shake(4.0)

func _spawn_ring(pos: Vector2, color: Color, radius: float, duration: float, width: float) -> void:
	var ring := Line2D.new()
	ring.position = pos
	ring.width = width
	ring.default_color = color
	ring.closed = true
	ring.antialiased = true
	var points := PackedVector2Array()
	for i in range(33):
		var angle := TAU * float(i) / 32.0
		points.append(Vector2.from_angle(angle) * radius)
	ring.points = points
	ring.scale = Vector2(0.28, 0.28)
	add_child(ring)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(ring, "scale", Vector2(1.15, 1.15), duration).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(ring, "modulate:a", 0.0, duration).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(func(): ring.queue_free())

func _spawn_direction_streak(pos: Vector2, dir: Vector2, reach: float, color: Color, duration: float) -> void:
	var streak := Line2D.new()
	streak.width = 8.0
	streak.default_color = color
	streak.begin_cap_mode = Line2D.LINE_CAP_ROUND
	streak.end_cap_mode = Line2D.LINE_CAP_ROUND
	streak.points = PackedVector2Array([pos + dir * 25.0, pos + dir * reach])
	add_child(streak)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(streak, "width", 1.0, duration)
	tw.tween_property(streak, "modulate:a", 0.0, duration)
	tw.chain().tween_callback(func(): streak.queue_free())

func _flash(color: Color, duration: float) -> void:
	var flash := ColorRect.new()
	flash.color = color
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	layer.add_child(flash)
	var tw := create_tween()
	tw.tween_property(flash, "color:a", 0.0, duration)
	tw.tween_callback(func(): layer.queue_free())

func _shake(amount: float) -> void:
	shake_strength = maxf(shake_strength, amount)

func _update_camera_shake(delta: float) -> void:
	if cam == null:
		return
	shake_strength = move_toward(shake_strength, 0.0, delta * 35.0)
	cam.offset = Vector2(randf_range(-shake_strength, shake_strength), randf_range(-shake_strength, shake_strength))

func _build_cached_skill_resources() -> void:
	light_texture = _make_radial_light_texture()

func _spawn_energy_burst(pos: Vector2, color: Color) -> Node2D:
	var holder := Node2D.new()
	holder.position = pos
	add_child(holder)
	var aura := Sprite2D.new()
	aura.texture = light_texture
	aura.modulate = Color(color, 0.88)
	aura.scale = Vector2(0.18, 0.18)
	holder.add_child(aura)
	var core := Sprite2D.new()
	core.texture = light_texture
	core.modulate = Color(1.0, 0.92, 0.62, 1.0)
	core.scale = Vector2(0.08, 0.08)
	holder.add_child(core)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(aura, "scale", Vector2(1.25, 1.25), 0.24).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(aura, "modulate:a", 0.0, 0.30)
	tw.tween_property(core, "scale", Vector2(0.46, 0.46), 0.15).set_trans(Tween.TRANS_BACK)
	tw.tween_property(core, "modulate:a", 0.0, 0.23)
	tw.chain().tween_callback(func(): holder.queue_free())
	return holder

func _make_radial_light_texture() -> Texture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 1))
	gradient.set_color(1, Color(1, 1, 1, 0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 128
	texture.height = 128
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	return texture

# ---------------------------------------------------------------------------
# Other players (online presence)
# ---------------------------------------------------------------------------
func _poll_presence(delta: float) -> void:
	presence_t += delta
	if presence_t < 0.35:
		return
	presence_t = 0.0
	if profile.address == "":
		return
	cardano_service.send_presence(profile.address, profile.player_name, player.position.x, player.position.y, profile.level, player.action_state, player.facing, local_hp, func(_r, _c, _d): pass)
	cardano_service.fetch_presence(_cb_presence)

func _cb_presence(result: int, code: int, data) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code != 200 or data == null or not data.get("ok", false):
		return
	var players = data.get("players", [])
	var seen := {}
	for p in players:
		var addr: String = str(p.get("address", ""))
		if addr == profile.address or addr == "":
			continue
		seen[addr] = true
		var x := float(p.get("x", 0))
		var y := float(p.get("y", 0))
		if other_players.has(addr):
			var n = other_players[addr]
			var target := Vector2(x, y)
			n.position = n.position.lerp(target, 0.68)
			var state := str(p.get("state", "idle"))
			var remote_sprite: Sprite2D = n.get_node("Sprite")
			remote_sprite.flip_h = float(p.get("facing_x", 0.0)) > 0.0
			remote_sprite.rotation = PI * 0.5 if state == "dead" else 0.0
			remote_sprite.modulate = Color(1.0, 0.35, 0.35) if state == "hurt" else Color.WHITE
		else:
			var holder := Node2D.new()
			var s := Sprite2D.new()
			s.name = "Sprite"
			var other_atlas := AtlasTexture.new()
			other_atlas.atlas = hero_idle_tex
			other_atlas.region = Rect2(0, 0, 32, 32)
			s.texture = other_atlas
			s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			s.scale = Vector2(2.0, 2.0)
			s.position = Vector2(0, -18)
			holder.add_child(s)
			var name_l := Label.new()
			name_l.text = str(p.get("name", "Player"))
			name_l.add_theme_font_size_override("font_size", 12)
			name_l.add_theme_color_override("font_color", Color(0.5, 1.0, 0.7))
			name_l.position = Vector2(-30, -70)
			holder.add_child(name_l)
			var hb := Area2D.new()
			var cs := CircleShape2D.new(); cs.radius = 30
			var col := CollisionShape2D.new(); col.shape = cs
			hb.add_child(col)
			holder.add_child(hb)
			holder.position = Vector2(x, y)
			holder.set_meta("addr", addr)
			hb.input_event.connect(func(_v, _e, _i, _s): player_clicked.emit(addr, str(p.get("name", "Player"))))
			add_child(holder)
			other_players[addr] = holder
	for addr in other_players.keys():
		if not seen.has(addr):
			var n = other_players[addr]
			other_players.erase(addr)
			n.queue_free()

# ---------------------------------------------------------------------------
# Effects
# ---------------------------------------------------------------------------
func _spawn_particles(pos: Vector2, color: Color, amount := 10, spread := 180.0) -> void:
	var pt := CPUParticles2D.new()
	pt.position = pos
	pt.emitting = true
	pt.one_shot = true
	pt.amount = amount
	pt.lifetime = 0.45
	pt.direction = Vector2(0, -1)
	pt.spread = spread
	pt.initial_velocity_min = 60
	pt.initial_velocity_max = 180
	pt.gravity = Vector2(0, 120)
	pt.scale_amount_min = 2
	pt.scale_amount_max = 4
	pt.color = color
	add_child(pt)
	get_tree().create_timer(1.0).timeout.connect(func(): pt.queue_free())

func _spawn_popup(pos: Vector2, text: String, color: Color) -> void:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.add_theme_font_size_override("font_size", 20)
	l.add_theme_color_override("font_color", color)
	add_child(l)
	var tw := create_tween()
	tw.tween_property(l, "position:y", l.position.y - 40, 0.8)
	tw.tween_property(l, "modulate:a", 0.0, 0.3)
	tw.tween_callback(func(): l.queue_free())

func reset_player() -> void:
	player.position = Vector2(ARENA_W / 2, ARENA_H / 2)
	player.velocity = Vector2.ZERO
