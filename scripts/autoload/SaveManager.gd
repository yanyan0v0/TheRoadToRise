## 存档管理器 - 管理游戏存档的读写、版本管理和错误处理
extends Node

# ===== 存档配置 =====
const SAVE_PATH := "user://save_game.json"
const ACHIEVEMENT_PATH := "user://achievements.json"
const SAVE_VERSION := 1

# ===== 存档状态 =====
var has_valid_save: bool = false

# ===== 成就数据（永久保存） =====
var achievements: Dictionary = {}
var unlocked_characters: Array[String] = ["sun_wukong"]  # 齐天大圣默认解锁
var total_clears: int = 0
## 已解锁的内容（按类型存储）
var unlocked_content: Dictionary = {
	"new_pill": [],
	"new_card": [],
	"new_relic": [],
	"new_event": [],
}
## 累计统计数据
var persistent_stats: Dictionary = {}

func _ready() -> void:
	_check_save_exists()
	_load_achievements()

## 检查是否存在有效存档
func _check_save_exists() -> void:
	has_valid_save = FileAccess.file_exists(SAVE_PATH)
	if has_valid_save:
		# 验证存档完整性
		var data := _read_json_file(SAVE_PATH)
		if data.is_empty() or not data.has("version"):
			has_valid_save = false
			push_warning("[SaveManager] 存档文件损坏，标记为无效")

## 保存游戏进度
func save_game() -> bool:
	var save_data := {
		"version": SAVE_VERSION,
		"timestamp": Time.get_datetime_string_from_system(),
		"game_data": GameManager.get_save_data(),
	}
	
	var success := _write_json_file(SAVE_PATH, save_data)
	if success:
		has_valid_save = true
		print("[SaveManager] 游戏进度已保存")
	else:
		push_error("[SaveManager] 保存游戏进度失败")
	return success

## 加载游戏进度
func load_game() -> bool:
	if not has_valid_save:
		push_warning("[SaveManager] 没有有效的存档")
		return false
	
	var data := _read_json_file(SAVE_PATH)
	if data.is_empty():
		push_error("[SaveManager] 读取存档失败")
		has_valid_save = false
		return false
	
	# 版本检查与迁移
	var save_version: int = data.get("version", 0)
	if save_version != SAVE_VERSION:
		data = _migrate_save_data(data, save_version)
		if data.is_empty():
			push_error("[SaveManager] 存档版本迁移失败")
			return false
	
	# 恢复游戏数据
	var game_data: Dictionary = data.get("game_data", {})
	if game_data.is_empty():
		push_error("[SaveManager] 存档数据为空")
		return false
	
	GameManager.load_save_data(game_data)
	print("[SaveManager] 游戏进度已加载")
	return true

## 删除存档
func delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
	has_valid_save = false
	print("[SaveManager] 存档已删除")

## 保存成就数据（永久）
func save_achievements() -> bool:
	var data := {
		"version": SAVE_VERSION,
		"achievements": achievements,
		"unlocked_characters": unlocked_characters,
		"total_clears": total_clears,
		"unlocked_content": unlocked_content,
		"persistent_stats": persistent_stats,
	}
	
	var success := _write_json_file(ACHIEVEMENT_PATH, data)
	if success:
		print("[SaveManager] 成就数据已保存")
	return success

## 加载成就数据
func _load_achievements() -> void:
	if not FileAccess.file_exists(ACHIEVEMENT_PATH):
		return
	
	var data := _read_json_file(ACHIEVEMENT_PATH)
	if data.is_empty():
		return
	
	achievements = data.get("achievements", {})
	var chars_array: Array = data.get("unlocked_characters", ["sun_wukong"])
	unlocked_characters.clear()
	for c in chars_array:
		unlocked_characters.append(str(c))
	total_clears = data.get("total_clears", 0)
	
	# 加载解锁内容
	var content_data: Dictionary = data.get("unlocked_content", {})
	for key in unlocked_content.keys():
		var arr: Array = content_data.get(key, [])
		unlocked_content[key] = arr
	
	# 加载统计数据
	persistent_stats = data.get("persistent_stats", {})

## 解锁成就
func unlock_achievement(achievement_id: String, achievement_name: String) -> void:
	if achievements.has(achievement_id):
		return
	
	achievements[achievement_id] = {
		"name": achievement_name,
		"unlocked_at": Time.get_datetime_string_from_system(),
	}
	save_achievements()
	EventBus.achievement_unlocked.emit(achievement_id, achievement_name)
	print("[SaveManager] 成就解锁: %s" % achievement_name)

## 解锁角色
func unlock_character(character_id: String) -> void:
	if character_id in unlocked_characters:
		return
	
	unlocked_characters.append(character_id)
	save_achievements()
	EventBus.character_unlocked.emit(character_id)
	print("[SaveManager] 角色解锁: %s" % character_id)

## 检查角色是否已解锁
func is_character_unlocked(character_id: String) -> bool:
	return character_id in unlocked_characters

## 检查成就是否已解锁
func is_achievement_unlocked(achievement_id: String) -> bool:
	return achievements.has(achievement_id)

## 增加通关次数
func increment_clear_count() -> void:
	total_clears += 1
	save_achievements()

## 解锁内容
func unlock_content(content_type: String, content_id: String) -> void:
	if not unlocked_content.has(content_type):
		unlocked_content[content_type] = []
	var arr: Array = unlocked_content[content_type]
	if content_id in arr:
		return
	arr.append(content_id)
	unlocked_content[content_type] = arr
	save_achievements()
	print("[SaveManager] 内容解锁: [%s] %s" % [content_type, content_id])

## 检查内容是否已解锁
func is_content_unlocked(content_type: String, content_id: String) -> bool:
	if not unlocked_content.has(content_type):
		return false
	return content_id in unlocked_content[content_type]

## 获取统计数据
func get_stat(stat_name: String, default_value: int = 0) -> int:
	return persistent_stats.get(stat_name, default_value)

## 增加统计数据
func increment_stat(stat_name: String, amount: int = 1) -> void:
	var current: int = persistent_stats.get(stat_name, 0)
	persistent_stats[stat_name] = current + amount
	save_achievements()

## 存档数据版本迁移
func _migrate_save_data(data: Dictionary, from_version: int) -> Dictionary:
	print("[SaveManager] 迁移存档数据: v%d -> v%d" % [from_version, SAVE_VERSION])
	# 未来版本迁移逻辑在此添加
	# 例如: if from_version == 0: ...
	data["version"] = SAVE_VERSION
	return data

## 写入JSON文件
func _write_json_file(path: String, data: Dictionary) -> bool:
	var json_string := JSON.stringify(data, "\t")
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("[SaveManager] 无法打开文件写入: %s, 错误: %s" % [path, FileAccess.get_open_error()])
		return false
	
	file.store_string(json_string)
	file.close()
	return true

## 读取JSON文件
func _read_json_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("[SaveManager] 无法打开文件读取: %s" % path)
		return {}
	
	var json_string := file.get_as_text()
	file.close()
	
	var json := JSON.new()
	var error := json.parse(json_string)
	if error != OK:
		push_error("[SaveManager] JSON解析失败: %s, 行: %d" % [json.get_error_message(), json.get_error_line()])
		return {}
	
	if json.data is Dictionary:
		return json.data
	
	return {}
