## 数据管理器 - 负责从JSON加载并缓存所有游戏数据
extends Node

# ===== 数据缓存 =====
var cards: Dictionary = {}          # card_id -> CardData字典
var enemies: Dictionary = {}        # enemy_id -> EnemyData字典
var relics: Dictionary = {}         # relic_id -> RelicData字典
var consumables: Dictionary = {}    # consumable_id -> ConsumableData字典
var events: Dictionary = {}         # event_id -> EventData字典
var characters: Dictionary = {}     # character_id -> CharacterData字典

# ===== 卡池分类缓存 =====
var base_card_pool: Array[String] = []           # 基础卡池（所有角色通用）
var character_card_pools: Dictionary = {}         # 角色专属卡池 character_id -> Array[card_id]

# ===== 敌人分类缓存 =====
var _enemies_by_chapter: Dictionary = {}          # chapter(int) -> Array[enemy_id]
var _enemies_by_type: Dictionary = {}             # enemy_type(String) -> Array[enemy_id]
var _enemies_by_chapter_type: Dictionary = {}     # "chapter_type" -> Array[enemy_id]
var _normal_enemy_pools: Dictionary = {}          # chapter(int) -> Array[Array[enemy_id]] (auto-generated combat pools)
var _boss_pool: Array[String] = []                # All boss enemy ids
var _elite_pool: Array[String] = []               # All elite enemy ids

# ===== 数据文件路径 =====
const DATA_DIR := "res://data/"
const CARDS_FILE := "res://data/cards.json"
const ENEMIES_FILE := "res://data/enemies.json"
const RELICS_FILE := "res://data/relics.json"
const CONSUMABLES_FILE := "res://data/consumables.json"
const EVENTS_FILE := "res://data/events.json"
const CHARACTERS_FILE := "res://data/characters.json"
const ACHIEVEMENTS_FILE := "res://data/achievements.json"

var _is_loaded: bool = false

func _ready() -> void:
	load_all_data()

## 加载所有游戏数据
func load_all_data() -> void:
	if _is_loaded:
		return
	
	_load_characters()
	_load_cards()
	_load_enemies()
	_load_relics()
	_load_consumables()
	_load_events()
	_load_achievements()
	
	_is_loaded = true
	print("[DataManager] 所有游戏数据加载完成")
	print("  - 角色: %d" % characters.size())
	print("  - 卡牌: %d (基础池: %d)" % [cards.size(), base_card_pool.size()])
	print("  - 敌人: %d" % enemies.size())
	print("  - 法宝: %d" % relics.size())
	print("  - 消耗品: %d" % consumables.size())
	print("  - 成就: %d" % AchievementManager.ACHIEVEMENTS.size())

## 加载角色数据
func _load_characters() -> void:
	var data := _load_json(CHARACTERS_FILE)
	if data.is_empty():
		return
	
	var char_list: Array = data.get("characters", [])
	for char_data in char_list:
		var char_id: String = char_data.get("character_id", "")
		if char_id != "":
			characters[char_id] = char_data

## 加载卡牌数据
func _load_cards() -> void:
	var data := _load_json(CARDS_FILE)
	if data.is_empty():
		return
	
	var card_list: Array = data.get("cards", [])
	for card_data in card_list:
		var card_id: String = card_data.get("card_id", "")
		if card_id == "":
			continue
		
		cards[card_id] = card_data
		
		# 分类到卡池
		var exclusive: String = card_data.get("character_exclusive", "")
		if exclusive == "" or exclusive == "all":
			base_card_pool.append(card_id)
		else:
			if not character_card_pools.has(exclusive):
				character_card_pools[exclusive] = []
			character_card_pools[exclusive].append(card_id)

## 加载敌人数据
func _load_enemies() -> void:
	var data := _load_json(ENEMIES_FILE)
	if data.is_empty():
		return
	
	var enemy_list: Array = data.get("enemies", [])
	for enemy_data in enemy_list:
		var enemy_id: String = enemy_data.get("enemy_id", "")
		if enemy_id != "":
			enemies[enemy_id] = enemy_data
	
	# Build enemy classification cache
	_build_enemy_cache()

## 加载法宝数据
func _load_relics() -> void:
	var data := _load_json(RELICS_FILE)
	if data.is_empty():
		return
	
	var relic_list: Array = data.get("relics", [])
	for relic_data in relic_list:
		var relic_id: String = relic_data.get("relic_id", "")
		if relic_id != "":
			relics[relic_id] = relic_data

