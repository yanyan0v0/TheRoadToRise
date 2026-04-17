## 战斗场景脚本 - 管理战斗界面布局和交互
extends Control

const ENEMY_SCENE := preload("res://scenes/battle/Enemy.tscn")

var battle_manager: Node = null
var deck_manager: Node = null
var hand_manager: Node = null
var selected_target: Node = null

@onready var background: TextureRect = $Background
@onready var battle_area: Control = $BattleArea
@onready var player_area: VBoxContainer = $BattleArea/PlayerArea
@onready var enemy_area: HBoxContainer = $BattleArea/EnemyArea
@onready var player_sprite: TextureRect = $BattleArea/PlayerArea/PlayerSprite
@onready var player_label: Label = $BattleArea/PlayerArea/PlayerSprite/PlayerLabel
@onready var player_hp_bar: ProgressBar = $BattleArea/PlayerArea/PlayerHPRow/PlayerHPBar
@onready var player_armor_label: Label = $BattleArea/PlayerArea/PlayerHPRow/ArmorLabel
## Combo center display label (created dynamically)
var _combo_center_label: Label = null
var _combo_tween: Tween = null
@onready var player_debuff_bar: HBoxContainer = $BattleArea/PlayerArea/PlayerStatusBar
@onready var hand_area: Control = $HandArea
@onready var end_turn_button: TextureButton = $EndTurnButton
@onready var draw_pile_label: Label = $DrawPileLabel
@onready var discard_pile_label: Label = $DiscardPileLabel
@onready var floating_text_container: Control = $FloatingTextContainer
@onready var pause_menu: Control = $PauseMenu

@onready var player_hp_text: Label = $BattleArea/PlayerArea/PlayerHPRow/PlayerHPBar/PlayerHPText

## HP bar fill styles
var _hp_fill_normal: StyleBoxFlat = null
var _hp_fill_armored: StyleBoxFlat = null

## Player status effect tooltip
var _player_status_tooltip: PanelContainer = null

## Player status effect descriptions
const PLAYER_STATUS_DESCRIPTIONS := {
	"golden_body": "下次受到的伤害降至1点",
	"regeneration": "每回合恢复生命值，每层+1",
	"thorns": "受到攻击时，每层对敌方造成伤害+1",
	"overcharge": "下回合获得额外法力",
	"agility": "法力消耗减少1",
	"armor_break": "每层每回合受到攻击时无视护甲的伤害+1",
	"slow": "每回合出牌数减少",
	"burn": "每回合受到伤害，每层-1生命",
	"seal": "每层每回合无法发动1次技能",
	"bleed": "流血层数≥当前血量时立即死亡",
	"stun": "无法行动",
	"counter": "受到攻击时反击等量伤害",
	"weaken": "每层力量-1",
	"combo": "连续打出攻击牌的连击数，前3次为蓄力期，3次后每次连击+1伤害加成，打出非攻击牌或回合开始时清0",
}

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

## EndTurnButton hover animation
var _end_turn_base_y: float = 0.0
var _end_turn_tween: Tween = null



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
	end_turn_button.mouse_entered.connect(_on_end_turn_hover)
	end_turn_button.mouse_exited.connect(_on_end_turn_unhover)
	end_turn_button.pivot_offset = end_turn_button.size / 2.0
	_end_turn_base_y = end_turn_button.position.y
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
	
	# Initialize HP bar styles
	_hp_fill_normal = player_hp_bar.get_theme_stylebox("fill").duplicate()
	_hp_fill_armored = _hp_fill_normal.duplicate()
	_hp_fill_armored.bg_color = Color(0.3, 0.75, 0.85, 1)
	
	# Initialize player character frame animation
	_setup_player_animation()
	
	# 初始化UI
	_update_player_ui()
	_update_player_name()
	
	# 加载敌人数据	
	# 加载敌人数据（从 GameManager 获取当前战斗的敌人）
	_setup_battle(_no_shuffle)

## Setup player character sprite from static image
func _setup_player_animation() -> void:
	var char_id := GameManager.current_character_id
	var image_path := "res://ui/images/battle/character/%s.png" % char_id
	var tex := load(image_path) as Texture2D
	if tex != null:
		player_sprite.texture = tex
		player_label.visible = false
		print("[BattleScene] Loaded character image: %s" % image_path)
	else:
		print("[BattleScene] Character image not found: %s" % image_path)

