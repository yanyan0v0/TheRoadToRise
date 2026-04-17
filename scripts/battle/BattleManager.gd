## 战斗管理器 - 管理战斗流程状态机
extends Node

signal battle_state_changed(new_state: String)
signal player_turn_ready()
signal enemy_turn_ready()
signal battle_won()
signal battle_lost()

## 战斗状态
enum BattleState {
	INIT,           # 初始化
	PLAYER_TURN,    # 玩家回合
	PLAYER_ACTION,  # 玩家行动中
	ENEMY_TURN,     # 敌人回合
	TURN_END,       # 回合结束
	VICTORY,        # 胜利
	DEFEAT,         # 失败
}

var current_state: BattleState = BattleState.INIT
var turn_number: int = 0
var cards_played_this_turn: int = 0
var max_cards_per_turn: int = 99  # 默认无限制
var attack_cards_played_this_turn: int = 0  # Combo counter: attack cards played this turn
var combo_display_count: int = 0  # Combo display value for status bar (0 for first 3 attacks, +1 after)
var _combo_broken: bool = false  # Whether combo was broken by non-attack card
var skill_cards_blocked_this_turn: int = 0  # Seal: number of skill cards blocked this turn
var armor_retain_this_turn: bool = false  # Whether armor should be retained (not reset) next turn

## 子系统引用
var deck_manager: Node = null
var hand_manager: Node = null
var player_status: StatusEffectManager = null
var enemies: Array[Node] = []

## 初始化战斗
func init_battle(enemy_data_list: Array, p_deck_manager: Node, p_hand_manager: Node, shuffle_deck: bool = true) -> void:
	deck_manager = p_deck_manager
	hand_manager = p_hand_manager
	player_status = StatusEffectManager.new()
	add_child(player_status)
	
	turn_number = 0
	cards_played_this_turn = 0
	attack_cards_played_this_turn = 0
	armor_retain_this_turn = false
	
	# 初始化牌组
	deck_manager.init_deck(GameManager.current_deck, shuffle_deck)
	
	# 重置护甲
	GameManager.reset_armor()
	
	# 重置法力
	GameManager.reset_mana()
	
	# 触发战斗开始效果
	EventBus.battle_started.emit(enemy_data_list)
	
	# 卷帘大将被动：每10点生命护甲+1
	if GameManager.current_character_id == "sha_wujing":
		var bonus_armor := GameManager.current_hp / 10
		GameManager.modify_armor(bonus_armor)
	
	# 天蓬元帅被动：战斗开始恢复3点体力
	if GameManager.current_character_id == "zhu_bajie":
		GameManager.modify_stamina(3)
	
	# 开始第一个回合
	_start_player_turn()

## 开始玩家回合
func _start_player_turn() -> void:
	current_state = BattleState.PLAYER_TURN
	turn_number += 1
	cards_played_this_turn = 0
	attack_cards_played_this_turn = 0
	combo_display_count = 0
	_combo_broken = false
	max_cards_per_turn = 99
	skill_cards_blocked_this_turn = 0
	
	# 恢复法力
	GameManager.reset_mana()
	
	# Player armor resets every turn (unless armor_retain is active)
	if armor_retain_this_turn:
		armor_retain_this_turn = false
	else:
		GameManager.current_armor = 0
		EventBus.armor_changed.emit(0)
	
	# 回合开始状态效果结算
	var turn_start_results := player_status.on_turn_start()
	
	# 充盈加成
	if turn_start_results.mana_bonus > 0:
		GameManager.modify_mana(turn_start_results.mana_bonus)
	
	# 减速限制
	if turn_start_results.card_limit_reduction > 0:
		max_cards_per_turn = maxi(1, 5 - turn_start_results.card_limit_reduction)
	
	# 抽5张手牌 + 降魔宝杖额外抽牌
	var draw_count: int = 5
	if GameManager.has_relic("xiang_mo_zhang"):
		var alive_enemies := _get_alive_enemy_count()
		var xmz_enhance: int = GameManager.get_relic_enhance("xiang_mo_zhang")
		var draw_per_enemy: int = 1 + xmz_enhance
		draw_count += alive_enemies * draw_per_enemy
		if alive_enemies > 0:
			print("[BattleManager] Xiang Mo Zhang: +%d draw (%d enemies x %d)" % [alive_enemies * draw_per_enemy, alive_enemies, draw_per_enemy])
			EventBus.relic_effect_triggered.emit(null)
	var drawn_cards: Array[Dictionary] = deck_manager.draw_cards(draw_count)
	for card_data in drawn_cards:
		hand_manager.add_card(card_data)
	
	# 更新可打出状态
	hand_manager.update_playable_states(GameManager.current_mana, GameManager.current_stamina)
	
	# Enemy defend intent: apply armor immediately at turn start
	for enemy in enemies:
		if enemy == null or (enemy.has_method("is_dead") and enemy.is_dead()):
			continue
		if enemy.has_method("apply_defend_at_turn_start"):
			enemy.apply_defend_at_turn_start()
	
	EventBus.turn_started.emit(turn_number)
	EventBus.player_turn_started.emit()
	player_turn_ready.emit()
	battle_state_changed.emit("player_turn")

