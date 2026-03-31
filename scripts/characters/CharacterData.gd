## 角色数据管理类 - 管理角色初始化和属性
class_name CharacterData
extends Resource

@export var character_id: String = ""
@export var character_name: String = ""
@export var max_hp: int = 70
@export var mana: int = 3
@export var stamina: int = 0
@export var gold: int = 50
@export var passive_id: String = ""
@export var passive_name: String = ""
@export var passive_description: String = ""
@export var unlock_condition: String = "none"
@export var unlock_achievement: String = ""
@export var starter_deck: Array[String] = []
@export var bailongma_hp: int = 0  # 大唐圣僧专属

## 从字典数据初始化
static func from_dict(data: Dictionary) -> CharacterData:
	var character := CharacterData.new()
	character.character_id = data.get("character_id", "")
	character.character_name = data.get("character_name", "")
	character.max_hp = data.get("max_hp", 70)
	character.mana = data.get("mana", 3)
	character.stamina = data.get("stamina", 0)
	character.gold = data.get("gold", 50)
	character.passive_id = data.get("passive_id", "")
	character.passive_name = data.get("passive_name", "")
	character.passive_description = data.get("passive_description", "")
	character.unlock_condition = data.get("unlock_condition", "none")
	character.unlock_achievement = data.get("unlock_achievement", "")
	character.bailongma_hp = data.get("bailongma_hp", 0)
	
	var deck_data: Array = data.get("starter_deck", [])
	for card_id in deck_data:
		character.starter_deck.append(str(card_id))
	
	return character

## 初始化角色到GameManager
func apply_to_game() -> void:
	GameManager.start_new_game(character_id)
	GameManager.init_character_stats(max_hp, mana, gold, stamina, starter_deck.duplicate())
	
	# 角色专属初始化
	match character_id:
		"sha_wujing":
			# 卷帘大将：每10点生命护甲+1
			var bonus_armor := max_hp / 10
			GameManager.modify_armor(bonus_armor)
		"tang_seng":
			# 大唐圣僧：初始化白龙马数据
			GameManager.current_character = self

## 获取角色描述信息
func get_info_text() -> String:
	var info := "生命值: %d\n法力: %d\n" % [max_hp, mana]
	if stamina > 0:
		info += "体力: %d\n" % stamina
	info += "金币: %d\n" % gold
	info += "\n被动技能: %s\n%s" % [passive_name, passive_description]
	return info

## 获取角色颜色（用于UI标识）
func get_character_color() -> Color:
	match character_id:
		"sun_wukong": return Color("D63031")  # 朱砂红
		"zhu_bajie": return Color("00B894")   # 翠绿
		"sha_wujing": return Color("0984E3")  # 靛青蓝
		"tang_seng": return Color("FDCB6E")   # 金色
	return Color.WHITE
