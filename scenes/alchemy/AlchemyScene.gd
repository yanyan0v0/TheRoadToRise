## 炼丹阁场景脚本 - 花费金币炼制丹药
extends Control

## 炼丹档位配置：{金币花费, 品质概率}
const ALCHEMY_TIERS := {
	"low": {"cost": 40, "name": "初级炼丹", "desc": "花费40金币，大概率获得普通丹药", "probs": {"normal": 0.75, "rare": 0.20, "legendary": 0.05}},
	"mid": {"cost": 70, "name": "中级炼丹", "desc": "花费70金币，较高概率获得稀有丹药", "probs": {"normal": 0.40, "rare": 0.45, "legendary": 0.15}},
	"high": {"cost": 100, "name": "高级炼丹", "desc": "花费100金币，有机会获得传说丹药", "probs": {"normal": 0.15, "rare": 0.50, "legendary": 0.35}},
}

var _result_popup: Control = null

func _ready() -> void:
	GameManager.change_state(GameManager.GameState.REST)
	_build_ui()

## 构建炼丹阁界面
func _build_ui() -> void:
	# 背景
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.06, 0.05, 0.12, 1.0)
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
	title.text = "🧪 炼丹阁"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color("A29BFE"))
	main_vbox.add_child(title)
	
	# 说明
	var desc := Label.new()
	desc.text = "消耗金币炼制丹药，不同档位影响丹药品质"
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.add_theme_font_size_override("font_size", 14)
	desc.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	main_vbox.add_child(desc)
	
	# 状态信息
	var info_hbox := HBoxContainer.new()
	info_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	info_hbox.add_theme_constant_override("separation", 30)
	main_vbox.add_child(info_hbox)
	
	var gold_label := Label.new()
	gold_label.name = "GoldLabel"
	gold_label.text = "💰 金币: %d" % GameManager.current_gold
	gold_label.add_theme_font_size_override("font_size", 18)
	info_hbox.add_child(gold_label)
	
	var pill_label := Label.new()
	pill_label.name = "PillLabel"
	pill_label.text = "💊 丹药: %d/%d" % [GameManager.current_consumables.size(), GameManager.get_consumable_capacity()]
	pill_label.add_theme_font_size_override("font_size", 18)
	info_hbox.add_child(pill_label)
	
	# 间隔
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	main_vbox.add_child(spacer)
	
	# 三个炼丹档位
	var tiers_hbox := HBoxContainer.new()
	tiers_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	tiers_hbox.add_theme_constant_override("separation", 20)
	main_vbox.add_child(tiers_hbox)
	
	for tier_key in ["low", "mid", "high"]:
		var tier_data: Dictionary = ALCHEMY_TIERS[tier_key]
		var tier_panel := _create_tier_panel(tier_key, tier_data)
		tiers_hbox.add_child(tier_panel)
	
	# 离开按钮
	var leave_spacer := Control.new()
	leave_spacer.custom_minimum_size = Vector2(0, 20)
	main_vbox.add_child(leave_spacer)
	
	var leave_btn := Button.new()
	leave_btn.text = "离开炼丹阁"
	leave_btn.custom_minimum_size = Vector2(200, 50)
	leave_btn.add_theme_font_size_override("font_size", 18)
	leave_btn.pressed.connect(_on_leave_pressed)
	
	var leave_center := CenterContainer.new()
	leave_center.add_child(leave_btn)
	main_vbox.add_child(leave_center)

