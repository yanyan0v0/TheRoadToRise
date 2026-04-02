## 战斗场景脚本 - 管理战斗界面布局和交互
extends Control

const ENEMY_SCENE := preload("res://scenes/battle/Enemy.tscn")

var battle_manager: Node = null
var deck_manager: Node = null
var hand_manager: Node = null
var selected_target: Node = null

@onready var battle_area: Control = $BattleArea
@onready var player_area: Control = $BattleArea/PlayerArea
@onready var enemy_area: HBoxContainer = $BattleArea/EnemyArea
@onready var player_sprite: ColorRect = $BattleArea/PlayerArea/PlayerSprite
@onready var player_label: Label = $BattleArea/PlayerArea/PlayerSprite/PlayerLabel
@onready var player_hp_bar: ProgressBar = $BattleArea/PlayerArea/PlayerHPBar
@onready var player_armor_label: Label = $BattleArea/PlayerArea/ArmorLabel
@onready var player_status_bar: HBoxContainer = $BattleArea/PlayerArea/StatusBar
@onready var player_debuff_bar: HBoxContainer = $BattleArea/PlayerArea/PlayerStatusBar
@onready var hand_area: Control = $HandArea
@onready var end_turn_button: Button = $EndTurnButton
@onready var draw_pile_label: Label = $DrawPileLabel
@onready var discard_pile_label: Label = $DiscardPileLabel
@onready var floating_text_container: Control = $FloatingTextContainer
@onready var pause_menu: Control = $PauseMenu

@onready var player_hp_text: Label = $BattleArea/PlayerArea/PlayerHPText

## 战斗初始状态（用于重打）
var _initial_hp: int = 0
var _initial_armor: int = 0
var _initial_deck: Array[Dictionary] = []
var _initial_consumables: Array[String] = []
var _initial_gold: int = 0
var _initial_mana: int = 0
var _initial_max_mana: int = 0
## 重打标记：是否为重打模式（重打时不洗牌，保持卡牌顺序）
static var _is_restart: bool = false
static var _restart_deck_order: Array[Dictionary] = []



func _ready() -> void:
	GameManager.change_state(GameManager.GameState.BATTLE)
	
	# 初始化子系统
	deck_manager = Node.new()
	deck_manager.set_script(load("res://scripts/cards/DeckManager.gd"))
	deck_manager.name = "DeckManager"
	add_child(deck_manager)
	
	hand_manager = $HandArea
	
	battle_manager = Node.new()
	battle_manager.set_script(load("res://scripts/battle/BattleManager.gd"))
	battle_manager.name = "BattleManager"
	add_child(battle_manager)
	
	# 连接信号
	end_turn_button.pressed.connect(_on_end_turn_pressed)
	hand_manager.card_play_requested.connect(_on_card_play_requested)
	
	battle_manager.battle_won.connect(_on_battle_won)
	battle_manager.battle_lost.connect(_on_battle_lost)
	
	deck_manager.deck_changed.connect(_on_deck_changed)
	
	# 连接EventBus信号
	EventBus.health_changed.connect(_on_health_changed)
	EventBus.armor_changed.connect(_on_armor_changed)
	EventBus.gold_changed.connect(_on_gold_changed)
	EventBus.mana_changed.connect(_on_mana_changed)
	EventBus.damage_dealt.connect(_on_damage_dealt)
	EventBus.healing_applied.connect(_on_healing_applied)
	EventBus.enemy_died.connect(_on_enemy_died)
	EventBus.status_effect_applied.connect(_on_status_effect_applied)
	
	# 保存战斗初始状态（用于重打）
	_initial_hp = GameManager.current_hp
	_initial_armor = GameManager.current_armor
	_initial_deck = GameManager.current_deck.duplicate(true)
	_initial_consumables = GameManager.current_consumables.duplicate()
	_initial_gold = GameManager.current_gold
	_initial_mana = GameManager.current_mana
	_initial_max_mana = GameManager.max_mana
	
	# 如果是重打模式，恢复卡牌顺序并清除标记
	var _no_shuffle := false
	if _is_restart and not _restart_deck_order.is_empty():
		GameManager.current_deck = _restart_deck_order.duplicate(true)
		_initial_deck = _restart_deck_order.duplicate(true)
		_no_shuffle = true
		_is_restart = false
		_restart_deck_order.clear()
	
	# 初始化UI
	_update_player_ui()
	_update_player_name()
	
	# 加载敌人数据	
	# 加载敌人数据（从 GameManager 获取当前战斗的敌人）
	_setup_battle(_no_shuffle)

