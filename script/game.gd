extends Node2D

enum GameMode { ZEN, LEVEL }

const GRID_SIZE = 8
const COLORS = [
	Color("aaaaaa"), Color("aa66cc"), Color("ff4444"), 
	Color("ffbb33"), Color("33b6e5"), Color("99cc00")
]
const BLOCK_SIZE = 64
const SPACING = 0
const SAVE_FILE_PATH = "user://game_data.save"

@export var current_mode: GameMode = GameMode.LEVEL
var is_animating: bool = false 

var grid_array = [] 
var score: int = 0
var current_level: int = 1
var target_score: int = 1000
var sound_enabled: bool = true
var moves: int = 30 
var high_scores: Dictionary = {
	GameMode.ZEN: 0,
	GameMode.LEVEL: 0
}
var saved_states: Dictionary = {
	GameMode.ZEN: {},
	GameMode.LEVEL: {}
}

@onready var background = $Background
@onready var board_pivot = $BorderPivot
@onready var board = $BorderPivot/Board

@onready var score_label = $UI/ScoresContainer/ScoreLabel
@onready var high_score_label = $UI/ScoresContainer/HighScoreLabel
@onready var level_ring = $UI/LevelRing
@onready var level_label = $UI/LevelRing/LevelLabel

@onready var pause_btn = $UI/PauseBtn
@onready var settings_btn = $UI/SettingsBtn
@onready var moves_label = $UI/MovesLabel

@onready var pause_menu = $UI/PauseMenu
@onready var pause_card = $UI/PauseMenu/MenuCard
@onready var resume_btn = $UI/PauseMenu/MenuCard/VBoxContainer/ResumeBtn
@onready var restart_btn = $UI/PauseMenu/MenuCard/VBoxContainer/RestartBtn

@onready var settings_menu = $UI/SettingsMenu
@onready var settings_card = $UI/SettingsMenu/MenuCard
@onready var sound_btn = $UI/SettingsMenu/MenuCard/VBoxContainer/SoundBtn
@onready var mode_btn = $UI/SettingsMenu/MenuCard/VBoxContainer/ModeBtn
@onready var lang_btn = $UI/SettingsMenu/MenuCard/VBoxContainer/LangBtn

@onready var sfx_block = $SfxBlock
@onready var sfx_level_up = $SfxLevelUp
@onready var sfx_button = $SfxButton

var block_scene = preload("res://scene/block.tscn")

func _ready():
	get_viewport().size_changed.connect(_on_window_resized)
	_on_window_resized()
	
	var board_pixel_size = GRID_SIZE * BLOCK_SIZE + (GRID_SIZE - 1) * SPACING
	board.position = -Vector2(board_pixel_size, board_pixel_size) / 2.0
	
	setup_ui_connections()
	
	# 如果返回 false 说明没有进度，就开新局
	if not load_game_data():
		start_new_game(current_mode)
	
	update_sound_btn_text() 
	update_lang_btn_text()
	# 注：如果 load_game_data 返回 true，load_state 内部其实已经调用过 update_ui 了。
	# 为了确保最高分在一开始也正常显示，再强制刷新一次 UI
	update_ui()

func _on_window_resized():
	var screen_size = get_viewport_rect().size
	var screen_center = screen_size / 2.0
	
	var board_pixel_size = GRID_SIZE * BLOCK_SIZE + (GRID_SIZE - 1) * SPACING
	var max_board_size = min(screen_size.x, screen_size.y) * 0.9
	var scale_factor = max_board_size / board_pixel_size
	
	if has_node("BorderPivot"): 
		$BorderPivot.position = screen_center
		$BorderPivot.scale = Vector2(scale_factor, scale_factor) 
		
	if has_node("Background"):
		$Background.resize_bg(screen_size)
		$Background.update_board_center(screen_center)
		if $Background.has_method("update_scale"):
			$Background.update_scale(scale_factor)

