## 成就列表界面
extends Control

var _category_buttons: Dictionary = {}
var _achievement_list: VBoxContainer = null
var _current_category: String = "all"

func _ready() -> void:
	_build_ui()
	_show_achievements("all")

## 构建成就界面
func _build_ui() -> void:
	# 背景
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.05, 0.05, 0.1, 1.0)
	add_child(bg)
	
	# 主容器
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 40)
	margin.add_theme_constant_override("margin_right", 40)
	margin.add_theme_constant_override("margin_top", 30)
	margin.add_theme_constant_override("margin_bottom", 30)
	add_child(margin)
	
	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 15)
	margin.add_child(main_vbox)
	
	# 标题栏
	var title_hbox := HBoxContainer.new()
	title_hbox.add_theme_constant_override("separation", 20)
	main_vbox.add_child(title_hbox)
	
	var title := Label.new()
	title.text = "🏆 成就"
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color("FDCB6E"))
	title_hbox.add_child(title)
	
	# 统计
	var all_achievements := AchievementManager.get_all_achievements()
	var unlocked_count := 0
	for a in all_achievements:
		if a.get("unlocked", false):
			unlocked_count += 1
	
	var stats_label := Label.new()
	stats_label.text = "已解锁: %d/%d" % [unlocked_count, all_achievements.size()]
	stats_label.add_theme_font_size_override("font_size", 18)
	stats_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	stats_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	title_hbox.add_child(stats_label)
	
	# 分类按钮
	var category_hbox := HBoxContainer.new()
	category_hbox.add_theme_constant_override("separation", 10)
	main_vbox.add_child(category_hbox)
	
	var categories := [
		{"id": "all", "name": "全部"},
		{"id": "battle", "name": "⚔️ 战斗"},
		{"id": "explore", "name": "🗺️ 探索"},
		{"id": "collect", "name": "📦 收集"},
		{"id": "challenge", "name": "🏅 挑战"},
	]
	
	for cat in categories:
		var btn := Button.new()
		btn.text = cat["name"]
		btn.custom_minimum_size = Vector2(100, 35)
		btn.pressed.connect(_on_category_pressed.bind(cat["id"]))
		category_hbox.add_child(btn)
		_category_buttons[cat["id"]] = btn
	
	# 成就列表（滚动容器）
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(scroll)
	
	_achievement_list = VBoxContainer.new()
	_achievement_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_achievement_list.add_theme_constant_override("separation", 8)
	scroll.add_child(_achievement_list)
	
	# 返回按钮
	var back_btn := Button.new()
	back_btn.text = "返回"
	back_btn.custom_minimum_size = Vector2(150, 45)
	back_btn.add_theme_font_size_override("font_size", 18)
	back_btn.pressed.connect(_on_back_pressed)
	
	var back_center := CenterContainer.new()
	back_center.add_child(back_btn)
	main_vbox.add_child(back_center)

## 显示指定分类的成就
func _show_achievements(category: String) -> void:
	_current_category = category
	
	# 清除旧列表
	for child in _achievement_list.get_children():
		child.queue_free()
	
	var achievements: Array[Dictionary]
	if category == "all":
		achievements = AchievementManager.get_all_achievements()
	else:
		achievements = AchievementManager.get_achievements_by_category(category)
	
	for achievement in achievements:
		var item := _create_achievement_item(achievement)
		_achievement_list.add_child(item)

## 创建成就条目UI
func _create_achievement_item(data: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 70)
	
	var style := StyleBoxFlat.new()
	var is_unlocked: bool = data.get("unlocked", false)
	
	if is_unlocked:
		style.bg_color = Color(0.1, 0.15, 0.1, 0.9)
		style.border_color = Color("00B894")
	else:
		style.bg_color = Color(0.08, 0.08, 0.08, 0.9)
		style.border_color = Color(0.3, 0.3, 0.3)
	
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", style)
	
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 15)
	panel.add_child(hbox)
	
	# 状态图标
	var icon := Label.new()
	icon.text = "✅" if is_unlocked else "🔒"
	icon.add_theme_font_size_override("font_size", 24)
	hbox.add_child(icon)
	
	# 成就信息
	var info_vbox := VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(info_vbox)
	
	var name_label := Label.new()
	name_label.text = data.get("name", "???")
	name_label.add_theme_font_size_override("font_size", 16)
	if is_unlocked:
		name_label.add_theme_color_override("font_color", Color("FDCB6E"))
	info_vbox.add_child(name_label)
	
	var desc_label := Label.new()
	desc_label.text = data.get("description", "")
	desc_label.add_theme_font_size_override("font_size", 12)
	desc_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	info_vbox.add_child(desc_label)
	
	# 奖励预览
	var unlock_type: String = data.get("unlock_type", "")
	if not unlock_type.is_empty():
		var reward_label := Label.new()
		var type_name := ""
		match unlock_type:
			"new_pill": type_name = "🧪 新丹药"
			"new_card": type_name = "🃏 新卡牌"
			"new_relic": type_name = "💎 新法宝"
			"new_event": type_name = "📜 新事件"
		reward_label.text = "奖励: %s" % type_name
		reward_label.add_theme_font_size_override("font_size", 12)
		reward_label.add_theme_color_override("font_color", Color("6C5CE7"))
		hbox.add_child(reward_label)
	
	return panel

## 分类按钮点击
func _on_category_pressed(category: String) -> void:
	_show_achievements(category)

## 返回
func _on_back_pressed() -> void:
	SceneTransition.change_scene("res://scenes/main_menu/MainMenuScene.tscn")
