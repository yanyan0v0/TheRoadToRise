## 状态效果管理器 - 管理所有正面和负面状态效果
class_name StatusEffectManager
extends Node

## 状态效果类型
enum EffectType {
	# 正面状态
	GOLDEN_BODY,   # 金身：下次伤害降至1
	REGENERATION,  # 治愈：每层每回合+1生命
	THORNS,        # 反甲：受伤时反弹
	OVERCHARGE,    # 充盈：下回合法力+1
	AGILITY,       # 敏捷：法力消耗-1
	# 负面状态
	ARMOR_BREAK,   # 破甲：护甲减少
	SLOW,          # 减速：出牌数-1
	BURN,          # 灼烧：每层每回合-1生命
	SEAL,          # 封印：无法使用技能牌
	VULNERABLE,    # 易伤：受到伤害+1每层
	# 特殊状态
	STUN,          # 眩晕：无法行动
	COUNTER,       # 反击：受伤时反击
	DAMAGE_HALVE,  # 伤害减半
	WEAKEN,        # 弱化：攻击力降低
}

## 状态效果颜色
const EFFECT_COLORS := {
	"golden_body": Color("FDCB6E"),    # 金色
	"regeneration": Color("00B894"),   # 绿色
	"thorns": Color("CD7F32"),         # 铜色
	"overcharge": Color("0984E3"),     # 蓝色
	"agility": Color("6C5CE7"),        # 紫色
	"armor_break": Color("636E72"),    # 灰色
	"slow": Color("00CEC9"),           # 青色
	"burn": Color("E17055"),           # 橙色
	"seal": Color("D63031"),           # 红色
	"vulnerable": Color("FDCB6E"),     # 黄色
	"stun": Color("636E72"),           # 灰色
	"counter": Color("D63031"),        # 红色
	"damage_halve": Color("0984E3"),   # 蓝色
	"weaken": Color("636E72"),         # 灰色
}

## 状态效果名称
const EFFECT_NAMES := {
	"golden_body": "金身",
	"regeneration": "治愈",
	"thorns": "反甲",
	"overcharge": "充盈",
	"agility": "敏捷",
	"armor_break": "破甲",
	"slow": "减速",
	"burn": "灼烧",
	"seal": "封印",
	"vulnerable": "易伤",
	"stun": "眩晕",
	"counter": "反击",
	"damage_halve": "伤害减半",
	"weaken": "弱化",
}

## 当前状态效果 {effect_type_string: stacks}
var effects: Dictionary = {}

## 施加状态效果
func apply_effect(effect_type: String, stacks: int = 1) -> void:
	if effects.has(effect_type):
		effects[effect_type] += stacks
	else:
		effects[effect_type] = stacks
	
	print("[StatusEffect] 施加 %s x%d (总计: %d)" % [
		EFFECT_NAMES.get(effect_type, effect_type),
		stacks,
		effects[effect_type]
	])

## 移除状态效果
func remove_effect(effect_type: String, stacks: int = -1) -> void:
	if not effects.has(effect_type):
		return
	
	if stacks < 0:
		effects.erase(effect_type)
	else:
		effects[effect_type] -= stacks
		if effects[effect_type] <= 0:
			effects.erase(effect_type)

## 获取状态效果层数
func get_stacks(effect_type: String) -> int:
	return effects.get(effect_type, 0)

## 是否有指定状态
func has_effect(effect_type: String) -> bool:
	return effects.has(effect_type) and effects[effect_type] > 0

## 清除所有状态
func clear_all() -> void:
	effects.clear()

## 清除所有负面状态
func clear_debuffs() -> void:
	var debuffs := ["armor_break", "slow", "burn", "seal", "vulnerable", "stun", "weaken"]
	for debuff in debuffs:
		effects.erase(debuff)

## 清除所有正面状态
func clear_buffs() -> void:
	var buffs := ["golden_body", "regeneration", "thorns", "overcharge", "agility", "counter", "damage_halve"]
	for buff in buffs:
		effects.erase(buff)

## 回合开始结算
func on_turn_start() -> Dictionary:
	var results := {
		"mana_bonus": 0,
		"mana_reduction": 0,
		"card_limit_reduction": 0,
	}
	
	# 充盈：下回合法力+1
	if has_effect("overcharge"):
		results.mana_bonus = get_stacks("overcharge")
		remove_effect("overcharge")
	
	# 敏捷：法力消耗-1（在打牌时处理）
	
	# 减速：出牌数-1
	if has_effect("slow"):
		results.card_limit_reduction = get_stacks("slow")
	
	return results

## 回合结束结算
func on_turn_end() -> Dictionary:
	var results := {
		"damage": 0,
		"heal": 0,
	}
	
	# 灸烧：每层每回合-1生命
	if has_effect("burn"):
		results.damage += get_stacks("burn")
	
	# 治愈：每层每回合+1生命
	if has_effect("regeneration"):
		results.heal += get_stacks("regeneration")
	
	# 所有状态效果每回合-1层
	var effects_to_decay: Array = effects.keys()
	for effect_type in effects_to_decay:
		remove_effect(effect_type, 1)
	
	return results
## 处理受到伤害时的效果
func on_damage_taken(damage: int, attacker_status: StatusEffectManager) -> Dictionary:
	var results := {
		"modified_damage": damage,
		"reflect_damage": 0,
		"prevent_death": false,
	}
	
	# 金身：伤害降至1
	if has_effect("golden_body"):
		results.modified_damage = 1
		remove_effect("golden_body", 1)
	
	# 伤害减半
	if has_effect("damage_halve"):
		results.modified_damage = results.modified_damage / 2
	
	# 反甲：反弹伤害
	if has_effect("thorns"):
		results.reflect_damage = get_stacks("thorns")
	
	# 反击：反弹等量伤害
	if has_effect("counter"):
		results.reflect_damage += results.modified_damage
	
	return results

## 获取所有状态效果列表（用于UI显示）
func get_all_effects() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for effect_type in effects:
		result.append({
			"type": effect_type,
			"name": EFFECT_NAMES.get(effect_type, effect_type),
			"stacks": effects[effect_type],
			"color": EFFECT_COLORS.get(effect_type, Color.WHITE),
		})
	return result