## 加载消耗品数据
func _load_consumables() -> void:
	var data := _load_json(CONSUMABLES_FILE)
	if data.is_empty():
		return
	
	var consumable_list: Array = data.get("consumables", [])
	for consumable_data in consumable_list:
		var consumable_id: String = consumable_data.get("consumable_id", "")
		if consumable_id != "":
			consumables[consumable_id] = consumable_data

## 加载事件数据
func _load_events() -> void:
	var data := _load_json(EVENTS_FILE)
	if data.is_empty():
		return
	
	var event_list: Array = data.get("events", [])
	for event_data in event_list:
		var event_id: String = event_data.get("event_id", "")
		if event_id != "":
			events[event_id] = event_data

## 加载成就数据
func _load_achievements() -> void:
	var data := _load_json(ACHIEVEMENTS_FILE)
	if data.is_empty():
		return
	
	var achievement_dict: Dictionary = {}
	var achievement_list: Array = data.get("achievements", [])
	for ach_data in achievement_list:
		var ach_id: String = ach_data.get("achievement_id", "")
		if ach_id != "":
			achievement_dict[ach_id] = ach_data
	
	AchievementManager.init_achievements(achievement_dict)

## 获取卡牌数据
func get_card(card_id: String) -> Dictionary:
	return cards.get(card_id, {})

## 获取敌人数据
func get_enemy(enemy_id: String) -> Dictionary:
	return enemies.get(enemy_id, {})

## Get all boss enemy ids (cached)
func get_boss_pool() -> Array[String]:
	return _boss_pool

## Get all elite enemy ids (cached)
func get_elite_pool() -> Array[String]:
	return _elite_pool

## Get normal enemy ids for a specific chapter (cached)
func get_normal_enemies_by_chapter(chapter: int) -> Array[String]:
	var key := str(chapter) + "_normal"
	if _enemies_by_chapter_type.has(key):
		return _enemies_by_chapter_type[key]
	return []

## Get auto-generated normal enemy combat pools for a chapter
## Each pool is an Array of enemy_ids representing one possible encounter
func get_normal_enemy_pools(chapter: int) -> Array:
	if _normal_enemy_pools.has(chapter):
		return _normal_enemy_pools[chapter]
	return []

## 获取法宝数据
func get_relic(relic_id: String) -> Dictionary:
	return relics.get(relic_id, {})

## 获取消耗品数据
func get_consumable(consumable_id: String) -> Dictionary:
	return consumables.get(consumable_id, {})

## 获取角色数据
func get_character(character_id: String) -> Dictionary:
	return characters.get(character_id, {})

## 获取角色可用卡池（基础+专属）
func get_available_cards_for_character(character_id: String) -> Array[String]:
	var pool: Array[String] = []
	pool.append_array(base_card_pool)
	if character_card_pools.has(character_id):
		var exclusive_pool: Array = character_card_pools[character_id]
		for card_id in exclusive_pool:
			pool.append(str(card_id))
	return pool

## 按稀有度筛选卡牌
func get_cards_by_rarity(rarity: String, character_id: String = "") -> Array[String]:
	var result: Array[String] = []
	var pool := get_available_cards_for_character(character_id) if character_id != "" else cards.keys()
	for card_id in pool:
		var card_data: Dictionary = cards.get(str(card_id), {})
		if card_data.get("rarity", "") == rarity:
			result.append(str(card_id))
	return result

## 获取所有卡牌数据列表
func get_all_cards() -> Array:
	return cards.values()

## 获取所有法宝数据列表
func get_all_relics() -> Array:
	return relics.values()

## 获取所有消耗品数据列表
func get_all_consumables() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for consumable_data in consumables.values():
		result.append(consumable_data)
	return result

## 获取所有事件数据列表
func get_all_events() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for event_data in events.values():
		result.append(event_data)
	return result

## 获取所有角色数据列表
func get_all_characters() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for character_data in characters.values():
		result.append(character_data)
	return result

## 获取随机卡牌（用于奖励）
func get_random_cards(count: int, character_id: String = "", min_rarity: String = "") -> Array[String]:
	var pool := get_available_cards_for_character(character_id)
	
	# 按稀有度筛选
	if min_rarity != "":
		var rarity_order := ["common", "uncommon", "rare", "legendary"]
		var min_idx := rarity_order.find(min_rarity)
		if min_idx >= 0:
			var filtered: Array[String] = []
			for card_id in pool:
				var card_data: Dictionary = cards.get(card_id, {})
				var card_rarity: String = card_data.get("rarity", "common")
				if rarity_order.find(card_rarity) >= min_idx:
					filtered.append(card_id)
			pool = filtered
	
	# 随机选择
	pool.shuffle()
	var result: Array[String] = []
	for i in range(mini(count, pool.size())):
		result.append(pool[i])
	return result