func setup_ui_connections():
	var top_panel_buttons = [pause_btn, settings_btn]
	var menu_buttons = [resume_btn, restart_btn, sound_btn, mode_btn, lang_btn] 
	
	for btn in top_panel_buttons + menu_buttons:
		if btn:
			btn.pressed.connect(play_button_sound)
			
	# 初始化语言按钮的显示文字
	update_lang_btn_text()
	
	pause_btn.pressed.connect(func(): 
		pause_menu.show()
		pause_card.open()
	)
	
	settings_btn.pressed.connect(func(): 
		settings_menu.show()
		settings_card.open()
	)
	
	resume_btn.pressed.connect(func(): 
		pause_card.close_menu_properly()
	)
	
	restart_btn.pressed.connect(func(): 
		resume_btn.visible = true
		pause_card.title_text = tr("UI_PAUSED")
		pause_card.close_menu_properly()
		
		saved_states[current_mode] = {} 
		save_game_data()
		
		start_new_game(current_mode)
	)
	
	sound_btn.pressed.connect(func(): 
		sound_enabled = !sound_enabled
		update_sound_btn_text()
		play_button_sound()
		save_game_data()
	)
	
	mode_btn.pressed.connect(func():
		var new_mode = GameMode.ZEN if current_mode == GameMode.LEVEL else GameMode.LEVEL
		save_current_state()
		settings_card.close_menu_properly()
		
		if saved_states[new_mode].has("is_saved") and saved_states[new_mode]["is_saved"]:
			load_state(new_mode)
		else:
			start_new_game(new_mode)
			
		# 切换模式后将最新状态写入磁盘
		save_game_data()
	)

	# 语言切换
	if lang_btn:
		lang_btn.pressed.connect(func():
			# 获取当前系统/游戏设置的语言
			var current_locale = TranslationServer.get_locale()
			
			if current_locale.begins_with("zh"):
				TranslationServer.set_locale("en")
			else:
				TranslationServer.set_locale("zh")
			
			update_lang_btn_text()
			update_sound_btn_text()
			update_ui()
			save_game_data()
		)
		
# 更新语言按钮文字
func update_lang_btn_text():
	if not lang_btn: return
	
	var current_locale = TranslationServer.get_locale()
	if current_locale.begins_with("zh"):
		lang_btn.text = "语言：中文"
	else:
		lang_btn.text = "LANGUAGE: EN"

# 更新音效按钮文字
func update_sound_btn_text():
	if not sound_btn: return
	
	if sound_enabled:
		sound_btn.text = tr("UI_SOUND_ON")
	else:
		sound_btn.text = tr("UI_SOUND_OFF")

func start_new_game(mode: GameMode):
	current_mode = mode
	score = 0
	current_level = 1
	moves = 30
	target_score = 1000 if mode == GameMode.LEVEL else 0
	level_ring.visible = (mode == GameMode.LEVEL)
	background.set_game_mode(mode)
	update_ui()
	clear_board()
	setup_grid()

func clear_board():
	for child in board.get_children():
		child.queue_free()
	grid_array.clear()

func setup_grid():
	grid_array.clear()
	for y in range(GRID_SIZE):
		var row = []
		for x in range(GRID_SIZE):
			row.append(null)
		grid_array.append(row)
		
	for x in range(GRID_SIZE):
		for y in range(GRID_SIZE):
			spawn_new_block(x, y, true)

func spawn_new_block(x: int, y: int, instant: bool = false):
	var block = block_scene.instantiate()
	
	# 以一定概率生成特殊方块
	var rand_val = randf()
	if rand_val < 0.08:
		# 8% 概率生成屏障
		block.is_barrier = true
	elif rand_val < 0.12:
		# 4% 概率生成能量核心
		block.is_core = true
	else:
		# 正常生成普通色块
		var type_index = randi() % COLORS.size()
		block.color_type = COLORS[type_index]
		block.shape_type = type_index
	
	block.pressed.connect(_on_block_pressed.bind(block))
	board.add_child(block)
	grid_array[y][x] = block
	
	if not instant:
		block.position = Vector2(x * (BLOCK_SIZE + SPACING), -BLOCK_SIZE * 2)
		block.update_pos(Vector2i(x, y), false)
	else:
		block.update_pos(Vector2i(x, y), true)

