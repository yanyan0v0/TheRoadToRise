## 伤害计算引擎 - 处理所有伤害计算逻辑
class_name DamageCalculator
extends RefCounted

## 计算最终伤害
## 公式：最终伤害 = (基础伤害 + 力量 + 额外加成) × (1+增伤%) × (1-减伤%)
## 护甲抵消 = min(护甲值, 最终伤害)
## 实际承受 = 最终伤害 - 护甲抵消
static func calculate_damage(
	base_damage: int,
	strength: int = 0,
	damage_bonus_percent: float = 0.0,
	_bleed_stacks: int = 0,  # Unused, kept for API compatibility
	damage_reduction_percent: float = 0.0,
	target_armor: int = 0,
	extra_strength_bonus: int = 0
) -> Dictionary:
	# 基础伤害 + 力量加成 + 额外加成（连击等）
	var raw_damage: float = float(base_damage + strength + extra_strength_bonus)
	
	# 增伤百分比
	raw_damage *= (1.0 + damage_bonus_percent)
	
	# 减伤百分比
	raw_damage *= (1.0 - damage_reduction_percent)
	
	# 确保伤害不为负
	var final_damage := maxi(0, int(raw_damage))
	
	# 护甲抵消
	var armor_absorbed := mini(target_armor, final_damage)
	var actual_damage := final_damage - armor_absorbed
	
	return {
		"raw_damage": int(raw_damage),
		"final_damage": final_damage,
		"armor_absorbed": armor_absorbed,
		"actual_damage": actual_damage,
		"remaining_armor": target_armor - armor_absorbed,
	}

## 计算治疗量
static func calculate_heal(base_heal: int, heal_bonus_percent: float = 0.0) -> int:
	var final_heal := float(base_heal) * (1.0 + heal_bonus_percent)
	return maxi(0, int(final_heal))

## 计算护甲获得量
static func calculate_armor(base_armor: int, armor_bonus_percent: float = 0.0) -> int:
	var final_armor := float(base_armor) * (1.0 + armor_bonus_percent)
	return maxi(0, int(final_armor))
