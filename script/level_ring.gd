extends Control

var current_progress: float = 0.0
var target_progress: float = 1000.0
var display_progress: float = 0.0 # 用于动画平滑过渡的值

var bg_color = Color(0.1, 0.1, 0.1, 0.1)  # 轨道底色
var fill_color = Color("#1A1A1A")         # 填充色

func _ready():
	# 确保它的最小尺寸，保证画圆的空间
	custom_minimum_size = Vector2(80, 80)

func _process(_delta):
	# 每帧请求重绘，以便展示平滑动画
	queue_redraw()

# 抗锯齿圆环
func _draw():
	var center = size / 2.0
	var radius = min(size.x, size.y) / 2.0 - 4.0 # 留一点边距
	
	# 轨道圈
	draw_arc(center, radius, 0, TAU, 64, bg_color, 2.0, true)
	
	# 进度实线圈
	if display_progress > 0:
		var fill_ratio = clamp(display_progress / target_progress, 0.0, 1.0)
		var end_angle = -PI / 2.0 + (fill_ratio * TAU) 
		# 从正上方 (-PI/2) 开始顺时针画
		draw_arc(center, radius, -PI / 2.0, end_angle, 64, fill_color, 4.0, true)

# 更新分数并触发动画
func update_score(new_score: int, new_target: int):
	target_progress = float(new_target)
	
	# 创建平滑增长的动画
	var tween = create_tween()
	tween.tween_property(self, "display_progress", float(new_score), 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func reset():
	display_progress = 0.0
	current_progress = 0.0
	queue_redraw()
