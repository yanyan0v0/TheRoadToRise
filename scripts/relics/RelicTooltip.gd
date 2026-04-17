## Unified relic tooltip builder - provides consistent hover tooltip UI for relics
class_name RelicTooltip
extends RefCounted

## Rarity display name mapping
const RARITY_NAMES := {
	"common": "普通",
	"uncommon": "稀有",
	"rare": "史诗",
	"legendary": "传说",
}

## Rarity color mapping
const RARITY_COLORS := {
	"common": Color(0.7, 0.7, 0.7),
	"uncommon": Color("00B894"),
	"rare": Color("0984E3"),
	"legendary": Color("FDCB6E"),
}

## Rarity enhance value bonus per level: higher rarity = more value per enhance level
const RARITY_ENHANCE_BONUS := {
	"common": 1,
	"uncommon": 1,
	"rare": 2,
	"legendary": 3,
}

## Trigger type display name mapping
const TRIGGER_NAMES := {
	"on_battle_start": "战斗开始时",
	"on_attack": "攻击时",
	"on_take_damage": "受到伤害时",
	"on_kill": "击败敌人时",
	"on_turn_start": "每回合开始时",
	"on_turn_end": "回合结束时",
	"on_card_play": "每打出1张牌时",
	"on_fatal_damage": "受到致命伤害时",
	"passive": "",
}

## Status type display name mapping
const STATUS_NAMES := {
	"burn": "灼烧",
	"stun": "眩晕",
	"weaken": "虚弱",
	"slow": "减速",
	"seal": "封印",
	"regeneration": "治愈",
}

## Condition display name mapping
const CONDITION_NAMES := {
	"mana_gte_3": "若法力≥3，",
	"empty_hand": "若手牌为0，",
}

## Calculate actual sell price based on base price, rarity, and enhance level
## Formula: sell_price = base_price + (enhance_level * 10)
static func calc_sell_price(relic_data: Dictionary, enhance_level: int = 0) -> int:
	var base_price: int = relic_data.get("sell_price", 15)
	return base_price + enhance_level * 10

## Get description dynamically built from effects, with enhance_level applied to value fields
static func get_enhanced_description(relic_data: Dictionary, enhance_level: int = 0) -> String:
	var effects: Array = relic_data.get("effects", [])
	if effects.is_empty():
		return relic_data.get("description", "")
	return build_description_from_effects(relic_data, enhance_level)

## Build description string from effects array with enhance_level applied
## enhance_level increases integer "value" fields (not chance/percent), scaled by rarity
static func build_description_from_effects(relic_data: Dictionary, enhance_level: int = 0) -> String:
	var effects: Array = relic_data.get("effects", [])
	var trigger_type: String = relic_data.get("trigger_type", "passive")
	var rarity: String = relic_data.get("rarity", "common")
	if effects.is_empty():
		return relic_data.get("description", "")

	# Collect description fragments from each effect
	var fragments: Array[String] = []
	for effect in effects:
		var frag := _describe_single_effect(effect, enhance_level, rarity)
		if not frag.is_empty():
			fragments.append(frag)

	if fragments.is_empty():
		return relic_data.get("description", "")

	# Build trigger prefix
	var trigger_prefix: String = TRIGGER_NAMES.get(trigger_type, "")

	# Combine: for single-trigger effects with shared chance, merge naturally
	# For multi-effect, join with "，"
	var body: String = "，".join(fragments)

	if trigger_prefix.is_empty():
		return "%s。" % body
	else:
		return "%s%s。" % [trigger_prefix, body]