## 设置战斗
func _setup_battle(no_shuffle: bool = false) -> void:
	# 获取当前节点的敌人数据（简化：默认加载一个普通敌人）
	var enemy_ids := _get_current_enemies()
	var enemy_data_list: Array = []
	
	for enemy_id in enemy_ids:
		var data := DataManager.get_enemy(enemy_id)
		if not data.is_empty():
			enemy_data_list.append(data)
			_spawn_enemy(data)
	
	# 初始化战斗（重打时不洗牌）
	battle_manager.init_battle(enemy_data_list, deck_manager, hand_manager, not no_shuffle)

## 获取当前战斗的敌人列表
func _get_current_enemies() -> Array[String]:
	# 根据章节和战斗类型随机选择敌人组合
	var chapter := GameManager.current_chapter
	var battle_type := GameManager.current_battle_type
	
	if battle_type == "boss":
		match chapter:
			0: return ["bai_gu_fu_ren"]
			1: return ["huang_pao_guai"]
			2: return ["niu_mo_wang"]
			3: return ["ru_lai_hua_shen"]
		return ["bai_gu_fu_ren"]
	
	if battle_type == "elite":
		var elite_pools: Array = [
			["sheng_ying_da_wang"], ["pi_pa_jing"], ["liu_er_mi_hou"],
			["jiu_tou_chong"], ["sai_tai_sui"]
		]
		var elite_result: Array[String] = []
		for s in elite_pools[randi() % elite_pools.size()]:
			elite_result.append(s)
		return elite_result
	
	# 普通战斗：根据章节随机组合
	var normal_pools: Array = []
	match chapter:
		0:
			normal_pools = [
				["hun_shi_mo_wang", "yin_jiang_jun"],
				["xiong_shan_jun", "te_chu_shi"],
				["hei_feng_guai", "bai_yi_xiu_shi"],
				["ling_xu_zi", "yin_jiang_jun", "te_chu_shi"],
				["hun_shi_mo_wang", "xiong_shan_jun"],
				["hei_feng_guai", "ling_xu_zi"],
			]
		1:
			normal_pools = [
				["huang_feng_guai", "jing_xi_gui"],
				["bai_gu_jing", "yin_jiao"],
				["ling_li_chong", "shi_li_guai"],
				["huang_pao_guai", "jing_xi_gui", "ling_li_chong"],
				["tuo_long", "shi_li_guai"],
			]
		2:
			normal_pools = [
				["hu_li_da_xian", "lu_li_da_xian"],
				["yang_li_da_xian", "jin_yu_guai"],
				["ru_yi_zhen_xian", "hu_li_da_xian", "tuo_long"],
				["tie_shan_gong_zhu", "yu_mian_hu_li"],
				["jin_yu_guai", "lu_li_da_xian", "yang_li_da_xian"],
			]
		3:
			normal_pools = [
				["ben_bo_er_ba", "ba_bo_er_ben", "gu_zhi_gong"],
				["xing_xian", "ju_mang_guai"],
				["qi_zhi_zhu_jing", "mi_ma_lu_ban"],
				["bai_lu_guai", "bai_mian_hu_li", "jin_bi_lao_shu_jing"],
			]
	
	if normal_pools.is_empty():
		return ["hun_shi_mo_wang"]
	var result: Array[String] = []
	for s in normal_pools[randi() % normal_pools.size()]:
		result.append(s)
	return result

## 生成敌人节点
func _spawn_enemy(data: Dictionary) -> void:
	if ENEMY_SCENE == null:
		# 如果敌人场景还未创建，使用占位
		var enemy_placeholder := _create_enemy_placeholder(data)
		enemy_area.add_child(enemy_placeholder)
		battle_manager.add_enemy(enemy_placeholder)
		return
	
	var enemy := ENEMY_SCENE.instantiate()
	enemy_area.add_child(enemy)
	if enemy.has_method("setup"):
		enemy.setup(data, battle_manager)
	battle_manager.add_enemy(enemy)
	# 设置hover事件
	_setup_enemy_hover(enemy)

