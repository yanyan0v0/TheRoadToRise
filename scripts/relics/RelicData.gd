## 法宝数据资源类
class_name RelicData
extends Resource

## 法宝触发类型
enum TriggerType {
	ON_BATTLE_START,    # 战斗开始时
	ON_ATTACK,          # 攻击时
	ON_TAKE_DAMAGE,     # 受到伤害时
	ON_KILL,            # 击杀敌人时
	ON_TURN_START,      # 回合开始时
	ON_TURN_END,        # 回合结束时
	ON_CARD_PLAY,       # 打出卡牌时
	ON_FATAL_DAMAGE,    # 受到致命伤害时
	PASSIVE,            # 被动效果
}

## 法宝稀有度
enum RelicRarity {
	COMMON,
	UNCOMMON,
	RARE,
	LEGENDARY,
}

@export var relic_id: String = ""
@export var relic_name: String = ""
@export var rarity: RelicRarity = RelicRarity.COMMON
@export var trigger_type: TriggerType = TriggerType.PASSIVE
@export var description: String = ""
@export var star_level: int = 1  # 星级（1-3）

## 效果列表
## 格式: {"type": "armor/damage/heal/draw/mana", "value": 数值, "chance": 概率(0-1)}
@export var effects: Array[Dictionary] = []
## 2星效果
@export var star_2_effects: Array[Dictionary] = []
## 3星效果
@export var star_3_effects: Array[Dictionary] = []
## 2星描述
@export var star_2_description: String = ""
## 3星描述
@export var star_3_description: String = ""

## 获取星级显示
func get_star_display() -> String:
	match star_level:
		1: return "★☆☆"
		2: return "★★☆"
		3: return "★★★"
	return "★☆☆"

## 获取当前星级的效果
func get_effects_for_star() -> Array[Dictionary]:
	match star_level:
		2:
			if not star_2_effects.is_empty():
				return star_2_effects
		3:
			if not star_3_effects.is_empty():
				return star_3_effects
	return effects

## 获取当前星级的描述
func get_description_for_star() -> String:
	match star_level:
		2:
			if not star_2_description.is_empty():
				return star_2_description
		3:
			if not star_3_description.is_empty():
				return star_3_description
	return description

## 获取显示名称（含星级）
func get_display_name() -> String:
	return "%s %s" % [relic_name, get_star_display()]

## 获取稀有度颜色
func get_rarity_color() -> Color:
	match rarity:
		RelicRarity.COMMON: return Color.WHITE
		RelicRarity.UNCOMMON: return Color("00B894")
		RelicRarity.RARE: return Color("0984E3")
		RelicRarity.LEGENDARY: return Color("FDCB6E")
	return Color.WHITE

## 从字典数据初始化
static func from_dict(data: Dictionary) -> RelicData:
	var relic := RelicData.new()
	relic.relic_id = data.get("relic_id", "")
	relic.relic_name = data.get("relic_name", "")
	relic.description = data.get("description", "")
	relic.star_level = data.get("star_level", 1)
	relic.star_2_description = data.get("star_2_description", "")
	relic.star_3_description = data.get("star_3_description", "")
	
	var rarity_str: String = data.get("rarity", "common")
	match rarity_str:
		"common": relic.rarity = RelicRarity.COMMON
		"uncommon": relic.rarity = RelicRarity.UNCOMMON
		"rare": relic.rarity = RelicRarity.RARE
		"legendary": relic.rarity = RelicRarity.LEGENDARY
	
	var trigger_str: String = data.get("trigger_type", "passive")
	match trigger_str:
		"on_battle_start": relic.trigger_type = TriggerType.ON_BATTLE_START
		"on_attack": relic.trigger_type = TriggerType.ON_ATTACK
		"on_take_damage": relic.trigger_type = TriggerType.ON_TAKE_DAMAGE
		"on_kill": relic.trigger_type = TriggerType.ON_KILL
		"on_turn_start": relic.trigger_type = TriggerType.ON_TURN_START
		"on_turn_end": relic.trigger_type = TriggerType.ON_TURN_END
		"on_card_play": relic.trigger_type = TriggerType.ON_CARD_PLAY
		"on_fatal_damage": relic.trigger_type = TriggerType.ON_FATAL_DAMAGE
		"passive": relic.trigger_type = TriggerType.PASSIVE
	
	var effects_data: Array = data.get("effects", [])
	for e in effects_data:
		relic.effects.append(e)
	
	var star_2_data: Array = data.get("star_2_effects", [])
	for e in star_2_data:
		relic.star_2_effects.append(e)
	
	var star_3_data: Array = data.get("star_3_effects", [])
	for e in star_3_data:
		relic.star_3_effects.append(e)
	
	return relic