## Describe a single effect entry, applying enhance_level to value (scaled by rarity)
static func _describe_single_effect(effect: Dictionary, enhance_level: int, rarity: String = "common") -> String:
	var etype: String = effect.get("type", "")
	var value: int = _enhanced_value(effect, enhance_level, rarity)
	var chance: float = effect.get("chance", 0.0)
	var condition: String = effect.get("condition", "")

	# Build chance prefix
	var chance_str := ""
	if chance > 0.0:
		chance_str = "有%d%%概率" % int(chance * 100)

	# Build condition prefix
	var cond_str: String = CONDITION_NAMES.get(condition, "")

	match etype:
		"draw":
			return "%s%s抽%d张牌" % [cond_str, chance_str, value]
		"aoe_splash":
			var dmg_pct: float = effect.get("damage_percent", 0.5)
			return "%s掀起狂风，对所有敌人造成本次攻击%d%%的伤害" % [chance_str, int(dmg_pct * 100)]
		"prevent_death":
			var consume: bool = effect.get("consume_on_trigger", false)
			var suffix := "触发后法宝消失" if consume else ""
			return "保留%d点生命。%s" % [value, suffix]
		"extra_attack":
			return "%s多触发一次攻击" % chance_str
		"armor":
			var trigger: String = effect.get("trigger", "")
			if trigger == "on_kill":
				return "每击败一个敌人+%d护甲" % value
			return "%s获得%d点护甲" % [chance_str, value]
		"burn_reduction":
			var reduction: float = effect.get("value", 0.5)
			return "灼烧伤害减少%d%%" % int(reduction * 100)
		"status":
			var status_type: String = effect.get("status_type", "")
			var status_name: String = STATUS_NAMES.get(status_type, status_type)
			var target: String = effect.get("target", "")
			var target_str := ""
			if target == "random_enemy":
				target_str = "使一个随机敌人"
				return "%s%s%s%d回合" % [cond_str, chance_str, target_str, value]
			return "%s%s施加%d层%s" % [cond_str, chance_str, value, status_name]
		"mana":
			return "获得%d点额外法力" % value
		"consumable_capacity":
			return "丹药携带上限+%d" % value
		"damage_reduction":
			var threshold: int = effect.get("threshold", 0)
			if threshold > 0:
				return "%s受到伤害超过%d点时，减少%d点伤害" % [chance_str, threshold, value]
			return "%s减少%d点伤害" % [chance_str, value]
		"heal_bonus":
			var bonus: float = effect.get("value", 0.0)
			return "治疗效果提升%d%%" % int(bonus * 100)
		"dispel_buff":
			return "%s移除敌人%d层增益" % [chance_str, value]
		"gain_strength":
			return "%s增加%d点力量" % [chance_str, value]
		"stamina":
			return "获得%d点体力" % value
		"draw_per_enemy":
			return "每一名敌人，额外抽取卡牌数+%d" % value
		"bailongma_heal":
			return "白龙马恢复%d点生命" % value
		"bonus_damage":
			return "%s造成额外%d点伤害" % [chance_str, value]
		"armor_pierce":
			return "%s无视%d点护甲" % [chance_str, value]
		"reduce_armor":
			return "%s使敌人减少%d点护甲" % [chance_str, value]
		"critical_hit":
			return "%s造成双倍伤害" % chance_str
		"steal_armor":
			return "%s偷取敌人%d点护甲" % [chance_str, value]
		"extra_hit":
			return "%s多造成一次%d点伤害" % [chance_str, value]
		"lifesteal":
			return "%s恢复%d点生命" % [chance_str, value]
		_:
			return ""

## Get enhanced value: increase integer "value" by enhance_level * rarity bonus
static func _enhanced_value(effect: Dictionary, enhance_level: int, rarity: String = "common") -> int:
	var val = effect.get("value", 0)
	if enhance_level > 0:
		var bonus_per_level: int = RARITY_ENHANCE_BONUS.get(rarity, 1)
		return val + enhance_level * bonus_per_level
	return val

## Get the enhance bonus per level for a given rarity string
static func get_enhance_bonus(rarity: String) -> int:
	return RARITY_ENHANCE_BONUS.get(rarity, 1)

## Get rarity display name
static func get_rarity_name(rarity: String) -> String:
	return RARITY_NAMES.get(rarity, "普通")

## Get rarity color
static func get_rarity_color(rarity: String) -> Color:
	return RARITY_COLORS.get(rarity, Color.WHITE)

