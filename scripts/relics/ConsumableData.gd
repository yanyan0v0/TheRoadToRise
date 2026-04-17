## 丹药数据资源类（原消耗品系统改造为丹药体系）
class_name ConsumableData
extends Resource

## 丹药品质枚举
enum PillQuality {
	LOW,        # 下品
	MID,        # 中品
	HIGH,       # 上品
	EXTREME,    # 极品
}

## 使用场景枚举
enum UseScene {
	BATTLE,     # 仅战斗中
	ANYTIME,    # 任意时刻
	PASSIVE,    # 被动触发（如死亡时自动使用）
}

@export var consumable_id: String = ""
@export var consumable_name: String = ""
@export var description: String = ""
@export var price: int = 0  # 商店价格
@export var quality: PillQuality = PillQuality.LOW
@export var use_scene: UseScene = UseScene.ANYTIME

## 效果列表
## 格式: {"type": "heal/max_hp/damage/strength/mana/draw", "value": 数值, "target": "self/enemy", "duration": "permanent/battle"}
@export var effects: Array[Dictionary] = []

## 获取品质名称
func get_quality_name() -> String:
	match quality:
		PillQuality.LOW: return "下品"
		PillQuality.MID: return "中品"
		PillQuality.HIGH: return "上品"
		PillQuality.EXTREME: return "极品"
	return "下品"

## 获取品质颜色
func get_quality_color() -> Color:
	match quality:
		PillQuality.LOW: return Color.WHITE           # 白色
		PillQuality.MID: return Color("00B894")        # 绿色
		PillQuality.HIGH: return Color("0984E3")       # 蓝色
		PillQuality.EXTREME: return Color("FDCB6E")    # 金色
	return Color.WHITE

## 获取使用场景名称
func get_use_scene_name() -> String:
	match use_scene:
		UseScene.BATTLE: return "战斗中"
		UseScene.ANYTIME: return "任意时刻"
		UseScene.PASSIVE: return "被动"
	return "任意时刻"

## 是否可在战斗中使用
func can_use_in_battle() -> bool:
	return use_scene == UseScene.BATTLE or use_scene == UseScene.ANYTIME

## 是否可在地图中使用
func can_use_on_map() -> bool:
	return use_scene == UseScene.ANYTIME

## 从字典数据初始化
static func from_dict(data: Dictionary) -> ConsumableData:
	var consumable := ConsumableData.new()
	consumable.consumable_id = data.get("consumable_id", "")
	consumable.consumable_name = data.get("consumable_name", "")
	consumable.description = data.get("description", "")
	consumable.price = data.get("price", 0)
	
	# 解析品质
	var quality_str: String = data.get("quality", "low")
	match quality_str:
		"low": consumable.quality = PillQuality.LOW
		"mid": consumable.quality = PillQuality.MID
		"high": consumable.quality = PillQuality.HIGH
		"extreme": consumable.quality = PillQuality.EXTREME
	
	# 解析使用场景
	var scene_str: String = data.get("use_scene", "anytime")
	match scene_str:
		"battle": consumable.use_scene = UseScene.BATTLE
		"anytime": consumable.use_scene = UseScene.ANYTIME
		"passive": consumable.use_scene = UseScene.PASSIVE
	
	var effects_data: Array = data.get("effects", [])
	for e in effects_data:
		consumable.effects.append(e)
	
	return consumable
