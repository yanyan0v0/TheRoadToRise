## 商店场景脚本
extends Control

var shop_cards: Array = []
var shop_relics: Array = []
var shop_consumables: Array = []

## Card scene for reuse
const CARD_SCENE := preload("res://scenes/battle/Card.tscn")

## 是否为神秘商人（商品有概率出现高星级/高强化值）
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

## Roll relic enhance level for normal merchant (+0: 70%, +1: 25%, +2: 5%)
func _roll_normal_relic_enhance() -> int:
	var roll := randf()
	if roll < 0.05:
		return 2
	elif roll < 0.30:
		return 1
	return 0

## Roll relic enhance level for mystery merchant (+0: 20%, +1: 25%, +2: 25%, +3: 15%, +4: 10%, +5: 5%)
func _roll_mystery_relic_enhance() -> int:
	var roll := randf()
	if roll < 0.05:
		return 5
	elif roll < 0.15:
		return 4
	elif roll < 0.30:
		return 3
	elif roll < 0.55:
		return 2
	elif roll < 0.80:
		return 1
	return 0

## 生成商店物品
func _generate_shop_items() -> void:
	if is_mystery_merchant:
		print("[商店] 神秘商人 - 商品有概率出现高星级/高强化值法宝")
	
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
	
	# 生成1-2个法宝（普通商人有概率出现低强化值，神秘商人有概率出现高强化值）
	var all_relics := DataManager.get_all_relics()
	all_relics.shuffle()
	var relic_count := randi_range(1, 2)
	for i in range(mini(relic_count, all_relics.size())):
		var relic_data: Dictionary = all_relics[i]
		var enhance_level: int = 0
		if is_mystery_merchant:
			enhance_level = _roll_mystery_relic_enhance()
		else:
			enhance_level = _roll_normal_relic_enhance()
		var price := _get_relic_price(relic_data)
		# Higher enhance level increases price
		if enhance_level > 0:
			price = int(price * (1.0 + enhance_level * 0.4))
		_add_shop_relic(relic_data, price, enhance_level)
	
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
	
	# Setup the card after adding to tree so @onready nodes resolve
	var card_node: Control = item.get_meta("card_node")
	if card_node != null:
		card_node.setup(card_data, star_level)
		card_node.is_playable = false
		card_node.modulate = Color.WHITE
		card_node.set_process_input(false)
		# Hide background for non-battle card UI
		if card_node.has_node("Background"):
			card_node.get_node("Background").visible = false
	
	# Click overlay handles purchase
	var click_overlay: ColorRect = item.get_meta("click_overlay")
	if click_overlay != null:
		click_overlay.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				if GameManager.current_gold >= price:
					GameManager.modify_gold(-price)
					GameManager.current_deck.append({"card_id": card_data.get("card_id", ""), "star_level": star_level})
					GameManager.modify_karma(1)  # 天劫系统：购买卡牌增加1点劫数
					item.queue_free()
				else:
					_shake_item(item)
		)

## 添加商店法宝
func _add_shop_relic(relic_data: Dictionary, price: int, enhance_level: int = 0) -> void:
	var base_name: String = relic_data.get("relic_name", "???")
	var display_name := "[+%d] %s" % [enhance_level, base_name]
	var desc: String = RelicTooltip.get_enhanced_description(relic_data, enhance_level)
	var item := _create_shop_detail_item(display_name, price, "法宝", desc)
	relic_container.add_child(item)
	
	# Tint the name color based on enhance level
	var name_node: Label = item.get_meta("bg_node").get_child(0) if item.has_meta("bg_node") else null
	if name_node != null and enhance_level > 0:
		if enhance_level >= 4:
			name_node.add_theme_color_override("font_color", Color("FF6B6B"))  # Red for +4/+5
		elif enhance_level >= 2:
			name_node.add_theme_color_override("font_color", Color("74B9FF"))  # Blue for +2/+3
		else:
			name_node.add_theme_color_override("font_color", Color("00B894"))  # Green for +1
	
	# Click on item to purchase
	var bg_node: ColorRect = item.get_meta("bg_node")
	if bg_node != null:
		bg_node.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				if GameManager.current_gold >= price:
					GameManager.modify_gold(-price)
					GameManager.add_relic(relic_data.get("relic_id", ""), enhance_level)
					GameManager.modify_karma(1)  # 天劫系统：购买法宝增加1点劫数
					EventBus.relic_acquired.emit(null)
					item.queue_free()
				else:
					_shake_item(item)
		)

