## 敌人控制器 - 管理敌人的行为、意图和状态
extends Control

signal enemy_died_signal(enemy: Control)
signal intent_changed(intent: Dictionary)

## 敌人数据
var enemy_data: Dictionary = {}
var enemy_id: String = ""
var enemy_name: String = ""
var enemy_type: String = "normal"  # normal/elite/boss
var max_hp: int = 30
var current_hp: int = 30
var current_armor: int = 0
var strength: int = 0

## 意图系统
var intent_pattern: Array = []
var current_intent_index: int = 0
var current_intent: Dictionary = {}

## 状态效果
var status_manager: StatusEffectManager = null

## BOSS阶段
var current_phase: int = 0
var phase_thresholds: Array = []  # HP百分比阈值
var phase_skills: Array = []  # 每阶段技能池

## 战斗管理器引用
var battle_manager: Node = null

## UI节点
@onready var sprite: TextureRect = $Sprite
@onready var name_label: Label = $NameLabel
@onready var hp_bar: ProgressBar = $HPRow/HPBar
@onready var hp_text: Label = $HPRow/HPBar/HPText
@onready var armor_label: Label = $HPRow/ArmorLabel
@onready var intent_icon: Label = $IntentIcon
@onready var intent_value_label: Label = $IntentValueLabel
@onready var status_bar: HBoxContainer = $StatusBar

## HP bar fill styles for armor color change
var _hp_fill_normal: StyleBoxFlat = null
var _hp_fill_armored: StyleBoxFlat = null

## 意图气泡框
var _intent_tooltip: PanelContainer = null

func _ready() -> void:
	status_manager = StatusEffectManager.new()
	add_child(status_manager)
	# 为意图图标设置hover事件
	_setup_intent_hover()
	# Initialize HP bar styles for armor color change
	await get_tree().process_frame
	if hp_bar:
		_hp_fill_normal = hp_bar.get_theme_stylebox("fill").duplicate()
		_hp_fill_armored = _hp_fill_normal.duplicate()
		_hp_fill_armored.bg_color = Color(0.3, 0.75, 0.85, 1)

## 初始化敌人
func setup(data: Dictionary, p_battle_manager: Node) -> void:
	enemy_data = data
	battle_manager = p_battle_manager
	
	enemy_id = data.get("enemy_id", "")
	enemy_name = data.get("enemy_name", "???")
	enemy_type = data.get("enemy_type", "normal")
	max_hp = data.get("max_hp", 30)
	current_hp = max_hp
	current_armor = 0
	strength = data.get("strength", 0)
	
	# 加载意图模式
	intent_pattern = data.get("intent_pattern", [])
	if intent_pattern.is_empty():
		intent_pattern = _generate_default_pattern()
	
	# BOSS阶段数据
	phase_thresholds = data.get("phase_thresholds", [])
	phase_skills = data.get("phase_skills", [])
	
	# Load wait frame animation
	_setup_enemy_animation()
	
	_update_ui()
	_decide_next_intent()

## Setup enemy sprite from static image
func _setup_enemy_animation() -> void:
	var image_path := "res://ui/images/battle/enemy/%s.png" % enemy_id
	var tex := load(image_path) as Texture2D
	if tex != null:
		sprite.texture = tex
		# Hide the sprite label since we now have a sprite image
		var sprite_label := sprite.get_node_or_null("SpriteLabel")
		if sprite_label:
			sprite_label.visible = false
		print("[Enemy] Loaded enemy image: %s" % image_path)
	else:
		# No image found, show fallback color background
		sprite.self_modulate = Color(0.839216, 0.192157, 0.192157, 1)
		print("[Enemy] Enemy image not found: %s" % image_path)

## 生成默认意图模式（普通敌人）
func _generate_default_pattern() -> Array:
	return [
		{"type": "attack", "value": 8},
		{"type": "attack", "value": 8},
		{"type": "defend", "value": 6},
	]

