## 游戏状态管理器 - 管理全局游戏状态和当前运行数据
extends Node

# ===== 游戏状态枚举 =====
enum GameState {
	MENU,              # 主菜单
	CHARACTER_SELECT,  # 角色选择
	MAP,               # 地图探索
	BATTLE,            # 战斗中
	EVENT,             # 事件
	SHOP,              # 商店
	REST,              # 篝火休息
	REWARD,            # 战斗奖励
	GAME_OVER,         # 游戏结束（失败）
	VICTORY            # 游戏胜利
}

# ===== 当前游戏状态 =====
var current_state: GameState = GameState.MENU
var previous_state: GameState = GameState.MENU
var is_paused: bool = false

# ===== 当前运行数据 =====
## 当前选择的角色数据
var current_character: Resource = null
## 当前角色ID
var current_character_id: String = ""
## 当前生命值
var current_hp: int = 0
## 最大生命值
var max_hp: int = 0
## 当前法力
var current_mana: int = 0
## 最大法力（初始法力）
var max_mana: int = 3
## 当前体力（天蓬元帅专属）
var current_stamina: int = 0
## 最大体力
var max_stamina: int = 0
## 当前护甲
var current_armor: int = 0
## 当前力量
var current_strength: int = 0
## 当前金币
var current_gold: int = 0

## 当前卡组（卡牌字典数组，每项含 card_id 和 star_level）
var current_deck: Array[Dictionary] = []
## 当前法宝（法宝ID+星级字典数组，法宝无携带上限）
var current_relics: Array[Dictionary] = []
## 当前消耗品（丹药ID数组）
var current_consumables: Array[String] = []
## 丹药携带上限（初始3颗）
var max_consumable_slots: int = 3
## 妖灵容量（初始3只）
var spirit_capacity: int = 3

## 当前章节索引（0-3对应4章）
var current_chapter: int = 0
## 当前地图节点索引
var current_node_index: int = 0
## 当前地图数据
var current_map_data: Dictionary = {}
## 当前战斗类型（normal/elite/boss）
var current_battle_type: String = "normal"
## 当前BOSS ID
var current_boss_id: String = ""

## 开发者模式
var dev_mode: bool = false
var _dev_gold_click_count: int = 0
var _dev_gold_click_timer: float = 0.0
const DEV_GOLD_CLICK_THRESHOLD: int = 5
const DEV_GOLD_CLICK_TIMEOUT: float = 2.0  # 2秒内连点5次
const DEV_GOLD_REWARD: int = 100

## 本局统计数据
var stats: Dictionary = {
	"enemies_defeated": 0,
	"cards_obtained": 0,
	"max_single_damage": 0,
	"turns_played": 0,
	"start_time": 0,
}

# ===== 天劫系统 =====
## 当前劫数
var current_karma: int = 0
## 本局最高劫数
var max_karma_reached: int = 0
## 渡劫次数
var tribulation_count: int = 0
## 本场战斗是否受伤
var battle_took_damage: bool = false

## 天劫等级阈值
const TRIBULATION_LEVELS := {
	"清净": 0,
	"微劫": 5,
	"小劫": 15,
	"大劫": 30,
	"天罚": 50,
}

## 天劫等级对应的敌人增强系数
const TRIBULATION_ENEMY_BUFF := {
	"清净": 0.0,
	"微劫": 0.10,
	"小劫": 0.25,
	"大劫": 0.50,
	"天罚": 1.00,
}

## 获取当前天劫等级
func get_tribulation_level() -> String:
	if current_karma >= TRIBULATION_LEVELS["天罚"]:
		return "天罚"
	elif current_karma >= TRIBULATION_LEVELS["大劫"]:
		return "大劫"
	elif current_karma >= TRIBULATION_LEVELS["小劫"]:
		return "小劫"
	elif current_karma >= TRIBULATION_LEVELS["微劫"]:
		return "微劫"
	return "清净"

## 修改劫数
func modify_karma(amount: int) -> void:
	var old_level := get_tribulation_level()
	current_karma = max(0, current_karma + amount)
	if current_karma > max_karma_reached:
		max_karma_reached = current_karma
	var new_level := get_tribulation_level()
	EventBus.karma_changed.emit(current_karma, new_level)
	if old_level != new_level:
		EventBus.tribulation_level_changed.emit(old_level, new_level)

## 获取天劫敌人增强系数
func get_tribulation_buff() -> float:
	var level := get_tribulation_level()
	return TRIBULATION_ENEMY_BUFF.get(level, 0.0)