## 添加商店消耗品
func _add_shop_consumable(consumable_data: Dictionary, price: int) -> void:
	var item := _create_shop_detail_item(consumable_data.get("consumable_name", "???"), price, "消耗品", consumable_data.get("description", ""))
	consumable_container.add_child(item)
	
	# Click on item to purchase
	var bg_node: ColorRect = item.get_meta("bg_node")
	if bg_node != null:
		bg_node.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				if GameManager.is_consumable_full():
					_show_full_tip(item, "丹药已满")
					return
				if GameManager.current_gold >= price:
					GameManager.modify_gold(-price)
					if not GameManager.add_consumable(consumable_data.get("consumable_id", "")):
						GameManager.modify_gold(price)
						_show_full_tip(item, "丹药已满")
						return
					item.queue_free()
				else:
					_shake_item(item)
		)

## 创建商店卡牌物品UI（使用战斗卡牌UI）
func _create_shop_card_item(card_data: Dictionary, price: int, star_level: int = 1) -> VBoxContainer:
	var container := VBoxContainer.new()
	container.custom_minimum_size = Vector2(180, 310)
	container.add_theme_constant_override("separation", 5)
	
	# Use the battle Card scene for consistent UI
	var card_node: Control = CARD_SCENE.instantiate()
	card_node.custom_minimum_size = Vector2(180, 270)
	card_node.mouse_filter = Control.MOUSE_FILTER_STOP
	container.add_child(card_node)
	
	# Store card_node reference for later setup
	container.set_meta("card_node", card_node)
	
	# Add a transparent overlay to prevent battle drag behavior
	var click_overlay := ColorRect.new()
	click_overlay.color = Color(0, 0, 0, 0)
	click_overlay.position = Vector2.ZERO
	click_overlay.size = Vector2(180, 270)
	click_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	card_node.add_child(click_overlay)
	
	# Hover highlight effect
	click_overlay.mouse_entered.connect(func():
		card_node.modulate = Color(1.2, 1.2, 1.2, 1.0)
		card_node.scale = Vector2(1.05, 1.05)
	)
	click_overlay.mouse_exited.connect(func():
		card_node.modulate = Color.WHITE
		card_node.scale = Vector2.ONE
	)
	
	# Price label with coin icon
	var price_hbox := HBoxContainer.new()
	price_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	price_hbox.add_theme_constant_override("separation", 4)
	var coin_icon := TextureRect.new()
	coin_icon.custom_minimum_size = Vector2(14, 14)
	coin_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	coin_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	coin_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var coin_path := "res://ui/images/global/coin.png"
	if ResourceLoader.exists(coin_path):
		coin_icon.texture = load(coin_path)
	price_hbox.add_child(coin_icon)
	var price_label := Label.new()
	price_label.text = "%d" % price
	price_label.add_theme_font_size_override("font_size", 13)
	price_label.add_theme_color_override("font_color", Color("FDCB6E"))
	price_hbox.add_child(price_label)
	container.add_child(price_hbox)
	
	# Store click_overlay reference for purchase handling
	container.set_meta("click_overlay", click_overlay)
	
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
	
	# Price with coin icon
	var price_hbox := HBoxContainer.new()
	price_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	price_hbox.add_theme_constant_override("separation", 4)
	price_hbox.position = Vector2(5, 90)
	price_hbox.size = Vector2(140, 20)
	var coin_icon := TextureRect.new()
	coin_icon.custom_minimum_size = Vector2(14, 14)
	coin_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	coin_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	coin_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var coin_path := "res://ui/images/global/coin.png"
	if ResourceLoader.exists(coin_path):
		coin_icon.texture = load(coin_path)
	price_hbox.add_child(coin_icon)
	var price_label := Label.new()
	price_label.text = "%d" % price
	price_label.add_theme_font_size_override("font_size", 13)
	price_label.add_theme_color_override("font_color", Color("FDCB6E"))
	price_hbox.add_child(price_label)
	bg.add_child(price_hbox)
	
	# Store bg reference for click handling, enable mouse
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	container.set_meta("bg_node", bg)
	
	# Hover effect
	var base_color := bg.color
	bg.mouse_entered.connect(func():
		bg.color = base_color.lightened(0.2)
	)
	bg.mouse_exited.connect(func():
		bg.color = base_color
	)
	
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

## 显示携带已满提示（飘字）
func _show_full_tip(item: Control, text: String) -> void:
	_shake_item(item)
	var tip := Label.new()
	tip.text = text
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip.add_theme_font_size_override("font_size", 16)
	tip.add_theme_color_override("font_color", Color("D63031"))
	tip.add_theme_constant_override("outline_size", 2)
	tip.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	tip.position = Vector2(item.size.x / 2.0 - 40, -20)
	item.add_child(tip)
	
	tip.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_property(tip, "position:y", tip.position.y - 30, 0.8)
	tween.parallel().tween_property(tip, "modulate:a", 0.0, 0.8)
	tween.tween_callback(tip.queue_free)

## 离开商店
func _on_leave_pressed() -> void:
	SceneTransition.change_scene("res://scenes/map/MapScene.tscn")