## 加载JSON文件
func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_warning("[DataManager] 数据文件不存在: %s" % path)
		return {}
	
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("[DataManager] 无法打开数据文件: %s" % path)
		return {}
	
	var json_string := file.get_as_text()
	file.close()
	
	var json := JSON.new()
	var error := json.parse(json_string)
	if error != OK:
		push_error("[DataManager] JSON解析失败: %s, 错误: %s" % [path, json.get_error_message()])
		return {}
	
	if json.data is Dictionary:
		return json.data
	
	return {}

## Build enemy classification cache from loaded enemy data
func _build_enemy_cache() -> void:
	_enemies_by_chapter.clear()
	_enemies_by_type.clear()
	_enemies_by_chapter_type.clear()
	_normal_enemy_pools.clear()
	_boss_pool.clear()
	_elite_pool.clear()
	
	for enemy_id in enemies:
		var data: Dictionary = enemies[enemy_id]
		var chapter: int = data.get("chapter", 0)
		var etype: String = data.get("enemy_type", "normal")
		
		# By chapter
		if not _enemies_by_chapter.has(chapter):
			_enemies_by_chapter[chapter] = []
		_enemies_by_chapter[chapter].append(enemy_id)
		
		# By type
		if not _enemies_by_type.has(etype):
			_enemies_by_type[etype] = []
		_enemies_by_type[etype].append(enemy_id)
		
		# By chapter + type
		var key := str(chapter) + "_" + etype
		if not _enemies_by_chapter_type.has(key):
			_enemies_by_chapter_type[key] = []
		_enemies_by_chapter_type[key].append(enemy_id)
		
		# Boss pool
		if etype == "boss":
			_boss_pool.append(enemy_id)
		
		# Elite pool
		if etype == "elite":
			_elite_pool.append(enemy_id)
	
	# Generate normal enemy combat pools per chapter
	for chapter in range(4):
		_normal_enemy_pools[chapter] = _generate_combat_pools(chapter)
	
	print("  - 敌人缓存: boss=%d, elite=%d, pools=%s" % [
		_boss_pool.size(), _elite_pool.size(),
		str([_normal_enemy_pools.get(0, []).size(), _normal_enemy_pools.get(1, []).size(),
			_normal_enemy_pools.get(2, []).size(), _normal_enemy_pools.get(3, []).size()])
	])

## Generate combat encounter pools for a chapter from normal enemies
## Creates 2-enemy and 3-enemy combinations from the chapter's normal enemy pool
func _generate_combat_pools(chapter: int) -> Array:
	var key := str(chapter) + "_normal"
	var normal_ids: Array = _enemies_by_chapter_type.get(key, [])
	if normal_ids.is_empty():
		return []
	
	var pools: Array = []
	var shuffled: Array = normal_ids.duplicate()
	shuffled.shuffle()
	
	# Generate pools: alternate between 2-enemy and 3-enemy groups
	var idx := 0
	while idx < shuffled.size():
		var remaining := shuffled.size() - idx
		if remaining >= 3 and (pools.size() % 2 == 1 or remaining == 3):
			# 3-enemy pool
			pools.append([shuffled[idx], shuffled[idx + 1], shuffled[idx + 2]])
			idx += 3
		elif remaining >= 2:
			# 2-enemy pool
			pools.append([shuffled[idx], shuffled[idx + 1]])
			idx += 2
		else:
			# 1 enemy left, pair with a random one from the same chapter
			var partner: String = shuffled[randi() % maxi(idx, 1)]
			pools.append([shuffled[idx], partner])
			idx += 1
	
	# Ensure at least 4 pools for variety
	while pools.size() < 4 and normal_ids.size() >= 2:
		var a: String = normal_ids[randi() % normal_ids.size()]
		var b: String = normal_ids[randi() % normal_ids.size()]
		while b == a and normal_ids.size() > 1:
			b = normal_ids[randi() % normal_ids.size()]
		var new_pool: Array = [a, b]
		# Avoid exact duplicates
		var is_dup := false
		for existing in pools:
			if existing == new_pool:
				is_dup = true
				break
		if not is_dup:
			pools.append(new_pool)
	
	return pools