## 决定下一个意图
func _decide_next_intent() -> void:
	if enemy_type == "boss":
		current_intent = _decide_boss_intent()
	elif enemy_type == "elite":
		current_intent = _decide_elite_intent()
	else:
		current_intent = _decide_normal_intent()
	
	_update_intent_display()
	intent_changed.emit(current_intent)

## 普通敌人意图决策
func _decide_normal_intent() -> Dictionary:
	if intent_pattern.is_empty():
		return {"type": "attack", "value": 5}
	
	var intent: Dictionary = intent_pattern[current_intent_index % intent_pattern.size()]
	current_intent_index += 1
	return intent

## 精英敌人意图决策
func _decide_elite_intent() -> Dictionary:
	# 精英敌人有条件触发的特殊技能
	var hp_percent := float(current_hp) / float(max_hp)
	
	# 低血量时使用特殊技能
	if hp_percent < 0.3 and randf() < 0.5:
		return {"type": "special", "value": 0, "skill": "enrage", "description": "狂暴：力量+3"}
	
	# 正常循环
	if intent_pattern.is_empty():
		return {"type": "attack", "value": 12}
	
	var intent: Dictionary = intent_pattern[current_intent_index % intent_pattern.size()]
	current_intent_index += 1
	return intent

## BOSS意图决策
func _decide_boss_intent() -> Dictionary:
	# 检查阶段转换
	_check_phase_transition()
	
	# 获取当前阶段的技能池
	var skills: Array = []
	if current_phase < phase_skills.size():
		skills = phase_skills[current_phase]
	
	if skills.is_empty():
		# 使用默认意图模式
		if intent_pattern.is_empty():
			return {"type": "attack", "value": 15}
		var intent: Dictionary = intent_pattern[current_intent_index % intent_pattern.size()]
		current_intent_index += 1
		return intent
	
	# 从当前阶段技能池中选择
	var skill_index := current_intent_index % skills.size()
	current_intent_index += 1
	return skills[skill_index]

## 检查BOSS阶段转换
func _check_phase_transition() -> void:
	if phase_thresholds.is_empty():
		return
	
	var hp_percent := float(current_hp) / float(max_hp)
	
	for i in range(phase_thresholds.size()):
		var phase_data: Dictionary = phase_thresholds[i] if phase_thresholds[i] is Dictionary else {"threshold": phase_thresholds[i]}
		var threshold: float = phase_data.get("threshold", 0.0)
		if hp_percent <= threshold and current_phase <= i:
			current_phase = i + 1
			current_intent_index = 0
			_on_phase_change(current_phase)
			break

## 阶段转换处理
func _on_phase_change(new_phase: int) -> void:
	print("[Enemy] %s 进入阶段 %d" % [enemy_name, new_phase])
	
	# 播放阶段转换动画
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color.RED, 0.3)
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.3)
	
	# 清除负面状态
	status_manager.clear_debuffs()
	
	# 获得护甲
	current_armor += 10
	
	_update_ui()

## Apply defend intent armor immediately at turn start (called by BattleManager)
func apply_defend_at_turn_start() -> void:
	if current_intent.is_empty():
		return
	var intent_type: String = current_intent.get("type", "")
	if intent_type == "defend":
		var value: int = current_intent.get("value", 0)
		current_armor += value
		_update_ui()

