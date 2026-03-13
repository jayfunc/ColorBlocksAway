extends Node2D

var fragments: Array = []
var base_color: Color = Color.WHITE
var shape_type: int = 0

# 供外部调用
func explode(color: Color, shape: int):
	base_color = color
	shape_type = shape
	
	# 几何碎片数量
	var count = randi_range(6, 10)
	for i in range(count):
		var angle = randf_range(0, TAU)
		# 爆炸的初速度
		var speed = randf_range(200.0, 500.0) 
		fragments.append({
			"pos": Vector2.ZERO,
			"vel": Vector2(cos(angle), sin(angle)) * speed,
			"rot": randf_range(0, TAU),           # 初始角度
			"rot_speed": randf_range(-15.0, 15.0),# 旋转速度
			"size": randf_range(4.0, 12.0),       # 碎片大小
			"life": randf_range(0.2, 0.4),        # 持续时间
			"max_life": 0.4
		})

func _process(delta):
	var all_dead = true
	for f in fragments:
		if f.life > 0:
			f.life -= delta
			f.pos += f.vel * delta
			f.rot += f.rot_speed * delta
			# 加入空气阻力让碎片炸开后迅速悬停
			f.vel *= 0.85 
			all_dead = false
			
	if all_dead:
		queue_free() # 动画结束
	else:
		queue_redraw() # 请求重新绘制

func _draw():
	for f in fragments:
		if f.life <= 0: continue
		
		var c = base_color
		c.a = f.life / f.max_life 
		
		draw_set_transform(f.pos, f.rot, Vector2.ONE)
		
		# 圆角碎片
		draw_circle(Vector2.ZERO, f.size * 0.8, c)
			
		draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
