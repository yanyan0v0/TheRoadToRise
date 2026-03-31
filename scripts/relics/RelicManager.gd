## 法宝管理器 - 管理法宝的触发和效果
class_name RelicManager
extends Node

signal relic_triggered(relic_id: String, effect_description: String)

## 当前持有的法宝数据
var relics: Array[Dictionary] = []

## 法宝触发计数器
var _trigger_counts: Dictionary = {}

## 初始化法宝列表
func init_relics(relic_ids: Array) -> void:
	relics.clear()
	_trigger_counts.clear()
	
	for relic_id in relic_ids:
		var data := DataManager.get_relic(relic_id)
		if not data.is_empty():
			relics.append(data)
			_trigger_counts[relic_id] = 0

## 触发指定时机的法宝效果
func trigger_relics(trigger_type: String, context: Dictionary = {}) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	
	for relic in relics:
		var relic_trigger: String = relic.get("trigger_type", "")
		if relic_trigger != trigger_type:
			continue
		
		var effect := _execute_relic_effect(relic, context)
		if not effect.is_empty():
			results.append(effect)
			var relic_id: String = relic.get("relic_id", "")
			_trigger_counts[relic_id] = _trigger_counts.get(relic_id, 0) + 1
			relic_triggered.emit(relic_id, effect.get("description", ""))
	
	return results

## 执行法宝效果
func _execute_relic_effect(relic: Dictionary, context: Dictionary) -> Dictionary:
	var relic_id: String = relic.get("relic_id", "")
	var effects: Array = relic.get("effects", [])
	var result := {}
	
	match relic_id:
		"jingu_bang":
			# 紧箍圈：每场战斗开始获得1点力量
			GameManager.modify_strength(1)
			result = {"type": "strength", "value": 1, "description": "紧箍圈：力量+1"}
		
		"ba_jiao_shan":
			# 芭蕉扇：攻击时20%概率双倍伤害
			if randf() < 0.2:
				result = {"type": "double_damage", "value": 2, "description": "芭蕉扇：双倍伤害！"}
		
		"guan_yin_ping":
			# 观音玉瓶：首次致命伤害保留1点生命（一次性）
			if context.get("lethal", false) and _trigger_counts.get(relic_id, 0) == 0:
				GameManager.current_hp = 1
				result = {"type": "prevent_death", "value": 1, "description": "观音玉瓶：免死一次！"}
		
		"feng_huo_lun":
			# 风火轮：每场战斗开始获得2点护甲
			GameManager.modify_armor(2)
			result = {"type": "armor", "value": 2, "description": "风火轮：护甲+2"}
		
		"zhen_yao_ta":
			# 镇妖塔：每场战斗开始获得10点护甲
			GameManager.modify_armor(10)
			result = {"type": "armor", "value": 10, "description": "镇妖塔：护甲+10"}
		
		"jin_lan_jia_sha":
			# 金兰袈裟：每回合开始恢复2点生命
			GameManager.modify_hp(2)
			result = {"type": "heal", "value": 2, "description": "金兰袈裟：恢复2点生命"}
		
		"zi_jin_hong_lu":
			# 紫金红葫芦：每击败一个敌人获得10金币
			GameManager.modify_gold(10)
			result = {"type": "gold", "value": 10, "description": "紫金红葫芦：获得10金币"}
		
		"bi_huo_zhao":
			# 避火罩：免疫灼烧效果
			result = {"type": "immunity", "value": 0, "description": "避火罩：免疫灼烧"}
		
		"ding_hai_shen_zhen":
			# 定海神针：每3回合获得一张额外手牌
			if context.get("turn_number", 0) % 3 == 0:
				result = {"type": "draw", "value": 1, "description": "定海神针：额外抽1张牌"}
		
		"ru_yi_jin_gu_bang":
			# 如意金箍棒：力量每增加1点，额外+1伤害
			var strength_bonus: int = context.get("strength_gained", 0)
			if strength_bonus > 0:
				result = {"type": "extra_damage", "value": strength_bonus, "description": "如意金箍棒：额外伤害+%d" % strength_bonus}
		
		_:
			# 通用效果处理
			for effect in effects:
				_apply_generic_effect(effect)
			result = {"type": "generic", "value": 0, "description": relic.get("relic_name", "") + " 触发"}
	
	return result

## 应用通用效果
func _apply_generic_effect(effect: Dictionary) -> void:
	var effect_type: String = effect.get("type", "")
	var value: int = effect.get("value", 0)
	
	match effect_type:
		"armor":
			GameManager.modify_armor(value)
		"heal":
			GameManager.modify_hp(value)
		"strength":
			GameManager.modify_strength(value)
		"gold":
			GameManager.modify_gold(value)
		"draw":
			pass  # 需要DeckManager处理

## 检查是否持有指定法宝
func has_relic(relic_id: String) -> bool:
	for relic in relics:
		if relic.get("relic_id", "") == relic_id:
			return true
	return false

## 获取所有法宝数据（用于UI显示）
func get_all_relics() -> Array[Dictionary]:
	return relics

## 获取法宝数量
func get_relic_count() -> int:
	return relics.size()
