## 角色选择场景脚本
extends Control

const CHARACTER_IDS: Array[String] = ["sun_wukong", "zhu_bajie", "sha_wujing", "tang_seng"]

## 选中状态缩放比例
const SELECTED_SCALE := Vector2(1.08, 1.08)
## 默认缩放比例
const DEFAULT_SCALE := Vector2(1.0, 1.0)
## 悬停缩放比例
const HOVER_SCALE := Vector2(1.04, 1.04)
## 动画时长（秒）
const ANIM_DURATION := 0.2
## 卡片尺寸
const CARD_SIZE := Vector2(236, 310)

var _character_cards: Array[Panel] = []
var _selected_index: int = -1
var _active_tweens: Dictionary = {}

@onready var cards_container: HBoxContainer = $VBoxContainer/CardsContainer
@onready var start_button: Button = $VBoxContainer/ButtonContainer/StartButton
@onready var back_button: Button = $VBoxContainer/ButtonContainer/BackButton

func _ready() -> void:
	GameManager.change_state(GameManager.GameState.CHARACTER_SELECT)
	start_button.disabled = true
	start_button.pressed.connect(_on_start_pressed)
	back_button.pressed.connect(_on_back_pressed)
	_create_character_cards()
	# 默认选择第一个角色
	if _character_cards.size() > 0:
		_on_card_selected(0)
	# Listen for dev_mode changes to refresh card unlock states
	EventBus.dev_mode_changed.connect(_on_dev_mode_changed)

func _exit_tree() -> void:
	if EventBus.dev_mode_changed.is_connected(_on_dev_mode_changed):
		EventBus.dev_mode_changed.disconnect(_on_dev_mode_changed)

## Refresh character cards when dev_mode is toggled
func _on_dev_mode_changed(_enabled: bool) -> void:
	_selected_index = -1
	start_button.disabled = true
	_create_character_cards()
	# Auto-select first unlocked character (dev_mode check is inside _on_card_selected)
	for i in range(CHARACTER_IDS.size()):
		var char_id := CHARACTER_IDS[i]
		if SaveManager.is_character_unlocked(char_id) or GameManager.dev_mode:
			_on_card_selected(i)
			break

## 创建角色卡片
func _create_character_cards() -> void:
	for child in cards_container.get_children():
		child.queue_free()
	_character_cards.clear()
	
	for i in range(CHARACTER_IDS.size()):
		var char_id := CHARACTER_IDS[i]
		var char_data: Dictionary = DataManager.get_character(char_id)
		if char_data.is_empty():
			continue
		
		var card := _create_card(char_data, i)
		cards_container.add_child(card)
		_character_cards.append(card)

## 创建卡片样式（无边框，圆角）
func _create_card_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	# 背景透明，完全依赖立绘图片
	style.bg_color = Color(0, 0, 0, 0.0) 
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.border_width_top = 0
	style.border_width_bottom = 0
	style.border_width_left = 0
	style.border_width_right = 0
	style.content_margin_top = 0
	style.content_margin_bottom = 0
	style.content_margin_left = 0
	style.content_margin_right = 0
	return style