func _on_block_pressed(block):
	if is_animating: return
	var pos = block.grid_pos
	
	# 屏蔽屏障和能量核心的点击
	if block.is_barrier or block.is_core:
		return

	# 炸弹触发 3x3 爆炸
	if block.is_bomb:
		is_animating = true
		play_block_sound()
		activate_bomb(pos)
		return

	var target_color = block.color_type
	var matches = find_matches(pos, target_color)
	
	if matches.size() >= 2:
		if current_mode == GameMode.LEVEL:
			moves -= 1
		
		is_animating = true
		play_block_sound()
		
		var points_gained = matches.size() * matches.size() * 10
		add_score(points_gained)
		
		# 满足 5 个以上合成为炸弹
		var generate_bomb = matches.size() >= 5
		
		for p in matches:
			var b = grid_array[p.y][p.x]
			if b:
				if generate_bomb and p == pos:
					b.is_bomb = true
					b.scale = Vector2(1.2, 1.2)
					b.queue_redraw()
				else:
					var explosion = Node2D.new()
					explosion.set_script(preload("res://script/explosion.gd"))
					board.add_child(explosion)
					explosion.position = b.position + (b.size / 2.0)
					explosion.explode(b.color_type, b.shape_type)
					
					b.die()
					grid_array[p.y][p.x] = null
					
		# 检查周围是否有需要震碎的屏障
		damage_adjacent_barriers(matches)
				
		await get_tree().create_timer(0.2).timeout 
		apply_gravity()

# 炸弹引爆
func activate_bomb(center_pos: Vector2i):
	var to_clear = []
	for y in range(center_pos.y - 1, center_pos.y + 2):
		for x in range(center_pos.x - 1, center_pos.x + 2):
			if x >= 0 and x < GRID_SIZE and y >= 0 and y < GRID_SIZE:
				var b = grid_array[y][x]
				# 炸弹可以炸毁普通方块和屏障，不能炸毁能量核心
				if b != null and not b.is_core:
					to_clear.append(Vector2i(x, y))
					
	if current_mode == GameMode.LEVEL:
		moves -= 1
	add_score(to_clear.size() * 20) 
	
	for p in to_clear:
		var b = grid_array[p.y][p.x]
		# 只有普通方块才播放彩色爆炸特效
		if not b.is_barrier:
			var explosion = Node2D.new()
			explosion.set_script(preload("res://script/explosion.gd"))
			board.add_child(explosion)
			explosion.position = b.position + (b.size / 2.0)
			explosion.explode(b.color_type, b.shape_type)
		
		b.die()
		grid_array[p.y][p.x] = null

	# 震碎更外围的屏障
	damage_adjacent_barriers(to_clear)

	await get_tree().create_timer(0.2).timeout
	apply_gravity()

# 震波击碎屏障
func damage_adjacent_barriers(cleared_positions: Array):
	var dirs = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
	var processed_barriers = {} 
	
	for p in cleared_positions:
		for dir in dirs:
			var next_pos = p + dir
			if next_pos.x >= 0 and next_pos.x < GRID_SIZE and next_pos.y >= 0 and next_pos.y < GRID_SIZE:
				var neighbor = grid_array[next_pos.y][next_pos.x]
				if neighbor and neighbor.is_barrier and not processed_barriers.has(next_pos):
					processed_barriers[next_pos] = true
					add_score(50) 
					neighbor.die()
					grid_array[next_pos.y][next_pos.x] = null

func find_matches(start_pos: Vector2i, color: Color) -> Array:
	var stack = [start_pos]
	var found = []
	var visited = {} 

	while stack.size() > 0:
		var curr = stack.pop_back()
		if visited.has(curr): continue
		visited[curr] = true
		
		var b = grid_array[curr.y][curr.x]
		# 忽略屏障和核心的匹配
		if b != null and not b.is_barrier and not b.is_core and b.color_type == color:
			found.append(curr)
			var dirs = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
			for dir in dirs:
				var next = curr + dir
				if next.x >= 0 and next.x < GRID_SIZE and next.y >= 0 and next.y < GRID_SIZE:
					stack.append(next)
	return found

func apply_gravity():
	for x in range(GRID_SIZE):
		var empty_slots = 0
		for y in range(GRID_SIZE - 1, -1, -1):
			if grid_array[y][x] == null:
				empty_slots += 1
			elif empty_slots > 0:
				var block = grid_array[y][x]
				grid_array[y + empty_slots][x] = block
				grid_array[y][x] = null
				block.update_pos(Vector2i(x, y + empty_slots), false)

	for x in range(GRID_SIZE):
		var empty_slots = 0
		for y in range(GRID_SIZE):
			if grid_array[y][x] == null:
				empty_slots += 1
		for i in range(empty_slots):
			spawn_new_block(x, i, false)
			
	await get_tree().create_timer(0.3).timeout
	
	# 检测核心是否触底
	var core_collected = false
	for x in range(GRID_SIZE):
		# 只检查最底部的这一行
		var bottom_block = grid_array[GRID_SIZE - 1][x]
		if bottom_block and bottom_block.is_core:
			bottom_block.die()
			grid_array[GRID_SIZE - 1][x] = null
			add_score(200) # 核心奖励高分
			core_collected = true
			
	# 如果收集到了核心，产生了新的空位，必须再次触发掉落
	if core_collected:
		apply_gravity()
		return # 中断当前的执行，防止多次结算重叠
	
	is_animating = false
	
	if score >= target_score:
		check_level_up()
	else:
		check_game_over() 
	
	if not pause_menu.visible and is_deadlocked():
		await get_tree().create_timer(0.5).timeout
		handle_deadlock()