## 玩家打出卡牌
func play_card(card_node: Control, target: Node = null) -> bool:
	if current_state != BattleState.PLAYER_TURN:
		return false
	
	if cards_played_this_turn >= max_cards_per_turn:
		return false
	
	var card_data: Dictionary = card_node.card_data
	var energy_cost: int = CardData.get_card_energy_cost(card_data)
	var stamina_cost: int = card_data.get("stamina_cost", 0)
	var card_type = card_data.get("card_type", "attack")
	# Normalize card_type to Array
	var card_types: Array = card_type if card_type is Array else [card_type]
	
	# 封印检查：每层封印每回合无法发动1次技能
	if player_status.has_effect("seal") and "skill" in card_types:
		var seal_stacks: int = player_status.get_stacks("seal")
		if skill_cards_blocked_this_turn < seal_stacks:
			skill_cards_blocked_this_turn += 1
			return false
	
	# 敏捷减费
	if player_status.has_effect("agility"):
		energy_cost = maxi(0, energy_cost - player_status.get_stacks("agility"))
	
	# 法力检查
	if energy_cost > GameManager.current_mana:
		return false
	
	# 体力检查
	if stamina_cost > 0 and stamina_cost > GameManager.current_stamina:
		return false
	
	# 消耗资源
	GameManager.modify_mana(-energy_cost)
	if stamina_cost > 0:
		GameManager.modify_stamina(-stamina_cost)
	
	cards_played_this_turn += 1
	var is_attack_card: bool = "attack" in card_types
	if is_attack_card:
		if not _combo_broken:
			attack_cards_played_this_turn += 1
			# Combo display: first 3 attacks show 0, after that +1 per attack
			if attack_cards_played_this_turn > 3:
				combo_display_count = attack_cards_played_this_turn - 3
			else:
				combo_display_count = 0
	else:
		# Non-attack card breaks combo
		_combo_broken = true
		attack_cards_played_this_turn = 0
		combo_display_count = 0
	current_state = BattleState.PLAYER_ACTION
	
	# 执行卡牌效果
	_execute_card_effects(card_data, target)
	
	# 从手牌移除：summon类型的卡牌进入消耗堆，其他进入弃牌堆
	var card_id: String = card_data.get("card_id", "")
	if "summon" in card_types:
		deck_manager.exhaust_card(card_id)
	else:
		deck_manager.play_card(card_id)
	hand_manager.remove_card(card_node)
	
	# 通知全局
	EventBus.card_played.emit(null, target)
	
	# 更新可打出状态
	hand_manager.update_playable_states(GameManager.current_mana, GameManager.current_stamina)
	
	# 检查胜负
	if _check_all_enemies_dead():
		_on_battle_won()
		return true
	
	current_state = BattleState.PLAYER_TURN
	return true

## 执行卡牌效果
func _execute_card_effects(card_data: Dictionary, target: Node) -> void:
	var effects: Array = card_data.get("effects", [])
	
	for effect in effects:
		_execute_single_effect(effect, target)