# ===== 章节名称 =====
const CHAPTER_NAMES: Array[String] = [
	"第一章：取经路",
	"第二章：三打白骨",
	"第三章：火焰山",
	"第四章：西天真经"
]

func _ready() -> void:
	stats.start_time = Time.get_unix_time_from_system()

## 处理开发者模式金币连点
func dev_gold_click() -> void:
	if not dev_mode:
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - _dev_gold_click_timer > DEV_GOLD_CLICK_TIMEOUT:
		_dev_gold_click_count = 0
	_dev_gold_click_timer = now
	_dev_gold_click_count += 1
	if _dev_gold_click_count >= DEV_GOLD_CLICK_THRESHOLD:
		_dev_gold_click_count = 0
		modify_gold(DEV_GOLD_REWARD)
		print("[开发者模式] 金币 +%d，当前金币: %d" % [DEV_GOLD_REWARD, current_gold])

## 切换游戏状态
func change_state(new_state: GameState) -> void:
	if new_state == current_state:
		return
	previous_state = current_state
	current_state = new_state
	EventBus.game_state_changed.emit(previous_state, new_state)
	print("[GameManager] 状态切换: %s -> %s" % [GameState.keys()[previous_state], GameState.keys()[new_state]])

## 初始化新游戏
func start_new_game(character_id: String) -> void:
	current_character_id = character_id
	current_chapter = 0
	current_node_index = 0
	current_map_data = {}  # 清空地图数据，重新生成
	current_deck.clear()
	current_relics.clear()
	current_consumables.clear()
	current_armor = 0
	current_strength = 0
	
	# 重置天劫系统
	current_karma = 0
	max_karma_reached = 0
	tribulation_count = 0
	battle_took_damage = false
	# 重置丹药上限和妖灵容量
	max_consumable_slots = 3
	spirit_capacity = 3
	
	# 重置统计
	stats = {
		"enemies_defeated": 0,
		"cards_obtained": 0,
		"max_single_damage": 0,
		"turns_played": 0,
		"start_time": Time.get_unix_time_from_system(),
	}
	
	# 角色初始化将由CharacterData处理
	print("[GameManager] 新游戏开始，角色: %s" % character_id)

## 初始化角色属性
func init_character_stats(hp: int, mana: int, gold: int, stamina: int = 0, deck: Array[String] = []) -> void:
	max_hp = hp
	current_hp = hp
	max_mana = mana
	current_mana = mana
	current_gold = gold
	max_stamina = stamina
	current_stamina = stamina
	# 将String数组转换为Dictionary数组（兼容旧接口）
	current_deck.clear()
	for card_id in deck:
		current_deck.append({"card_id": card_id, "star_level": 1})
	
	EventBus.health_changed.emit(current_hp, max_hp)
	EventBus.mana_changed.emit(current_mana, max_mana)
	EventBus.gold_changed.emit(current_gold)

## 修改生命值
func modify_hp(amount: int) -> void:
	# 天劫系统：标记本场战斗是否受伤
	if amount < 0 and current_state == GameState.BATTLE:
		battle_took_damage = true
	current_hp = clampi(current_hp + amount, 0, max_hp)
	EventBus.health_changed.emit(current_hp, max_hp)
	if current_hp <= 0:
		EventBus.game_ended.emit(false)

## 修改法力
func modify_mana(amount: int) -> void:
	current_mana = maxi(0, current_mana + amount)
	EventBus.mana_changed.emit(current_mana, max_mana)

## 重置法力（回合开始）
func reset_mana() -> void:
	current_mana = max_mana
	EventBus.mana_changed.emit(current_mana, max_mana)

## 修改体力
func modify_stamina(amount: int) -> void:
	current_stamina = clampi(current_stamina + amount, 0, max_stamina)
	EventBus.stamina_changed.emit(current_stamina, max_stamina)

## 修改护甲
func modify_armor(amount: int) -> void:
	current_armor = maxi(0, current_armor + amount)
	EventBus.armor_changed.emit(current_armor)

## 重置护甲（战斗开始）
func reset_armor() -> void:
	current_armor = 0
	EventBus.armor_changed.emit(current_armor)

## 修改力量
func modify_strength(amount: int) -> void:
	current_strength += amount
	EventBus.strength_changed.emit(current_strength)

## 修改金币
func modify_gold(amount: int) -> void:
	current_gold = maxi(0, current_gold + amount)
	EventBus.gold_changed.emit(current_gold)

