## 牌组管理器 - 管理抽牌堆、弃牌堆、手牌的卡牌流转
extends Node

signal deck_changed(draw_count: int, discard_count: int)
signal card_drawn(card_data: Dictionary)
signal deck_shuffled()

## 抽牌堆（卡牌条目数组，每项含 card_id 和 star_level）
var draw_pile: Array[Dictionary] = []
## 弃牌堆
var discard_pile: Array[Dictionary] = []
## 当前手牌
var hand: Array[Dictionary] = []
## 消耗堆（被消耗的卡牌，不会回到牌组）
var exhaust_pile: Array[Dictionary] = []

## 初始化牌组（支持Dictionary数组和String数组兼容）
## shuffle_deck: 是否洗牌，默认true。重打时传false保持卡牌顺序
func init_deck(deck_entries: Array, shuffle_deck: bool = true) -> void:
	draw_pile.clear()
	discard_pile.clear()
	hand.clear()
	exhaust_pile.clear()
	
	for entry in deck_entries:
		if entry is Dictionary:
			draw_pile.append(entry)
		elif entry is String:
			draw_pile.append({"card_id": entry, "star_level": 1})
	if shuffle_deck:
		shuffle_draw_pile()
	_emit_deck_changed()

## 洗牌
func shuffle_draw_pile() -> void:
	draw_pile.shuffle()
	deck_shuffled.emit()

## 抽牌（返回卡牌数据字典，含星级信息）
func draw_card() -> Dictionary:
	# 如果抽牌堆为空，将弃牌堆洗入
	if draw_pile.is_empty():
		if discard_pile.is_empty():
			# 两个堆都空了，无法抽牌
			return {}
		_shuffle_discard_into_draw()
	
	if draw_pile.is_empty():
		return {}
	
	var deck_entry: Dictionary = draw_pile.pop_front()
	hand.append(deck_entry)
	
	var card_id: String = deck_entry.get("card_id", "")
	var star_level: int = deck_entry.get("star_level", 1)
	var card_data := DataManager.get_card(card_id)
	if not card_data.is_empty():
		card_data = card_data.duplicate(true)
		card_data["star_level"] = star_level
		# 根据星级替换效果
		var star_effects: Array = CardFusionManager.get_card_effects_at_star(card_id, star_level)
		if not star_effects.is_empty():
			card_data["effects"] = star_effects
	_emit_deck_changed()
	card_drawn.emit(card_data)
	EventBus.card_drawn.emit(null)  # 通知全局
	
	return card_data

## 抽多张牌
func draw_cards(count: int) -> Array[Dictionary]:
	var drawn: Array[Dictionary] = []
	for i in range(count):
		var card_data := draw_card()
		if card_data.is_empty():
			break
		drawn.append(card_data)
	return drawn

## 打出卡牌（从手牌移到弃牌堆）
## If the card was transformed (e.g. by 七十二变), restore original card identity
func play_card(card_id: String) -> void:
	for i in range(hand.size()):
		if hand[i].get("card_id", "") == card_id:
			var entry: Dictionary = hand[i]
			hand.remove_at(i)
			discard_pile.append(_restore_original_entry(entry))
			_emit_deck_changed()
			return

## 弃掉手牌中的指定卡牌
func discard_from_hand(card_id: String) -> void:
	for i in range(hand.size()):
		if hand[i].get("card_id", "") == card_id:
			var entry: Dictionary = hand[i]
			hand.remove_at(i)
			discard_pile.append(_restore_original_entry(entry))
			_emit_deck_changed()
			return

## 弃掉所有手牌
func discard_all_hand() -> void:
	for entry in hand:
		discard_pile.append(_restore_original_entry(entry))
	hand.clear()
	_emit_deck_changed()

## 消耗卡牌（永久移除，不回到牌组）
func exhaust_card(card_id: String) -> void:
	for i in range(hand.size()):
		if hand[i].get("card_id", "") == card_id:
			var entry: Dictionary = hand[i]
			hand.remove_at(i)
			exhaust_pile.append(entry)
			_emit_deck_changed()
			return

## 添加卡牌到牌组（战斗中获得）
func add_card_to_draw_pile(card_id: String, star_level: int = 1) -> void:
	draw_pile.append({"card_id": card_id, "star_level": star_level})
	draw_pile.shuffle()
	_emit_deck_changed()

## 添加卡牌到弃牌堆
func add_card_to_discard(card_id: String, star_level: int = 1) -> void:
	discard_pile.append({"card_id": card_id, "star_level": star_level})
	_emit_deck_changed()

## 添加卡牌到手牌
func add_card_to_hand(card_id: String, star_level: int = 1) -> void:
	hand.append({"card_id": card_id, "star_level": star_level})
	_emit_deck_changed()

## 将弃牌堆洗入抽牌堆
func _shuffle_discard_into_draw() -> void:
	draw_pile.append_array(discard_pile)
	discard_pile.clear()
	shuffle_draw_pile()
	print("[DeckManager] 弃牌堆洗入抽牌堆，当前抽牌堆: %d张" % draw_pile.size())

## 获取抽牌堆数量
func get_draw_count() -> int:
	return draw_pile.size()

## 获取弃牌堆数量
func get_discard_count() -> int:
	return discard_pile.size()

## 获取手牌数量
func get_hand_count() -> int:
	return hand.size()

## 升级卡牌
func upgrade_card(card_id: String) -> Dictionary:
	var card_data := DataManager.get_card(card_id)
	if card_data.is_empty():
		return {}
	
	# 创建升级版本（默认升级：所有数值+50%）
	var upgraded := card_data.duplicate(true)
	upgraded["card_id"] = card_id + "_upgraded"
	
	for effect in upgraded.get("effects", []):
		if effect.has("value"):
			effect["value"] = int(effect["value"] * 1.5)
	
	# 更新名称
	var original_name: String = upgraded.get("card_name", "")
	if not original_name.ends_with("·极"):
		upgraded["card_name"] = original_name + "·极"
	
	return upgraded

## Restore a hand entry to its original card identity if it was transformed
## Returns a clean entry with only card_id and star_level (no _original_ fields)
func _restore_original_entry(entry: Dictionary) -> Dictionary:
	if entry.has("_original_card_id"):
		return {
			"card_id": entry["_original_card_id"],
			"star_level": entry.get("_original_star_level", 1)
		}
	return entry

## 发送牌组变化信号
func _emit_deck_changed() -> void:
	deck_changed.emit(draw_pile.size(), discard_pile.size())