## 执行单个效果
func _execute_single_effect(effect: Dictionary, target: Node) -> void:
	var effect_type: String = effect.get("type", "")
	var value: int = effect.get("value", 0)
	var effect_target: String = effect.get("target", "enemy")
	var times: int = effect.get("times", 1)
	
	match effect_type:
		"damage":
			for i in range(times):
				_deal_damage_to_target(value, effect_target, target)
		
		"armor":
			GameManager.modify_armor(DamageCalculator.calculate_armor(value))
			EventBus.armor_gained.emit(null, value)
		
		"heal":
			var heal_amount := DamageCalculator.calculate_heal(value)
			GameManager.modify_hp(heal_amount)
			EventBus.healing_applied.emit(null, heal_amount)
		
		"heal_percent":
			var heal_amount := int(GameManager.max_hp * value / 100.0)
			GameManager.modify_hp(heal_amount)
			EventBus.healing_applied.emit(null, heal_amount)
		
		"draw":
			var drawn: Array[Dictionary] = deck_manager.draw_cards(value)
			for card_data in drawn:
				hand_manager.add_card(card_data)
		
		"mana":
			GameManager.modify_mana(value)
		
		"stamina":
			GameManager.modify_stamina(value)
		
		"strength":
			GameManager.modify_strength(value)
		
		"self_damage":
			GameManager.modify_hp(-value)
		
		"status":
			var status_type: String = effect.get("status_type", "")
			var condition: String = effect.get("condition", "")
			
			# Check condition before applying
			if condition != "" and not _check_effect_condition(condition, target):
				return
			
			if effect_target == "self":
				player_status.apply_effect(status_type, value)
				EventBus.status_effect_applied.emit(null, status_type, value)
			elif effect_target == "enemy" and target != null:
				if target.has_method("apply_status"):
					target.apply_status(status_type, value)
			elif effect_target == "all_enemies":
				for enemy in enemies:
					if enemy.has_method("apply_status"):
						enemy.apply_status(status_type, value)
		
		"remove_armor":
			if target != null and target.has_method("set_armor"):
				target.set_armor(0)
		
		"damage_from_armor":
			var bonus: int = effect.get("bonus", 0)
			var armor_damage := GameManager.current_armor + bonus
			_deal_damage_to_target(armor_damage, effect_target, target)
		
		"transform_hand":
			_transform_all_hand_cards()
		
		"armor_retain":
			armor_retain_this_turn = true
			print("[BattleManager] Armor retain activated: armor will not reset next turn")
		
		"armor_per_enemy":
			var alive_enemies := _get_alive_enemy_count()
			var total_armor := DamageCalculator.calculate_armor(value * alive_enemies)
			GameManager.modify_armor(total_armor)
			EventBus.armor_gained.emit(null, total_armor)
		
		"status_per_enemy":
			var alive_enemies := _get_alive_enemy_count()
			var status_type: String = effect.get("status_type", "")
			var total_stacks := value * alive_enemies
			if total_stacks > 0 and status_type != "":
				player_status.apply_effect(status_type, total_stacks)
				EventBus.status_effect_applied.emit(null, status_type, total_stacks)
		
		"special":
			var special_id: String = effect.get("special_id", "")
			_execute_special_effect(special_id, effect, target)

## Execute special card effects by special_id
func _execute_special_effect(special_id: String, effect: Dictionary, target: Node) -> void:
	match special_id:
		"da_nao_tian_gong":
			_apply_da_nao_tian_gong(effect)
		"ni_zhuan_qian_kun":
			_apply_ni_zhuan_qian_kun(effect)

## Da Nao Tian Gong (大闹天宫): for every X HP lost, gain +1 strength, agility, regeneration, overcharge, thorns
func _apply_da_nao_tian_gong(effect: Dictionary) -> void:
	var hp_per_stack: int = effect.get("hp_per_stack", 10)
	var hp_lost: int = GameManager.max_hp - GameManager.current_hp
	var stacks: int = hp_lost / hp_per_stack
	
	if stacks <= 0:
		print("[BattleManager] 大闹天宫: no HP lost, no buffs applied")
		return
	
	# Strength +stacks
	GameManager.modify_strength(stacks)
	
	# Agility +stacks
	player_status.apply_effect("agility", stacks)
	EventBus.status_effect_applied.emit(null, "agility", stacks)
	
	# Regeneration +stacks
	player_status.apply_effect("regeneration", stacks)
	EventBus.status_effect_applied.emit(null, "regeneration", stacks)
	
	# Overcharge +stacks
	player_status.apply_effect("overcharge", stacks)
	EventBus.status_effect_applied.emit(null, "overcharge", stacks)
	
	# Thorns +stacks
	player_status.apply_effect("thorns", stacks)
	EventBus.status_effect_applied.emit(null, "thorns", stacks)
	
	print("[BattleManager] 大闹天宫: lost %d HP, gained %d stacks of strength/agility/regeneration/overcharge/thorns (hp_per_stack=%d)" % [hp_lost, stacks, hp_per_stack])

