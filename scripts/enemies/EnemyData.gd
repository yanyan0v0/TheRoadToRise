## 敌人数据资源类
class_name EnemyData
extends Resource

## 敌人类型枚举
enum EnemyType {
	NORMAL,   # 普通敌人
	ELITE,    # 精英敌人
	BOSS,     # BOSS
}

## 意图类型枚举
enum IntentType {
	ATTACK,         # 攻击 ⚔️
	DEFEND,         # 防御 🛡️
	SPECIAL,        # 特殊技能 🔮
	RANDOM,         # 随机 ❓
	HEAVY_ATTACK,   # 高伤害攻击 💀
	BUFF,           # 增益
	DEBUFF,         # 减益
	SUMMON,         # 召唤
}

@export var enemy_id: String = ""
@export var enemy_name: String = ""
@export var enemy_type: EnemyType = EnemyType.NORMAL
@export var max_hp: int = 30
@export var base_armor: int = 0
@export var description: String = ""

## 意图模式（普通敌人使用循环模式）
## 格式: [{"type": "attack", "value": 8}, {"type": "defend", "value": 5}, ...]
@export var intent_pattern: Array[Dictionary] = []

## 技能列表
## 格式: [{"skill_id": "xxx", "name": "技能名", "effects": [...], "intent_type": "attack", "value": 10}]
@export var skills: Array[Dictionary] = []

## BOSS阶段阈值（生命百分比触发）
## 格式: [{"threshold": 0.5, "phase": 2, "new_skills": [...]}, ...]
@export var phase_thresholds: Array[Dictionary] = []

## 掉落物
@export var drops: Dictionary = {}

## 获取意图图标文本
static func get_intent_icon(intent_type: IntentType) -> String:
	match intent_type:
		IntentType.ATTACK: return "⚔️"
		IntentType.DEFEND: return "🛡️"
		IntentType.SPECIAL: return "🔮"
		IntentType.RANDOM: return "❓"
		IntentType.HEAVY_ATTACK: return "💀"
		IntentType.BUFF: return "✨"
		IntentType.DEBUFF: return "💜"
		IntentType.SUMMON: return "👻"
	return "❓"

## 从字典数据初始化
static func from_dict(data: Dictionary) -> EnemyData:
	var enemy := EnemyData.new()
	enemy.enemy_id = data.get("enemy_id", "")
	enemy.enemy_name = data.get("enemy_name", "")
	enemy.max_hp = data.get("max_hp", 30)
	enemy.base_armor = data.get("base_armor", 0)
	enemy.description = data.get("description", "")
	
	# 解析敌人类型
	var type_str: String = data.get("enemy_type", "normal")
	match type_str:
		"normal": enemy.enemy_type = EnemyType.NORMAL
		"elite": enemy.enemy_type = EnemyType.ELITE
		"boss": enemy.enemy_type = EnemyType.BOSS
	
	# 解析意图模式
	var pattern_data: Array = data.get("intent_pattern", [])
	for p in pattern_data:
		enemy.intent_pattern.append(p)
	
	# 解析技能
	var skills_data: Array = data.get("skills", [])
	for s in skills_data:
		enemy.skills.append(s)
	
	# 解析阶段阈值
	var phases_data: Array = data.get("phase_thresholds", [])
	for ph in phases_data:
		enemy.phase_thresholds.append(ph)
	
	enemy.drops = data.get("drops", {})
	
	return enemy
