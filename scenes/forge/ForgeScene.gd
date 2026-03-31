## 炼器坊场景脚本 - 锻造新法宝或融合法宝升星
extends Control

## 锻造档位配置
const FORGE_TIERS := {
	"low": {"cost": 60, "name": "初级锻造", "desc": "花费60金币，大概率获得普通法宝", "probs": {"common": 0.65, "uncommon": 0.25, "rare": 0.08, "legendary": 0.02}},
	"mid": {"cost": 100, "name": "中级锻造", "desc": "花费100金币，较高概率获得优秀法宝", "probs": {"common": 0.30, "uncommon": 0.40, "rare": 0.22, "legendary": 0.08}},
	"high": {"cost": 150, "name": "高级锻造", "desc": "花费150金币，有机会获得稀有法宝", "probs": {"common": 0.10, "uncommon": 0.30, "rare": 0.40, "legendary": 0.20}},
}

var _result_popup: Control = null
var _current_tab: String = "forge"  # "forge" 或 "fuse"

func _ready() -> void:
	GameManager.change_state(GameManager.GameState.REST)
	_build_ui()

## 构建界面
func _build_ui() -> void:
	# 背景
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.08, 0.06, 0.04, 1.0)
	add_child(bg)
	
	# 中心容器
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	
	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 15)
	center.add_child(main_vbox)
	
	# 标题
	var title := Label.new()
	title.text = "🔨 炼器坊"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color("E67E22"))
	main_vbox.add_child(title)
	
	# 金币信息
	var gold_label := Label.new()
	gold_label.name = "GoldLabel"
	gold_label.text = "💰 金币: %d" % GameManager.current_gold
	gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gold_label.add_theme_font_size_override("font_size", 18)
	main_vbox.add_child(gold_label)
	
	# 标签页切换
	var tab_hbox := HBoxContainer.new()
	tab_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	tab_hbox.add_theme_constant_override("separation", 10)
	main_vbox.add_child(tab_hbox)
	
	var forge_tab := Button.new()
	forge_tab.text = "🔨 锻造新法宝"
	forge_tab.custom_minimum_size = Vector2(180, 40)
	forge_tab.add_theme_font_size_override("font_size", 16)
	forge_tab.disabled = (_current_tab == "forge")
	forge_tab.pressed.connect(func():
		_current_tab = "forge"
		_refresh_ui()
	)
	tab_hbox.add_child(forge_tab)
	
	var fuse_tab := Button.new()
	fuse_tab.text = "🔮 融合法宝"
	fuse_tab.custom_minimum_size = Vector2(180, 40)
	fuse_tab.add_theme_font_size_override("font_size", 16)
	fuse_tab.disabled = (_current_tab == "fuse")
	fuse_tab.pressed.connect(func():
		_current_tab = "fuse"
		_refresh_ui()
	)
	tab_hbox.add_child(fuse_tab)
	
	# 内容区域
	var content := VBoxContainer.new()
	content.name = "ContentArea"
	content.add_theme_constant_override("separation", 10)
	main_vbox.add_child(content)
	
	if _current_tab == "forge":
		_build_forge_content(content)
	else:
		_build_fuse_content(content)
	
	# 离开按钮
	var leave_spacer := Control.new()
	leave_spacer.custom_minimum_size = Vector2(0, 15)
	main_vbox.add_child(leave_spacer)
	
	var leave_btn := Button.new()
	leave_btn.text = "离开炼器坊"
	leave_btn.custom_minimum_size = Vector2(200, 50)
	leave_btn.add_theme_font_size_override("font_size", 18)
	leave_btn.pressed.connect(_on_leave_pressed)
	
	var leave_center := CenterContainer.new()
	leave_center.add_child(leave_btn)
	main_vbox.add_child(leave_center)

## 构建锻造内容
func _build_forge_content(container: VBoxContainer) -> void:
	var desc := Label.new()
	desc.text = "消耗金币锻造一件全新的1星法宝"
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.add_theme_font_size_override("font_size", 14)
	desc.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	container.add_child(desc)
	
	var tiers_hbox := HBoxContainer.new()
	tiers_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	tiers_hbox.add_theme_constant_override("separation", 20)
	container.add_child(tiers_hbox)
	
	for tier_key in ["low", "mid", "high"]:
		var tier_data: Dictionary = FORGE_TIERS[tier_key]
		var tier_panel := _create_forge_tier_panel(tier_key, tier_data)
		tiers_hbox.add_child(tier_panel)

