## 事件场景脚本 - 随机事件系统
extends Control

var current_event: Dictionary = {}

@onready var event_title: Label = $CenterContainer/VBox/EventTitle
@onready var event_description: RichTextLabel = $CenterContainer/VBox/EventDescription
@onready var choices_container: VBoxContainer = $CenterContainer/VBox/ChoicesContainer
@onready var result_label: RichTextLabel = $CenterContainer/VBox/ResultLabel
@onready var continue_button: Button = $CenterContainer/VBox/ContinueButton

func _ready() -> void:
	GameManager.change_state(GameManager.GameState.EVENT)
	continue_button.visible = false
	result_label.visible = false
	continue_button.pressed.connect(_on_continue_pressed)
	
	_load_random_event()

## 加载随机事件
func _load_random_event() -> void:
	var events: Array[Dictionary] = DataManager.get_all_events()
	if events.is_empty():
		# 默认事件
		current_event = {
			"event_name": "路遇仙人",
			"description": "一位白发仙人拦住去路，微笑着说：'施主，贫道有一物相赠，不知施主可愿一试？'",
			"choices": [
				{"text": "接受馈赠", "effects": [{"type": "heal", "value": 10}], "result_text": "仙人赠你一颗仙丹，恢复了10点生命。"},
				{"text": "婉言谢绝", "effects": [{"type": "gold", "value": 20}], "result_text": "仙人点头微笑，留下20枚金币后飘然而去。"},
				{"text": "警惕离开", "effects": [], "result_text": "你小心翼翼地绕过仙人，继续前行。"}
			]
		}
	else:
		current_event = events[randi() % events.size()]
	
	_display_event()

## 显示事件
func _display_event() -> void:
	event_title.text = current_event.get("event_name", "未知事件")
	event_description.text = current_event.get("description", "")
	
	# 清除旧选项
	for child in choices_container.get_children():
		child.queue_free()
	
	# 兼容两种字段名：choices 和 options
	var choices: Array = current_event.get("choices", [])
	if choices.is_empty():
		choices = current_event.get("options", [])
	
	for i in range(choices.size()):
		var choice: Dictionary = choices[i]
		var button := Button.new()
		button.text = choice.get("text", "选项 %d" % (i + 1))
		button.custom_minimum_size = Vector2(400, 45)
		button.add_theme_font_size_override("font_size", 16)
		
		var choice_idx := i
		button.pressed.connect(func(): _on_choice_selected(choice_idx))
		
		choices_container.add_child(button)

## 选择选项
func _on_choice_selected(choice_index: int) -> void:
	# 兼容两种字段名
	var choices: Array = current_event.get("choices", [])
	if choices.is_empty():
		choices = current_event.get("options", [])
	
	if choice_index >= choices.size():
		return
	
	var choice: Dictionary = choices[choice_index]
	
	# 检查费用
	var cost: Dictionary = choice.get("cost", {})
	if not cost.is_empty():
		var cost_type: String = cost.get("type", "")
		var cost_value: int = cost.get("value", 0)
		if cost_type == "gold" and GameManager.current_gold < cost_value:
			# 金币不足
			result_label.text = "金币不足，无法选择此选项。"
			result_label.visible = true
			return
		if cost_type == "gold":
			GameManager.modify_gold(-cost_value)
	
	# 支持两种格式：effects（简单格式）和 results（概率格式）
	var effects: Array = choice.get("effects", [])
	var results: Array = choice.get("results", [])
	
	var result_text: String = ""
	
	if not results.is_empty():
		# 概率格式：根据chance随机选择一个结果
		var roll := randf()
		var cumulative: float = 0.0
		for result in results:
			cumulative += result.get("chance", 0.0)
			if roll <= cumulative:
				_apply_effect(result)
				result_text = result.get("description", "事件结束。")
				result_text += "\n" + _get_effect_detail_text(result)
				break
		if result_text.is_empty():
			# 兆底：使用最后一个结果
			var last_result: Dictionary = results[results.size() - 1]
			_apply_effect(last_result)
			result_text = last_result.get("description", "事件结束。")
			result_text += "\n" + _get_effect_detail_text(last_result)
	elif not effects.is_empty():
		# 简单格式：直接执行所有效果
		var detail_parts: Array[String] = []
		for effect in effects:
			_apply_effect(effect)
			var detail := _get_effect_detail_text(effect)
			if not detail.is_empty():
				detail_parts.append(detail)
		result_text = choice.get("result_text", "事件结束。")
		if not detail_parts.is_empty():
			result_text += "\n" + "\n".join(detail_parts)
		else:
			result_text = choice.get("result_text", "事件结束。")
	
	result_label.text = result_text
	result_label.visible = true
	
	# 隐藏选项，显示继续按钮
	choices_container.visible = false
	continue_button.visible = true