func add_score(points: int):
	score += points
	# 判断是否超过当前模式的最高分
	if score > high_scores[current_mode]:
		high_scores[current_mode] = score
		save_game_data()
	update_ui()

func update_ui():
	if score_label:
		score_label.text = "%05d" % score
	if high_score_label:
		high_score_label.text = tr("UI_BEST") + " %05d" % high_scores[current_mode]
		
	if current_mode == GameMode.LEVEL:
		level_label.text = tr("UI_LEVEL") + "%d" % current_level
		level_ring.update_score(score, target_score)
		level_ring.visible = true
		moves_label.text = str(moves)
		moves_label.visible = true
	else:
		level_ring.visible = false
		moves_label.visible = false
		
	var mode_text = tr("UI_MODE_LEVEL") if current_mode == GameMode.LEVEL else tr("UI_MODE_ZEN")
	mode_btn.text = mode_text

func check_level_up():
	if current_mode == GameMode.LEVEL and score >= target_score:
		current_level += 1
		moves = 30
		score = 0 
		target_score = int(target_score * 1.5) 
		
		level_ring.reset()
		update_ui()
		play_level_up_sound()
		
		var screen_center = get_viewport_rect().size / 2.0
		background.trigger_ripple(screen_center)
		
		clear_board()
		setup_grid()

func is_deadlocked() -> bool:
	for y in range(GRID_SIZE):
		for x in range(GRID_SIZE):
			var b = grid_array[y][x]
			# 死局判定排除屏障和核心，因不能连线
			if not b or b.is_barrier or b.is_core: continue
			
			if x < GRID_SIZE - 1 and grid_array[y][x+1] and not grid_array[y][x+1].is_barrier and not grid_array[y][x+1].is_core and grid_array[y][x+1].color_type == b.color_type:
				return false
			if y < GRID_SIZE - 1 and grid_array[y+1][x] and not grid_array[y+1][x].is_barrier and not grid_array[y+1][x].is_core and grid_array[y+1][x].color_type == b.color_type:
				return false
	return true

func handle_deadlock():
	for y in range(GRID_SIZE):
		for x in range(GRID_SIZE):
			var block = grid_array[y][x]
			# 洗牌时不改变屏障和核心
			if block and not block.is_barrier and not block.is_core:
				var type_index = randi() % COLORS.size()
				block.color_type = COLORS[type_index]
				block.shape_type = type_index
				block.queue_redraw() 
				
				var tween = create_tween()
				tween.tween_property(block, "scale", Vector2(0.2, 0.2), 0.15).set_delay(randf_range(0.0, 0.2))
				tween.tween_property(block, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BACK)
	
	if is_deadlocked():
		handle_deadlock()

func check_game_over():
	if current_mode == GameMode.LEVEL and moves <= 0:
		if score < target_score:
			trigger_death()

func trigger_death():
	pause_menu.show()
	var card = $UI/PauseMenu/MenuCard
	card.title_text = tr("UI_GAME_OVER")
	resume_btn.visible = false
	card.open()
	
	# 游戏结束后清空当前模式的存档
	saved_states[current_mode] = {}
	save_game_data()

func _unhandled_input(event: InputEvent):
	if event.is_action_pressed("ui_cancel"): 
		if settings_menu.visible:
			$UI/SettingsMenu/MenuCard.close_menu_properly()
			return 
		if pause_menu.visible:
			$UI/PauseMenu/MenuCard.close_menu_properly()
			return
		if not is_animating: 
			pause_menu.show()
			$UI/PauseMenu/MenuCard.open()

func play_block_sound():
	if sound_enabled:
		sfx_block.pitch_scale = randf_range(0.9, 1.1) 
		sfx_block.play()

func play_level_up_sound():
	if sound_enabled:
		sfx_level_up.play()

func play_button_sound():
	if sound_enabled:
		sfx_button.play()