## 执行当前意图
func execute_intent() -> void:
	if current_intent.is_empty():
		return
	
	var intent_type: String = current_intent.get("type", "attack")
	var value: int = current_intent.get("value", 0)
	
	# Seal check: each stack blocks 1 skill-type intent (buff/debuff/special) per turn
	var skill_intents := ["buff", "debuff", "special"]
	if intent_type in skill_intents and status_manager.has_effect("seal"):
		status_manager.remove_effect("seal", 1)
		# Skip this intent, wait and decide next
		await get_tree().create_timer(0.5).timeout
		_decide_next_intent()
		return
	
	match intent_type:
		"attack":
			_execute_attack(value)
		"heavy_attack":
			_execute_attack(value)
		"defend":
			pass  # Already applied at turn start
		"buff":
			_execute_buff(current_intent)
		"debuff":
			_execute_debuff(current_intent)
		"special":
			_execute_special(current_intent)
		"summon":
			_execute_summon(current_intent)
		"heal":
			_execute_heal(value)
	
	# 等待动画
	await get_tree().create_timer(0.5).timeout
	
	# Decide next intent
	_decide_next_intent()

## 执行攻击
func _execute_attack(base_damage: int) -> void:
	var total_damage := base_damage + strength
	
	# Weaken: reduce strength by stacks (each stack = -1 strength for damage calc)
	if status_manager.has_effect("weaken"):
		total_damage -= status_manager.get_stacks("weaken")
		total_damage = maxi(0, total_damage)
	
	if battle_manager and battle_manager.has_method("deal_damage_to_player"):
		battle_manager.deal_damage_to_player(total_damage, self)
	
	# 攻击动画
	_play_attack_animation()

## 执行防御
func _execute_defend(armor_value: int) -> void:
	current_armor += armor_value
	_update_ui()

## 执行增益
func _execute_buff(intent: Dictionary) -> void:
	var buff_type: String = intent.get("status_type", "")
	var stacks: int = intent.get("stacks", 1)
	
	match buff_type:
		"strength":
			strength += stacks
		_:
			status_manager.apply_effect(buff_type, stacks)

## 执行减益（对玩家）
func _execute_debuff(intent: Dictionary) -> void:
	var debuff_type: String = intent.get("status_type", "")
	var stacks: int = intent.get("stacks", 1)
	
	if battle_manager and battle_manager.player_status:
		battle_manager.player_status.apply_effect(debuff_type, stacks)
		EventBus.status_effect_applied.emit(null, debuff_type, stacks)

## 执行特殊技能
func _execute_special(intent: Dictionary) -> void:
	var skill: String = intent.get("skill", "")
	
	match skill:
		"enrage":
			strength += 3
			_play_buff_animation()
		"summon":
			_execute_summon(intent)
		"heal_all":
			current_hp = mini(current_hp + 15, max_hp)
			_update_ui()
		_:
			# 默认当作攻击处理
			var value: int = intent.get("value", 10)
			_execute_attack(value)

## 执行召唤
func _execute_summon(intent: Dictionary) -> void:
	# Get children array from enemy_data
	var children: Array = enemy_data.get("children", [])
	if children.is_empty():
		return
	
	# Randomly pick one child to summon
	var summon_data: Dictionary = children[randi() % children.size()]
	if summon_data.is_empty():
		return
	
	# Find the BattleScene and call spawn_summon_enemy
	var battle_scene := _find_battle_scene()
	if battle_scene and battle_scene.has_method("spawn_summon_enemy"):
		battle_scene.spawn_summon_enemy(summon_data)
	
	_play_buff_animation()

## Find the BattleScene node in the scene tree
func _find_battle_scene() -> Node:
	var node := get_tree().current_scene
	if node and node.has_method("spawn_summon_enemy"):
		return node
	return null

## 执行治疗
func _execute_heal(value: int) -> void:
	current_hp = mini(current_hp + value, max_hp)
	_update_ui()

## 受到伤害
func take_damage(damage: int, armor_absorbed: int = 0) -> void:
	# 先扣护甲
	if armor_absorbed > 0:
		current_armor = maxi(0, current_armor - armor_absorbed)
	
	# 扣血
	current_hp = maxi(0, current_hp - damage)
	
	_update_ui()
	_play_hit_animation()
	
	# 检查死亡
	if current_hp <= 0:
		_on_death()

## 设置护甲
func set_armor(value: int) -> void:
	current_armor = maxi(0, value)
	_update_ui()

