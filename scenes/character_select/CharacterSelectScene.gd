## 角色选择场景脚本
extends Control

const CHARACTER_IDS: Array[String] = ["sun_wukong", "zhu_bajie", "sha_wujing", "tang_seng"]

var _character_cards: Array[Panel] = []
var _selected_index: int = -1

@onready var title_label: Label = $VBoxContainer/TitleLabel
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

## 创建单个角色卡片
func _create_card(char_data: Dictionary, index: int) -> Panel:
	var card := Panel.new()
	card.custom_minimum_size = Vector2(250, 350)
	
	var is_unlocked := SaveManager.is_character_unlocked(char_data.get("character_id", ""))
	
	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 8)
	
	# 角色占位图
	var portrait := ColorRect.new()
	portrait.custom_minimum_size = Vector2(200, 150)
	var char_res := CharacterData.from_dict(char_data)
	portrait.color = char_res.get_character_color() if is_unlocked else Color(0.3, 0.3, 0.3)
	vbox.add_child(portrait)
	
	# 角色名称标签
	var portrait_label := Label.new()
	portrait_label.text = char_data.get("character_name", "???")
	portrait_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	portrait_label.set_anchors_preset(Control.PRESET_CENTER)
	portrait.add_child(portrait_label)
	
	# 角色名称
	var name_label := Label.new()
	name_label.text = char_data.get("character_name", "???") if is_unlocked else "???"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 20)
	vbox.add_child(name_label)
	
	# 属性简介
	var stats_label := Label.new()
	if is_unlocked:
		stats_label.text = "HP: %d | 法力: %d" % [char_data.get("max_hp", 0), char_data.get("mana", 0)]
		if char_data.get("stamina", 0) > 0:
			stats_label.text += " | 体力: %d" % char_data.get("stamina", 0)
	else:
		var unlock_text := _get_unlock_text(char_data.get("unlock_achievement", ""))
		stats_label.text = "🔒 %s" % unlock_text
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(stats_label)
	
	# 被动技能
	var passive_label := Label.new()
	if is_unlocked:
		passive_label.text = char_data.get("passive_name", "")
	else:
		passive_label.text = ""
	passive_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	passive_label.add_theme_font_size_override("font_size", 12)
	passive_label.add_theme_color_override("font_color", Color("FDCB6E"))
	vbox.add_child(passive_label)
	
	card.add_child(vbox)
	
	# 点击事件
	if is_unlocked:
		card.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				_on_card_selected(index)
		)
		card.mouse_entered.connect(func(): _on_card_hover(index, true))
		card.mouse_exited.connect(func(): _on_card_hover(index, false))
	
	return card

## 获取解锁条件文本
func _get_unlock_text(achievement_id: String) -> String:
	match achievement_id:
		"first_play": return "完成成就：初窥门径"
		"floor_18": return "完成成就：18层地狱"
		"clear_game": return "完成成就：取得真经"
	return "未知条件"

## 角色卡片选中
func _on_card_selected(index: int) -> void:
	# 取消之前的选中
	if _selected_index >= 0 and _selected_index < _character_cards.size():
		var prev_card := _character_cards[_selected_index]
		prev_card.modulate = Color.WHITE
	
	_selected_index = index
	
	# 高亮选中卡片
	var card := _character_cards[index]
	card.modulate = Color(1.2, 1.2, 1.0)
	
	start_button.disabled = false

## 角色卡片悬停
func _on_card_hover(index: int, is_hovering: bool) -> void:
	if index == _selected_index:
		return
	var card := _character_cards[index]
	if is_hovering:
		card.modulate = Color(1.1, 1.1, 1.1)
	else:
		card.modulate = Color.WHITE

## 开始游戏
func _on_start_pressed() -> void:
	if _selected_index < 0:
		return
	
	var char_id := CHARACTER_IDS[_selected_index]
	var char_data: Dictionary = DataManager.get_character(char_id)
	var character := CharacterData.from_dict(char_data)
	character.apply_to_game()
	
	# 切换到地图场景
	SceneTransition.change_scene("res://scenes/map/MapScene.tscn")

## 返回主菜单
func _on_back_pressed() -> void:
	SceneTransition.change_scene("res://scenes/main_menu/MainMenuScene.tscn")