## Build a unified relic tooltip PanelContainer
## Parameters:
##   relic_data: Dictionary from DataManager.get_relic()
##   enhance_level: current enhance level (0 if not enhanced)
## Returns: PanelContainer ready to be added to scene tree
static func build_tooltip(relic_data: Dictionary, enhance_level: int = 0) -> PanelContainer:
	var rarity: String = relic_data.get("rarity", "common")
	var rarity_color: Color = get_rarity_color(rarity)
	var rarity_name: String = get_rarity_name(rarity)
	var relic_name: String = relic_data.get("relic_name", "???")
	var description: String = get_enhanced_description(relic_data, enhance_level)
	var source: String = relic_data.get("source", "")
	var sell_price: int = calc_sell_price(relic_data, enhance_level)
	
	var panel := PanelContainer.new()
	panel.z_index = 200
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.12, 0.95)
	style.border_color = rarity_color.darkened(0.3)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", style)
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(vbox)
	
	# === Line 1: [+enhance] relic_name (colored by rarity) ===
	var title_label := Label.new()
	var title_text := "[+%d] %s" % [enhance_level, relic_name]
	title_label.text = title_text
	title_label.add_theme_font_size_override("font_size", 15)
	title_label.add_theme_color_override("font_color", rarity_color)
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(title_label)
	
	# === Separator ===
	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 4)
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(sep)
	
	# === Rarity ===
	var rarity_label := Label.new()
	rarity_label.text = "等级：%s" % rarity_name
	rarity_label.add_theme_font_size_override("font_size", 12)
	rarity_label.add_theme_color_override("font_color", rarity_color)
	rarity_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(rarity_label)
	
	# === Description ===
	var desc_label := Label.new()
	desc_label.text = "描述：%s" % description
	desc_label.add_theme_font_size_override("font_size", 12)
	desc_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc_label.custom_minimum_size = Vector2(220, 0)
	desc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(desc_label)
	
	# === Source ===
	if not source.is_empty():
		var source_label := Label.new()
		source_label.text = "来源：%s" % source
		source_label.add_theme_font_size_override("font_size", 12)
		source_label.add_theme_color_override("font_color", Color("74B9FF"))
		source_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(source_label)
	
	# === Sell price ===
	var price_label := Label.new()
	price_label.text = "出售金额：%d 💰" % sell_price
	price_label.add_theme_font_size_override("font_size", 12)
	price_label.add_theme_color_override("font_color", Color("FDCB6E"))
	price_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(price_label)
	
	return panel

## Position a tooltip panel relative to a target control
## Adds the tooltip to parent_node, waits one frame, then positions it
static func show_tooltip(
	parent_node: Node,
	target: Control,
	relic_data: Dictionary,
	enhance_level: int = 0
) -> PanelContainer:
	var tooltip := build_tooltip(relic_data, enhance_level)
	parent_node.add_child(tooltip)
	return tooltip

## Position tooltip after it's been added to the tree (call after await get_tree().process_frame)
static func position_tooltip(tooltip: PanelContainer, target: Control, viewport_size: Vector2) -> void:
	if tooltip == null or not is_instance_valid(tooltip):
		return
	
	var tooltip_size := tooltip.size
	var target_pos := target.global_position
	var target_size := target.size
	
	# Default: show to the right of target
	var pos_x := target_pos.x + target_size.x + 8
	var pos_y := target_pos.y
	
	# Right side overflow -> show on left
	if pos_x + tooltip_size.x > viewport_size.x:
		pos_x = target_pos.x - tooltip_size.x - 8
	
	# Left side overflow -> clamp to left edge
	if pos_x < 0:
		pos_x = 4
	
	# Bottom overflow -> move up
	if pos_y + tooltip_size.y > viewport_size.y:
		pos_y = viewport_size.y - tooltip_size.y - 4
	
	# Top overflow -> clamp to top
	if pos_y < 0:
		pos_y = 4
	
	tooltip.position = Vector2(pos_x, pos_y)

## Position tooltip above a target (used in RewardScene)
static func position_tooltip_above(tooltip: PanelContainer, target: Control, viewport_size: Vector2) -> void:
	if tooltip == null or not is_instance_valid(tooltip):
		return
	
	var tooltip_size := tooltip.size
	var target_pos := target.global_position
	var target_size := target.size
	
	# Default: show above the target, centered
	var pos_x := target_pos.x + target_size.x / 2.0 - tooltip_size.x / 2.0
	var pos_y := target_pos.y - tooltip_size.y - 8
	
	# If above goes off screen, show below
	if pos_y < 0:
		pos_y = target_pos.y + target_size.y + 8
	
	# Clamp horizontal
	if pos_x < 4:
		pos_x = 4
	if pos_x + tooltip_size.x > viewport_size.x - 4:
		pos_x = viewport_size.x - tooltip_size.x - 4
	
	tooltip.global_position = Vector2(pos_x, pos_y)