## 创建炼丹档位面板
func _create_tier_panel(tier_key: String, tier_data: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(220, 280)
	
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.14, 0.18, 0.95)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(15)
	
	# 根据档位设置边框颜色
	match tier_key:
		"low": style.border_color = Color.WHITE
		"mid": style.border_color = Color("0984E3")
		"high": style.border_color = Color("FDCB6E")
	style.set_border_width_all(2)
	panel.add_theme_stylebox_override("panel", style)
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)
	
	# 档位名称
	var name_label := Label.new()
	name_label.text = tier_data["name"]
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 20)
	match tier_key:
		"low": name_label.add_theme_color_override("font_color", Color.WHITE)
		"mid": name_label.add_theme_color_override("font_color", Color("0984E3"))
		"high": name_label.add_theme_color_override("font_color", Color("FDCB6E"))
	vbox.add_child(name_label)
	
	# 花费
	var cost_label := Label.new()
	cost_label.text = "💰 %d 金币" % tier_data["cost"]
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(cost_label)
	
	# 分隔线
	var sep := HSeparator.new()
	vbox.add_child(sep)
	
	# 概率说明
	var probs: Dictionary = tier_data["probs"]
	var prob_text := "普通: %d%%\n稀有: %d%%\n传说: %d%%" % [
		int(probs["normal"] * 100),
		int(probs["rare"] * 100),
		int(probs["legendary"] * 100),
	]
	var prob_label := Label.new()
	prob_label.text = prob_text
	prob_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prob_label.add_theme_font_size_override("font_size", 13)
	prob_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	vbox.add_child(prob_label)
	
	# 间隔
	var btn_spacer := Control.new()
	btn_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(btn_spacer)
	
	# 炼丹按钮
	var alchemy_btn := Button.new()
	alchemy_btn.text = "炼丹"
	alchemy_btn.custom_minimum_size = Vector2(0, 45)
	alchemy_btn.add_theme_font_size_override("font_size", 16)
	
	# 检查是否可以炼丹
	var can_afford: bool  = GameManager.current_gold >= tier_data["cost"]
	var is_full := GameManager.is_consumable_full()
	alchemy_btn.disabled = not can_afford or is_full
	if not can_afford:
		alchemy_btn.tooltip_text = "金币不足"
	elif is_full:
		alchemy_btn.tooltip_text = "丹药已满"
	
	alchemy_btn.pressed.connect(func(): _on_alchemy_pressed(tier_key))
	vbox.add_child(alchemy_btn)
	
	return panel

## 炼丹按钮点击
func _on_alchemy_pressed(tier_key: String) -> void:
	var tier_data: Dictionary = ALCHEMY_TIERS[tier_key]
	var cost: int = tier_data["cost"]
	
	# 检查金币
	if GameManager.current_gold < cost:
		return
	
	# 检查丹药上限
	if GameManager.is_consumable_full():
		return
	
	# 扣除金币
	GameManager.modify_gold(-cost)
	
	# 根据概率决定品质
	var probs: Dictionary = tier_data["probs"]
	var roll := randf()
	var quality: String = "normal"
	if roll < probs["legendary"]:
		quality = "legendary"
	elif roll < probs["legendary"] + probs["rare"]:
		quality = "rare"
	
	# 从对应品质的丹药中随机选取
	var pill := _get_random_pill(quality)
	if pill.is_empty():
		# 降级尝试
		pill = _get_random_pill("normal")
	
	if not pill.is_empty():
		var pill_id: String = pill.get("consumable_id", "")
		GameManager.add_consumable(pill_id)
		_show_result(pill, quality)
	
	# 刷新界面
	_refresh_ui()

## 获取随机丹药
func _get_random_pill(quality: String) -> Dictionary:
	var all_consumables: Array = DataManager.get_all_consumables()
	var candidates: Array = []
	for c in all_consumables:
		if c.get("quality", "normal") == quality:
			candidates.append(c)
	if candidates.is_empty():
		return {}
	return candidates[randi() % candidates.size()]

