extends CharacterBody2D
## Top-down player (Kenney alien, CC0). WASD/arrows move.

const SPEED := 360.0

var facing := Vector2(0, 1)
var anim: AnimatedSprite2D
var moving := false
var action_state := "idle"
var state_until := 0.0
var aim_direction := Vector2.DOWN

func _ready() -> void:
	anim = AnimatedSprite2D.new()
	anim.name = "Anim"
	add_child(anim)
	_build_animations()
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(30, 34)
	shape.shape = rect
	shape.position = Vector2(0, -10)
	add_child(shape)
	anim.play("idle_down")

func _safe_tex(path: String) -> Texture2D:
	var t = load(path)
	if t == null:
		var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
		img.fill(Color(0.4, 0.7, 0.9))
		t = ImageTexture.create_from_image(img)
	return t

func _build_animations() -> void:
	var sf := SpriteFrames.new()
	var idle_tex := _safe_tex("res://assets/local_pack/characters/hero_idle.png")
	var walk_tex := _safe_tex("res://assets/local_pack/characters/hero_walk.png")
	# Use one canonical side-facing row and mirror it at runtime. This avoids
	# relying on inconsistent left/right labels in the source asset metadata.
	var direction_rows := {"down": 0, "left": 1, "right": 1, "up": 3}
	for direction in ["down", "right", "left", "up"]:
		var row: int = int(direction_rows[direction])
		var idle_name: String = "idle_" + direction
		var run_name: String = "run_" + direction
		sf.add_animation(idle_name)
		for frame in range(6):
			sf.add_frame(idle_name, _atlas_frame(idle_tex, frame, row))
		sf.set_animation_speed(idle_name, 6.0)
		sf.set_animation_loop(idle_name, true)
		sf.add_animation(run_name)
		for frame in range(6):
			sf.add_frame(run_name, _atlas_frame(walk_tex, frame, row))
		sf.set_animation_speed(run_name, 10.0)
		sf.set_animation_loop(run_name, true)
	anim.sprite_frames = sf
	anim.offset = Vector2(0, -18)
	anim.scale = Vector2(2.0, 2.0)
	anim.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func _atlas_frame(texture: Texture2D, column: int, row: int) -> AtlasTexture:
	var frame := AtlasTexture.new()
	frame.atlas = texture
	frame.region = Rect2(column * 32, row * 32, 32, 32)
	return frame

func _draw() -> void:
	draw_set_transform(Vector2(0, 10), 0.0, Vector2(1.8, 0.55))
	draw_circle(Vector2.ZERO, 13.0, Color(0.02, 0.03, 0.05, 0.42))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _physics_process(_delta: float) -> void:
	var raw_dir := Vector2(
		Input.get_axis("ui_left", "ui_right"),
		Input.get_axis("ui_up", "ui_down"),
	)
	var dir := raw_dir.normalized()
	velocity = dir * SPEED
	moving = velocity.length() > 10.0
	if Time.get_ticks_msec() * 0.001 >= state_until:
		action_state = "run" if moving else "idle"
	facing = aim_direction
	move_and_slide()
	var direction := "down"
	if absf(facing.x) > absf(facing.y):
		direction = "right" if facing.x > 0 else "left"
	elif facing.y < 0:
		direction = "up"
	anim.flip_h = direction == "right"
	anim.play(("run_" if moving else "idle_") + direction)

func set_aim_direction(value: Vector2) -> void:
	if value.length_squared() > 0.001:
		aim_direction = value.normalized()

func show_hurt() -> void:
	action_state = "hurt"
	state_until = Time.get_ticks_msec() * 0.001 + 0.28
	var tw := create_tween()
	tw.tween_property(anim, "modulate", Color(1.0, 0.28, 0.28), 0.05)
	tw.tween_property(anim, "modulate", Color.WHITE, 0.18)

func show_attack(duration := 0.22) -> void:
	action_state = "attack"
	state_until = Time.get_ticks_msec() * 0.001 + duration

func show_death() -> void:
	action_state = "dead"
	state_until = Time.get_ticks_msec() * 0.001 + 0.65
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(anim, "rotation", PI * 0.5, 0.28).set_trans(Tween.TRANS_BACK)
	tw.tween_property(anim, "modulate:a", 0.25, 0.58)

func revive_visual() -> void:
	anim.rotation = 0.0
	anim.modulate = Color.WHITE
	action_state = "idle"
