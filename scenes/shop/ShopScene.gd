## 商店场景脚本
extends Control

var shop_cards: Array = []
var shop_relics: Array = []
var shop_consumables: Array = []

## 是否为神秘商人（商品有概率出现2星/3星）
var is_mystery_merchant: bool = false

@onready var card_container: HBoxContainer = $ScrollContainer/VBox/CardSection/CardContainer
@onready var relic_container: HBoxContainer = $ScrollContainer/VBox/RelicSection/RelicContainer
@onready var consumable_container: HBoxContainer = $ScrollContainer/VBox/ConsumableSection/ConsumableContainer
@onready var leave_button: Button = $LeaveButton

func _ready() -> void:
	GameManager.change_state(GameManager.GameState.SHOP)
	leave_button.pressed.connect(_on_leave_pressed)
	
	# 检测是否为神秘商人（通过GameManager当前地图节点类型判断）
	is_mystery_merchant = _check_is_mystery_merchant()
	_generate_shop_items()

## 检测是否为神秘商人
func _check_is_mystery_merchant() -> bool:
	var map_data: Dictionary = GameManager.current_map_data
	var node_index: int = GameManager.current_node_index
	var nodes: Array = map_data.get("nodes", [])
	for node_data in nodes:
		if not node_data is Dictionary:
			continue
		if node_data.get("id", -1) == node_index:
			# MapGenerator.NodeType.MYSTERY == 4
			return node_data.get("node_type", -1) == 4
	return false

## 为神秘商人随机生成星级（概率：1星60%，2星30%，3星10%）
func _roll_mystery_star_level() -> int:
	if not is_mystery_merchant:
		return 1
	var roll := randf()
	if roll < 0.10:
		return 3
	elif roll < 0.40:
		return 2
	return 1

## 生成商店物品
func _generate_shop_items() -> void:
	if is_mystery_merchant:
		print("[商店] 神秘商人 - 商品有概率出现高星级")
	
	# 生成3-5张卡牌（过滤其他角色专属牌）
	var all_cards := DataManager.get_all_cards()
	var current_char_id: String = GameManager.current_character_id
	var eligible_cards: Array = []
	for card in all_cards:
		var exclusive: String = card.get("character_exclusive", "all")
		if exclusive == "all" or exclusive == current_char_id:
			eligible_cards.append(card)
	eligible_cards.shuffle()
	var card_count := randi_range(3, 5)
	for i in range(mini(card_count, eligible_cards.size())):
		var card_data: Dictionary = eligible_cards[i]
		var star_level := _roll_mystery_star_level()
		var price := _get_card_price(card_data)
		# 高星级卡牌价格上浮
		if star_level == 2:
			price = int(price * 1.5)
		elif star_level == 3:
			price = int(price * 2.5)
		_add_shop_card(card_data, price, star_level)
	
	# 生成1-2个法宝
	var all_relics := DataManager.get_all_relics()
	all_relics.shuffle()
	var relic_count := randi_range(1, 2)
	for i in range(mini(relic_count, all_relics.size())):
		var relic_data: Dictionary = all_relics[i]
		var star_level := _roll_mystery_star_level()
		var price := _get_relic_price(relic_data)
		if star_level == 2:
			price = int(price * 1.5)
		elif star_level == 3:
			price = int(price * 2.5)
		_add_shop_relic(relic_data, price, star_level)
	
	# 生成2-3个消耗品
	var all_consumables := DataManager.get_all_consumables()
	all_consumables.shuffle()
	var consumable_count := randi_range(2, 3)
	for i in range(mini(consumable_count, all_consumables.size())):
		var consumable_data: Dictionary = all_consumables[i]
		var price := _get_consumable_price(consumable_data)
		_add_shop_consumable(consumable_data, price)

## 获取卡牌价格
func _get_card_price(card_data: Dictionary) -> int:
	var rarity: String = card_data.get("rarity", "common")
	match rarity:
		"common": return randi_range(30, 50)
		"uncommon": return randi_range(50, 80)
		"rare": return randi_range(80, 120)
		"legendary": return randi_range(120, 180)
	return 50

## 获取法宝价格
func _get_relic_price(relic_data: Dictionary) -> int:
	var rarity: String = relic_data.get("rarity", "common")
	match rarity:
		"common": return randi_range(80, 120)
		"uncommon": return randi_range(120, 180)
		"rare": return randi_range(180, 250)
		"legendary": return randi_range(250, 350)
	return 150

## 获取消耗品价格
func _get_consumable_price(_data: Dictionary) -> int:
	return randi_range(20, 50)