## 添加卡牌到卡组（支持星级）
func add_card_to_deck(card_id: String, star_level: int = 1) -> void:
	current_deck.append({"card_id": card_id, "star_level": star_level})
	stats.cards_obtained += 1

## 从卡组移除卡牌（移除第一张匹配的卡牌）
func remove_card_from_deck(card_id: String, star_level: int = -1) -> void:
	for i in range(current_deck.size()):
		var entry: Dictionary = current_deck[i]
		if entry.get("card_id", "") == card_id:
			if star_level < 0 or entry.get("star_level", 1) == star_level:
				current_deck.remove_at(i)
				return

## 获取卡组中所有卡牌ID列表（兼容旧接口）
func get_deck_card_ids() -> Array[String]:
	var ids: Array[String] = []
	for entry in current_deck:
		ids.append(entry.get("card_id", ""))
	return ids

## 获取卡组条目（含星级信息）
func get_deck_entry(index: int) -> Dictionary:
	if index < 0 or index >= current_deck.size():
		return {}
	return current_deck[index]

## 添加法宝（支持星级）
func add_relic(relic_id: String, star_level: int = 1) -> void:
	current_relics.append({"relic_id": relic_id, "star_level": star_level})

## 检查是否拥有某个法宝
func has_relic(relic_id: String) -> bool:
	for entry in current_relics:
		if entry.get("relic_id", "") == relic_id:
			return true
	return false

## 获取法宝星级
func get_relic_star(relic_id: String) -> int:
	for entry in current_relics:
		if entry is Dictionary and entry.get("relic_id", "") == relic_id:
			return entry.get("star_level", 1)
	return 0

## 获取可融合的法宝分组
func get_fusable_relic_groups() -> Array:
	var groups: Dictionary = {}  # relic_id+star_level -> {count, indices}
	for i in range(current_relics.size()):
		var entry: Dictionary = current_relics[i]
		var rid: String = entry.get("relic_id", "")
		var star: int = entry.get("star_level", 1)
		var key := "%s_%d" % [rid, star]
		if not groups.has(key):
			groups[key] = {"relic_id": rid, "star_level": star, "count": 0, "indices": []}
		groups[key]["count"] += 1
		groups[key]["indices"].append(i)
	
	var result: Array = []
	for key in groups:
		var group: Dictionary = groups[key]
		group["can_fuse"] = group["count"] >= 2 and group["star_level"] < 3
		var relic_data := DataManager.get_relic(group["relic_id"])
		group["relic_name"] = relic_data.get("relic_name", "???")
		result.append(group)
	return result

## 融合法宝
func fuse_relics(index1: int, index2: int) -> Dictionary:
	if index1 < 0 or index2 < 0 or index1 >= current_relics.size() or index2 >= current_relics.size():
		return {}
	var entry1: Dictionary = current_relics[index1]
	var entry2: Dictionary = current_relics[index2]
	if entry1.get("relic_id", "") != entry2.get("relic_id", ""):
		return {}
	if entry1.get("star_level", 1) != entry2.get("star_level", 1):
		return {}
	var star: int = entry1.get("star_level", 1)
	if star >= 3:
		return {}
	
	# 移除两张（先移除较大索引）
	var max_idx: int = max(index1, index2)
	var min_idx: int = min(index1, index2)
	current_relics.remove_at(max_idx)
	current_relics.remove_at(min_idx)
	
	# 添加升星法宝
	var new_entry := {"relic_id": entry1.get("relic_id", ""), "star_level": star + 1}
	current_relics.append(new_entry)
	return new_entry

## 添加消耗品（丹药）——带上限校验
func add_consumable(consumable_id: String) -> bool:
	if current_consumables.size() >= get_consumable_capacity():
		return false
	current_consumables.append(consumable_id)
	EventBus.consumable_capacity_changed.emit(current_consumables.size(), get_consumable_capacity())
	return true

## 使用消耗品（丹药）
func use_consumable(consumable_id: String) -> void:
	var idx := current_consumables.find(consumable_id)
	if idx >= 0:
		current_consumables.remove_at(idx)
		EventBus.consumable_capacity_changed.emit(current_consumables.size(), get_consumable_capacity())

## 获取丹药实际容量（检测炼丹瓶法宝）
func get_consumable_capacity() -> int:
	var capacity := max_consumable_slots
	# 检测是否拥有炼丹瓶法宝
	if has_relic("lian_dan_ping"):
		capacity += 3  # 炼丹瓶提升上限3颗
	return capacity

