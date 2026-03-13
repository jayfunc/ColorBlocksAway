extends Button

func _ready():
	flat = true 
	
	add_theme_color_override("font_color", Color("#1A1A1A"))
	add_theme_color_override("font_hover_color", Color("#E62727"))
	add_theme_color_override("font_focus_color", Color("#1A1A1A"))
	
	add_theme_font_size_override("font_size", 28)
	
	pivot_offset = size / 2.0
	
	mouse_entered.connect(func():
		var t = create_tween()
		t.tween_property(self, "scale", Vector2(1.1, 1.1), 0.15).set_trans(Tween.TRANS_BACK)
	)
	mouse_exited.connect(func():
		var t = create_tween()
		t.tween_property(self, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_SINE)
	)
	button_down.connect(func():
		var t = create_tween()
		t.tween_property(self, "scale", Vector2(0.9, 0.9), 0.05)
	)
