extends CharacterBody2D
## Platformer player with animated sprite (Kenney alien, CC0).

signal jumped
signal landed

const SPEED := 330.0
const JUMP_VELOCITY := -640.0
const GRAVITY := 1500.0

var facing := 1
var was_on_floor := true
var anim: AnimatedSprite2D

func _ready() -> void:
	anim = AnimatedSprite2D.new()
	anim.name = "Anim"
	add_child(anim)
	_build_animations()
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(34, 74)
	shape.shape = rect
	shape.position = Vector2(0, -20)
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
	var jump := _safe_tex("res://assets/player/alienBlue_jump.png")
	var hurt := _safe_tex("res://assets/player/alienBlue_hurt.png")
	sf.add_animation("idle")
	sf.add_frame("idle", stand)
	sf.set_animation_speed("idle", 1.0)
	sf.add_animation("run")
	sf.add_frame("run", walk1)
	sf.add_frame("run", walk2)
	sf.set_animation_speed("run", 12.0)
	sf.add_animation("jump")
	sf.add_frame("jump", jump)
	sf.set_animation_speed("jump", 1.0)
	sf.add_animation("hurt")
	sf.add_frame("hurt", hurt)
	sf.set_animation_speed("hurt", 1.0)
	anim.sprite_frames = sf
	anim.offset = Vector2(0, -42)
	anim.scale = Vector2(1.4, 1.4)

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	var dir := Input.get_axis("ui_left", "ui_right")
	velocity.x = dir * SPEED
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY
		jumped.emit()
	var was := was_on_floor
	move_and_slide()
	was_on_floor = is_on_floor()
	if not was and was_on_floor:
		landed.emit()
	_update_anim(dir)

func _update_anim(dir: float) -> void:
	if not is_on_floor():
		anim.play("jump")
	elif absf(dir) > 0.1:
		anim.play("run")
	else:
		anim.play("idle")
	if dir != 0.0:
		facing = -1 if dir < 0 else 1
		anim.flip_h = facing < 0