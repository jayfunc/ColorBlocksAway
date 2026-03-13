extends Button

var grid_pos: Vector2i = Vector2i.ZERO
var color_type: Color = Color.WHITE
var shape_type: int = 0 

# 状态标识
var is_bomb: bool = false
var is_barrier: bool = false
var is_core: bool = false

const BLOCK_SIZE = 64
const SPACING = 0

func _ready():
	var empty_style = StyleBoxEmpty.new()
	add_theme_stylebox_override("normal", empty_style)
	add_theme_stylebox_override("hover", empty_style)
	add_theme_stylebox_override("pressed", empty_style)
	add_theme_stylebox_override("focus", empty_style)
	
	pivot_offset = size / 2
	scale = Vector2.ZERO
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _draw():
	var center = size / 2.0
	var r = size.x * 0.45 
	var rect = Rect2(center.x - r, center.y - r, r * 2, r * 2)
	
	# 屏障
	if is_barrier:
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.3, 0.3, 0.3) # 深灰色底
		style.corner_radius_top_left = 8
		style.corner_radius_top_right = 8
		style.corner_radius_bottom_left = 8
		style.corner_radius_bottom_right = 8
		style.anti_aliasing = true
		draw_style_box(style, rect)
		
		# 内部画一个几何交叉线
		var line_color = Color(0.6, 0.6, 0.6)
		var offset = r * 0.5
		draw_line(center - Vector2(offset, offset), center + Vector2(offset, offset), line_color, 3.0, true)
		draw_line(center - Vector2(offset, -offset), center + Vector2(offset, -offset), line_color, 3.0, true)
		return

	# 能量核心
	if is_core:
		# 包豪斯黄色菱形
		var diamond_pts = PackedVector2Array([
			center + Vector2(0, -r * 0.85),
			center + Vector2(r * 0.85, 0),
			center + Vector2(0, r * 0.85),
			center + Vector2(-r * 0.85, 0)
		])
		draw_polygon(diamond_pts, PackedColorArray([Color(0.95, 0.75, 0.10)]))
		
		# 内部纯白菱形，增加发光感
		var inner_pts = PackedVector2Array([
			center + Vector2(0, -r * 0.4),
			center + Vector2(r * 0.4, 0),
			center + Vector2(0, r * 0.4),
			center + Vector2(-r * 0.4, 0)
		])
		draw_polygon(inner_pts, PackedColorArray([Color.WHITE]))
		return
		
	# 基础方块
	var style = StyleBoxFlat.new()
	style.bg_color = color_type
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.anti_aliasing = true
	draw_style_box(style, rect)

	# 炸弹
	if is_bomb:
		# 用同心圆来表示炸弹
		draw_circle(center, r * 0.45, Color(0.2, 0.2, 0.2, 0.9))
		draw_circle(center, r * 0.15, Color(0.9, 0.15, 0.15)) # 包豪斯红核心

func _pressed():
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(0.8, 0.8), 0.05)
	tween.tween_property(self, "scale", Vector2.ONE, 0.05)

func update_pos(new_pos: Vector2i, instant: bool = false):
	grid_pos = new_pos
	var target_pixel_pos = Vector2(new_pos.x * (BLOCK_SIZE + SPACING), new_pos.y * (BLOCK_SIZE + SPACING))
	
	if instant:
		position = target_pixel_pos
	else:
		var tween = create_tween()
		tween.tween_property(self, "position", target_pixel_pos, 0.25).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)

func die():
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.15)
	tween.tween_property(self, "scale", Vector2.ZERO, 0.15)
	tween.finished.connect(queue_free)
