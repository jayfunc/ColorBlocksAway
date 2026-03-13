extends ColorRect

enum GameMode { ZEN, LEVEL }
var current_mode: GameMode = GameMode.LEVEL

var time_passed: float = 0.0
var ripples: Array = []
var floating_shapes: Array = []
var actual_board_center: Vector2 = Vector2.ZERO

var current_scale: float = 1.0 

enum ShapeType { CIRCLE, DIAMOND, TRIANGLE }

func _ready():
	color = Color("#F4F4F0")
	
	for i in range(12):
		var s_type = randi() % 3
		floating_shapes.append({
			"type": s_type,
			"pos": Vector2(randf_range(0, 2000), randf_range(0, 2000)),
			"radius": randf_range(120, 350), 
			"velocity": Vector2(randf_range(-6, 6), randf_range(-6, 6)),
			"base_alpha": randf_range(0.015, 0.035),
			"rotation": randf_range(0, TAU),
			"rotation_speed": randf_range(-0.15, 0.15)
		})

func resize_bg(new_size: Vector2):
	size = new_size
	queue_redraw()

func update_scale(new_scale: float):
	current_scale = new_scale
	queue_redraw()

func update_board_center(center_pos: Vector2):
	actual_board_center = center_pos
	queue_redraw()

func _process(delta):
	time_passed += delta
	var needs_redraw = false

	if current_mode == GameMode.ZEN:
		for s in floating_shapes:
			s.pos += s.velocity * delta
			s.rotation += s.rotation_speed * delta 
			
			if s.pos.x < -s.radius: s.pos.x = size.x + s.radius
			if s.pos.x > size.x + s.radius: s.pos.x = -s.radius
			if s.pos.y < -s.radius: s.pos.y = size.y + s.radius
			if s.pos.y > size.y + s.radius: s.pos.y = -s.radius
		needs_redraw = true

	for i in range(ripples.size() - 1, -1, -1):
		var r = ripples[i]
		r.radius += r.speed * delta
		r.alpha -= (r.speed * delta) / r.max_radius
		if r.alpha <= 0:
			ripples.remove_at(i)
		needs_redraw = true

	if needs_redraw or current_mode == GameMode.ZEN:
		queue_redraw()

func _draw():
	# ==============================
	# 绘制十字点阵
	# ==============================
	var grid_alpha = 0.15
	if current_mode == GameMode.ZEN:
		grid_alpha = 0.1 + sin(time_passed * 1.5) * 0.05 # 让点阵也有微弱的呼吸感

	var dot_color = Color(0.5, 0.5, 0.5, grid_alpha)
	
	var scaled_grid_size = 64.0 * current_scale
	var scaled_half_board = 256.0 * current_scale
	var center_to_use = actual_board_center if actual_board_center != Vector2.ZERO else size / 2.0
	
	# 计算网格对齐偏移
	var board_top_left = center_to_use - Vector2(scaled_half_board, scaled_half_board)
	var offset_x = fmod(board_top_left.x, scaled_grid_size)
	var offset_y = fmod(board_top_left.y, scaled_grid_size)

	# 定义避让区域：棋盘大小 + 外延半个网格的边距
	var safe_margin = scaled_grid_size * 0.5
	var board_rect = Rect2(
		center_to_use.x - scaled_half_board - safe_margin, 
		center_to_use.y - scaled_half_board - safe_margin, 
		(scaled_half_board + safe_margin) * 2, 
		(scaled_half_board + safe_margin) * 2
	)

	# 遍历屏幕绘制十字星
	var cross_size = 4.0 * current_scale # 十字的长短
	var x = offset_x
	while x <= size.x:
		var y = offset_y
		while y <= size.y:
			var point = Vector2(x, y)
			# 如果点阵不在棋盘区域内才把它画出来
			if not board_rect.has_point(point):
				draw_line(point - Vector2(cross_size, 0), point + Vector2(cross_size, 0), dot_color, 1.0, true)
				draw_line(point - Vector2(0, cross_size), point + Vector2(0, cross_size), dot_color, 1.0, true)
			y += scaled_grid_size
		x += scaled_grid_size

	if current_mode == GameMode.ZEN:
		for s in floating_shapes:
			var stroke_width = 1 * current_scale
			var s_radius = s.radius * current_scale
			
			var s_color: Color
			match s.type:
				ShapeType.CIRCLE:
					# 深灰
					s_color = Color(0.2, 0.2, 0.2, s.base_alpha)
					draw_arc(s.pos, s_radius, 0, TAU, 64, s_color, stroke_width, true)
				ShapeType.DIAMOND:
					# 中灰
					s_color = Color(0.4, 0.4, 0.4, s.base_alpha)
					_draw_hollow_polygon(s.pos, s_radius, 4, s.rotation, s_color, stroke_width)
				ShapeType.TRIANGLE:
					# 浅灰
					s_color = Color(0.5, 0.5, 0.5, s.base_alpha)
					_draw_hollow_polygon(s.pos, s_radius, 3, s.rotation, s_color, stroke_width)

	for r in ripples:
		# 水波纹
		var wave_color = Color(0.3, 0.3, 0.3, r.alpha)
		draw_arc(r.center, r.radius, 0, TAU, 64, wave_color, 4.0, true)
		if r.radius > 30:
			draw_arc(r.center, r.radius - 30, 0, TAU, 64, wave_color * Color(1, 1, 1, 0.4), 1.0, true)

func _draw_hollow_polygon(center: Vector2, radius: float, sides: int, rotation_angle: float, c: Color, width: float):
	var points = PackedVector2Array()
	for i in range(sides + 1):
		var angle = rotation_angle + i * (TAU / sides)
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	draw_polyline(points, c, width, true)

func set_game_mode(mode: int):
	current_mode = mode
	queue_redraw()

func trigger_ripple(center_pos: Vector2):
	ripples.append({
		"center": center_pos,
		"radius": 10.0,
		"max_radius": 800.0 * current_scale,
		"speed": 1200.0 * current_scale,
		"alpha": 0.8
	})
