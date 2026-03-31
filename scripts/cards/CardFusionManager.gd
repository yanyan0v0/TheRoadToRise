## 卡牌融合管理器 - 管理卡牌融合升星逻辑
class_name CardFusionManager
extends RefCounted

## 获取可融合的卡牌分组
## 返回: Array[Dictionary]，每项包含 {"card_id": String, "card_name": String, "star_level": int, "indices": Array[int], "count": int, "can_fuse": bool}
static func get_fusable_groups() -> Array[Dictionary]:
	var groups: Dictionary = {}  # key: "card_id:star_level" -> Dictionary
	
	for i in range(GameManager.current_deck.size()):
		var deck_entry: Dictionary = GameManager.current_deck[i]
		var card_id: String = deck_entry.get("card_id", "")
		var star_level: int = deck_entry.get("star_level", 1)
		var group_key: String = "%s:%d" % [card_id, star_level]
		
		if not groups.has(group_key):
			var card_data: Dictionary = DataManager.get_card(card_id)
			groups[group_key] = {
				"card_id": card_id,
				"card_name": card_data.get("card_name", card_id),
				"star_level": star_level,
				"indices": [],
				"count": 0,
				"can_fuse": false,
			}
		
		groups[group_key]["indices"].append(i)
		groups[group_key]["count"] += 1
	
	# 标记可融合状态
	var result: Array[Dictionary] = []
	for key in groups:
		var group: Dictionary = groups[key]
		group["can_fuse"] = group["count"] >= 2 and group["star_level"] < 3
		result.append(group)
	
	# 按卡牌名称排序
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["card_name"] != b["card_name"]:
			return a["card_name"] < b["card_name"]
		return a["star_level"] < b["star_level"]
	)
	
	return result

## 检查两张卡牌是否可以融合
## index_a, index_b: 卡组中的索引
static func can_fuse(index_a: int, index_b: int) -> bool:
	if index_a < 0 or index_a >= GameManager.current_deck.size():
		return false
	if index_b < 0 or index_b >= GameManager.current_deck.size():
		return false
	if index_a == index_b:
		return false
	
	var entry_a: Dictionary = GameManager.current_deck[index_a]
	var entry_b: Dictionary = GameManager.current_deck[index_b]
	
	# 必须是相同卡牌
	if entry_a.get("card_id", "") != entry_b.get("card_id", ""):
		return false
	
	# 必须是相同星级
	if entry_a.get("star_level", 1) != entry_b.get("star_level", 1):
		return false
	
	# 星级不能已经是3星
	if entry_a.get("star_level", 1) >= 3:
		return false
	
	return true

## 执行卡牌融合
## index_a, index_b: 要融合的两张卡牌在卡组中的索引
## 返回: 融合后的卡牌数据字典，失败返回空字典
static func fuse_cards(index_a: int, index_b: int) -> Dictionary:
	if not can_fuse(index_a, index_b):
		return {}
	
	var entry_a: Dictionary = GameManager.current_deck[index_a]
	var card_id: String = entry_a.get("card_id", "")
	var current_star: int = entry_a.get("star_level", 1)
	var new_star: int = current_star + 1
	
	# 创建融合后的卡牌条目
	var fused_entry: Dictionary = {
		"card_id": card_id,
		"star_level": new_star,
	}
	
	# 从卡组中移除两张原卡（先移除较大索引，避免索引偏移）
	var indices := [index_a, index_b]
	indices.sort()
	indices.reverse()
	for idx in indices:
		GameManager.current_deck.remove_at(idx)
	
	# 添加融合后的卡牌
	GameManager.current_deck.append(fused_entry)
	
	print("[CardFusionManager] 融合成功: %s %d星 -> %d星" % [card_id, current_star, new_star])
	
	return fused_entry

## 获取融合预览信息
## 返回融合后卡牌的效果数据
static func get_fusion_preview(card_id: String, current_star: int) -> Dictionary:
	var card_data: Dictionary = DataManager.get_card(card_id)
	if card_data.is_empty():
		return {}
	
	var new_star: int = current_star + 1
	if new_star > 3:
		return {}
	
	var preview: Dictionary = card_data.duplicate(true)
	preview["star_level"] = new_star
	
	# 获取对应星级的效果
	match new_star:
		2:
			var star_2: Array = card_data.get("star_2_effects", [])
			if not star_2.is_empty():
				preview["preview_effects"] = star_2
			else:
				# 自动计算：基础效果×1.5
				preview["preview_effects"] = _auto_scale_effects(card_data.get("effects", []), 1.5)
		3:
			var star_3: Array = card_data.get("star_3_effects", [])
			if not star_3.is_empty():
				preview["preview_effects"] = star_3
			else:
				# 自动计算：基础效果×2.0
				preview["preview_effects"] = _auto_scale_effects(card_data.get("effects", []), 2.0)
	
	return preview

## 自动缩放效果数值（当JSON中未配置星级效果时使用）
static func _auto_scale_effects(base_effects: Array, multiplier: float) -> Array:
	var scaled: Array = []
	for effect in base_effects:
		var new_effect: Dictionary = effect.duplicate()
		# 缩放数值类字段
		if new_effect.has("value"):
			new_effect["value"] = int(ceil(new_effect["value"] * multiplier))
		if new_effect.has("bonus_value"):
			new_effect["bonus_value"] = int(ceil(new_effect["bonus_value"] * multiplier))
		scaled.append(new_effect)
	return scaled

## 获取指定卡牌在指定星级下的实际效果
static func get_card_effects_at_star(card_id: String, star_level: int) -> Array:
	var card_data: Dictionary = DataManager.get_card(card_id)
	if card_data.is_empty():
		return []
	
	match star_level:
		2:
			var star_2: Array = card_data.get("star_2_effects", [])
			if not star_2.is_empty():
				return star_2
			return _auto_scale_effects(card_data.get("effects", []), 1.5)
		3:
			var star_3: Array = card_data.get("star_3_effects", [])
			if not star_3.is_empty():
				return star_3
			return _auto_scale_effects(card_data.get("effects", []), 2.0)
		_:
			return card_data.get("effects", [])
