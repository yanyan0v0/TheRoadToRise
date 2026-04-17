## Relic data resource class
class_name RelicData
extends Resource

## Relic trigger types
enum TriggerType {
	ON_BATTLE_START,    # Battle start
	ON_ATTACK,          # On attack
	ON_TAKE_DAMAGE,     # On take damage
	ON_KILL,            # On kill
	ON_TURN_START,      # Turn start
	ON_TURN_END,        # Turn end
	ON_CARD_PLAY,       # On card play
	ON_FATAL_DAMAGE,    # On fatal damage
	PASSIVE,            # Passive effect
}

## Relic rarity
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
@export var enhance_level: int = 0  # Enhancement level (0+, no cap), each level +1 to numeric values

## Effect list
## Format: {"type": "armor/damage/heal/draw/mana", "value": number, "chance": probability(0-1)}
@export var effects: Array[Dictionary] = []

## Get enhancement display text
func get_enhance_display() -> String:
	if enhance_level <= 0:
		return ""
	return "+%d" % enhance_level

## Get enhanced effects (each numeric "value" field increased by enhance_level * rarity bonus)
func get_enhanced_effects() -> Array[Dictionary]:
	if enhance_level <= 0:
		return effects
	var rarity_str := ""
	match rarity:
		RelicRarity.COMMON: rarity_str = "common"
		RelicRarity.UNCOMMON: rarity_str = "uncommon"
		RelicRarity.RARE: rarity_str = "rare"
		RelicRarity.LEGENDARY: rarity_str = "legendary"
	var bonus_per_level: int = RelicTooltip.get_enhance_bonus(rarity_str)
	var enhanced: Array[Dictionary] = []
	for effect in effects:
		var e: Dictionary = effect.duplicate()
		# Only enhance integer "value" fields, not percentages like "chance", "damage_percent"
		if e.has("value") and e["value"] is int:
			e["value"] = e["value"] + enhance_level * bonus_per_level
		enhanced.append(e)
	return enhanced

## Get enhanced description dynamically built from effects
func get_enhanced_description() -> String:
	var rarity_str := ""
	match rarity:
		RelicRarity.COMMON: rarity_str = "common"
		RelicRarity.UNCOMMON: rarity_str = "uncommon"
		RelicRarity.RARE: rarity_str = "rare"
		RelicRarity.LEGENDARY: rarity_str = "legendary"
	var data := {"effects": effects, "trigger_type": "", "description": description, "source": "", "relic_name": relic_name, "rarity": rarity_str}
	match trigger_type:
		TriggerType.ON_BATTLE_START: data["trigger_type"] = "on_battle_start"
		TriggerType.ON_ATTACK: data["trigger_type"] = "on_attack"
		TriggerType.ON_TAKE_DAMAGE: data["trigger_type"] = "on_take_damage"
		TriggerType.ON_KILL: data["trigger_type"] = "on_kill"
		TriggerType.ON_TURN_START: data["trigger_type"] = "on_turn_start"
		TriggerType.ON_TURN_END: data["trigger_type"] = "on_turn_end"
		TriggerType.ON_CARD_PLAY: data["trigger_type"] = "on_card_play"
		TriggerType.ON_FATAL_DAMAGE: data["trigger_type"] = "on_fatal_damage"
		TriggerType.PASSIVE: data["trigger_type"] = "passive"
	return RelicTooltip.build_description_from_effects(data, enhance_level)

## Get display name (with enhancement level)
func get_display_name() -> String:
	if enhance_level > 0:
		return "%s +%d" % [relic_name, enhance_level]
	return relic_name

## Get rarity color
func get_rarity_color() -> Color:
	match rarity:
		RelicRarity.COMMON: return Color.WHITE
		RelicRarity.UNCOMMON: return Color("00B894")
		RelicRarity.RARE: return Color("0984E3")
		RelicRarity.LEGENDARY: return Color("FDCB6E")
	return Color.WHITE

## Initialize from dictionary data
static func from_dict(data: Dictionary) -> RelicData:
	var relic := RelicData.new()
	relic.relic_id = data.get("relic_id", "")
	relic.relic_name = data.get("relic_name", "")
	relic.description = data.get("description", "")
	relic.enhance_level = data.get("enhance_level", 0)
	
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
	
	return relic