## Load battle background image based on the first enemy id
func _load_battle_background(enemy_ids: Array[String]) -> void:
	var bg_path := "res://ui/images/battle/scene/default.jpg"
	if not enemy_ids.is_empty():
		var first_enemy_id: String = enemy_ids[0]
		var enemy_bg_path := "res://ui/images/battle/scene/%s.jpg" % first_enemy_id
		if ResourceLoader.exists(enemy_bg_path):
			bg_path = enemy_bg_path
	var tex := load(bg_path) as Texture2D
	if tex != null:
		background.texture = tex
		print("[BattleScene] Loaded battle background: %s" % bg_path)
	else:
		print("[BattleScene] Failed to load battle background: %s" % bg_path)

## 设置战斗
func _setup_battle(no_shuffle: bool = false) -> void:
	# 获取当前节点的敌人数据（简化：默认加载一个普通敌人）
	var enemy_ids := _get_current_enemies()
	var enemy_data_list: Array = []
	
	# Load battle background based on the first enemy
	_load_battle_background(enemy_ids)
	
	for enemy_id in enemy_ids:
		var data := DataManager.get_enemy(enemy_id)
		if not data.is_empty():
			enemy_data_list.append(data)
			_spawn_enemy(data)
	
	# 初始化战斗（重打时不洗牌）
	battle_manager.init_battle(enemy_data_list, deck_manager, hand_manager, not no_shuffle)

## 获取当前战斗的敌人列表
func _get_current_enemies() -> Array[String]:
	# If the map node already assigned enemy_ids, use them directly
	if not GameManager.current_enemy_ids.is_empty():
		var result: Array[String] = GameManager.current_enemy_ids.duplicate()
		return result
	
	# Fallback: randomly select enemies (should not normally reach here)
	var chapter := GameManager.current_chapter
	var battle_type := GameManager.current_battle_type
	
	if battle_type == "boss":
		# Use the boss_id assigned by the map node
		var boss_id: String = GameManager.current_boss_id
		if boss_id != "":
			return [boss_id]
		# Fallback: pick a boss from DataManager cache matching current chapter
		var boss_pool: Array[String] = DataManager.get_boss_pool()
		for bid in boss_pool:
			var bdata: Dictionary = DataManager.get_enemy(bid)
			if bdata.get("chapter", -1) == chapter:
				return [bid]
		if not boss_pool.is_empty():
			return [boss_pool[randi() % boss_pool.size()]]
		return ["bai_gu_jing"]
	
	if battle_type == "elite":
		var elite_ids: Array[String] = DataManager.get_elite_pool()
		var elite_pools: Array = []
		for eid in elite_ids:
			elite_pools.append([eid])
		if elite_pools.is_empty():
			return ["hun_shi_mo_wang"]
		var chosen: Array = _pick_unique_pool(elite_pools)
		var elite_result: Array[String] = []
		for s in chosen:
			elite_result.append(s)
		return elite_result
	
	# 普通战斗：从DataManager缓存获取章节敌人池
	var normal_pools: Array = DataManager.get_normal_enemy_pools(chapter)
	
	if normal_pools.is_empty():
		return ["hun_shi_mo_wang"]
	var chosen: Array = _pick_unique_pool(normal_pools)
	var result: Array[String] = []
	for s in chosen:
		result.append(s)
	return result

## Pick a unique enemy pool that hasn't been encountered yet
func _pick_unique_pool(pools: Array) -> Array:
	# Filter out already encountered pools
	var available: Array = []
	for pool in pools:
		var pool_key: String = ",".join(PackedStringArray(pool))
		if pool_key not in GameManager.encountered_enemy_pools:
			available.append(pool)
	# If all pools have been used, reset and allow all
	if available.is_empty():
		available = pools.duplicate()
	var chosen: Array = available[randi() % available.size()]
	# Record this pool as encountered
	var chosen_key: String = ",".join(PackedStringArray(chosen))
	GameManager.encountered_enemy_pools.append(chosen_key)
	return chosen

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