## 创建锻造档位面板
func _create_forge_tier_panel(tier_key: String, tier_data: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(220, 260)
	
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.14, 0.18, 0.95)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(15)
	match tier_key:
		"low": style.border_color = Color.WHITE
		"mid": style.border_color = Color("0984E3")
		"high": style.border_color = Color("FDCB6E")
	style.set_border_width_all(2)
	panel.add_theme_stylebox_override("panel", style)
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)
	
	var name_label := Label.new()
	name_label.text = tier_data["name"]
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 20)
	match tier_key:
		"low": name_label.add_theme_color_override("font_color", Color.WHITE)
		"mid": name_label.add_theme_color_override("font_color", Color("0984E3"))
		"high": name_label.add_theme_color_override("font_color", Color("FDCB6E"))
	vbox.add_child(name_label)
	
	var cost_label := Label.new()
	cost_label.text = "💰 %d 金币" % tier_data["cost"]
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(cost_label)
	
	var sep := HSeparator.new()
	vbox.add_child(sep)
	
	var probs: Dictionary = tier_data["probs"]
	var prob_text := "普通: %d%%\n优秀: %d%%\n稀有: %d%%\n传说: %d%%" % [
		int(probs["common"] * 100),
		int(probs["uncommon"] * 100),
		int(probs["rare"] * 100),
		int(probs["legendary"] * 100),
	]
	var prob_label := Label.new()
	prob_label.text = prob_text
	prob_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prob_label.add_theme_font_size_override("font_size", 13)
	prob_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	vbox.add_child(prob_label)
	
	var btn_spacer := Control.new()
	btn_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(btn_spacer)
	
	var forge_btn := Button.new()
	forge_btn.text = "锻造"
	forge_btn.custom_minimum_size = Vector2(0, 45)
	forge_btn.add_theme_font_size_override("font_size", 16)
	forge_btn.disabled = GameManager.current_gold < tier_data["cost"]
	if forge_btn.disabled:
		forge_btn.tooltip_text = "金币不足"
	forge_btn.pressed.connect(func(): _on_forge_pressed(tier_key))
	vbox.add_child(forge_btn)
	
	return panel

## 构建融合内容
func _build_fuse_content(container: VBoxContainer) -> void:
	var desc := Label.new()
	desc.text = "将2件相同星级的相同法宝融合为更高星级（最高3星）"
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.add_theme_font_size_override("font_size", 14)
	desc.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	container.add_child(desc)
	
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(700, 350)
	container.add_child(scroll)
	
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 8)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	
	var groups := GameManager.get_fusable_relic_groups()
	var has_fusable := false
	
	for group in groups:
		if not group.get("can_fuse", false):
			continue
		has_fusable = true
		
		var relic_id: String = group.get("relic_id", "")
		var relic_name: String = group.get("relic_name", "???")
		var star_level: int = group.get("star_level", 1)
		var count: int = group.get("count", 0)
		var indices: Array = group.get("indices", [])
		var new_star: int = star_level + 1
		
		var row := _create_relic_fuse_row(relic_id, relic_name, star_level, new_star, count, indices)
		list.add_child(row)
	
	if not has_fusable:
		var empty_label := Label.new()
		empty_label.text = "没有可融合的法宝"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.add_theme_font_size_override("font_size", 16)
		empty_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		list.add_child(empty_label)

## 创建法宝融合行
func _create_relic_fuse_row(relic_id: String, relic_name: String, star_level: int, new_star: int, count: int, indices: Array) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.17, 0.22, 0.9)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", style)
	
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 15)
	panel.add_child(hbox)
	
	var info_vbox := VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var star_text := _get_star_text(star_level)
	var new_star_text := _get_star_text(new_star)
	
	var name_label := Label.new()
	name_label.text = "%s %s → %s" % [relic_name, star_text, new_star_text]
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", Color("E67E22"))
	info_vbox.add_child(name_label)
	
	var count_label := Label.new()
	count_label.text = "持有: %d件  |  可融合: %d次" % [count, count / 2]
	count_label.add_theme_font_size_override("font_size", 12)
	count_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	info_vbox.add_child(count_label)
	
	# 显示升星后效果预览
	var relic_data := DataManager.get_relic(relic_id)
	var preview_desc := ""
	if new_star == 2:
		preview_desc = relic_data.get("star_2_description", "")
	elif new_star == 3:
		preview_desc = relic_data.get("star_3_description", "")
	if not preview_desc.is_empty():
		var preview_label := Label.new()
		preview_label.text = "融合后: " + preview_desc
		preview_label.add_theme_font_size_override("font_size", 11)
		preview_label.add_theme_color_override("font_color", Color("A29BFE"))
		preview_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		info_vbox.add_child(preview_label)
	
	hbox.add_child(info_vbox)
	
	var fuse_btn := Button.new()
	fuse_btn.text = "融合"
	fuse_btn.custom_minimum_size = Vector2(80, 40)
	fuse_btn.pressed.connect(func():
		_execute_relic_fusion(relic_id, star_level, indices)
	)
	hbox.add_child(fuse_btn)
	
	return panel

