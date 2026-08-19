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
const CHUNK_RADIUS := 1

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
var current_chunk := Vector2i(999999, 999999)
var sign_tex: Texture2D
var redraw_accum := 0.0
var projectile_particle_accum := 0.0

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
	var light := PointLight2D.new()
	light.position = Vector2(0, -10)
	light.energy = 1.3
	light.texture_scale = 10.0
	light.color = Color(1.0, 0.95, 0.8)
	light.texture = _radial_light_texture()
	player.add_child(light)
	cam = Camera2D.new()
	cam.position_smoothing_enabled = true
	player.add_child(cam)
	var dark := CanvasModulate.new()
	dark.color = Color(0.68, 0.72, 0.78)
	add_child(dark)

func _process(delta: float) -> void:
	time += delta
	skill1_cd = maxf(skill1_cd - delta, 0.0)
	skill2_cd = maxf(skill2_cd - delta, 0.0)
	_wander_monsters(delta)
	_update_light()
	_handle_skills()
	_update_projectiles(delta)
	_poll_presence(delta)
	_update_camera_shake(delta)
	_update_chunks()
	redraw_accum += delta
	if redraw_accum >= 0.12:
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
	var next_chunk := Vector2i(floori(player.position.x / CHUNK_SIZE), floori(player.position.y / CHUNK_SIZE))
	if not force and next_chunk == current_chunk:
		return
	current_chunk = next_chunk
	var needed := {}
	for x in range(current_chunk.x - CHUNK_RADIUS, current_chunk.x + CHUNK_RADIUS + 1):
		for y in range(current_chunk.y - CHUNK_RADIUS, current_chunk.y + CHUNK_RADIUS + 1):
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
	for _i in range(rng.randi_range(2, 4)):
		var tree_pos := origin + Vector2(rng.randf_range(64, CHUNK_SIZE - 64), rng.randf_range(64, CHUNK_SIZE - 64))
		if tree_pos.distance_to(Vector2(ARENA_W * 0.5, ARENA_H * 0.5)) > 180.0:
			trees.append(tree_pos)
	for _i in range(rng.randi_range(4, 7)):
		flowers.append(origin + Vector2(rng.randf_range(20, CHUNK_SIZE - 20), rng.randf_range(20, CHUNK_SIZE - 20)))
	for _i in range(rng.randi_range(1, 2)):
		patches.append(origin + Vector2(rng.randf_range(60, CHUNK_SIZE - 60), rng.randf_range(60, CHUNK_SIZE - 60)))
	if rng.randf() < 0.12:
		ponds.append(origin + Vector2(rng.randf_range(100, CHUNK_SIZE - 100), rng.randf_range(100, CHUNK_SIZE - 100)))
	if rng.randf() < 0.05:
		ruins.append(origin + Vector2(rng.randf_range(120, CHUNK_SIZE - 120), rng.randf_range(110, CHUNK_SIZE - 110)))
	return { "origin": origin, "trees": trees, "flowers": flowers, "patches": patches, "ponds": ponds, "ruins": ruins, "tone": rng.randf_range(-0.012, 0.012) }

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
		var tone: float = chunk.tone
		draw_rect(Rect2(origin, Vector2(CHUNK_SIZE, CHUNK_SIZE)), Color(0.16 + tone, 0.29 + tone, 0.20 + tone))
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
			draw_circle(p + Vector2(4, 8), 25, Color(0, 0, 0, 0.16))
			var tree_variant: int = abs(int(p.x + p.y)) % 3
			var src: Rect2 = [Rect2(0, 0, 64, 96), Rect2(64, 0, 64, 96), Rect2(128, 64, 64, 64)][tree_variant]
			draw_texture_rect_region(nature_tex, Rect2(p - Vector2(34, 62), Vector2(68, 96)), src)
	# Quest actors use the actual repository sprites.
	for m in monsters:
		var frame := int(time * 8.0) % 6
		var row := 1 if m.dir.x >= 0 else 2
		draw_texture_rect_region(enemy_tex, Rect2(m.pos - Vector2(28, 46), Vector2(56, 56)), Rect2(frame * 32, row * 32, 32, 32))
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
		monsters.append({ "pos": p, "hp": 3, "dir": Vector2.from_angle(angle), "sprite": null })

func _wander_monsters(delta: float) -> void:
	for m in monsters:
		m.pos += m.dir * 40.0 * delta
		if m.pos.x < 120 or m.pos.x > ARENA_W - 120:
			m.dir = Vector2(-m.dir.x, m.dir.y)
		if m.pos.y < 120 or m.pos.y > ARENA_H - 120:
			m.dir = Vector2(m.dir.x, -m.dir.y)
		if player.position.distance_to(m.pos) < 40:
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
	if Input.is_action_just_pressed("skill_1") and skill1_cd <= 0.0:
		skill1_cd = 1.0
		_cast_slash()
	if Input.is_action_just_pressed("skill_2") and skill2_cd <= 0.0:
		skill2_cd = 2.0
		_cast_fireball()