## 施加状态效果
func apply_status(effect_type: String, stacks: int = 1) -> void:
	status_manager.apply_effect(effect_type, stacks)
	_update_status_display()
	
	# Bleed check: if bleed stacks >= current HP, enemy dies immediately
	if effect_type == "bleed":
		_check_bleed_death()

## Check if bleed stacks >= current HP, if so enemy dies immediately
func _check_bleed_death() -> void:
	if is_dead():
		return
	var bleed_stacks := status_manager.get_stacks("bleed")
	if bleed_stacks > 0 and bleed_stacks >= current_hp:
		print("[Enemy] %s bleed death! bleed=%d >= hp=%d" % [enemy_name, bleed_stacks, current_hp])
		current_hp = 0
		_update_ui()
		_on_death()

## 获取流血层数
func get_bleed_stacks() -> int:
	return status_manager.get_stacks("bleed")

## 是否有指定状态
func has_status(effect_type: String) -> bool:
	return status_manager.has_effect(effect_type)

## 是否死亡
func is_dead() -> bool:
	return current_hp <= 0

## 回合结束结算
## 护甲每回合重置
func on_turn_end() -> void:
	var results := status_manager.on_turn_end()
	
	# 灸烧伤害
	if results.damage > 0:
		current_hp = maxi(0, current_hp - results.damage)
	
	# 治愈回复
	if results.heal > 0:
		current_hp = mini(current_hp + results.heal, max_hp)
	
	# Armor resets every turn
	current_armor = 0
	
	_update_ui()
	_update_status_display()
	
	if current_hp <= 0:
		_on_death()
		return
	
	# Check bleed death after turn end status settlement
	_check_bleed_death()

## 死亡处理
func _on_death() -> void:
	print("[Enemy] %s 已被击败" % enemy_name)
	EventBus.enemy_died.emit(self)
	enemy_died_signal.emit(self)
	
	# 死亡动画
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	await tween.finished
	
	# Hide all child nodes but keep this node in the tree
	# so HBoxContainer layout is preserved (other enemies don't shift)
	for child in get_children():
		if child is CanvasItem:
			child.visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)

## 更新UI
func _update_ui() -> void:
	if name_label:
		name_label.text = enemy_name
	if hp_bar:
		hp_bar.max_value = max_hp
		hp_bar.value = current_hp
	if hp_text:
		hp_text.text = "%d/%d" % [current_hp, max_hp]
	# Armor display: show on left of HP bar, change HP bar color
	if armor_label:
		if current_armor > 0:
			armor_label.text = "🛡️%d" % current_armor
			if _hp_fill_armored and hp_bar:
				hp_bar.add_theme_stylebox_override("fill", _hp_fill_armored)
		else:
			armor_label.text = ""
			if _hp_fill_normal and hp_bar:
				hp_bar.add_theme_stylebox_override("fill", _hp_fill_normal)

## 更新意图显示
func _update_intent_display() -> void:
	if not intent_icon or not intent_value_label:
		return
	
	var intent_type: String = current_intent.get("type", "")
	var value: int = current_intent.get("value", 0)
	
	match intent_type:
		"attack":
			intent_icon.text = "⚔️"
			var atk_total := maxi(0, value + strength - status_manager.get_stacks("weaken"))
			intent_value_label.text = str(atk_total)
		"heavy_attack":
			intent_icon.text = "💀"
			var heavy_total := maxi(0, value + strength - status_manager.get_stacks("weaken"))
			intent_value_label.text = str(heavy_total)
		"defend":
			intent_icon.text = "🛡️"
			intent_value_label.text = str(value)
		"buff":
			intent_icon.text = "🔮"
			intent_value_label.text = ""
		"debuff":
			intent_icon.text = "🔮"
			intent_value_label.text = ""
		"special":
			intent_icon.text = "🔮"
			intent_value_label.text = ""
		"summon":
			intent_icon.text = "👻"
			intent_value_label.text = ""
		"heal":
			intent_icon.text = "💚"
			intent_value_label.text = str(value)
		_:
			intent_icon.text = "❓"
			intent_value_label.text = ""