## 创建单个角色卡片
func _create_card(char_data: Dictionary, index: int) -> Panel:
	var card := Panel.new()
	card.custom_minimum_size = CARD_SIZE
	card.clip_contents = true
	
	var char_id: String = char_data.get("character_id", "")
	var is_unlocked := SaveManager.is_character_unlocked(char_id) or GameManager.dev_mode
	
	# 设置卡片样式（无边框）
	var card_style := _create_card_style()
	card.add_theme_stylebox_override("panel", card_style)
	
	# === 角色立绘（全铺卡片背景） ===
	var portrait := TextureRect.new()
	portrait.set_anchors_preset(Control.PRESET_FULL_RECT)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	# 根据解锁状态加载不同图片
	var img_path: String
	if is_unlocked:
		img_path = "res://ui/images/character_select/%s.png" % char_id
	else:
		img_path = "res://ui/images/character_select/%s_locked.png" % char_id
	if ResourceLoader.exists(img_path):
		portrait.texture = load(img_path)
	card.add_child(portrait)
	
	# === 顶部信息区域容器（所有文字放在顶部） ===
	var info_container := VBoxContainer.new()
	info_container.set_anchors_preset(Control.PRESET_TOP_WIDE)
	info_container.offset_top = 32
	info_container.offset_bottom = 160
	info_container.offset_left = 10
	info_container.offset_right = -10
	info_container.add_theme_constant_override("separation", 3)
	info_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(info_container)
	
	# 角色名称（大字标题）
	var name_label := Label.new()
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 24)
	name_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.85))
	name_label.add_theme_constant_override("outline_size", 3)
	name_label.add_theme_color_override("font_outline_color", Color(0.15, 0.1, 0.05, 0.9))
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if is_unlocked:
		name_label.text = char_data.get("character_name")
	else:
		name_label.text = "???"
	info_container.add_child(name_label)
	
	# 属性简介
	if is_unlocked:
		# 使用图标+数值的水平布局
		var stats_hbox := HBoxContainer.new()
		stats_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
		stats_hbox.add_theme_constant_override("separation", 2)
		stats_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		
		# 生命值：图标+数值
		var heart_icon := TextureRect.new()
		var heart_path := "res://ui/images/global/heart.png"
		if ResourceLoader.exists(heart_path):
			heart_icon.texture = load(heart_path)
		heart_icon.custom_minimum_size = Vector2(16, 16)
		heart_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		heart_icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		heart_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stats_hbox.add_child(heart_icon)
		
		var hp_label := Label.new()
		hp_label.text = "%d" % char_data.get("max_hp", 0)
		hp_label.add_theme_font_size_override("font_size", 14)
		hp_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.85))
		hp_label.add_theme_constant_override("outline_size", 2)
		hp_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.7))
		hp_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stats_hbox.add_child(hp_label)
		
		# 分隔符
		var sep1 := Label.new()
		sep1.text = " | "
		sep1.add_theme_font_size_override("font_size", 14)
		sep1.add_theme_color_override("font_color", Color(1.0, 0.95, 0.85))
		sep1.add_theme_constant_override("outline_size", 2)
		sep1.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.7))
		sep1.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stats_hbox.add_child(sep1)
		
		# 法力：图标+数值
		var power_icon := TextureRect.new()
		var power_path := "res://ui/images/global/power.png"
		if ResourceLoader.exists(power_path):
			power_icon.texture = load(power_path)
		power_icon.custom_minimum_size = Vector2(16, 16)
		power_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		power_icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		power_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stats_hbox.add_child(power_icon)
		
		var mana_label := Label.new()
		mana_label.text = "%d" % char_data.get("mana", 0)
		mana_label.add_theme_font_size_override("font_size", 14)
		mana_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.85))
		mana_label.add_theme_constant_override("outline_size", 2)
		mana_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.7))
		mana_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stats_hbox.add_child(mana_label)
		
		# 体力（仅当有体力值时显示）
		if char_data.get("stamina", 0) > 0:
			var sep2 := Label.new()
			sep2.text = " | "
			sep2.add_theme_font_size_override("font_size", 14)
			sep2.add_theme_color_override("font_color", Color(1.0, 0.95, 0.85))
			sep2.add_theme_constant_override("outline_size", 2)
			sep2.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.7))
			sep2.mouse_filter = Control.MOUSE_FILTER_IGNORE
			stats_hbox.add_child(sep2)
			
			var strength_icon := TextureRect.new()
			var strength_path := "res://ui/images/global/strength.png"
			if ResourceLoader.exists(strength_path):
				strength_icon.texture = load(strength_path)
			strength_icon.custom_minimum_size = Vector2(16, 16)
			strength_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			strength_icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
			strength_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			stats_hbox.add_child(strength_icon)
			
			var stamina_label := Label.new()
			stamina_label.text = "%d" % char_data.get("stamina", 0)
			stamina_label.add_theme_font_size_override("font_size", 14)
			stamina_label.add_theme_color_override("font_color", Color(0.9, 0.88, 0.82))
			stamina_label.add_theme_constant_override("outline_size", 2)
			stamina_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.7))
			stamina_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			stats_hbox.add_child(stamina_label)
		
		info_container.add_child(stats_hbox)
	else:
		# 未解锁角色：图标+成就名 换行显示成就描述
		var achievement_id: String = char_data.get("unlock_achievement", "")
		var unlock_info := _get_unlock_info(achievement_id)
		
		# 图标+成就名 水平排列
		var lock_hbox := HBoxContainer.new()
		lock_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
		lock_hbox.add_theme_constant_override("separation", 4)
		lock_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		
		# 锁图标
		var lock_icon := TextureRect.new()
		var lock_icon_path := "res://ui/images/character_select/locked.png"
		if ResourceLoader.exists(lock_icon_path):
			lock_icon.texture = load(lock_icon_path)
		lock_icon.custom_minimum_size = Vector2(16, 16)
		lock_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		lock_icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		lock_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lock_hbox.add_child(lock_icon)
		
		# 成就名称
		var lock_name_label := Label.new()
		lock_name_label.text = unlock_info.get("name", "???")
		lock_name_label.add_theme_font_size_override("font_size", 16)
		lock_name_label.add_theme_color_override("font_color", Color(0.9, 0.88, 0.82))
		lock_name_label.add_theme_constant_override("outline_size", 2)
		lock_name_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.7))
		lock_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lock_hbox.add_child(lock_name_label)
		
		info_container.add_child(lock_hbox)
		
		# 成就描述（换行显示）
		var lock_desc_label := Label.new()
		lock_desc_label.text = unlock_info.get("description", "")
		lock_desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lock_desc_label.add_theme_font_size_override("font_size", 14)
		lock_desc_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.85))
		lock_desc_label.add_theme_constant_override("outline_size", 2)
		lock_desc_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.7))
		lock_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		lock_desc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		info_container.add_child(lock_desc_label)
	
	# Starter relic name
	var relic_label := Label.new()
	relic_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	relic_label.add_theme_font_size_override("font_size", 16)
	relic_label.add_theme_constant_override("outline_size", 2)
	relic_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.7))
	relic_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if is_unlocked:
		var starter_relic_id: String = char_data.get("starter_relic", "")
		var relic_data: Dictionary = DataManager.get_relic(starter_relic_id) if starter_relic_id != "" else {}
		relic_label.text = relic_data.get("relic_name", "")
		relic_label.add_theme_color_override("font_color", Color(0.99, 0.8, 0.43))
	else:
		relic_label.text = ""
		relic_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	info_container.add_child(relic_label)
	
	# Starter relic description
	var relic_desc_label := Label.new()
	relic_desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	relic_desc_label.add_theme_font_size_override("font_size", 14)
	relic_desc_label.add_theme_constant_override("outline_size", 2)
	relic_desc_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.7))
	relic_desc_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.85))
	relic_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	relic_desc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if is_unlocked:
		var starter_relic_id2: String = char_data.get("starter_relic", "")
		var relic_data2: Dictionary = DataManager.get_relic(starter_relic_id2) if starter_relic_id2 != "" else {}
		relic_desc_label.text = RelicTooltip.get_enhanced_description(relic_data2)
	else:
		relic_desc_label.text = ""
	info_container.add_child(relic_desc_label)
	
	# 设置pivot_offset为卡片中心，使缩放从中心进行
	card.pivot_offset = CARD_SIZE / 2.0
	
	# 点击事件
	if is_unlocked:
		card.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				_on_card_selected(index)
		)
		card.mouse_entered.connect(func(): _on_card_hover(index, true))
		card.mouse_exited.connect(func(): _on_card_hover(index, false))
	else:
		card.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				_show_locked_tip(card)
		)
	
	return card

