## 卡组查看场景脚本
extends Control

@onready var card_grid: GridContainer = $ScrollContainer/CardGrid
@onready var sort_type_button: Button = $TopBar/SortTypeButton
@onready var sort_rarity_button: Button = $TopBar/SortRarityButton
@onready var sort_cost_button: Button = $TopBar/SortCostButton
@onready var count_label: Label = $TopBar/CountLabel
@onready var close_button: Button = $TopBar/CloseButton

var current_sort: String = "type"

func _ready() -> void:
	sort_type_button.pressed.connect(func(): _sort_and_display("type"))
	sort_rarity_button.pressed.connect(func(): _sort_and_display("rarity"))
	sort_cost_button.pressed.connect(func(): _sort_and_display("cost"))
	close_button.pressed.connect(_on_close_pressed)
	
	_sort_and_display("type")

## 排序并显示卡组
func _sort_and_display(sort_by: String) -> void:
	current_sort = sort_by
	
	# 清除旧内容
	for child in card_grid.get_children():
		child.queue_free()
	
	# 获取卡组数据
	var deck_cards: Array = []
	for entry in GameManager.current_deck:
		var card_id: String = entry.get("card_id", "") if entry is Dictionary else str(entry)
		var star_level: int = entry.get("star_level", 1) if entry is Dictionary else 1
		var card_data := DataManager.get_card(card_id)
		if not card_data.is_empty():
			var display_data: Dictionary = card_data.duplicate(true)
			display_data["star_level"] = star_level
			deck_cards.append(display_data)
	
	# 排序
	match sort_by:
		"type":
			deck_cards.sort_custom(func(a, b): return a.get("card_type", "") < b.get("card_type", ""))
		"rarity":
			var rarity_order := {"common": 0, "uncommon": 1, "rare": 2, "legendary": 3}
			deck_cards.sort_custom(func(a, b):
				return rarity_order.get(a.get("rarity", ""), 0) > rarity_order.get(b.get("rarity", ""), 0)
			)
		"cost":
			deck_cards.sort_custom(func(a, b): return a.get("energy_cost", 0) < b.get("energy_cost", 0))
	
	# 显示
	for card_data in deck_cards:
		var card_item := _create_card_display(card_data)
		card_grid.add_child(card_item)
	
	count_label.text = "卡组: %d张" % deck_cards.size()

## 创建卡牌显示
func _create_card_display(card_data: Dictionary) -> Control:
	var container := VBoxContainer.new()
	container.custom_minimum_size = Vector2(140, 100)
	
	var bg := ColorRect.new()
	bg.custom_minimum_size = Vector2(140, 80)
	
	var rarity: String = card_data.get("rarity", "common")
	match rarity:
		"common": bg.color = Color(0.25, 0.25, 0.25)
		"uncommon": bg.color = Color(0.0, 0.36, 0.29)
		"rare": bg.color = Color(0.04, 0.26, 0.45)
		"legendary": bg.color = Color(0.4, 0.32, 0.08)
	container.add_child(bg)
	
	var name_label := Label.new()
	var card_name: String = card_data.get("card_name", "???")
	var star_level: int = card_data.get("star_level", 1)
	var card_type: String = card_data.get("card_type", "")
	if card_data.get("is_upgraded", false):
		card_name += "·极"
	# 显示星级标识
	var star_text := ""
	match star_level:
		1: star_text = "★☆☆"
		2: star_text = "★★☆"
		3: star_text = "★★★"
	# 妖灵卡标识
	if card_type == "spirit":
		card_name = "🐾 " + card_name
	name_label.text = "%s %s" % [card_name, star_text]
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 13)
	# 根据星级设置名称颜色
	match star_level:
		3: name_label.add_theme_color_override("font_color", Color("FF6B6B"))
		2: name_label.add_theme_color_override("font_color", Color("74B9FF"))
		_: name_label.add_theme_color_override("font_color", Color("FDCB6E"))
	name_label.position = Vector2(5, 5)
	name_label.size = Vector2(130, 20)
	bg.add_child(name_label)
	
	var cost_label := Label.new()
	cost_label.text = "费用: %d" % card_data.get("energy_cost", 1)
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost_label.add_theme_font_size_override("font_size", 11)
	cost_label.position = Vector2(5, 28)
	cost_label.size = Vector2(130, 18)
	bg.add_child(cost_label)
	
	var desc_label := Label.new()
	desc_label.text = card_data.get("description", "")
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc_label.add_theme_font_size_override("font_size", 10)
	desc_label.position = Vector2(5, 48)
	desc_label.size = Vector2(130, 30)
	bg.add_child(desc_label)
	
	return container

## 关闭（仅关闭卡组查看界面，返回之前的场景）
func _on_close_pressed() -> void:
	# 根据之前的游戏状态返回对应场景
	var prev_state := GameManager.previous_state
	match prev_state:
		GameManager.GameState.BATTLE:
			SceneTransition.change_scene("res://scenes/battle/BattleScene.tscn")
		GameManager.GameState.SHOP:
			SceneTransition.change_scene("res://scenes/shop/ShopScene.tscn")
		GameManager.GameState.EVENT:
			SceneTransition.change_scene("res://scenes/event/EventScene.tscn")
		_:
			SceneTransition.change_scene("res://scenes/map/MapScene.tscn")