## Ni Zhuan Qian Kun (逆转乾坤): consume X% current HP, recover equivalent mana and stamina
func _apply_ni_zhuan_qian_kun(effect: Dictionary) -> void:
	var hp_percent: int = effect.get("hp_percent", 10)
	var hp_cost: int = int(GameManager.current_hp * hp_percent / 100.0)
	
	if hp_cost <= 0:
		hp_cost = 1
	
	# Prevent self-kill: ensure at least 1 HP remains
	if hp_cost >= GameManager.current_hp:
		hp_cost = GameManager.current_hp - 1
	
	if hp_cost <= 0:
		print("[BattleManager] 逆转乾坤: HP too low, cannot activate")
		return
	
	# Consume HP
	GameManager.modify_hp(-hp_cost)
	
	# Recover mana and stamina equal to HP consumed
	GameManager.modify_mana(hp_cost)
	GameManager.modify_stamina(hp_cost)
	
	print("[BattleManager] 逆转乾坤: consumed %d HP (%d%%), gained %d mana and %d stamina" % [hp_cost, hp_percent, hp_cost, hp_cost])

## Transform all hand cards into random cards (七十二变)
## The transformation is temporary - original card info is preserved so cards
## revert to their original identity when discarded/played (end of battle restore).
func _transform_all_hand_cards() -> void:
	var character_id: String = GameManager.current_character_id
	var card_pool: Array[String] = DataManager.get_available_cards_for_character(character_id)
	
	if card_pool.is_empty():
		return
	
	# Collect current hand cards (excluding the card being played, which is already removed)
	var cards_to_transform: Array[Control] = hand_manager.hand_cards.duplicate()
	
	for card_node in cards_to_transform:
		var old_card_id: String = card_node.card_data.get("card_id", "")
		var old_star_level: int = card_node.card_data.get("star_level", 1)
		
		# Pick a random card from pool (different from the original if possible)
		var new_card_id: String = card_pool[randi() % card_pool.size()]
		var attempts := 0
		while new_card_id == old_card_id and attempts < 10:
			new_card_id = card_pool[randi() % card_pool.size()]
			attempts += 1
		
		# Get new card data
		var new_card_data: Dictionary = DataManager.get_card(new_card_id)
		if new_card_data.is_empty():
			continue
		
		new_card_data = new_card_data.duplicate(true)
		new_card_data["star_level"] = 1
		var star_effects: Array = CardFusionManager.get_card_effects_at_star(new_card_id, 1)
		if not star_effects.is_empty():
			new_card_data["effects"] = star_effects
		
		# Update the card node with new data
		card_node.setup(new_card_data, 1)
		
		# Update deck_manager hand tracking, preserving original card info for restoration
		for i in range(deck_manager.hand.size()):
			var hand_entry: Dictionary = deck_manager.hand[i]
			if hand_entry.get("card_id", "") == old_card_id:
				# Save original card info before overwriting
				var original_id: String = hand_entry.get("_original_card_id", old_card_id)
				var original_star: int = hand_entry.get("_original_star_level", old_star_level)
				deck_manager.hand[i] = {
					"card_id": new_card_id,
					"star_level": 1,
					"_original_card_id": original_id,
					"_original_star_level": original_star
				}
				break
	
	# Update playable states after transformation
	hand_manager.update_playable_states(GameManager.current_mana, GameManager.current_stamina)
	print("[BattleManager] 七十二变: transformed %d hand cards" % cards_to_transform.size())

## Check if an effect condition is met
func _check_effect_condition(condition: String, target: Node) -> bool:
	match condition:
		"enemy_intent_attack":
			if target != null and target.get("current_intent") is Dictionary:
				var intent_type: String = target.current_intent.get("type", "")
				return intent_type == "attack"
			# If no specific target, check any enemy with attack intent
			for enemy in enemies:
				if enemy != null and enemy.get("current_intent") is Dictionary:
					var intent_type: String = enemy.current_intent.get("type", "")
					if intent_type == "attack":
						return true
			return false
	return true

## Get combo bonus damage (combo starts at 3rd attack card, +1 per card after that)
func _get_combo_bonus() -> int:
	if attack_cards_played_this_turn >= 3:
		return attack_cards_played_this_turn - 2
	return 0