## 应用效果
func _apply_effect(effect: Dictionary) -> void:
	var effect_type: String = effect.get("type", "")
	var value: int = effect.get("value", 0)
	
	match effect_type:
		"heal":
			GameManager.modify_hp(value)
		"damage":
			GameManager.modify_hp(-value)
		"gold":
			GameManager.modify_gold(value)
		"max_hp":
			GameManager.max_hp += value
			GameManager.modify_hp(value)
		"card":
			var card_id: String = effect.get("card_id", "")
			if card_id.is_empty():
				# 根据稀有度随机选取一张卡牌
				var rarity: String = effect.get("rarity", "common")
				var candidates := DataManager.get_cards_by_rarity(rarity, GameManager.current_character_id)
				if not candidates.is_empty():
					card_id = candidates[randi() % candidates.size()]
					effect["card_id"] = card_id  # 保存到effect中供后续显示
			if not card_id.is_empty():
				GameManager.current_deck.append({"card_id": card_id, "star_level": 1})
		"relic":
			var relic_id: String = effect.get("relic_id", "")
			if relic_id.is_empty():
				# 随机选取一个未拥有的法宝
				var all_relics := DataManager.get_all_relics()
				var available: Array = []
				for r in all_relics:
					var rid: String = r.get("relic_id", "")
					if not GameManager.has_relic(rid):
						available.append(rid)
				if not available.is_empty():
					relic_id = available[randi() % available.size()]
					effect["relic_id"] = relic_id  # 保存到effect中供后续显示
			if not relic_id.is_empty():
				GameManager.add_relic(relic_id)
		"consumable":
			var consumable_id: String = effect.get("consumable_id", "")
			if not consumable_id.is_empty():
				GameManager.current_consumables.append(consumable_id)
		"remove_card":
			if not GameManager.current_deck.is_empty():
				var idx: int = randi() % GameManager.current_deck.size()
				GameManager.current_deck.remove_at(idx)
		"card_fusion":
			# 自动融合一组可融合的卡牌
			var fusable_groups := CardFusionManager.get_fusable_groups()
			for group in fusable_groups:
				if group.get("can_fuse", false):
					var indices: Array = group.get("indices", [])
					if indices.size() >= 2:
						CardFusionManager.fuse_cards(indices[0], indices[1])
						break

## 继续
func _on_continue_pressed() -> void:
	SceneTransition.change_scene("res://scenes/map/MapScene.tscn")