## 显示炼丹结果
func _show_result(pill: Dictionary, quality: String) -> void:
	if _result_popup != null:
		_result_popup.queue_free()
	
	_result_popup = Control.new()
	_result_popup.set_anchors_preset(Control.PRESET_FULL_RECT)
	_result_popup.z_index = 50
	
	var overlay := ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0, 0.5)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_result_popup.add_child(overlay)
	
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.anchor_left = 0.25
	panel.anchor_right = 0.75
	panel.anchor_top = 0.2
	panel.anchor_bottom = 0.8
	panel.offset_left = 0
	panel.offset_right = 0
	panel.offset_top = 0
	panel.offset_bottom = 0
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.14, 0.18, 0.95)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(20)
	match quality:
		"normal": style.border_color = Color.WHITE
		"rare": style.border_color = Color("0984E3")
		"legendary": style.border_color = Color("FDCB6E")
	style.set_border_width_all(2)
	panel.add_theme_stylebox_override("panel", style)
	_result_popup.add_child(panel)
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)
	
	var result_title := Label.new()
	result_title.text = "✨ 炼丹成功！"
	result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_title.add_theme_font_size_override("font_size", 22)
	result_title.add_theme_color_override("font_color", Color("A29BFE"))
	vbox.add_child(result_title)
	
	var pill_name := Label.new()
	var quality_text := ""
	match quality:
		"normal": quality_text = "[普通]"
		"rare": quality_text = "[稀有]"
		"legendary": quality_text = "[传说]"
	pill_name.text = "%s %s" % [quality_text, pill.get("consumable_name", "???")]
	pill_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pill_name.add_theme_font_size_override("font_size", 18)
	match quality:
		"rare": pill_name.add_theme_color_override("font_color", Color("0984E3"))
		"legendary": pill_name.add_theme_color_override("font_color", Color("FDCB6E"))
	vbox.add_child(pill_name)
	
	var pill_desc := Label.new()
	pill_desc.text = pill.get("description", "")
	pill_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pill_desc.add_theme_font_size_override("font_size", 14)
	pill_desc.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	pill_desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(pill_desc)
	
	# 显示丹药效果属性
	var effects: Array = pill.get("effects", [])
	if not effects.is_empty():
		var effect_text := _build_effect_text(effects)
		var effect_label := Label.new()
		effect_label.text = "效果: " + effect_text
		effect_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		effect_label.add_theme_font_size_override("font_size", 13)
		effect_label.add_theme_color_override("font_color", Color("00B894"))
		effect_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		vbox.add_child(effect_label)
	
	# 显示使用场景
	var use_scene: String = pill.get("use_scene", "")
	if not use_scene.is_empty():
		var scene_name := ""
		match use_scene:
			"battle": scene_name = "战斗中使用"
			"any": scene_name = "任意时刻使用"
			"passive": scene_name = "被动生效"
			_: scene_name = use_scene
		var scene_label := Label.new()
		scene_label.text = "📋 " + scene_name
		scene_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		scene_label.add_theme_font_size_override("font_size", 12)
		scene_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
		vbox.add_child(scene_label)
	
	var ok_btn := Button.new()
	ok_btn.text = "确定"
	ok_btn.custom_minimum_size = Vector2(100, 35)
	ok_btn.pressed.connect(func():
		_result_popup.queue_free()
		_result_popup = null
	)
	var btn_center := CenterContainer.new()
	btn_center.add_child(ok_btn)
	vbox.add_child(btn_center)
	
	add_child(_result_popup)

## 刷新界面
func _refresh_ui() -> void:
	# 清除所有子节点并重建
	for child in get_children():
		child.queue_free()
	_build_ui()

## 离开
func _on_leave_pressed() -> void:
	SceneTransition.change_scene("res://scenes/map/MapScene.tscn")

## 构建效果文本
func _build_effect_text(effects: Array) -> String:
	var parts: Array[String] = []
	for effect in effects:
		var etype: String = effect.get("type", "")
		var value: int = effect.get("value", 0)
		match etype:
			"heal": parts.append("恢复%d生命" % value)
			"damage": parts.append("造成%d伤害" % value)
			"armor": parts.append("获得%d护甲" % value)
			"draw": parts.append("抽%d张牌" % value)
			"energy": parts.append("获得%d能量" % value)
			"strength": parts.append("力量+%d" % value)
			"max_hp": parts.append("最大生命+%d" % value)
			"heal_percent": parts.append("恢复%d%%生命" % value)
			_:
				if value != 0:
					parts.append("%s: %d" % [etype, value])
	return ", ".join(parts) if not parts.is_empty() else "无"