## 对目标造成伤害
func _deal_damage_to_target(base_damage: int, target_type: String, target: Node) -> void:
	var strength := GameManager.current_strength
	var combo_bonus := _get_combo_bonus()
	
	if target_type == "enemy" and target != null:
		var result := DamageCalculator.calculate_damage(
			base_damage, strength, 0.0, 0, 0.0,
			target.get("current_armor") if target.get("current_armor") != null else 0,
			combo_bonus
		)
		
		if target.has_method("take_damage"):
			target.take_damage(result.actual_damage, result.armor_absorbed)
		
		# Armor break: deal extra damage ignoring armor per stack
		if target.has_method("has_status") and target.has_status("armor_break"):
			var armor_break_stacks: int = target.get("status_manager").get_stacks("armor_break")
			if armor_break_stacks > 0 and target.has_method("take_damage"):
				target.take_damage(armor_break_stacks, 0)
				GameManager.record_damage(armor_break_stacks)
				EventBus.damage_dealt.emit(target, armor_break_stacks, "armor_break")
		
		GameManager.record_damage(result.final_damage)
		EventBus.damage_dealt.emit(target, result.final_damage, "attack")
		
		# Trigger relic on_attack effects (e.g. aoe_splash from Ba Jiao Shan)
		_trigger_on_attack_relics(result.final_damage, target)
	
	elif target_type == "all_enemies":
		for enemy in enemies:
			var result := DamageCalculator.calculate_damage(
				base_damage, strength, 0.0, 0, 0.0,
				enemy.get("current_armor") if enemy.get("current_armor") != null else 0,
				combo_bonus
			)
			
			if enemy.has_method("take_damage"):
				enemy.take_damage(result.actual_damage, result.armor_absorbed)
			
			# Armor break: deal extra damage ignoring armor per stack
			if enemy.has_method("has_status") and enemy.has_status("armor_break"):
				var armor_break_stacks: int = enemy.get("status_manager").get_stacks("armor_break")
				if armor_break_stacks > 0 and enemy.has_method("take_damage"):
					enemy.take_damage(armor_break_stacks, 0)
					GameManager.record_damage(armor_break_stacks)
					EventBus.damage_dealt.emit(enemy, armor_break_stacks, "armor_break")
			
			GameManager.record_damage(result.final_damage)
			EventBus.damage_dealt.emit(enemy, result.final_damage, "attack")

## Trigger on_attack relic effects after dealing damage
func _trigger_on_attack_relics(final_damage: int, attack_target: Node) -> void:
	for relic_entry in GameManager.current_relics:
		var relic_id: String = relic_entry.get("relic_id", "") if relic_entry is Dictionary else str(relic_entry)
		var enhance_level: int = relic_entry.get("enhance_level", 0) if relic_entry is Dictionary else 0
		var relic_data: Dictionary = DataManager.get_relic(relic_id)
		if relic_data.is_empty():
			continue
		var trigger_type: String = relic_data.get("trigger_type", "")
		if trigger_type != "on_attack":
			continue
		
		match relic_id:
			"ba_jiao_shan":
				_apply_ba_jiao_shan(final_damage, attack_target, enhance_level)
			"jin_gu_bang":
				_apply_jin_gu_bang(final_damage, attack_target, enhance_level)
			"feng_huo_lun":
				_apply_feng_huo_lun(final_damage, attack_target, enhance_level)
			"po_mo_jian":
				_apply_po_mo_jian(attack_target, enhance_level)

## Ba Jiao Shan: chance to deal splash damage to all enemies (enhance: +1 flat splash damage per level)
func _apply_ba_jiao_shan(final_damage: int, attack_target: Node, enhance_level: int) -> void:
	var splash_chance: float = 0.25
	var splash_percent: float = 0.5
	
	if randf() < splash_chance:
		var splash_dmg := maxi(1, int(final_damage * splash_percent) + enhance_level)
		for enemy in enemies:
			if enemy == null or (enemy.has_method("is_dead") and enemy.is_dead()):
				continue
			if enemy == attack_target:
				continue  # Skip the original target
			var enemy_armor: int = enemy.get("current_armor") if enemy.get("current_armor") != null else 0
			var splash_result := DamageCalculator.calculate_damage(splash_dmg, 0, 0.0, 0, 0.0, enemy_armor)
			if enemy.has_method("take_damage"):
				enemy.take_damage(splash_result.actual_damage, splash_result.armor_absorbed)
			GameManager.record_damage(splash_result.final_damage)
			EventBus.damage_dealt.emit(enemy, splash_result.final_damage, "relic_splash")
		EventBus.relic_effect_triggered.emit(null)

