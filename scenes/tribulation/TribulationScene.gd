## 渡劫场景脚本 - 特殊天劫挑战战斗
extends Control

func _ready() -> void:
	GameManager.change_state(GameManager.GameState.REST)
	_build_ui()

## 构建渡劫界面
func _build_ui() -> void:
	# 背景
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.04, 0.02, 0.08, 1.0)
	add_child(bg)
	
	# 中心容器
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	
	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 20)
	center.add_child(main_vbox)
	
	# 标题
	var title := Label.new()
	title.text = "⚡ 渡劫"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color("FF6B6B"))
	main_vbox.add_child(title)
	
	# 当前劫数信息
	var karma_level := GameManager.get_tribulation_level()
	var info := Label.new()
	info.text = "当前劫数: %d  |  天劫等级: %s" % [GameManager.current_karma, karma_level]
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.add_theme_font_size_override("font_size", 18)
	info.add_theme_color_override("font_color", Color("FDCB6E"))
	main_vbox.add_child(info)
	
	# 说明
	var desc := Label.new()
	desc.text = "渡劫将面对强大的天劫BOSS\n胜利后劫数归零，并获得传说级奖励\n失败则继续旅程，劫数不变"
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.add_theme_font_size_override("font_size", 14)
	desc.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	main_vbox.add_child(desc)
	
	# 天劫BOSS预览
	var boss_panel := PanelContainer.new()
	boss_panel.custom_minimum_size = Vector2(400, 120)
	var boss_style := StyleBoxFlat.new()
	boss_style.bg_color = Color(0.15, 0.05, 0.1, 0.9)
	boss_style.border_color = Color("FF6B6B")
	boss_style.set_border_width_all(2)
	boss_style.set_corner_radius_all(8)
	boss_style.set_content_margin_all(15)
	boss_panel.add_theme_stylebox_override("panel", boss_style)
	
	var boss_vbox := VBoxContainer.new()
	boss_vbox.add_theme_constant_override("separation", 8)
	boss_panel.add_child(boss_vbox)
	
	var boss_name := Label.new()
	boss_name.text = "⚡ 天劫雷灵"
	boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_name.add_theme_font_size_override("font_size", 20)
	boss_name.add_theme_color_override("font_color", Color("FF6B6B"))
	boss_vbox.add_child(boss_name)
	
	# 根据劫数计算BOSS强度
	var buff := GameManager.get_tribulation_buff()
	var boss_hp := int(100 * (1.0 + buff))
	var boss_atk := int(15 * (1.0 + buff))
	
	var boss_stats := Label.new()
	boss_stats.text = "生命: %d  |  攻击: %d  |  增强: +%d%%" % [boss_hp, boss_atk, int(buff * 100)]
	boss_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_stats.add_theme_font_size_override("font_size", 14)
	boss_vbox.add_child(boss_stats)
	
	var boss_center := CenterContainer.new()
	boss_center.add_child(boss_panel)
	main_vbox.add_child(boss_center)
	
	# 按钮区域
	var btn_hbox := HBoxContainer.new()
	btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_hbox.add_theme_constant_override("separation", 30)
	main_vbox.add_child(btn_hbox)
	
	# 渡劫按钮
	var tribulation_btn := Button.new()
	tribulation_btn.text = "⚡ 开始渡劫"
	tribulation_btn.custom_minimum_size = Vector2(200, 55)
	tribulation_btn.add_theme_font_size_override("font_size", 18)
	tribulation_btn.pressed.connect(_on_tribulation_pressed)
	btn_hbox.add_child(tribulation_btn)
	
	# 离开按钮
	var leave_btn := Button.new()
	leave_btn.text = "暂不渡劫"
	leave_btn.custom_minimum_size = Vector2(200, 55)
	leave_btn.add_theme_font_size_override("font_size", 18)
	leave_btn.pressed.connect(_on_leave_pressed)
	btn_hbox.add_child(leave_btn)

## 开始渡劫战斗
func _on_tribulation_pressed() -> void:
	# 设置为特殊渡劫战斗
	GameManager.current_battle_type = "tribulation"
	GameManager.current_boss_id = "tian_jie_lei_ling"
	SceneTransition.change_scene("res://scenes/battle/BattleScene.tscn")

## 离开
func _on_leave_pressed() -> void:
	SceneTransition.change_scene("res://scenes/map/MapScene.tscn")
