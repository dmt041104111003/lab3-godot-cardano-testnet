extends CharacterBody2D
## Top-down player (Kenney alien, CC0). WASD/arrows move.

const SPEED := 260.0

var facing := Vector2(0, 1)
var anim: AnimatedSprite2D
var moving := false

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
	# Runtime-facing order verified in game: front, left, right, back.
	# Each visible 32px frame spans two 16px tiles in the source atlas.
	var direction_rows := {"down": 0, "left": 1, "right": 2, "up": 3}
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

func _physics_process(_delta: float) -> void:
	var raw_dir := Vector2(
		Input.get_axis("ui_left", "ui_right"),
		Input.get_axis("ui_up", "ui_down"),
	)
	# This game uses four-direction art. Resolve simultaneous/stale browser input
	# to one dominant axis so vertical movement can never display as diagonal.
	var dir := Vector2.ZERO
	if absf(raw_dir.x) > absf(raw_dir.y):
		dir.x = signf(raw_dir.x)
	elif raw_dir.y != 0.0:
		dir.y = signf(raw_dir.y)
	elif raw_dir.x != 0.0:
		dir.x = signf(raw_dir.x)
	velocity = dir * SPEED
	moving = velocity.length() > 10.0
	if dir.x != 0:
		facing = Vector2(signf(dir.x), 0)
	elif dir.y != 0:
		facing = Vector2(0, signf(dir.y))
	move_and_slide()
	var direction := "down"
	if absf(facing.x) > absf(facing.y):
		direction = "right" if facing.x > 0 else "left"
	elif facing.y < 0:
		direction = "up"
	anim.play(("run_" if moving else "idle_") + direction)