## Spawn a summoned enemy during battle (called by EnemyController)
func spawn_summon_enemy(data: Dictionary) -> void:
	if ENEMY_SCENE == null:
		return
	
	var enemy := ENEMY_SCENE.instantiate()
	enemy_area.add_child(enemy)
	if enemy.has_method("setup"):
		enemy.setup(data, battle_manager)
	battle_manager.add_enemy(enemy)
	_setup_enemy_hover(enemy)
	
	# Play a spawn animation (fade in + scale up)
	if enemy is Control:
		enemy.modulate = Color(1, 1, 1, 0)
		enemy.scale = Vector2(0.5, 0.5)
		var tween := enemy.create_tween().set_parallel(true)
		tween.tween_property(enemy, "modulate:a", 1.0, 0.3)
		tween.tween_property(enemy, "scale", Vector2(1.0, 1.0), 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

## 创建敌人占位节点
func _create_enemy_placeholder(data: Dictionary) -> Control:
	var container := Control.new()
	container.custom_minimum_size = Vector2(200, 350)
	
	var sprite := ColorRect.new()
	sprite.custom_minimum_size = Vector2(200, 200)
	sprite.color = Color("D63031")
	sprite.position = Vector2(0, 10)
	container.add_child(sprite)
	
	var name_label := Label.new()
	name_label.text = data.get("enemy_name", "???")
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.position = Vector2(0, 215)
	name_label.size = Vector2(200, 25)
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
	player_hp_text.text = "%d/%d" % [GameManager.current_hp, GameManager.max_hp]
	_update_player_armor_display(GameManager.current_armor)
	_update_combo_display()

## 结束回合
func _on_end_turn_pressed() -> void:
	end_turn_button.disabled = true
	battle_manager.end_player_turn()
	# 等待敌人回合结束后重新启用
	await get_tree().create_timer(1.0).timeout
	end_turn_button.disabled = false

func _on_end_turn_hover() -> void:
	if _end_turn_tween != null:
		_end_turn_tween.kill()
	_end_turn_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_end_turn_tween.tween_property(end_turn_button, "position:y", _end_turn_base_y + 4, 0.15)
	_end_turn_tween.parallel().tween_property(end_turn_button, "scale", Vector2(0.95, 0.95), 0.15)

func _on_end_turn_unhover() -> void:
	if _end_turn_tween != null:
		_end_turn_tween.kill()
	_end_turn_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_end_turn_tween.tween_property(end_turn_button, "position:y", _end_turn_base_y, 0.15)
	_end_turn_tween.parallel().tween_property(end_turn_button, "scale", Vector2(1.0, 1.0), 0.15)

## 卡牌打出请求
func _on_card_play_requested(card: Control, drag_target: Node = null) -> void:
	# 获取目标：优先使用拖拽时选中的敌人，其次检查hover meta，最后随机选择
	var target: Node = null
	if battle_manager.enemies.size() > 0:
		# Priority 1: use the target passed from card drag
		if drag_target != null and is_instance_valid(drag_target) and not (drag_target.has_method("is_dead") and drag_target.is_dead()):
			target = drag_target
		else:
			# Priority 2: check is_hovered meta (fallback)
			var hovered_enemy: Node = _get_hovered_enemy()
			if hovered_enemy != null:
				target = hovered_enemy
			else:
				# Priority 3: random alive enemy
				var alive_enemies: Array = []
				for enemy in battle_manager.enemies:
					if enemy != null and not (enemy.has_method("is_dead") and enemy.is_dead()):
						alive_enemies.append(enemy)
				if not alive_enemies.is_empty():
					target = alive_enemies[randi() % alive_enemies.size()]
	
	var success: bool = battle_manager.play_card(card, target)
	if success:
		# Update combo display after playing a card
		_update_combo_display()
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
			var sprite: Object = enemy.get_node("Sprite")
			sprite.modulate = Color.WHITE
			sprite.scale = Vector2.ONE
			enemy.set_meta("is_hovered", false)

## 信号回调
func _on_health_changed(current_hp: int, max_hp: int) -> void:
	player_hp_bar.max_value = max_hp
	player_hp_bar.value = current_hp
	player_hp_text.text = "%d/%d" % [current_hp, max_hp]

func _on_armor_changed(current_armor: int) -> void:
	_update_player_armor_display(current_armor)

## Update player armor display and HP bar color
func _update_player_armor_display(current_armor: int) -> void:
	if current_armor > 0:
		player_armor_label.text = "🛡️%d" % current_armor
		player_hp_bar.add_theme_stylebox_override("fill", _hp_fill_armored)
	else:
		player_armor_label.text = ""
		player_hp_bar.add_theme_stylebox_override("fill", _hp_fill_normal)

## Update combo display - show combo text in screen center
func _update_combo_display() -> void:
	if battle_manager == null:
		return
	var combo: int = battle_manager.combo_display_count
	if combo >= 2:
		_show_combo_center_text(combo)
	# Update player status bar to show combo status
	_update_player_status_display()

## Show combo text in the center of the screen, fading out after 3 seconds
func _show_combo_center_text(combo_count: int) -> void:
	# Kill previous tween if any
	if _combo_tween != null and _combo_tween.is_valid():
		_combo_tween.kill()
	
	# Create or reuse the center label
	if _combo_center_label == null or not is_instance_valid(_combo_center_label):
		_combo_center_label = Label.new()
		_combo_center_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_combo_center_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_combo_center_label.add_theme_font_size_override("font_size", 48)
		_combo_center_label.add_theme_color_override("font_color", Color(1, 0.85, 0.3, 1))
		_combo_center_label.add_theme_color_override("font_outline_color", Color(0.2, 0.1, 0.0, 1))
		_combo_center_label.add_theme_constant_override("outline_size", 4)
		_combo_center_label.z_index = 150
		_combo_center_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		floating_text_container.add_child(_combo_center_label)
	
	_combo_center_label.text = "🔥 %d连击" % combo_count
	_combo_center_label.modulate = Color(1, 1, 1, 1)
	_combo_center_label.visible = true
	
	# Position at screen center
	var viewport_size := get_viewport_rect().size
	await get_tree().process_frame
	if _combo_center_label == null or not is_instance_valid(_combo_center_label):
		return
	_combo_center_label.position = Vector2(
		(viewport_size.x - _combo_center_label.size.x) / 2.0,
		viewport_size.y * 0.35 - _combo_center_label.size.y / 2.0
	)
	
	# Scale pop-in animation
	_combo_center_label.scale = Vector2(1.5, 1.5)
	_combo_center_label.pivot_offset = _combo_center_label.size / 2.0
	_combo_tween = create_tween()
	_combo_tween.tween_property(_combo_center_label, "scale", Vector2(1.0, 1.0), 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	# Wait 3 seconds then fade out
	_combo_tween.tween_interval(3.0)
	_combo_tween.tween_property(_combo_center_label, "modulate:a", 0.0, 0.5)
	_combo_tween.tween_callback(func():
		if _combo_center_label != null and is_instance_valid(_combo_center_label):
			_combo_center_label.visible = false
	)

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
	# Karma system: gain karma on enemy kill based on enemy type
	if enemy.has_method("get") or "enemy_type" in enemy:
		var etype: String = enemy.get("enemy_type") if "enemy_type" in enemy else "normal"
		match etype:
			"boss":
				GameManager.modify_karma(5)
			"elite":
				GameManager.modify_karma(2)
			_:
				GameManager.modify_karma(1)
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
	# 重置战斗受伤标记
	GameManager.battle_took_damage = false
	
	# 渡劫战斗特殊处理
	if GameManager.current_battle_type == "tribulation":
		GameManager.current_karma = 0  # 劫数归零
		GameManager.tribulation_count += 1
		EventBus.karma_changed.emit(0, "清净")
	
	# Disable battle interaction
	end_turn_button.visible = false
	hand_area.visible = false
	
	await get_tree().create_timer(1.0).timeout
	
	# Overlay reward scene on top of battle scene with transparent mask
	var reward_scene := preload("res://scenes/reward/RewardScene.tscn").instantiate()
	reward_scene.z_index = 100
	add_child(reward_scene)
	
	# Fade-in animation for the reward overlay
	reward_scene.modulate = Color(1, 1, 1, 0)
	var tween := create_tween()
	tween.tween_property(reward_scene, "modulate:a", 1.0, 0.4)

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
	
	# Add combo status first (if active)
	if battle_manager.attack_cards_played_this_turn >= 2 and not battle_manager._combo_broken:
		var combo_label := Label.new()
		var combo_val: int = battle_manager.combo_display_count
		combo_label.text = "🔥%d" % combo_val
		combo_label.add_theme_color_override("font_color", Color(1, 0.85, 0.3, 1))
		combo_label.add_theme_font_size_override("font_size", 12)
		combo_label.mouse_filter = Control.MOUSE_FILTER_STOP
		combo_label.mouse_entered.connect(func(): _show_player_status_tooltip(combo_label, "combo", "连击", combo_val))
		combo_label.mouse_exited.connect(func(): _hide_player_status_tooltip())
		player_debuff_bar.add_child(combo_label)
	
	# 添加新的状态图标
	var effects: Array[Dictionary] = battle_manager.player_status.get_all_effects()
	for effect in effects:
		var label := Label.new()
		label.text = "%s%d" % [effect.name.left(1), effect.stacks]
		label.add_theme_color_override("font_color", effect.color)
		label.add_theme_font_size_override("font_size", 12)
		label.mouse_filter = Control.MOUSE_FILTER_STOP
		# Hover tooltip for status effect details
		var effect_type: String = effect.type
		var effect_name: String = effect.name
		var effect_stacks: int = effect.stacks
		label.mouse_entered.connect(func(): _show_player_status_tooltip(label, effect_type, effect_name, effect_stacks))
		label.mouse_exited.connect(func(): _hide_player_status_tooltip())
		player_debuff_bar.add_child(label)

## Show player status effect tooltip
func _show_player_status_tooltip(target: Label, effect_type: String, effect_name: String, stacks: int) -> void:
	_hide_player_status_tooltip()
	
	var desc: String = PLAYER_STATUS_DESCRIPTIONS.get(effect_type, "未知效果")
	var text := "%s (%d层)\n%s" % [effect_name, stacks, desc]
	
	_player_status_tooltip = PanelContainer.new()
	_player_status_tooltip.z_index = 200
	
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.15, 0.95)
	style.border_color = Color(0.5, 0.5, 0.5, 0.8)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(8)
	_player_status_tooltip.add_theme_stylebox_override("panel", style)
	
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 12)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.custom_minimum_size = Vector2(150, 0)
	_player_status_tooltip.add_child(label)
	
	# Add to scene root to avoid clipping
	var battle_scene := get_tree().current_scene
	if battle_scene:
		battle_scene.add_child(_player_status_tooltip)
	else:
		add_child(_player_status_tooltip)
	
	# Position after one frame
	await get_tree().process_frame
	if _player_status_tooltip == null or not is_instance_valid(_player_status_tooltip):
		return
	
	var tooltip_size := _player_status_tooltip.size
	var label_global_pos := target.global_position
	var pos_x := label_global_pos.x - tooltip_size.x / 2.0 + target.size.x / 2.0
	var pos_y := label_global_pos.y - tooltip_size.y - 6
	
	if pos_y < 0:
		pos_y = label_global_pos.y + target.size.y + 6
	
	var screen_size := get_viewport_rect().size
	if pos_x < 4: pos_x = 4
	if pos_x + tooltip_size.x > screen_size.x: pos_x = screen_size.x - tooltip_size.x - 4
	
	_player_status_tooltip.global_position = Vector2(pos_x, pos_y)

## Hide player status effect tooltip
func _hide_player_status_tooltip() -> void:
	if _player_status_tooltip != null and is_instance_valid(_player_status_tooltip):
		_player_status_tooltip.queue_free()
		_player_status_tooltip = null





## 生成敌人节点后设置hover事件（仅视觉高亮，不设置is_hovered meta）
func _setup_enemy_hover(enemy: Node) -> void:
	if enemy == null or not enemy.has_node("Sprite"):
		return
	var sprite_node: TextureRect = enemy.get_node("Sprite")
	sprite_node.mouse_filter = Control.MOUSE_FILTER_STOP
	sprite_node.mouse_entered.connect(func():
		# Only show visual highlight when no card is being dragged
		if not enemy.get_meta("is_hovered", false):
			sprite_node.modulate = Color(1.3, 1.1, 0.8)
	)
	sprite_node.mouse_exited.connect(func():
		# Only reset visual when not selected by card drag
		if not enemy.get_meta("is_hovered", false):
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