## Jin Gu Bang (Ruyi Jingu Bang): chance to gain strength on attack (enhance: +1 strength per level)
func _apply_jin_gu_bang(_final_damage: int, _attack_target: Node, enhance_level: int) -> void:
	var chance: float = 0.2
	var strength_gain: int = 1 + enhance_level
	
	if randf() < chance:
		GameManager.modify_strength(strength_gain)
		EventBus.relic_effect_triggered.emit(null)

## Feng Huo Lun: chance to trigger extra attack (enhance: +1 extra damage per level)
func _apply_feng_huo_lun(_final_damage: int, attack_target: Node, enhance_level: int) -> void:
	var chance: float = 0.2
	
	if randf() < chance:
		# Extra attack with base strength damage + enhance bonus
		var strength := GameManager.current_strength + enhance_level
		var enemy_armor: int = attack_target.get("current_armor") if attack_target.get("current_armor") != null else 0
		var extra_result := DamageCalculator.calculate_damage(strength, 0, 0.0, 0, 0.0, enemy_armor)
		if attack_target.has_method("take_damage"):
			attack_target.take_damage(extra_result.actual_damage, extra_result.armor_absorbed)
		GameManager.record_damage(extra_result.final_damage)
		EventBus.damage_dealt.emit(attack_target, extra_result.final_damage, "relic_extra")
		EventBus.relic_effect_triggered.emit(null)

## Po Mo Jian: chance to dispel enemy buff (enhance: +1 dispel count per level)
func _apply_po_mo_jian(attack_target: Node, enhance_level: int) -> void:
	var chance: float = 0.15
	var dispel_count: int = 1 + enhance_level
	
	if randf() < chance:
		if attack_target.has_method("remove_random_buff"):
			for i in range(dispel_count):
				attack_target.remove_random_buff()

## 结束玩家回合
func end_player_turn() -> void:
	if current_state != BattleState.PLAYER_TURN:
		return
	
	# 弃掉所有手牌
	deck_manager.discard_all_hand()
	hand_manager.discard_all()
	
	EventBus.player_turn_ended.emit()
	
	# 进入敌人回合
	_start_enemy_turn()

## 开始敌人回合
func _start_enemy_turn() -> void:
	current_state = BattleState.ENEMY_TURN
	EventBus.enemy_turn_started.emit()
	
	# 敌人依次行动
	for enemy in enemies:
		if enemy == null or (enemy.has_method("is_dead") and enemy.is_dead()):
			continue
		
		# 检查眩晕
		if enemy.has_method("has_status") and enemy.has_status("stun"):
			continue
		
		if enemy.has_method("execute_intent"):
			await enemy.execute_intent()
	
	EventBus.enemy_turn_ended.emit()
	
	# 回合结束结算
	_end_turn()

## 回合结束
func _end_turn() -> void:
	current_state = BattleState.TURN_END
	
	# 玩家状态效果回合结束结算
	var results := player_status.on_turn_end()
	
	# 灼烧伤害
	if results.damage > 0:
		GameManager.modify_hp(-results.damage)
		EventBus.damage_dealt.emit(null, results.damage, "burn")
	
	# 治愈回复
	if results.heal > 0:
		GameManager.modify_hp(results.heal)
		EventBus.healing_applied.emit(null, results.heal)
	
	# 通知UI更新角色状态显示
	EventBus.status_effect_applied.emit(null, "", 0)
	
	# 敌人状态效果结算
	for enemy in enemies:
		if enemy != null and not (enemy.has_method("is_dead") and enemy.is_dead()) and enemy.has_method("on_turn_end"):
			enemy.on_turn_end()
	
	# 检查胜负
	if GameManager.current_hp <= 0:
		_on_battle_lost()
		return
	
	if _check_all_enemies_dead():
		_on_battle_won()
		return
	
	EventBus.turn_ended.emit(turn_number)
	
	# 开始新回合
	_start_player_turn()

## Get the count of alive enemies
func _get_alive_enemy_count() -> int:
	var count := 0
	for enemy in enemies:
		if enemy != null and not (enemy.has_method("is_dead") and enemy.is_dead()):
			count += 1
	return count

