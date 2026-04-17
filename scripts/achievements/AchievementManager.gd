## 成就管理器 - 检测和管理成就解锁
class_name AchievementManager
extends Node

## 成就分类
enum AchievementCategory {
	BATTLE,    # 战斗
	EXPLORE,   # 探索
	COLLECT,   # 收集
	CHALLENGE, # 挑战
}

## 成就定义（从DataManager加载）
static var ACHIEVEMENTS: Dictionary = {}

## 初始化成就数据（由DataManager调用）
static func init_achievements(data: Dictionary) -> void:
	ACHIEVEMENTS = data

## 检查所有成就条件
static func check_achievements() -> void:
	# 初窥门径：使用默认角色游玩一局
	if not SaveManager.is_achievement_unlocked("first_game"):
		if GameManager.current_character_id == "sun_wukong":
			SaveManager.unlock_achievement("first_game", "初窥门径")
			SaveManager.unlock_character("zhu_bajie")
	
	# 取得真经：完成通关
	if not SaveManager.is_achievement_unlocked("true_scripture"):
		if GameManager.current_chapter >= 4:
			SaveManager.unlock_achievement("true_scripture", "取得真经")
			SaveManager.unlock_character("tang_seng")
			SaveManager.increment_clear_count()
	
	# 十全十美：累计通关10次
	if not SaveManager.is_achievement_unlocked("ten_clears"):
		if SaveManager.total_clears >= 10:
			SaveManager.unlock_achievement("ten_clears", "十全十美")
	
	# 渡劫成功
	if not SaveManager.is_achievement_unlocked("tribulation_survivor"):
		if GameManager.tribulation_count >= 1:
			_unlock_with_content("tribulation_survivor", "渡劫成功")
	
	# 天罚降临
	if not SaveManager.is_achievement_unlocked("high_karma"):
		if GameManager.current_karma >= 50:
			_unlock_with_content("high_karma", "天罚降临")
	
	# 满星大师：检查卡组中是否有3星卡牌
	if not SaveManager.is_achievement_unlocked("star_master"):
		for entry in GameManager.current_deck:
			if entry is Dictionary and entry.get("star_level", 1) >= 3:
				_unlock_with_content("star_master", "满星大师")
				break
	
	# 强化大师：检查是否有法宝强化等级达到5
	if not SaveManager.is_achievement_unlocked("enhance_master"):
		for entry in GameManager.current_relics:
			if entry is Dictionary and entry.get("enhance_level", 0) >= 5:
				_unlock_with_content("enhance_master", "强化大师")
				break
	
	# 法宝收藏家
	if not SaveManager.is_achievement_unlocked("relic_collector"):
		if GameManager.current_relics.size() >= 5:
			_unlock_with_content("relic_collector", "法宝收藏家")
	
	# 丹药囤积者
	if not SaveManager.is_achievement_unlocked("pill_hoarder"):
		var capacity := GameManager.get_consumable_capacity()
		if GameManager.current_consumables.size() >= capacity:
			_unlock_with_content("pill_hoarder", "丹药囤积者")

## 检查战斗相关成就
static func check_battle_achievements() -> void:
	# 毫发无伤
	if not SaveManager.is_achievement_unlocked("perfect_battle"):
		if not GameManager.battle_took_damage:
			_unlock_with_content("perfect_battle", "毫发无伤")
	
	# 妖灵猎人
	if not SaveManager.is_achievement_unlocked("spirit_hunter"):
		var spirit_count := SpiritCaptureManager.get_spirit_count()
		if spirit_count >= 3:
			_unlock_with_content("spirit_hunter", "妖灵猎人")

## 检查关卡进度成就
static func check_floor_achievement(floor_number: int) -> void:
	# 18层地狱：通关第18关
	if not SaveManager.is_achievement_unlocked("floor_18"):
		if floor_number >= 18:
			SaveManager.unlock_achievement("floor_18", "18层地狱")
			SaveManager.unlock_character("sha_wujing")

## 检查炼丹成就
static func check_alchemy_achievement() -> void:
	if not SaveManager.is_achievement_unlocked("alchemy_master"):
		var count: int = SaveManager.get_stat("pills_crafted", 0)
		if count >= 10:
			_unlock_with_content("alchemy_master", "丹道宗师")

## 检查炼器成就
static func check_forge_achievement() -> void:
	if not SaveManager.is_achievement_unlocked("forge_master"):
		var count: int = SaveManager.get_stat("relics_forged", 0)
		if count >= 5:
			_unlock_with_content("forge_master", "炼器大师")

## 解锁成就并解锁关联内容
static func _unlock_with_content(achievement_id: String, achievement_name: String) -> void:
	SaveManager.unlock_achievement(achievement_id, achievement_name)
	
	var achievement_data: Dictionary = ACHIEVEMENTS.get(achievement_id, {})
	var unlock_type: String = achievement_data.get("unlock_type", "")
	var unlock_content: String = achievement_data.get("unlock_content", "")
	
	if unlock_type.is_empty() or unlock_content.is_empty():
		return
	
	SaveManager.unlock_content(unlock_type, unlock_content)

## 获取所有成就列表（含解锁状态）
static func get_all_achievements() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for id in ACHIEVEMENTS:
		var achievement: Dictionary = ACHIEVEMENTS[id].duplicate()
		achievement["id"] = id
		achievement["unlocked"] = SaveManager.is_achievement_unlocked(id)
		if achievement["unlocked"]:
			var unlock_data: Dictionary = SaveManager.achievements.get(id, {})
			achievement["unlocked_at"] = unlock_data.get("unlocked_at", "")
		result.append(achievement)
	return result

## 按分类获取成就
static func get_achievements_by_category(category: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for achievement in get_all_achievements():
		if achievement.get("category", "") == category:
			result.append(achievement)
	return result
