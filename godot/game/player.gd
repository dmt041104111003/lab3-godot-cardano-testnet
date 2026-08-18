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
	anim.play("idle")

func _safe_tex(path: String) -> Texture2D:
	var t = load(path)
	if t == null:
		var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
		img.fill(Color(0.4, 0.7, 0.9))
		t = ImageTexture.create_from_image(img)
	return t

func _build_animations() -> void:
	var sf := SpriteFrames.new()
	var stand := _safe_tex("res://assets/player/alienBlue_stand.png")
	var walk1 := _safe_tex("res://assets/player/alienBlue_walk1.png")
	var walk2 := _safe_tex("res://assets/player/alienBlue_walk2.png")
	sf.add_animation("idle")
	sf.add_frame("idle", stand)
	sf.set_animation_speed("idle", 1.0)
	sf.add_animation("run")
	sf.add_frame("run", walk1)
	sf.add_frame("run", walk2)
	sf.set_animation_speed("run", 12.0)
	anim.sprite_frames = sf
	anim.offset = Vector2(0, -30)
	anim.scale = Vector2(1.2, 1.2)

func _physics_process(delta: float) -> void:
	var dir := Vector2(
		Input.get_axis("ui_left", "ui_right"),
		Input.get_axis("ui_up", "ui_down"),
	)
	velocity = dir.normalized() * SPEED
	moving = velocity.length() > 10.0
	if dir.x != 0:
		facing = Vector2(signf(dir.x), 0)
	elif dir.y != 0:
		facing = Vector2(0, signf(dir.y))
	move_and_slide()
	if moving:
		anim.play("run")
	else:
		anim.play("idle")
	# face the movement direction
	if absf(facing.x) > 0.1:
		anim.flip_h = facing.x < 0