## 添加商店卡牌
func _add_shop_card(card_data: Dictionary, price: int, star_level: int = 1) -> void:
	var item := _create_shop_card_item(card_data, price, star_level)
	card_container.add_child(item)
	
	var buy_btn: Button = item.get_node("BuyButton")
	buy_btn.pressed.connect(func():
		if GameManager.current_gold >= price:
			GameManager.modify_gold(-price)
			GameManager.current_deck.append({"card_id": card_data.get("card_id", ""), "star_level": star_level})
			GameManager.modify_karma(1)  # 天劫系统：购买卡牌增加1点劫数
			item.queue_free()
		else:
			_shake_item(item)
	)

## 添加商店法宝
func _add_shop_relic(relic_data: Dictionary, price: int, star_level: int = 1) -> void:
	var star_text := ""
	match star_level:
		1: star_text = "★☆☆"
		2: star_text = "★★☆"
		3: star_text = "★★★"
	var display_name := "%s %s" % [relic_data.get("relic_name", "???"), star_text]
	var item := _create_shop_detail_item(display_name, price, "法宝", relic_data.get("description", ""))
	relic_container.add_child(item)
	
	var buy_btn: Button = item.get_node("BuyButton")
	buy_btn.pressed.connect(func():
		if GameManager.current_gold >= price:
			GameManager.modify_gold(-price)
			GameManager.add_relic(relic_data.get("relic_id", ""), star_level)
			GameManager.modify_karma(1)  # 天劫系统：购买法宝增加1点劫数
			# 通知GlobalHUD刷新法宝显示
			EventBus.relic_acquired.emit(null)
			item.queue_free()
		else:
			_shake_item(item)
	)

## 添加商店消耗品
func _add_shop_consumable(consumable_data: Dictionary, price: int) -> void:
	var item := _create_shop_detail_item(consumable_data.get("consumable_name", "???"), price, "消耗品", consumable_data.get("description", ""))
	consumable_container.add_child(item)
	
	var buy_btn: Button = item.get_node("BuyButton")
	buy_btn.pressed.connect(func():
		if GameManager.current_gold >= price:
			GameManager.modify_gold(-price)
			# 使用add_consumable方法（带上限校验和信号通知）
			if not GameManager.add_consumable(consumable_data.get("consumable_id", "")):
				# 丹药已满，退还金币
				GameManager.modify_gold(price)
				return
			item.queue_free()
		else:
			_shake_item(item)
	)

## 创建商店卡牌物品UI（显示具体效果）
func _create_shop_card_item(card_data: Dictionary, price: int, star_level: int = 1) -> VBoxContainer:
	var container := VBoxContainer.new()
	container.custom_minimum_size = Vector2(170, 180)
	
	var bg := ColorRect.new()
	bg.custom_minimum_size = Vector2(170, 145)
	
	var rarity: String = card_data.get("rarity", "common")
	match rarity:
		"common": bg.color = Color(0.22, 0.22, 0.25, 1)
		"uncommon": bg.color = Color(0.0, 0.3, 0.24, 1)
		"rare": bg.color = Color(0.04, 0.2, 0.4, 1)
		"legendary": bg.color = Color(0.35, 0.28, 0.05, 1)
		_: bg.color = Color(0.22, 0.22, 0.25, 1)
	container.add_child(bg)
	
	# 卡牌名称
	var name_label := Label.new()
	name_label.text = card_data.get("card_name", "???")
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.add_theme_color_override("font_color", Color("FDCB6E"))
	name_label.position = Vector2(5, 5)
	name_label.size = Vector2(160, 22)
	bg.add_child(name_label)
	
	# 类型和费用
	var card_type: String = card_data.get("card_type", "attack")
	var type_name := ""
	match card_type:
		"attack": type_name = "攻击"
		"skill": type_name = "技能"
		"ultimate": type_name = "终结技"
	var info_label := Label.new()
	info_label.text = "[%s] 费用:%d" % [type_name, card_data.get("energy_cost", 1)]
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_label.add_theme_font_size_override("font_size", 11)
	info_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	info_label.position = Vector2(5, 28)
	info_label.size = Vector2(160, 18)
	bg.add_child(info_label)
	
	# 描述/效果
	var desc_label := Label.new()
	desc_label.text = card_data.get("description", "")
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc_label.add_theme_font_size_override("font_size", 10)
	desc_label.position = Vector2(5, 48)
	desc_label.size = Vector2(160, 55)
	bg.add_child(desc_label)
	
	# 稀有度和星级
	var rarity_label := Label.new()
	var rarity_text := ""
	match rarity:
		"common": rarity_text = "普通"
		"uncommon": rarity_text = "稀有"
		"rare": rarity_text = "史诗"
		"legendary": rarity_text = "传说"
	var star_text := ""
	match star_level:
		1: star_text = "★☆☆"
		2: star_text = "★★☆"
		3: star_text = "★★★"
	rarity_label.text = "%s %s" % [rarity_text, star_text]
	rarity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rarity_label.add_theme_font_size_override("font_size", 11)
	rarity_label.position = Vector2(5, 105)
	rarity_label.size = Vector2(160, 18)
	bg.add_child(rarity_label)
	
	# 价格
	var price_label := Label.new()
	price_label.text = "%d 金币" % price
	price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	price_label.add_theme_font_size_override("font_size", 13)
	price_label.add_theme_color_override("font_color", Color("FDCB6E"))
	price_label.position = Vector2(5, 124)
	price_label.size = Vector2(160, 20)
	bg.add_child(price_label)
	
	var buy_button := Button.new()
	buy_button.name = "BuyButton"
	buy_button.text = "购买"
	buy_button.custom_minimum_size = Vector2(170, 30)
	container.add_child(buy_button)
	
	return container