func _setup_intent_hover() -> void:
	if intent_icon == null:
		return
	intent_icon.mouse_filter = Control.MOUSE_FILTER_STOP
	intent_icon.mouse_entered.connect(_on_intent_hover_enter)
	intent_icon.mouse_exited.connect(_on_intent_hover_exit)
	if intent_value_label:
		intent_value_label.mouse_filter = Control.MOUSE_FILTER_STOP
		intent_value_label.mouse_entered.connect(_on_intent_hover_enter)
		intent_value_label.mouse_exited.connect(_on_intent_hover_exit)

## 获取意图的详细描述文本
func _get_intent_description() -> String:
	var intent_type: String = current_intent.get("type", "")
	var value: int = current_intent.get("value", 0)
	var desc: String = current_intent.get("description", "")
	
	match intent_type:
		"attack":
			var total := maxi(0, value + strength - status_manager.get_stacks("weaken"))
			return "攻击\n造成 %d 点伤害" % total
		"heavy_attack":
			var total := maxi(0, value + strength - status_manager.get_stacks("weaken"))
			return "重击\n造成 %d 点伤害" % total
		"defend":
			return "防御\n获得 %d 点护甲" % value
		"buff":
			var buff_type: String = current_intent.get("status_type", "增益")
			var stacks: int = current_intent.get("stacks", 1)
			if desc != "":
				return "增益\n%s" % desc
			return "增益\n%s +%d" % [buff_type, stacks]
		"debuff":
			var debuff_type: String = current_intent.get("status_type", "减益")
			var stacks: int = current_intent.get("stacks", 1)
			if desc != "":
				return "减益\n%s" % desc
			return "减益\n对你施加 %s %d层" % [debuff_type, stacks]
		"special":
			if desc != "":
				return "特殊技能\n%s" % desc
			return "特殊技能\n未知效果"
		"summon":
			return "召唤\n召唤虫群助战"
		"heal":
			return "治疗\n恢复 %d 点生命" % value
		_:
			return "未知意图"

## 意图hover进入
func _on_intent_hover_enter() -> void:
	_show_intent_tooltip()

## 意图hover离开
func _on_intent_hover_exit() -> void:
	_hide_intent_tooltip()

## 显示意图气泡框
func _show_intent_tooltip() -> void:
	_hide_intent_tooltip()
	
	var text := _get_intent_description()
	
	_intent_tooltip = PanelContainer.new()
	_intent_tooltip.z_index = 200
	
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.15, 0.95)
	style.border_color = Color(0.5, 0.5, 0.5, 0.8)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(8)
	_intent_tooltip.add_theme_stylebox_override("panel", style)
	
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 12)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.custom_minimum_size = Vector2(150, 0)
	_intent_tooltip.add_child(label)
	
	# 添加到场景根节点以避免被裁剪
	var battle_scene := get_tree().current_scene
	if battle_scene:
		battle_scene.add_child(_intent_tooltip)
	else:
		add_child(_intent_tooltip)
	
	# 等一帧计算尺寸后定位
	await get_tree().process_frame
	if _intent_tooltip == null or not is_instance_valid(_intent_tooltip):
		return
	
	var tooltip_size := _intent_tooltip.size
	var icon_global_pos := intent_icon.global_position
	# 默认显示在意图图标上方
	var pos_x := icon_global_pos.x - tooltip_size.x / 2.0 + intent_icon.size.x / 2.0
	var pos_y := icon_global_pos.y - tooltip_size.y - 8
	
	# 上方超出屏幕则显示在下方
	if pos_y < 0:
		pos_y = icon_global_pos.y + intent_icon.size.y + 8
	
	# 左右边界检查
	var screen_size := get_viewport_rect().size
	if pos_x < 4:
		pos_x = 4
	if pos_x + tooltip_size.x > screen_size.x:
		pos_x = screen_size.x - tooltip_size.x - 4
	
	_intent_tooltip.global_position = Vector2(pos_x, pos_y)