## 获取星级文本
func _get_star_text(star: int) -> String:
	match star:
		1: return "★☆☆"
		2: return "★★☆"
		3: return "★★★"
	return "★☆☆"

## 锻造按钮点击
func _on_forge_pressed(tier_key: String) -> void:
	var tier_data: Dictionary = FORGE_TIERS[tier_key]
	var cost: int = tier_data["cost"]
	
	if GameManager.current_gold < cost:
		return
	
	GameManager.modify_gold(-cost)
	
	# 根据概率决定稀有度
	var probs: Dictionary = tier_data["probs"]
	var roll := randf()
	var rarity: String = "common"
	var cumulative := 0.0
	for r in ["legendary", "rare", "uncommon", "common"]:
		cumulative += probs.get(r, 0.0)
		if roll < cumulative:
			rarity = r
			break
	
	# 从对应稀有度的法宝中随机选取
	var relic := _get_random_relic(rarity)
	if relic.is_empty():
		relic = _get_random_relic("common")
	
	if not relic.is_empty():
		var relic_id: String = relic.get("relic_id", "")
		GameManager.add_relic(relic_id, 1)
		_show_forge_result(relic, rarity)
	
	_refresh_ui()

## 获取随机法宝
func _get_random_relic(rarity: String) -> Dictionary:
	var all_relics: Array = DataManager.get_all_relics()
	var candidates: Array = []
	for r in all_relics:
		if r.get("rarity", "common") == rarity:
			candidates.append(r)
	if candidates.is_empty():
		return {}
	return candidates[randi() % candidates.size()]

## 显示锻造结果
func _show_forge_result(relic: Dictionary, rarity: String) -> void:
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
	panel.custom_minimum_size = Vector2(350, 200)
	panel.position = Vector2(-175, -100)
	
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.14, 0.18, 0.95)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(20)
	match rarity:
		"common": style.border_color = Color.WHITE
		"uncommon": style.border_color = Color("00B894")
		"rare": style.border_color = Color("0984E3")
		"legendary": style.border_color = Color("FDCB6E")
	style.set_border_width_all(2)
	panel.add_theme_stylebox_override("panel", style)
	_result_popup.add_child(panel)
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)
	
	var result_title := Label.new()
	result_title.text = "⚒️ 锻造成功！"
	result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_title.add_theme_font_size_override("font_size", 22)
	result_title.add_theme_color_override("font_color", Color("E67E22"))
	vbox.add_child(result_title)
	
	var relic_name := Label.new()
	var rarity_text := ""
	match rarity:
		"common": rarity_text = "[普通]"
		"uncommon": rarity_text = "[优秀]"
		"rare": rarity_text = "[稀有]"
		"legendary": rarity_text = "[传说]"
	relic_name.text = "%s %s ★☆☆" % [rarity_text, relic.get("relic_name", "???")]
	relic_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	relic_name.add_theme_font_size_override("font_size", 18)
	match rarity:
		"uncommon": relic_name.add_theme_color_override("font_color", Color("00B894"))
		"rare": relic_name.add_theme_color_override("font_color", Color("0984E3"))
		"legendary": relic_name.add_theme_color_override("font_color", Color("FDCB6E"))
	vbox.add_child(relic_name)
	
	var relic_desc := Label.new()
	relic_desc.text = relic.get("description", "")
	relic_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	relic_desc.add_theme_font_size_override("font_size", 14)
	relic_desc.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	relic_desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(relic_desc)
	
	# 显示法宝效果属性
	var effects: Array = relic.get("effects", [])
	if not effects.is_empty():
		var effect_text := _build_relic_effect_text(effects)
		var effect_label := Label.new()
		effect_label.text = "效果: " + effect_text
		effect_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		effect_label.add_theme_font_size_override("font_size", 13)
		effect_label.add_theme_color_override("font_color", Color("00B894"))
		effect_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		vbox.add_child(effect_label)
	
	# 显示触发条件
	var trigger: String = relic.get("trigger_type", "")
	if not trigger.is_empty():
		var trigger_name := ""
		match trigger:
			"on_battle_start": trigger_name = "战斗开始时"
			"on_turn_start": trigger_name = "回合开始时"
			"on_attack": trigger_name = "攻击时"
			"on_fatal_damage": trigger_name = "受到致命伤害时"
			"passive": trigger_name = "被动生效"
			_: trigger_name = trigger
		var trigger_label := Label.new()
		trigger_label.text = "📋 触发: " + trigger_name
		trigger_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		trigger_label.add_theme_font_size_override("font_size", 12)
		trigger_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
		vbox.add_child(trigger_label)
	
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