## 获取效果详情文本
func _get_effect_detail_text(effect: Dictionary) -> String:
	var etype: String = effect.get("type", "")
	var value: int = effect.get("value", 0)
	
	match etype:
		"heal":
			return "💚 恢复了 %d 点生命" % value
		"damage":
			return "❤️ 失去了 %d 点生命" % value
		"gold":
			return "💰 获得了 %d 金币" % value
		"max_hp":
			return "⬆️ 最大生命值 +%d" % value
		"heal_percent":
			var actual := int(GameManager.max_hp * value / 100.0)
			return "💚 恢复了 %d 点生命 (%d%%)" % [actual, value]
		"card":
			var card_id: String = effect.get("card_id", "")
			var card_data: Dictionary = DataManager.get_card(card_id)
			var card_name: String = card_data.get("card_name", "神秘卡牌")
			var detail := "🃏 获得卡牌：%s" % card_name
			detail += _build_card_detail(card_data)
			return detail
		"relic":
			var relic_id: String = effect.get("relic_id", "")
			var relic_data: Dictionary = DataManager.get_relic(relic_id)
			var relic_name: String = relic_data.get("relic_name", "神秘法宝")
			var detail := "🔮 获得法宝：%s" % relic_name
			detail += _build_relic_detail(relic_data)
			return detail
		"consumable":
			var c_id: String = effect.get("consumable_id", "")
			var c_data: Dictionary = DataManager.get_consumable(c_id)
			var c_name: String = c_data.get("consumable_name", "神秘物品")
			var detail := "🍶 获得消耗品：%s" % c_name
			detail += _build_consumable_detail(c_data)
			return detail
		"remove_card":
			return "❌ 随机移除了一张卡牌"
		"card_upgrade":
			return "⬆️ 可以升级一张卡牌"
		"nothing":
			return ""
		_:
			if value != 0:
				return "%s: %d" % [etype, value]
	return ""

## 构建卡牌详细属性文本
func _build_card_detail(card_data: Dictionary) -> String:
	if card_data.is_empty():
		return ""
	
	var card_type: String = card_data.get("card_type", "attack")
	var type_name := ""
	match card_type:
		"attack": type_name = "攻击"
		"skill": type_name = "技能"
		"ultimate": type_name = "终结技"
	
	var rarity: String = card_data.get("rarity", "common")
	var rarity_name := ""
	match rarity:
		"common": rarity_name = "普通"
		"uncommon": rarity_name = "稀有"
		"rare": rarity_name = "史诗"
		"legendary": rarity_name = "传说"
	
	var energy_cost: int = card_data.get("energy_cost", 1)
	var desc: String = card_data.get("description", "")
	
	var text := "\n    ┌─────────────────────────┐"
	text += "\n    │ 类型: %s  |  费用: %d  |  %s" % [type_name, energy_cost, rarity_name]
	text += "\n    │ %s" % desc
	text += "\n    └─────────────────────────┘"
	return text

## 构建法宝详细属性文本
func _build_relic_detail(relic_data: Dictionary) -> String:
	if relic_data.is_empty():
		return ""
	
	var rarity: String = relic_data.get("rarity", "common")
	var rarity_name := ""
	match rarity:
		"common": rarity_name = "普通"
		"uncommon": rarity_name = "稀有"
		"rare": rarity_name = "史诗"
		"legendary": rarity_name = "传说"
	
	var trigger: String = relic_data.get("trigger_type", "")
	var trigger_name := ""
	match trigger:
		"on_battle_start": trigger_name = "战斗开始时"
		"on_turn_start": trigger_name = "回合开始时"
		"on_attack": trigger_name = "攻击时"
		"on_fatal_damage": trigger_name = "受到致命伤害时"
		"passive": trigger_name = "被动"
		_: trigger_name = trigger
	
	var desc: String = relic_data.get("description", "")
	
	var text := "\n    ┌─────────────────────────┐"
	text += "\n    │ 品质: %s  |  触发: %s" % [rarity_name, trigger_name]
	text += "\n    │ %s" % desc
	text += "\n    └─────────────────────────┘"
	return text

## 构建消耗品详细属性文本
func _build_consumable_detail(c_data: Dictionary) -> String:
	if c_data.is_empty():
		return ""
	
	var desc: String = c_data.get("description", "")
	
	var text := "\n    ┌─────────────────────────┐"
	text += "\n    │ %s" % desc
	text += "\n    └─────────────────────────┘"
	return text