## 创建商店物品UI（法宝/消耗品）
func _create_shop_detail_item(item_name: String, price: int, item_type: String, description: String) -> VBoxContainer:
	var container := VBoxContainer.new()
	container.custom_minimum_size = Vector2(150, 150)
	
	var bg := ColorRect.new()
	bg.custom_minimum_size = Vector2(150, 115)
	bg.color = Color(0.2, 0.2, 0.2, 1)
	container.add_child(bg)
	
	var name_label := Label.new()
	name_label.text = item_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.add_theme_color_override("font_color", Color("FDCB6E"))
	bg.add_child(name_label)
	name_label.position = Vector2(5, 5)
	name_label.size = Vector2(140, 22)
	
	var type_label := Label.new()
	type_label.text = "[%s]" % item_type
	type_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	type_label.add_theme_font_size_override("font_size", 11)
	type_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	bg.add_child(type_label)
	type_label.position = Vector2(5, 28)
	type_label.size = Vector2(140, 18)
	
	# 效果描述
	var desc_label := Label.new()
	desc_label.text = description
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc_label.add_theme_font_size_override("font_size", 10)
	bg.add_child(desc_label)
	desc_label.position = Vector2(5, 48)
	desc_label.size = Vector2(140, 40)
	
	var price_label := Label.new()
	price_label.text = "%d 金币" % price
	price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	price_label.add_theme_font_size_override("font_size", 13)
	price_label.add_theme_color_override("font_color", Color("FDCB6E"))
	bg.add_child(price_label)
	price_label.position = Vector2(5, 90)
	price_label.size = Vector2(140, 20)
	
	var buy_button := Button.new()
	buy_button.name = "BuyButton"
	buy_button.text = "购买"
	buy_button.custom_minimum_size = Vector2(150, 30)
	container.add_child(buy_button)
	
	return container

## 创建商店物品UI（通用旧版）
func _create_shop_item(item_name: String, price: int, item_type: String) -> VBoxContainer:
	var container := VBoxContainer.new()
	container.custom_minimum_size = Vector2(150, 120)
	
	var bg := ColorRect.new()
	bg.custom_minimum_size = Vector2(150, 80)
	bg.color = Color(0.2, 0.2, 0.2, 1)
	container.add_child(bg)
	
	var name_label := Label.new()
	name_label.text = item_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 14)
	bg.add_child(name_label)
	name_label.position = Vector2(5, 10)
	name_label.size = Vector2(140, 25)
	
	var type_label := Label.new()
	type_label.text = "[%s]" % item_type
	type_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	type_label.add_theme_font_size_override("font_size", 11)
	type_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	bg.add_child(type_label)
	type_label.position = Vector2(5, 35)
	type_label.size = Vector2(140, 20)
	
	var price_label := Label.new()
	price_label.text = "%d 金币" % price
	price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	price_label.add_theme_font_size_override("font_size", 13)
	price_label.add_theme_color_override("font_color", Color("FDCB6E"))
	bg.add_child(price_label)
	price_label.position = Vector2(5, 55)
	price_label.size = Vector2(140, 20)
	
	var buy_button := Button.new()
	buy_button.name = "BuyButton"
	buy_button.text = "购买"
	buy_button.custom_minimum_size = Vector2(150, 30)
	container.add_child(buy_button)
	
	return container

## 商品卡片抖动动画（金币不足提示）
func _shake_item(item: Control) -> void:
	# 防止重复抖动
	if item.has_meta("is_shaking") and item.get_meta("is_shaking"):
		return
	item.set_meta("is_shaking", true)
	
	var original_pos: Vector2 = item.position
	var tween := item.create_tween()
	# 快速左右抖动3次
	var shake_offset := 8.0
	var shake_duration := 0.05
	for i in range(3):
		tween.tween_property(item, "position:x", original_pos.x - shake_offset, shake_duration)
		tween.tween_property(item, "position:x", original_pos.x + shake_offset, shake_duration)
	tween.tween_property(item, "position:x", original_pos.x, shake_duration)
	tween.tween_callback(func(): item.set_meta("is_shaking", false))

## 离开商店
func _on_leave_pressed() -> void:
	SceneTransition.change_scene("res://scenes/map/MapScene.tscn")