## 创建敌人占位节点
func _create_enemy_placeholder(data: Dictionary) -> Control:
	var container := Control.new()
	container.custom_minimum_size = Vector2(150, 200)
	
	var sprite := ColorRect.new()
	sprite.custom_minimum_size = Vector2(120, 120)
	sprite.color = Color("D63031")
	sprite.position = Vector2(15, 0)
	container.add_child(sprite)
	
	var name_label := Label.new()
	name_label.text = data.get("enemy_name", "???")
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.position = Vector2(0, 125)
	name_label.size = Vector2(150, 25)
	container.add_child(name_label)
	
	return container

## 更新玩家名称显示
func _update_player_name() -> void:
	var char_data: Dictionary = DataManager.get_character(GameManager.current_character_id)
	var char_name: String = char_data.get("character_name", "取经人")
	player_label.text = char_name

## 更新玩家UI
func _update_player_ui() -> void:
	player_hp_bar.max_value = GameManager.max_hp
	player_hp_bar.value = GameManager.current_hp
	player_armor_label.text = "护甲: %d" % GameManager.current_armor
	player_hp_text.text = "%d/%d" % [GameManager.current_hp, GameManager.max_hp]

## 结束回合
func _on_end_turn_pressed() -> void:
	end_turn_button.disabled = true
	battle_manager.end_player_turn()
	# 等待敌人回合结束后重新启用
	await get_tree().create_timer(1.0).timeout
	end_turn_button.disabled = false

## 卡牌打出请求
func _on_card_play_requested(card: Control) -> void:
	# 获取目标：优先使用鼠标悬停的敌人，否则随机选择
	var target: Node = null
	if battle_manager.enemies.size() > 0:
		# 检查是否有被悬停高亮的敌人
		var hovered_enemy: Node = _get_hovered_enemy()
		if hovered_enemy != null:
			target = hovered_enemy
		else:
			# 随机选择一个存活的敌人
			var alive_enemies: Array = []
			for enemy in battle_manager.enemies:
				if enemy != null and not (enemy.has_method("is_dead") and enemy.is_dead()):
					alive_enemies.append(enemy)
			if not alive_enemies.is_empty():
				target = alive_enemies[randi() % alive_enemies.size()]
	
	var success: bool = battle_manager.play_card(card, target)
	if success:
		# 播放打出动画
		var target_pos := enemy_area.global_position + Vector2(75, 60)
		if target != null and target is Control:
			target_pos = target.global_position + Vector2(60, 70)
		card.animate_play(target_pos)
		# 清除敌人选中状态
		_clear_enemy_highlights()

## 获取当前被悬停的敌人
func _get_hovered_enemy() -> Node:
	for enemy in battle_manager.enemies:
		if enemy != null and enemy.has_meta("is_hovered") and enemy.get_meta("is_hovered"):
			return enemy
	return null

## 清除所有敌人高亮
func _clear_enemy_highlights() -> void:
	for enemy in battle_manager.enemies:
		if enemy != null and enemy.has_node("Sprite"):
			enemy.get_node("Sprite").modulate = Color.WHITE
			enemy.set_meta("is_hovered", false)

## 信号回调
func _on_health_changed(current_hp: int, max_hp: int) -> void:
	player_hp_bar.max_value = max_hp
	player_hp_bar.value = current_hp
	player_hp_text.text = "%d/%d" % [current_hp, max_hp]

func _on_armor_changed(current_armor: int) -> void:
	player_armor_label.text = "护甲: %d" % current_armor

func _on_gold_changed(_current_gold: int) -> void:
	pass  # 由GlobalHUD处理

func _on_mana_changed(current_mana: int, max_mana: int) -> void:
	pass  # 由GlobalHUD处理

func _on_deck_changed(draw_count: int, discard_count: int) -> void:
	draw_pile_label.text = "抽牌堆: %d" % draw_count
	discard_pile_label.text = "弃牌堆: %d" % discard_count

func _on_damage_dealt(target: Node, amount: int, damage_type: String) -> void:
	if target != null and target is Control:
		_show_floating_text(target.global_position + Vector2(50, -20), "-%d" % amount, Color("D63031"))

func _on_healing_applied(target: Node, amount: int) -> void:
	_show_floating_text(player_area.global_position + Vector2(50, -20), "+%d" % amount, Color("00B894"))

