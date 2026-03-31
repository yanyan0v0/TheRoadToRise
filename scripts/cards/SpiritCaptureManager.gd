## 妖灵收服管理器 - 处理收服和召唤逻辑
class_name SpiritCaptureManager
extends RefCounted

## 默认妖灵容量
const DEFAULT_SPIRIT_CAPACITY: int = 3

## 检查敌人是否可收服
## 条件：非BOSS、生命≤25%、妖灵容量未满
static func can_capture(enemy: Node) -> bool:
	# 检查妖灵容量
	if get_spirit_count() >= get_spirit_capacity():
		return false
	
	# 检查是否为BOSS
	if GameManager.current_battle_type == "boss":
		return false
	
	# 检查敌人生命值
	if enemy.has_method("get_hp_percent"):
		return enemy.get_hp_percent() <= 0.25
	
	# 兼容：通过属性检查
	if "current_hp" in enemy and "max_hp" in enemy:
		var hp_percent: float = float(enemy.current_hp) / float(enemy.max_hp)
		return hp_percent <= 0.25
	
	return false

## 尝试收服敌人
## 返回: {"success": bool, "card_id": String, "card_name": String}
static func capture_enemy(enemy: Node) -> Dictionary:
	if not can_capture(enemy):
		return {"success": false}
	
	# 精英敌人50%成功率
	var is_elite := GameManager.current_battle_type == "elite"
	if is_elite and randf() > 0.5:
		return {"success": false, "reason": "收服失败！精英妖灵挣脱了束缚。"}
	
	# 获取敌人信息
	var enemy_id: String = ""
	var enemy_name: String = "妖灵"
	if "enemy_id" in enemy:
		enemy_id = enemy.enemy_id
	if "enemy_name" in enemy:
		enemy_name = enemy.enemy_name
	
	# 生成妖灵召唤卡ID
	var spirit_card_id := "spirit_" + enemy_id
	
	# 检查是否有对应的妖灵卡牌数据
	var card_data := DataManager.get_card(spirit_card_id)
	if card_data.is_empty():
		# 使用通用妖灵卡
		spirit_card_id = "spirit_generic"
	
	# 添加到卡组
	GameManager.current_deck.append({"card_id": spirit_card_id, "star_level": 1})
	
	return {
		"success": true,
		"card_id": spirit_card_id,
		"card_name": "妖灵·" + enemy_name,
	}

## 获取当前妖灵卡数量
static func get_spirit_count() -> int:
	var count := 0
	for entry in GameManager.current_deck:
		var card_id: String = entry.get("card_id", "") if entry is Dictionary else str(entry)
		if card_id.begins_with("spirit_"):
			count += 1
	return count

## 获取妖灵容量
static func get_spirit_capacity() -> int:
	var capacity := DEFAULT_SPIRIT_CAPACITY
	# 检测妖灵壶法宝
	if GameManager.has_relic("yao_ling_hu"):
		capacity += 3
	return capacity
