## 战斗奖励场景脚本
extends Control

@onready var title_label: Label = $CenterContainer/VBox/TitleLabel
@onready var gold_reward_label: Label = $CenterContainer/VBox/GoldRewardLabel
@onready var card_choices_container: HBoxContainer = $CenterContainer/VBox/CardChoicesContainer
@onready var relic_reward_container: HBoxContainer = $CenterContainer/VBox/RelicRewardContainer
@onready var skip_button: Button = $CenterContainer/VBox/SkipButton
@onready var continue_button: Button = $CenterContainer/VBox/ContinueButton

var gold_reward: int = 0
var card_choices: Array = []
var relic_reward: Dictionary = {}
var has_chosen_card: bool = false

func _ready() -> void:
	GameManager.change_state(GameManager.GameState.REWARD)
	
	skip_button.pressed.connect(_on_skip_pressed)
	continue_button.pressed.connect(_on_continue_pressed)
	continue_button.visible = false
	
	_generate_rewards()
	_display_rewards()

## 生成奖励
func _generate_rewards() -> void:
	var battle_type: String = GameManager.current_battle_type
	
	match battle_type:
		"normal":
			gold_reward = randi_range(15, 30)
			_generate_card_choices(3, "common")
		"elite":
			gold_reward = randi_range(30, 50)
			_generate_card_choices(3, "uncommon")
			_generate_relic_reward()
		"boss":
			gold_reward = randi_range(50, 80)
			_generate_card_choices(3, "rare")
			_generate_relic_reward()
		"tribulation":
			gold_reward = randi_range(80, 120)
			_generate_card_choices(3, "rare")
			_generate_relic_reward()
	
	# 天劫系统：根据天劫等级调整金币奖励加成
	var karma_level := GameManager.get_tribulation_level()
	var gold_bonus := 0.0
	match karma_level:
		"微劫": gold_bonus = 0.20
		"小劫": gold_bonus = 0.50
		"大劫": gold_bonus = 1.00
		"天罚": gold_bonus = 2.00
	if gold_bonus > 0.0:
		var bonus_gold := int(gold_reward * gold_bonus)
		gold_reward += bonus_gold
	
	# 发放金币
	GameManager.modify_gold(gold_reward)

## 生成卡牌选择
func _generate_card_choices(count: int, min_rarity: String) -> void:
	var all_cards := DataManager.get_all_cards()
	var current_char_id: String = GameManager.current_character_id
	
	# 按稀有度筛选，并排除其他角色的专属牌
	var rarity_order := ["common", "uncommon", "rare", "legendary"]
	var min_idx := rarity_order.find(min_rarity)
	if min_idx < 0:
		min_idx = 0
	
	var eligible_cards: Array = []
	for card in all_cards:
		var card_rarity: String = card.get("rarity", "common")
		var rarity_idx := rarity_order.find(card_rarity)
		var exclusive: String = card.get("character_exclusive", "all")
		# 只保留通用牌和当前角色专属牌
		if exclusive != "all" and exclusive != current_char_id:
			continue
		if rarity_idx >= min_idx:
			eligible_cards.append(card)
	
	# 如果筛选后不够，放宽稀有度限制但仍然过滤专属
	if eligible_cards.size() < count:
		eligible_cards.clear()
		for card in all_cards:
			var exclusive: String = card.get("character_exclusive", "all")
			if exclusive == "all" or exclusive == current_char_id:
				eligible_cards.append(card)
	
	eligible_cards.shuffle()
	card_choices = eligible_cards.slice(0, mini(count, eligible_cards.size()))

## 生成法宝奖励
func _generate_relic_reward() -> void:
	var all_relics := DataManager.get_all_relics()
	# 排除已拥有的
	var available: Array = []
	for relic in all_relics:
		var relic_id: String = relic.get("relic_id", "")
		if not GameManager.has_relic(relic_id):
			available.append(relic)
	
	if not available.is_empty():
		available.shuffle()
		relic_reward = available[0]

## 显示奖励
func _display_rewards() -> void:
	title_label.text = "🎉 战斗胜利！"
	gold_reward_label.text = "获得 %d 金币" % gold_reward
	
	# 显示卡牌选择
	for card_data in card_choices:
		var card_button := _create_card_choice_button(card_data)
		card_choices_container.add_child(card_button)
	
	# 显示法宝奖励
	if not relic_reward.is_empty():
		var relic_button := _create_relic_reward_button(relic_reward)
		relic_reward_container.add_child(relic_button)