func _on_enemy_died(enemy: Node) -> void:
	battle_manager.remove_enemy(enemy)

## 显示飘字
func _show_floating_text(pos: Vector2, text: String, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", 24)
	label.global_position = pos
	floating_text_container.add_child(label)
	
	var tween := label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 50, 0.8)
	tween.tween_property(label, "modulate:a", 0.0, 0.8)
	tween.chain().tween_callback(label.queue_free)

## 战斗胜利
func _on_battle_won() -> void:
	# 天劫系统：完美通关（未受伤）增加2点劫数
	if not GameManager.battle_took_damage:
		GameManager.modify_karma(2)
	# 重置战斗受伤标记
	GameManager.battle_took_damage = false
	
	# 渡劫战斗特殊处理
	if GameManager.current_battle_type == "tribulation":
		GameManager.current_karma = 0  # 劫数归零
		GameManager.tribulation_count += 1
		EventBus.karma_changed.emit(0, "清净")
	
	await get_tree().create_timer(1.0).timeout
	SceneTransition.change_scene("res://scenes/reward/RewardScene.tscn")

## 战斗失败
func _on_battle_lost() -> void:
	await get_tree().create_timer(1.0).timeout
	SceneTransition.change_scene("res://scenes/game_over/GameOverScene.tscn")

## 重打：恢复到第一回合之前的状态（供GlobalHUD调用）
func restart_battle() -> void:
	GameManager.current_hp = _initial_hp
	GameManager.current_armor = _initial_armor
	GameManager.current_deck = _initial_deck.duplicate(true)
	GameManager.current_consumables = _initial_consumables.duplicate()
	GameManager.current_gold = _initial_gold
	GameManager.current_mana = _initial_mana
	GameManager.max_mana = _initial_max_mana
	GameManager.reset_mana()
	# 设置重打标记，保存当前卡牌顺序
	_is_restart = true
	_restart_deck_order = _initial_deck.duplicate(true)
	SceneTransition.change_scene("res://scenes/battle/BattleScene.tscn")

## 保存战斗初始状态到GameManager（供返回主菜单后继续游戏用）
func save_battle_state_for_continue() -> void:
	# 恢复到战斗初始状态，这样存档保存的是战斗前的数据
	GameManager.current_hp = _initial_hp
	GameManager.current_armor = _initial_armor
	GameManager.current_deck = _initial_deck.duplicate(true)
	GameManager.current_consumables = _initial_consumables.duplicate()
	GameManager.current_gold = _initial_gold
	GameManager.current_mana = _initial_mana
	GameManager.max_mana = _initial_max_mana

## 状态效果施加回调（更新角色状态显示）
func _on_status_effect_applied(_target: Node, _effect_type: String, _stacks: int) -> void:
	_update_player_status_display()

## 更新角色状态效果显示（显示在血量条下方）
func _update_player_status_display() -> void:
	if battle_manager == null or battle_manager.player_status == null:
		return
	
	# 清除旧的状态图标
	for child in player_debuff_bar.get_children():
		child.queue_free()
	
	# 添加新的状态图标
	var effects: Array[Dictionary] = battle_manager.player_status.get_all_effects()
	for effect in effects:
		var label := Label.new()
		label.text = "%s%d" % [effect.name.left(1), effect.stacks]
		label.add_theme_color_override("font_color", effect.color)
		label.add_theme_font_size_override("font_size", 12)
		player_debuff_bar.add_child(label)





## 生成敌人节点后设置hover事件
func _setup_enemy_hover(enemy: Node) -> void:
	if enemy == null or not enemy.has_node("Sprite"):
		return
	var sprite_node: ColorRect = enemy.get_node("Sprite")
	sprite_node.mouse_filter = Control.MOUSE_FILTER_STOP
	sprite_node.mouse_entered.connect(func():
		enemy.set_meta("is_hovered", true)
		sprite_node.modulate = Color(1.3, 1.1, 0.8)  # 选中高亮
	)
	sprite_node.mouse_exited.connect(func():
		enemy.set_meta("is_hovered", false)
		sprite_node.modulate = Color.WHITE
	)

## 获取指定位置的敌人（供GlobalHUD拖拽调用）
func get_enemy_at_position(pos: Vector2) -> Node:
	if battle_manager == null:
		return null
	for enemy in battle_manager.enemies:
		if enemy == null or (enemy.has_method("is_dead") and enemy.is_dead()):
			continue
		var enemy_rect := Rect2(enemy.global_position, enemy.size if enemy is Control else Vector2(150, 280))
		if enemy_rect.has_point(pos):
			return enemy
	return null