## 检查所有敌人是否死亡
func _check_all_enemies_dead() -> bool:
	for enemy in enemies:
		if enemy != null and enemy.has_method("is_dead") and not enemy.is_dead():
			return false
	return enemies.is_empty() or enemies.all(func(e): return e == null or (e.has_method("is_dead") and e.is_dead()))

## 战斗胜利
func _on_battle_won() -> void:
	current_state = BattleState.VICTORY
	GameManager.stats.enemies_defeated += enemies.size()
	
	# 齐天大圣被动：战斗结束回复5点生命
	if GameManager.current_character_id == "sun_wukong":
		GameManager.modify_hp(5)
	
	EventBus.battle_ended.emit(true)
	battle_won.emit()

## 战斗失败
func _on_battle_lost() -> void:
	current_state = BattleState.DEFEAT
	EventBus.battle_ended.emit(false)
	battle_lost.emit()

## 添加敌人
func add_enemy(enemy_node: Node) -> void:
	enemies.append(enemy_node)

## 移除敌人
func remove_enemy(enemy_node: Node) -> void:
	enemies.erase(enemy_node)

## 对玩家造成伤害（敌人调用）
func deal_damage_to_player(base_damage: int, attacker: Node = null) -> void:
	var damage_reduction := 0.0
	
	var result := DamageCalculator.calculate_damage(
		base_damage, 0, 0.0, 0, damage_reduction, GameManager.current_armor
	)
	
	# 金身检查
	if player_status.has_effect("golden_body"):
		result.actual_damage = mini(1, result.actual_damage)
		player_status.remove_effect("golden_body", 1)
	
	# 应用护甲消耗
	GameManager.modify_armor(-result.armor_absorbed)
	
	# 应用伤害
	GameManager.modify_hp(-result.actual_damage)
	
	# 破甲：每层额外受到1点无视护甲伤害
	var armor_break_stacks := player_status.get_stacks("armor_break")
	if armor_break_stacks > 0:
		GameManager.modify_hp(-armor_break_stacks)
		EventBus.damage_dealt.emit(null, armor_break_stacks, "armor_break")
	
	EventBus.damage_taken.emit(null, result.actual_damage + armor_break_stacks if armor_break_stacks > 0 else result.actual_damage)
	
	# 反甲：受到攻击时，每层对敌方造成伤害+1
	var thorns_stacks := player_status.get_stacks("thorns")
	if thorns_stacks > 0 and attacker != null:
		if attacker.has_method("take_damage"):
			attacker.take_damage(thorns_stacks, 0)
			EventBus.damage_dealt.emit(attacker, thorns_stacks, "thorns")
	
	# 反击：每层对1个敌人造成等量受到的伤害
	var on_damage_results := player_status.on_damage_taken(base_damage, null)
	if on_damage_results.reflect_damage > 0:
		var counter_stacks: int = on_damage_results.get("counter_stacks", 1)
		var reflect_dmg: int = on_damage_results.reflect_damage
		var alive_enemies: Array[Node] = []
		for enemy in enemies:
			if enemy != null and not (enemy.has_method("is_dead") and enemy.is_dead()):
				alive_enemies.append(enemy)
		if not alive_enemies.is_empty():
			for i in range(counter_stacks):
				var target_enemy: Node = alive_enemies[i % alive_enemies.size()]
				if target_enemy.has_method("take_damage"):
					target_enemy.take_damage(reflect_dmg, 0)
					EventBus.damage_dealt.emit(target_enemy, reflect_dmg, "counter")
	
	# 检查死亡
	if GameManager.current_hp <= 0:
		# 观音玉瓶：受到致命伤害时保留1点生命，触发后永久消失
		if GameManager.has_relic("guan_yin_yu_ping"):
			var enhance_level: int = GameManager.get_relic_enhance("guan_yin_yu_ping")
			GameManager.current_hp = 1
			EventBus.health_changed.emit(GameManager.current_hp, GameManager.max_hp)
			EventBus.relic_effect_triggered.emit(null)
			# Enhancement: heal extra HP based on enhance level
			if enhance_level > 0:
				var heal_amount: int = enhance_level * 5
				GameManager.modify_hp(heal_amount)
			# Permanently remove the relic
			GameManager.remove_relic("guan_yin_yu_ping")
			return
		_on_battle_lost()

## 清理战斗
func cleanup() -> void:
	if player_status:
		player_status.queue_free()
		player_status = null
	enemies.clear()
	turn_number = 0