## 创建卡牌选择按钮
func _create_card_choice_button(card_data: Dictionary) -> Control:
	var container := Control.new()
	container.custom_minimum_size = Vector2(180, 200)
	
	# 卡牌背景
	var bg := ColorRect.new()
	bg.position = Vector2.ZERO
	bg.size = Vector2(180, 200)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	
	var rarity: String = card_data.get("rarity", "common")
	var base_color: Color
	match rarity:
		"common": base_color = Color(0.3, 0.3, 0.3)
		"uncommon": base_color = Color(0.0, 0.45, 0.36)
		"rare": base_color = Color(0.04, 0.33, 0.56)
		"legendary": base_color = Color(0.5, 0.4, 0.1)
		_: base_color = Color(0.3, 0.3, 0.3)
	bg.color = base_color
	container.add_child(bg)
	
	# 卡牌名称
	var name_label := Label.new()
	name_label.text = card_data.get("card_name", "???")
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", Color("FDCB6E"))
	name_label.position = Vector2(5, 10)
	name_label.size = Vector2(170, 25)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.add_child(name_label)
	
	# 费用
	var cost_label := Label.new()
	cost_label.text = "费用: %d" % card_data.get("energy_cost", 1)
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost_label.add_theme_font_size_override("font_size", 13)
	cost_label.position = Vector2(5, 40)
	cost_label.size = Vector2(170, 20)
	cost_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.add_child(cost_label)
	
	# 类型
	var type_name := ""
	match card_data.get("card_type", ""):
		"attack": type_name = "攻击"
		"skill": type_name = "技能"
		"ultimate": type_name = "终结技"
	var type_label := Label.new()
	type_label.text = "[%s]" % type_name
	type_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	type_label.add_theme_font_size_override("font_size", 12)
	type_label.position = Vector2(5, 60)
	type_label.size = Vector2(170, 20)
	type_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.add_child(type_label)
	
	# 描述
	var desc_label := Label.new()
	desc_label.text = card_data.get("description", "")
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc_label.add_theme_font_size_override("font_size", 11)
	desc_label.position = Vector2(5, 85)
	desc_label.size = Vector2(170, 110)
	desc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.add_child(desc_label)
	
	# hover高亮效果
	bg.mouse_entered.connect(func():
		if not has_chosen_card:
			container.modulate = Color(1.2, 1.2, 1.2, 1.0)
			bg.color = base_color.lightened(0.2)
	)
	bg.mouse_exited.connect(func():
		if not has_chosen_card:
			container.modulate = Color.WHITE
			bg.color = base_color
	)
	
	# 点击卡片直接选择
	bg.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if not has_chosen_card:
				has_chosen_card = true
				var card_id: String = card_data.get("card_id", "")
				GameManager.current_deck.append({"card_id": card_id, "star_level": 1})
				GameManager.stats.cards_obtained += 1
				
				# 高亮选中的，暗化其他
				for child in card_choices_container.get_children():
					if child == container:
						bg.color = Color("FDCB6E").darkened(0.3)
						container.modulate = Color.WHITE
					else:
						child.modulate = Color(0.5, 0.5, 0.5)
				
				skip_button.visible = false
				continue_button.visible = true
	)
	
	return container

## 创建法宝奖励按钮
func _create_relic_reward_button(relic_data: Dictionary) -> VBoxContainer:
	var container := VBoxContainer.new()
	container.custom_minimum_size = Vector2(200, 100)
	
	var bg := ColorRect.new()
	bg.custom_minimum_size = Vector2(200, 60)
	bg.color = Color(0.3, 0.25, 0.1)
	container.add_child(bg)
	
	var name_label := Label.new()
	name_label.text = "🏺 " + relic_data.get("relic_name", "???")
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", Color("FDCB6E"))
	name_label.position = Vector2(5, 5)
	name_label.size = Vector2(190, 25)
	bg.add_child(name_label)
	
	var desc_label := Label.new()
	desc_label.text = relic_data.get("effect_description", "")
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.add_theme_font_size_override("font_size", 11)
	desc_label.position = Vector2(5, 30)
	desc_label.size = Vector2(190, 25)
	bg.add_child(desc_label)
	
	var take_button := Button.new()
	take_button.text = "获取法宝"
	take_button.custom_minimum_size = Vector2(200, 35)
	container.add_child(take_button)
	
	take_button.pressed.connect(func():
		var relic_id: String = relic_data.get("relic_id", "")
		GameManager.add_relic(relic_id)
		take_button.disabled = true
		take_button.text = "已获取"
	)
	
	return container

## 跳过卡牌选择
func _on_skip_pressed() -> void:
	# 天劫系统：跳过奖励减少1点劫数
	GameManager.modify_karma(-1)
	has_chosen_card = true
	skip_button.visible = false
	continue_button.visible = true

## 继续
func _on_continue_pressed() -> void:
	# 检查是否BOSS战胜利
	if GameManager.current_battle_type == "boss":
		# 进入下一章节
		GameManager.current_chapter += 1
		GameManager.current_map_data = {}
		
		if GameManager.current_chapter >= 4:
			# 通关！
			SceneTransition.change_scene("res://scenes/game_over/GameOverScene.tscn")
			return
	
	SceneTransition.change_scene("res://scenes/map/MapScene.tscn")