## 对角色使用消耗品（供GlobalHUD拖拽调用）
func apply_consumable_on_player(consumable_id: String, data: Dictionary) -> void:
	var effects: Array = data.get("effects", [])
	for effect in effects:
		var etype: String = effect.get("type", "")
		var value: int = effect.get("value", 0)
		var target_type: String = effect.get("target", "self")
		
		# 只应用对自身有效的效果
		match etype:
			"max_hp":
				GameManager.max_hp += value
				GameManager.modify_hp(value)
				_show_floating_text(player_area.global_position + Vector2(50, -20), "最大HP+%d" % value, Color("00B894"))
			"battle_hp":
				GameManager.modify_hp(value)
				_show_floating_text(player_area.global_position + Vector2(50, -20), "+%d HP" % value, Color("00B894"))
			"heal_percent":
				var heal := int(GameManager.max_hp * value / 100.0)
				GameManager.modify_hp(heal)
				_show_floating_text(player_area.global_position + Vector2(50, -20), "+%d HP" % heal, Color("00B894"))
			"strength":
				GameManager.modify_strength(value)
				_show_floating_text(player_area.global_position + Vector2(50, -20), "力量+%d" % value, Color("FDCB6E"))
			"card_limit":
				if battle_manager != null:
					battle_manager.max_cards_per_turn = value
			"damage":
				# 对敌人的伤害效果不在角色上生效，跳过
				if target_type == "enemy":
					continue
			"status":
				if target_type == "self" and battle_manager != null:
					var status_type: String = effect.get("status_type", "")
					battle_manager.player_status.apply_effect(status_type, value)
					EventBus.status_effect_applied.emit(null, status_type, value)
	
	# 消耗消耗品
	GameManager.use_consumable(consumable_id)
	_update_player_ui()
	print("[消耗品] 对角色使用了 %s" % data.get("consumable_name", ""))

## 对敌人使用消耗品（供GlobalHUD拖拽调用）
func apply_consumable_on_enemy(consumable_id: String, data: Dictionary, target_enemy: Node) -> void:
	var effects: Array = data.get("effects", [])
	for effect in effects:
		var etype: String = effect.get("type", "")
		var value: int = effect.get("value", 0)
		var target_type: String = effect.get("target", "self")
		
		match etype:
			"damage":
				if target_enemy.has_method("take_damage"):
					var result := DamageCalculator.calculate_damage(
						value, GameManager.current_strength, 0.0, 0, 0.0,
						target_enemy.get("current_armor") if target_enemy.get("current_armor") != null else 0
					)
					target_enemy.take_damage(result.actual_damage, result.armor_absorbed)
					EventBus.damage_dealt.emit(target_enemy, result.final_damage, "consumable")
			"remove_armor":
				if target_enemy.has_method("set_armor"):
					target_enemy.set_armor(0)
					_show_floating_text(target_enemy.global_position + Vector2(50, -20), "护甲清除", Color("74B9FF"))
			"status":
				var status_type: String = effect.get("status_type", "")
				if target_enemy.has_method("apply_status"):
					target_enemy.apply_status(status_type, value)
					_show_floating_text(target_enemy.global_position + Vector2(50, -20), "%s+%d" % [status_type, value], Color("FDCB6E"))
			"card_limit":
				if battle_manager != null:
					battle_manager.max_cards_per_turn = value
			# 对自身的效果也一并应用
			"max_hp":
				GameManager.max_hp += value
				GameManager.modify_hp(value)
			"battle_hp":
				GameManager.modify_hp(value)
			"heal_percent":
				var heal := int(GameManager.max_hp * value / 100.0)
				GameManager.modify_hp(heal)
			"strength":
				GameManager.modify_strength(value)
	
	# 消耗消耗品
	GameManager.use_consumable(consumable_id)
	_update_player_ui()
	
	# 检查敌人是否死亡
	if target_enemy.has_method("is_dead") and target_enemy.is_dead():
		EventBus.enemy_died.emit(target_enemy)
	
	print("[消耗品] 对敌人使用了 %s" % data.get("consumable_name", ""))
