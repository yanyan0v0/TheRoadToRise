## 卡牌数据资源类
class_name CardData
extends Resource

## 卡牌类型枚举
enum CardType {
	ATTACK,    # 攻击牌
	SKILL,     # 技能牌
	ULTIMATE,  # 终结技
	SPIRIT,    # 妖灵召唤
}

## 卡牌稀有度枚举
enum CardRarity {
	COMMON,     # 普通（白色）
	UNCOMMON,   # 优秀（绿色）
	RARE,       # 稀有（蓝色）
	LEGENDARY,  # 传说（橙色）
}

@export var card_id: String = ""
@export var card_name: String = ""
@export var card_type: CardType = CardType.ATTACK
@export var card_types: Array[String] = []  # All types from JSON card_type array
@export var rarity: CardRarity = CardRarity.COMMON
@export var energy_cost: int = 1
@export var star_2_energy_cost: int = -1  # 2星费用（-1表示未设置，使用默认energy_cost）
@export var star_3_energy_cost: int = -1  # 3星费用（-1表示未设置，使用默认energy_cost）
@export var stamina_cost: int = 0  # 体力消耗（天蓬元帅专属）
@export var description: String = ""
@export var character_exclusive: String = ""  # 空字符串表示通用

## 星级属性（1-3星）
@export var star_level: int = 1

## 卡牌效果数组，每个效果是一个字典（1星基础效果）
## 格式: {"type": "damage/armor/heal/status/draw/mana/special", "value": 数值, "target": "enemy/self/all_enemies", ...}
@export var effects: Array[Dictionary] = []

## 2星效果数组（融合升星后使用）
@export var star_2_effects: Array[Dictionary] = []

## 3星效果数组（融合升星后使用，含额外特效）
@export var star_3_effects: Array[Dictionary] = []

## 获取稀有度颜色
func get_rarity_color() -> Color:
	match rarity:
		CardRarity.COMMON:
			return Color.WHITE
		CardRarity.UNCOMMON:
			return Color("00B894")  # 翠绿
		CardRarity.RARE:
			return Color("0984E3")  # 靛青蓝
		CardRarity.LEGENDARY:
			return Color("FDCB6E")  # 金色
	return Color.WHITE

## 获取类型名称
func get_type_name() -> String:
	var names: Array[String] = []
	for t in card_types:
		match t:
			"attack": names.append("攻击")
			"defense": names.append("防御")
			"skill": names.append("技能")
			"summon": names.append("召唤")
	if names.is_empty():
		match card_type:
			CardType.ATTACK: return "攻击"
			CardType.SKILL: return "技能"
			CardType.ULTIMATE: return "终结技"
			CardType.SPIRIT: return "召唤"
		return "未知"
	return "/".join(names)

## 获取稀有度名称
func get_rarity_name() -> String:
	match rarity:
		CardRarity.COMMON:
			return "普通"
		CardRarity.UNCOMMON:
			return "优秀"
		CardRarity.RARE:
			return "稀有"
		CardRarity.LEGENDARY:
			return "传说"
	return "未知"

## 获取显示名称
func get_display_name() -> String:
	var display := card_name
	display += " " + get_star_display()
	return display

## 获取星级显示标识
func get_star_display() -> String:
	match star_level:
		1: return "★☆☆"
		2: return "★★☆"
		3: return "★★★"
	return "★☆☆"

## 获取星级名称
func get_star_name() -> String:
	match star_level:
		1: return "1星"
		2: return "2星"
		3: return "3星"
	return "1星"

## 获取星级颜色
func get_star_color() -> Color:
	match star_level:
		1: return Color.WHITE
		2: return Color("00B894")  # Green
		3: return Color("A855F7")  # Purple
	return Color.WHITE

## 获取当前星级对应的效果数组
func get_effects_for_star() -> Array[Dictionary]:
	match star_level:
		2:
			if not star_2_effects.is_empty():
				return star_2_effects
		3:
			if not star_3_effects.is_empty():
				return star_3_effects
	return effects

## 获取当前星级对应的费用（实例方法）
func get_energy_cost_for_star() -> int:
	if star_level >= 3 and star_3_energy_cost >= 0:
		return star_3_energy_cost
	elif star_level >= 2 and star_2_energy_cost >= 0:
		return star_2_energy_cost
	return energy_cost

## 根据卡牌字典数据和星级获取对应的费用（静态公共方法，供外部统一调用）
static func get_card_energy_cost(data: Dictionary) -> int:
	var slv: int = data.get("star_level", 1)
	if slv >= 3 and data.has("star_3_energy_cost"):
		return data.get("star_3_energy_cost")
	elif slv >= 2 and data.has("star_2_energy_cost"):
		return data.get("star_2_energy_cost")
	return data.get("energy_cost", 1)

## 是否可以继续融合升星
func can_fuse() -> bool:
	return star_level < 3

## 从字典数据初始化
static func from_dict(data: Dictionary) -> CardData:
	var card := CardData.new()
	card.card_id = data.get("card_id", "")
	card.card_name = data.get("card_name", "")
	
	# 解析卡牌类型（支持数组和字符串格式）
	var type_raw = data.get("card_type", "attack")
	var type_arr: Array = type_raw if type_raw is Array else [type_raw]
	card.card_types = []
	for t in type_arr:
		card.card_types.append(str(t))
	# Set primary card_type from first element
	var primary_type: String = type_arr[0] if not type_arr.is_empty() else "attack"
	match primary_type:
		"attack": card.card_type = CardType.ATTACK
		"skill": card.card_type = CardType.SKILL
		"defense": card.card_type = CardType.SKILL  # defense maps to SKILL enum
		"ultimate": card.card_type = CardType.ULTIMATE
		"spirit", "summon": card.card_type = CardType.SPIRIT
	
	# 解析稀有度
	var rarity_str: String = data.get("rarity", "common")
	match rarity_str:
		"common": card.rarity = CardRarity.COMMON
		"uncommon": card.rarity = CardRarity.UNCOMMON
		"rare": card.rarity = CardRarity.RARE
		"legendary": card.rarity = CardRarity.LEGENDARY
	
	card.energy_cost = data.get("energy_cost", 1)
	card.star_2_energy_cost = data.get("star_2_energy_cost", -1)
	card.star_3_energy_cost = data.get("star_3_energy_cost", -1)
	card.stamina_cost = data.get("stamina_cost", 0)
	card.description = data.get("description", "")
	card.character_exclusive = data.get("character_exclusive", "")
	card.star_level = data.get("star_level", 1)
	
	# 解析效果
	var effects_data: Array = data.get("effects", [])
	for effect in effects_data:
		card.effects.append(effect)
	
	# 解析星级效果
	var star_2_data: Array = data.get("star_2_effects", [])
	for effect in star_2_data:
		card.star_2_effects.append(effect)
	
	var star_3_data: Array = data.get("star_3_effects", [])
	for effect in star_3_data:
		card.star_3_effects.append(effect)
	
	return card