## 显示未解锁提示
func _show_locked_tip(card: Panel) -> void:
	# 避免重复创建提示
	for child in card.get_children():
		if child.name == "LockedTip":
			return
	
	var tip := Label.new()
	tip.name = "LockedTip"
	tip.text = "暂未解锁"
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tip.add_theme_font_size_override("font_size", 18)
	tip.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	tip.add_theme_constant_override("outline_size", 3)
	tip.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
	tip.set_anchors_preset(Control.PRESET_CENTER)
	tip.grow_horizontal = Control.GROW_DIRECTION_BOTH
	tip.grow_vertical = Control.GROW_DIRECTION_BOTH
	tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(tip)
	
	# 淡入淡出动画：出现 → 停留 → 上浮消失
	tip.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(tip, "modulate:a", 1.0, 0.15)
	tween.tween_interval(0.6)
	tween.parallel().tween_property(tip, "position:y", tip.position.y - 30, 0.4)
	tween.tween_property(tip, "modulate:a", 0.0, 0.3)
	tween.tween_callback(tip.queue_free)

## 获取解锁条件信息（返回成就名称和描述）
func _get_unlock_info(achievement_id: String) -> Dictionary:
	# 从 AchievementManager 的成就定义中获取
	if AchievementManager.ACHIEVEMENTS.has(achievement_id):
		var ach_data: Dictionary = AchievementManager.ACHIEVEMENTS[achievement_id]
		return {
			"name": ach_data.get("name", "???"),
			"description": ach_data.get("description", ""),
		}
	return {"name": "???", "description": ""}

