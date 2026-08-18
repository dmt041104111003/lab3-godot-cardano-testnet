extends Control
## Lightweight procedural backdrop for menus. No external requests at runtime.

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var viewport_size := size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	# Deep-space bands and a soft Cardano-blue horizon.
	draw_rect(Rect2(Vector2.ZERO, viewport_size), Color("#07101f"))
	draw_circle(Vector2(viewport_size.x * 0.82, viewport_size.y * 0.12), viewport_size.x * 0.32, Color(0.09, 0.25, 0.38, 0.34))
	draw_circle(Vector2(viewport_size.x * 0.08, viewport_size.y * 0.86), viewport_size.x * 0.28, Color(0.18, 0.08, 0.34, 0.28))
	for i in range(70):
		var x := fmod(float(i * 149 + 37), viewport_size.x)
		var y := fmod(float(i * 83 + 19), viewport_size.y)
		var pulse := 0.55 + sin(Time.get_ticks_msec() * 0.0015 + i) * 0.25
		var radius := 1.0 if i % 4 else 2.0
		draw_circle(Vector2(x, y), radius, Color(0.55, 0.87, 1.0, pulse))
	# Stylized floating landscape silhouette.
	var base_y := viewport_size.y * 0.82
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, base_y), Vector2(viewport_size.x * 0.18, base_y - 46),
		Vector2(viewport_size.x * 0.38, base_y - 18), Vector2(viewport_size.x * 0.57, base_y - 70),
		Vector2(viewport_size.x * 0.76, base_y - 25), Vector2(viewport_size.x, base_y - 54),
		Vector2(viewport_size.x, viewport_size.y), Vector2(0, viewport_size.y)
	]), Color("#0d2731"))
	draw_line(Vector2(0, base_y), Vector2(viewport_size.x, base_y - 54), Color(0.18, 0.78, 0.68, 0.35), 2.0)
