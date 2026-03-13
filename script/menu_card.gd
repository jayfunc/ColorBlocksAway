extends Control

@export var title_text: String = "":
	set(value):
		title_text = value
		if title_label: # 确保节点已经创建
			title_label.text = value

var title_label: Label # 标签节点
var bg_color = Color("#F4F4F0")   # 包豪斯纸白底色
var line_color = Color("#1A1A1A") # 包豪斯墨黑线框

var close_hovering = false
var close_rect = Rect2() # 存储关闭图标的区域
var close_rect_expanded = Rect2()

func _ready():
	# 设定卡片的基准大小，将缩放中心设为正中央
	custom_minimum_size = Vector2(280, 360)
	pivot_offset = custom_minimum_size / 2.0
	
	mouse_filter = Control.MOUSE_FILTER_STOP
	
	# 初始状态隐藏并缩小
	scale = Vector2(0.5, 0.5)
	modulate.a = 0.0
	hide()
	
	# 动态创建并配置标题
	title_label = Label.new()
	title_label.text = title_text
	
	title_label.add_theme_color_override("font_color", line_color)
	title_label.add_theme_font_size_override("font_size", 32)

	# 水平撑满并居中对齐
	title_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.offset_top = 24 
	
	add_child(title_label)
	
# 抗锯齿线框卡片
func _draw():
	var rect = Rect2(Vector2.ZERO, size)
	
	var style = StyleBoxFlat.new()
	style.bg_color = bg_color
	
	style.border_width_left = 4
	style.border_width_top = 4
	style.border_width_right = 4
	style.border_width_bottom = 4
	style.border_color = line_color
	
	# 圆角边角
	var radius = 24
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	
	# 阴影悬浮
	style.shadow_color = Color(0, 0, 0, 0.1)
	style.shadow_size = 40
	style.anti_aliasing = true
	
	draw_style_box(style, rect)
	
	# 右上角的关闭图标
	var right_padding = 30
	var top_padding = 34
	var icon_size = 24
	# 定义右上角的关闭按钮区域
	close_rect = Rect2(size.x - icon_size - right_padding, top_padding, icon_size, icon_size)
	close_rect_expanded = close_rect.grow(12)
	
	var x_color = Color("#E62727") if close_hovering else Color("#1A1A1A")
	var thickness = 3.0
	
	# 画叉叉的两条线
	draw_line(close_rect.position, close_rect.position + close_rect.size, x_color, thickness, true)
	draw_line(Vector2(close_rect.end.x, close_rect.position.y), Vector2(close_rect.position.x, close_rect.end.y), x_color, thickness, true)

# 检测点击并自动关闭
func _gui_input(event):
	if event is InputEventMouseMotion:
		var was_hovering = close_hovering
		close_hovering = close_rect_expanded.has_point(event.position)
		if was_hovering != close_hovering:
			queue_redraw() # 状态变化时重绘颜色
			
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if close_rect_expanded.has_point(event.position):
			# 自动寻找父节点并隐藏
			close_menu_properly()
			
func close_menu_properly():
	close() # 运行收缩动画
	await get_tree().create_timer(0.2).timeout
	if get_parent() is Control:
		get_parent().hide() # 自动隐藏背景遮罩

# 弹窗动效
func open():
	show()
	# 每次打开时重置状态
	scale = Vector2(0.8, 0.8)
	modulate.a = 0.0
	
	# 并行动画：同时变大和变不透明，使用 Back 曲线
	var tween = create_tween().set_parallel(true)
	tween.tween_property(self, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 1.0, 0.2)

func close():
	var tween = create_tween().set_parallel(true)
	# 关闭时向内收缩并变透明
	tween.tween_property(self, "scale", Vector2(0.8, 0.8), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "modulate:a", 0.0, 0.2)
	# 动画结束后彻底隐藏
	tween.chain().tween_callback(hide)