## 对卡片执行缩放动画
func _animate_card_scale(card: Panel, target_scale: Vector2) -> void:
	var card_id := card.get_instance_id()
	# 如果该卡片有正在进行的动画，先停止
	if _active_tweens.has(card_id) and _active_tweens[card_id] != null:
		_active_tweens[card_id].kill()
	var tween := create_tween()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(card, "scale", target_scale, ANIM_DURATION)
	_active_tweens[card_id] = tween

## 角色卡片选中
func _on_card_selected(index: int) -> void:
	# Check if the character is actually unlocked
	var char_id := CHARACTER_IDS[index]
	var is_unlocked := SaveManager.is_character_unlocked(char_id) or GameManager.dev_mode
	if not is_unlocked:
		_show_locked_tip(_character_cards[index])
		return
	
	# 取消之前的选中 —— 缩小回默认大小
	if _selected_index >= 0 and _selected_index < _character_cards.size():
		var prev_card := _character_cards[_selected_index]
		_animate_card_scale(prev_card, DEFAULT_SCALE)
	
	_selected_index = index
	
	# 高亮选中卡片 —— 放大
	var card := _character_cards[index]
	_animate_card_scale(card, SELECTED_SCALE)
	
	start_button.disabled = false

## 角色卡片悬停
func _on_card_hover(index: int, is_hovering: bool) -> void:
	if index == _selected_index:
		return
	var card := _character_cards[index]
	if is_hovering:
		_animate_card_scale(card, HOVER_SCALE)
	else:
		_animate_card_scale(card, DEFAULT_SCALE)

## 开始游戏
func _on_start_pressed() -> void:
	if _selected_index < 0:
		return
	
	var char_id := CHARACTER_IDS[_selected_index]
	
	# Check if character is actually unlocked (dev_mode may have been toggled off)
	var is_unlocked := SaveManager.is_character_unlocked(char_id) or GameManager.dev_mode
	if not is_unlocked:
		_show_locked_tip(_character_cards[_selected_index])
		start_button.disabled = true
		_selected_index = -1
		return
	
	var char_data: Dictionary = DataManager.get_character(char_id)
	var character := CharacterData.from_dict(char_data)
	character.apply_to_game()
	
	# 切换到地图场景
	SceneTransition.change_scene("res://scenes/map/MapScene.tscn")

## 返回主菜单
func _on_back_pressed() -> void:
	SceneTransition.change_scene("res://scenes/main_menu/MainMenuScene.tscn")
