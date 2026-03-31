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
	max_cards_per_turn = 99
	
	# 恢复法力
	GameManager.reset_mana()
	
	# 回合开始状态效果结算
	var turn_start_results := player_status.on_turn_start()
	
	# 充盈加成
	if turn_start_results.mana_bonus > 0:
		GameManager.modify_mana(turn_start_results.mana_bonus)
	
	# 减速限制
	if turn_start_results.card_limit_reduction > 0:
		max_cards_per_turn = maxi(1, 5 - turn_start_results.card_limit_reduction)
	
	# 抽5张手牌
	var drawn_cards: Array[Dictionary] = deck_manager.draw_cards(5)
	for card_data in drawn_cards:
		hand_manager.add_card(card_data)
	
	# 更新可打出状态
	hand_manager.update_playable_states(GameManager.current_mana, GameManager.current_stamina)
	
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
	var energy_cost: int = card_data.get("energy_cost", 1)
	var stamina_cost: int = card_data.get("stamina_cost", 0)
	var card_type: String = card_data.get("card_type", "attack")
	
	# 封印检查：无法使用技能牌
	if player_status.has_effect("seal") and card_type == "skill":
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
	current_state = BattleState.PLAYER_ACTION
	
	# 执行卡牌效果
	_execute_card_effects(card_data, target)
	
	# 从手牌移除并加入弃牌堆
	var card_id: String = card_data.get("card_id", "")
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
	if card_data.get("is_upgraded", false):
		var upgraded_effects: Array = card_data.get("upgraded_effects", [])
		if not upgraded_effects.is_empty():
			effects = upgraded_effects
	
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

## 对目标造成伤害
func _deal_damage_to_target(base_damage: int, target_type: String, target: Node) -> void:
	var strength := GameManager.current_strength
	var vulnerable_stacks := 0
	
	if target_type == "enemy" and target != null:
		if target.has_method("get_vulnerable_stacks"):
			vulnerable_stacks = target.get_vulnerable_stacks()
		
		var result := DamageCalculator.calculate_damage(
			base_damage, strength, 0.0, vulnerable_stacks, 0.0,
			target.get("current_armor") if target.get("current_armor") != null else 0
		)
		
		if target.has_method("take_damage"):
			target.take_damage(result.actual_damage, result.armor_absorbed)
		
		GameManager.record_damage(result.final_damage)
		EventBus.damage_dealt.emit(target, result.final_damage, "attack")
	
	elif target_type == "all_enemies":
		for enemy in enemies:
			if enemy.has_method("get_vulnerable_stacks"):
				vulnerable_stacks = enemy.get_vulnerable_stacks()
			
			var result := DamageCalculator.calculate_damage(
				base_damage, strength, 0.0, vulnerable_stacks, 0.0,
				enemy.get("current_armor") if enemy.get("current_armor") != null else 0
			)
			
			if enemy.has_method("take_damage"):
				enemy.take_damage(result.actual_damage, result.armor_absorbed)
			
			GameManager.record_damage(result.final_damage)
			EventBus.damage_dealt.emit(enemy, result.final_damage, "attack")

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
		if enemy != null and enemy.has_method("on_turn_end"):
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
	var vulnerable_stacks := player_status.get_stacks("vulnerable")
	var damage_reduction := 0.0
	
	if player_status.has_effect("damage_halve"):
		damage_reduction = 0.5
	
	var result := DamageCalculator.calculate_damage(
		base_damage, 0, 0.0, vulnerable_stacks, damage_reduction, GameManager.current_armor
	)
	
	# 金身检查
	if player_status.has_effect("golden_body"):
		result.actual_damage = mini(1, result.actual_damage)
		player_status.remove_effect("golden_body", 1)
	
	# 应用护甲消耗
	GameManager.modify_armor(-result.armor_absorbed)
	
	# 应用伤害
	GameManager.modify_hp(-result.actual_damage)
	
	EventBus.damage_taken.emit(null, result.actual_damage)
	
	# 反甲/反击
	var on_damage_results := player_status.on_damage_taken(base_damage, null)
	if on_damage_results.reflect_damage > 0 and attacker != null:
		if attacker.has_method("take_damage"):
			attacker.take_damage(on_damage_results.reflect_damage, 0)
	
	# 检查死亡
	if GameManager.current_hp <= 0:
		_on_battle_lost()

## 清理战斗
func cleanup() -> void:
	if player_status:
		player_status.queue_free()
		player_status = null
	enemies.clear()
	turn_number = 0
