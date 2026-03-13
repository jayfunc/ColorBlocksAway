extends Button

# 定义一个枚举，在检查器里选择 “暂停” 或 “设置”
enum IconType { PAUSE, SETTINGS }
@export var icon_type: IconType = IconType.PAUSE

var base_color = Color("#1A1A1A") # 包豪斯墨黑

func _ready():
	# 强行剥离系统默认的所有灰色底板样式
	var empty_style = StyleBoxEmpty.new()
	for state in ["normal", "hover", "pressed", "focus"]:
		add_theme_stylebox_override(state, empty_style)
	
	# 设置最小尺寸并把缩放中心对准正中央
	custom_minimum_size = Vector2(64, 64)
	pivot_offset = custom_minimum_size / 2.0
	
	# 绑定动画的信号
	mouse_entered.connect(_on_hover)
	mouse_exited.connect(_on_normal)
	button_down.connect(_on_down)
	button_up.connect(_on_hover)

# 绘制图标
func _draw():
	var center = size / 2.0
	var r = size.x * 0.25 # 图形的基础尺寸比例
	
	if icon_type == IconType.PAUSE:
		# 双竖线
		var line_w = r * 0.4
		var line_h = r * 2.0
		var gap = r * 0.6
		draw_rect(Rect2(center.x - gap - line_w/2, center.y - line_h/2, line_w, line_h), base_color)
		draw_rect(Rect2(center.x + gap - line_w/2, center.y - line_h/2, line_w, line_h), base_color)
		
	elif icon_type == IconType.SETTINGS:
		# 三横线
		var line_w = r * 2.2
		var line_h = r * 0.35
		var gap = r * 0.8
		draw_rect(Rect2(center.x - line_w/2, center.y - gap - line_h/2, line_w, line_h), base_color) # 上
		draw_rect(Rect2(center.x - line_w/2, center.y - line_h/2, line_w, line_h), base_color)       # 中
		draw_rect(Rect2(center.x - line_w/2, center.y + gap - line_h/2, line_w, line_h), base_color) # 下

# 物理反馈动画
func _on_hover():
	# 鼠标悬浮时，略微放大，使用 Back 缓动曲线产生越界效果
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.15, 1.15), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _on_normal():
	# 恢复原状
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_SINE)

func _on_down():
	# 点击瞬间，迅速内缩
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(0.85, 0.85), 0.05).set_trans(Tween.TRANS_SINE)