# 保存当前模式的游戏状态
func save_current_state():
	var board_data = []
	for y in range(GRID_SIZE):
		var row = []
		for x in range(GRID_SIZE):
			var block = grid_array[y][x]
			if block:
				# 记录方块的所有关键属性
				row.append({
					"color_type": block.color_type,
					"shape_type": block.shape_type,
					"is_barrier": block.is_barrier,
					"is_core": block.is_core,
					"is_bomb": block.is_bomb
				})
			else:
				row.append(null)
		board_data.append(row)
	
	# 将状态存入字典
	saved_states[current_mode] = {
		"score": score,
		"current_level": current_level,
		"moves": moves,
		"target_score": target_score,
		"board": board_data,
		"is_saved": true
	}

# 根据缓存的数据恢复游戏状态
func load_state(mode: GameMode):
	current_mode = mode
	var state = saved_states[mode]
	
	score = state["score"]
	current_level = state["current_level"]
	moves = state["moves"]
	target_score = state["target_score"]
	
	# 恢复背景、模式
	level_ring.visible = (mode == GameMode.LEVEL)
	background.set_game_mode(mode)
	
	clear_board()
	
	# 重建网格数组
	for y in range(GRID_SIZE):
		var row = []
		for x in range(GRID_SIZE):
			row.append(null)
		grid_array.append(row)
		
	# 根据数据重新生成方块
	var board_data = state["board"]
	for y in range(GRID_SIZE):
		for x in range(GRID_SIZE):
			var data = board_data[y][x]
			if data:
				spawn_block_from_data(x, y, data)
				
	update_ui()

# 根据数据生成特定方块
func spawn_block_from_data(x: int, y: int, data: Dictionary):
	var block = block_scene.instantiate()
	block.color_type = data["color_type"]
	block.shape_type = data["shape_type"]
	block.is_barrier = data["is_barrier"]
	block.is_core = data["is_core"]
	block.is_bomb = data["is_bomb"]
	
	# 恢复炸弹的外观大小
	if block.is_bomb:
		block.scale = Vector2(1.2, 1.2)
		
	block.pressed.connect(_on_block_pressed.bind(block))
	board.add_child(block)
	grid_array[y][x] = block
	# instant = true，方块直接出现在对应位置，不播放下落动画
	block.update_pos(Vector2i(x, y), true)
	
# 统一保存所有游戏数据
func save_game_data():
	save_current_state() # 同步当前屏幕上的状态到缓存字典
	
	# 打包进字典
	var save_data = {
		"high_scores": high_scores,
		"saved_states": saved_states,
		"current_mode": current_mode,
		"settings": {
			"sound_enabled": sound_enabled,
			"language": TranslationServer.get_locale() # 获取当前语言
		}
	}
	
	# 一次性写入文件
	var file = FileAccess.open(SAVE_FILE_PATH, FileAccess.WRITE)
	if file:
		file.store_var(save_data)
		file.close()

# 统一读取所有游戏数据
func load_game_data() -> bool:
	if FileAccess.file_exists(SAVE_FILE_PATH):
		var file = FileAccess.open(SAVE_FILE_PATH, FileAccess.READ)
		var save_data = file.get_var()
		file.close()
		
		if typeof(save_data) == TYPE_DICTIONARY:
			# 恢复最高分
			if save_data.has("high_scores"):
				high_scores = save_data["high_scores"]
				
			# 恢复设置
			if save_data.has("settings"):
				sound_enabled = save_data["settings"].get("sound_enabled", true)
				var saved_lang = save_data["settings"].get("language", "zh")
				TranslationServer.set_locale(saved_lang)
				
				# 更新 UI 按钮的状态
				update_lang_btn_text()
			
			# 恢复游戏进度和模式
			if save_data.has("saved_states") and save_data.has("current_mode"):
				saved_states = save_data["saved_states"]
				var saved_mode = save_data["current_mode"]
				
				# 检查最后玩的模式是否有进度
				if saved_states.has(saved_mode) and saved_states[saved_mode].has("is_saved") and saved_states[saved_mode]["is_saved"]:
					load_state(saved_mode)
					return true # 成功恢复了棋盘进度
					
	return false # 没有找到进度，或者存档为空

# 监听系统事件
func _notification(what):
	# NOTIFICATION_WM_CLOSE_REQUEST 点了关闭按钮
	# NOTIFICATION_APPLICATION_PAUSED 被切换到后台
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		# 防止在动画播放一半或者游戏失败时存入错误状态
		if not is_animating:
			save_game_data()