## 隐藏意图气泡框
func _hide_intent_tooltip() -> void:
	if _intent_tooltip != null and is_instance_valid(_intent_tooltip):
		_intent_tooltip.queue_free()
		_intent_tooltip = null

## 更新状态效果显示
func _update_status_display() -> void:
	if not status_bar:
		return
	
	# 清除旧的状态图标
	for child in status_bar.get_children():
		child.queue_free()
	
	# 添加新的状态图标
	var effects := status_manager.get_all_effects()
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
		label.mouse_entered.connect(func(): _show_status_tooltip(label, effect_type, effect_name, effect_stacks))
		label.mouse_exited.connect(func(): _hide_status_tooltip())
		status_bar.add_child(label)

## Status effect tooltip
var _status_tooltip: PanelContainer = null

## Status effect descriptions
const STATUS_DESCRIPTIONS := {
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
	"counter": "受到伤害时，每层对1个敌人造成等量伤害",
	"weaken": "每层力量-1",
}

## Show status effect tooltip
func _show_status_tooltip(target: Label, effect_type: String, effect_name: String, stacks: int) -> void:
	_hide_status_tooltip()
	
	var desc: String = STATUS_DESCRIPTIONS.get(effect_type, "未知效果")
	var text := "%s (%d层)\n%s" % [effect_name, stacks, desc]
	
	_status_tooltip = PanelContainer.new()
	_status_tooltip.z_index = 200
	
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.15, 0.95)
	style.border_color = Color(0.5, 0.5, 0.5, 0.8)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(8)
	_status_tooltip.add_theme_stylebox_override("panel", style)
	
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 12)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.custom_minimum_size = Vector2(150, 0)
	_status_tooltip.add_child(label)
	
	# Add to scene root to avoid clipping
	var battle_scene := get_tree().current_scene
	if battle_scene:
		battle_scene.add_child(_status_tooltip)
	else:
		add_child(_status_tooltip)
	
	# Position after one frame
	await get_tree().process_frame
	if _status_tooltip == null or not is_instance_valid(_status_tooltip):
		return
	
	var tooltip_size := _status_tooltip.size
	var label_global_pos := target.global_position
	var pos_x := label_global_pos.x - tooltip_size.x / 2.0 + target.size.x / 2.0
	var pos_y := label_global_pos.y - tooltip_size.y - 6
	
	if pos_y < 0:
		pos_y = label_global_pos.y + target.size.y + 6
	
	var screen_size := get_viewport_rect().size
	if pos_x < 4: pos_x = 4
	if pos_x + tooltip_size.x > screen_size.x: pos_x = screen_size.x - tooltip_size.x - 4
	
	_status_tooltip.global_position = Vector2(pos_x, pos_y)

## Hide status effect tooltip
func _hide_status_tooltip() -> void:
	if _status_tooltip != null and is_instance_valid(_status_tooltip):
		_status_tooltip.queue_free()
		_status_tooltip = null

## 攻击动画
func _play_attack_animation() -> void:
	if not sprite:
		return
	var original_pos := sprite.position
	var tween := create_tween()
	tween.tween_property(sprite, "position:x", original_pos.x - 30, 0.15)
	tween.tween_property(sprite, "position:x", original_pos.x, 0.15)

## 受击动画
func _play_hit_animation() -> void:
	if not sprite:
		return
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color.RED, 0.1)
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.2)

## 增益动画
func _play_buff_animation() -> void:
	if not sprite:
		return
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color("FDCB6E"), 0.2)
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.3)