## 执行法宝融合
func _execute_relic_fusion(relic_id: String, star_level: int, indices: Array) -> void:
	var match_indices: Array = []
	for idx in indices:
		if idx < GameManager.current_relics.size():
			var entry = GameManager.current_relics[idx]
			var rid: String = entry.get("relic_id", "") if entry is Dictionary else str(entry)
			var star: int = entry.get("star_level", 1) if entry is Dictionary else 1
			if rid == relic_id and star == star_level:
				match_indices.append(idx)
				if match_indices.size() >= 2:
					break
	
	if match_indices.size() < 2:
		return
	
	var result := GameManager.fuse_relics(match_indices[0], match_indices[1])
	if not result.is_empty():
		var new_star: int = result.get("star_level", 2)
		var relic_data := DataManager.get_relic(relic_id)
		_show_fuse_result(relic_data, relic_id, new_star)
		_refresh_ui()

## 刷新界面
func _refresh_ui() -> void:
	for child in get_children():
		child.queue_free()
	_build_ui()

## 离开
func _on_leave_pressed() -> void:
	SceneTransition.change_scene("res://scenes/map/MapScene.tscn")

## 显示融合结果弹窗
func _show_fuse_result(relic: Dictionary, relic_id: String, new_star: int) -> void:
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
	panel.custom_minimum_size = Vector2(380, 230)
	panel.position = Vector2(-190, -115)
	
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.14, 0.18, 0.95)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(20)
	style.border_color = Color("A29BFE")
	style.set_border_width_all(2)
	panel.add_theme_stylebox_override("panel", style)
	_result_popup.add_child(panel)
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)
	
	var result_title := Label.new()
	result_title.text = "🔮 融合成功！"
	result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_title.add_theme_font_size_override("font_size", 22)
	result_title.add_theme_color_override("font_color", Color("A29BFE"))
	vbox.add_child(result_title)
	
	var star_text := _get_star_text(new_star)
	var name_label := Label.new()
	name_label.text = "%s %s" % [relic.get("relic_name", "???"), star_text]
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 18)
	match new_star:
		3: name_label.add_theme_color_override("font_color", Color("FF6B6B"))
		2: name_label.add_theme_color_override("font_color", Color("74B9FF"))
		_: name_label.add_theme_color_override("font_color", Color("E67E22"))
	vbox.add_child(name_label)
	
	# 显示升星后的描述
	var desc_text := ""
	if new_star == 2:
		desc_text = relic.get("star_2_description", relic.get("description", ""))
	elif new_star == 3:
		desc_text = relic.get("star_3_description", relic.get("description", ""))
	else:
		desc_text = relic.get("description", "")
	
	var desc_label := Label.new()
	desc_label.text = desc_text
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.add_theme_font_size_override("font_size", 14)
	desc_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(desc_label)
	
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

## 构建法宝效果文本
func _build_relic_effect_text(effects: Array) -> String:
	var parts: Array[String] = []
	for effect in effects:
		var etype: String = effect.get("type", "")
		var value: int = effect.get("value", 0)
		match etype:
			"armor": parts.append("获得%d护甲" % value)
			"heal": parts.append("恢复%d生命" % value)
			"damage": parts.append("造成%d伤害" % value)
			"draw": parts.append("抽%d张牌" % value)
			"energy": parts.append("获得%d能量" % value)
			"strength": parts.append("力量+%d" % value)
			"max_hp": parts.append("最大生命+%d" % value)
			"revive": parts.append("复活并恢复%d%%生命" % value)
			_:
				if value != 0:
					parts.append("%s: %d" % [etype, value])
	return ", ".join(parts) if not parts.is_empty() else "无"