func _cast_slash() -> void:
	var dir: Vector2 = player.facing
	var start: Vector2 = player.position + dir * 40
	var end: Vector2 = player.position + dir * 260
	var wave := _spawn_vfx(0, start + dir * 55, 0.18)
	wave.rotation = dir.angle()
	wave.modulate = Color(0.65, 1.0, 1.0, 0.95)
	_spawn_particles(start, Color(0.4, 0.9, 1.0), 10)
	_damage_in_rect(Rect2(start.x - 30, start.y - 40, dir.x * 260 + 60, 80), 1)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(wave, "position", end, 0.22).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(wave, "scale", Vector2(0.24, 0.24), 0.22)
	tw.tween_property(wave, "modulate:a", 0.0, 0.28)
	tw.tween_callback(func(): wave.queue_free())
	_flash(Color(0.25, 0.9, 1.0, 0.045), 0.08)
	_shake(3.0)

func _cast_fireball() -> void:
	var dir: Vector2 = player.facing
	var node := Node2D.new()
	var col := _vfx_sprite(2)
	col.scale = Vector2(1.45, 1.45)
	col.rotation = dir.angle()
	node.add_child(col)
	var trail := Line2D.new()
	trail.width = 9
	trail.default_color = Color(1.0, 0.52, 0.14, 0.55)
	trail.begin_cap_mode = Line2D.LINE_CAP_ROUND
	trail.end_cap_mode = Line2D.LINE_CAP_ROUND
	trail.points = PackedVector2Array([Vector2.ZERO, -dir * 32])
	node.add_child(trail)
	var light := PointLight2D.new()
	light.energy = 1.3
	light.texture_scale = 5.0
	light.color = Color(1.0, 0.7, 0.3)
	light.texture = _radial_light_texture()
	node.add_child(light)
	node.position = player.position + dir * 36
	add_child(node)
	projectiles.append({ "node": node, "dir": dir, "speed": 420.0, "life": 1.2 })

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
		if projectile_particle_accum >= 0.08:
			_spawn_particles(node.position, Color(1.0, 0.6, 0.2), 1, 25)
		for m in monsters.duplicate():
			if node.position.distance_to(m.pos) < 30:
				_damage_monster(m, 1)
				_spawn_impact(node.position, true)
				projectiles.erase(p)
				node.queue_free()
				break
	if projectile_particle_accum >= 0.08:
		projectile_particle_accum = 0.0

func _damage_in_rect(rect: Rect2, dmg: int) -> void:
	for m in monsters.duplicate():
		if rect.has_point(m.pos):
			_damage_monster(m, dmg)

func _damage_monster(m: Dictionary, dmg: int) -> void:
	m.hp -= dmg
	_spawn_particles(m.pos, Color(1.0, 0.4, 0.3), 8)
	_spawn_popup(m.pos, str(dmg), Color(1.0, 0.5, 0.4))
	var hit := _spawn_vfx(1, m.pos, 0.065)
	var hit_tw := create_tween()
	hit_tw.set_parallel(true)
	hit_tw.tween_property(hit, "scale", Vector2(0.12, 0.12), 0.18)
	hit_tw.tween_property(hit, "modulate:a", 0.0, 0.25)
	hit_tw.tween_callback(func(): hit.queue_free())
	if m.hp <= 0:
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

func _spawn_impact(pos: Vector2, fiery: bool) -> void:
	var fx := _spawn_vfx(3 if fiery else 1, pos, 0.055)
	var light := PointLight2D.new()
	light.texture = _radial_light_texture()
	light.color = Color("#ff8a22") if fiery else Color("#52e8ff")
	light.energy = 1.5
	light.texture_scale = 2.5
	fx.add_child(light)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(fx, "scale", Vector2(0.13, 0.13), 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(fx, "modulate:a", 0.0, 0.42).set_delay(0.10)
	tw.tween_callback(func(): fx.queue_free()).set_delay(0.45)
	_spawn_particles(pos, light.color, 10, 140.0)
	_flash(Color(light.color, 0.055), 0.09)
	_shake(4.0)

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

func _radial_light_texture() -> Texture2D:
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
	if presence_t < 2.0:
		return
	presence_t = 0.0
	if profile.address == "":
		return
	cardano_service.send_presence(profile.address, profile.player_name, player.position.x, player.position.y, profile.level, func(_r, _c, _d): pass)
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
			n.position = Vector2(x, y)
		else:
			var holder := Node2D.new()
			var s := Sprite2D.new()
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