## 丹药是否已满
func is_consumable_full() -> bool:
	return current_consumables.size() >= get_consumable_capacity()

## 记录最高伤害
func record_damage(amount: int) -> void:
	if amount > stats.max_single_damage:
		stats.max_single_damage = amount

## 进入下一章节
func advance_chapter() -> void:
	current_chapter += 1
	current_node_index = 0
	if current_chapter >= CHAPTER_NAMES.size():
		# 通关
		change_state(GameState.VICTORY)
		EventBus.game_ended.emit(true)
	else:
		EventBus.next_chapter_entered.emit(current_chapter)

## 获取游戏时长（秒）
func get_play_time() -> int:
	return int(Time.get_unix_time_from_system() - stats.start_time)

## 暂停/恢复游戏
func toggle_pause() -> void:
	is_paused = !is_paused
	get_tree().paused = is_paused
	EventBus.pause_menu_toggled.emit(is_paused)

## 获取当前运行数据（用于存档）
func get_save_data() -> Dictionary:
	return {
		"character_id": current_character_id,
		"current_state": current_state,
		"current_hp": current_hp,
		"max_hp": max_hp,
		"current_mana": current_mana,
		"max_mana": max_mana,
		"current_stamina": current_stamina,
		"max_stamina": max_stamina,
		"current_armor": current_armor,
		"current_strength": current_strength,
		"current_gold": current_gold,
		"current_deck": _serialize_deck(),
		"current_relics": current_relics,
		"current_consumables": current_consumables,
		"current_chapter": current_chapter,
		"current_node_index": current_node_index,
		"current_map_data": current_map_data,
		"stats": stats,
		# 天劫系统
		"current_karma": current_karma,
		"max_karma_reached": max_karma_reached,
		"tribulation_count": tribulation_count,
		# 丹药上限
		"max_consumable_slots": max_consumable_slots,
		# 妖灵容量
		"spirit_capacity": spirit_capacity,
	}

## 从存档数据恢复
func load_save_data(data: Dictionary) -> void:
	current_character_id = data.get("character_id", "")
	current_state = data.get("current_state", GameState.MAP) as GameState
	current_hp = data.get("current_hp", 70)
	max_hp = data.get("max_hp", 70)
	current_mana = data.get("current_mana", 3)
	max_mana = data.get("max_mana", 3)
	current_stamina = data.get("current_stamina", 0)
	max_stamina = data.get("max_stamina", 0)
	current_armor = data.get("current_armor", 0)
	current_strength = data.get("current_strength", 0)
	current_gold = data.get("current_gold", 50)
	_deserialize_deck(data.get("current_deck", []))
	var raw_relics: Array = data.get("current_relics", [])
	current_relics.clear()
	for relic_entry in raw_relics:
		if relic_entry is Dictionary:
			current_relics.append(relic_entry)
		elif relic_entry is String:
			current_relics.append({"relic_id": relic_entry, "star_level": 1})
	current_consumables = Array(data.get("current_consumables", []), TYPE_STRING, "", null)
	current_chapter = data.get("current_chapter", 0)
	current_node_index = data.get("current_node_index", 0)
	current_map_data = data.get("current_map_data", {})
	stats = data.get("stats", stats)
	# 天劫系统
	current_karma = data.get("current_karma", 0)
	max_karma_reached = data.get("max_karma_reached", 0)
	tribulation_count = data.get("tribulation_count", 0)
	# 丹药上限
	max_consumable_slots = data.get("max_consumable_slots", 3)
	# 妖灵容量
	spirit_capacity = data.get("spirit_capacity", 3)
	
	# 通知UI更新
	EventBus.health_changed.emit(current_hp, max_hp)
	EventBus.mana_changed.emit(current_mana, max_mana)
	EventBus.gold_changed.emit(current_gold)
	EventBus.armor_changed.emit(current_armor)
	EventBus.strength_changed.emit(current_strength)
	if max_stamina > 0:
		EventBus.stamina_changed.emit(current_stamina, max_stamina)

## 序列化卡组数据（用于存档）
func _serialize_deck() -> Array:
	var result: Array = []
	for entry in current_deck:
		result.append(entry)
	return result

## 反序列化卡组数据（从存档恢复）
func _deserialize_deck(data: Array) -> void:
	current_deck.clear()
	for entry in data:
		if entry is Dictionary:
			current_deck.append(entry)
		elif entry is String:
			# 兼容旧存档的String格式
			current_deck.append({"card_id": entry, "star_level": 1})
