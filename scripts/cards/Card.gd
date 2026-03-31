## 卡牌UI节点脚本 - 管理单张卡牌的显示和交互
extends Control

signal card_clicked(card: Control)
signal card_drag_started(card: Control)
signal card_drag_ended(card: Control)
signal card_played(card: Control, target: Node)

## 卡牌数据
var card_data: Dictionary = {}
var card_id: String = ""
var star_level: int = 1
var is_playable: bool = true
var is_dragging: bool = false
var is_hovering: bool = false
var original_position: Vector2 = Vector2.ZERO
var original_index: int = 0
var _saved_border_color: Color = Color.WHITE  # 保存原始边框颜色

## 内部节点引用
@onready var background: ColorRect = $Background
@onready var border: ColorRect = $Border
@onready var cost_circle: ColorRect = $CostCircle
@onready var cost_label: Label = $CostCircle/CostLabel
@onready var rarity_indicator: ColorRect = $RarityIndicator
@onready var title_area: ColorRect = $TitleArea
@onready var title_label: Label = $TitleArea/TitleLabel
@onready var artwork_area: ColorRect = $ArtworkArea
@onready var artwork_label: Label = $ArtworkArea/ArtworkLabel
@onready var type_label: Label = $TypeLabel
@onready var description_area: ColorRect = $DescriptionArea
@onready var description_label: RichTextLabel = $DescriptionArea/DescriptionLabel

const CARD_WIDTH := 180
const CARD_HEIGHT := 270
const HOVER_SCALE := 1.3
const HOVER_OFFSET_Y := -60.0
const DRAG_THRESHOLD_Y := -100.0
const ENEMY_SELECT_SCALE := Vector2(1.15, 1.15)  # 拖拽到敌人上时的放大比例

## 拖拽时的敌人选中状态
var _drag_hovered_enemy: Node = null

## 稀有度颜色映射
const RARITY_COLORS := {
	"common": Color.WHITE,
	"uncommon": Color("00B894"),
	"rare": Color("0984E3"),
	"legendary": Color("FDCB6E"),
}

## 类型颜色映射
const TYPE_COLORS := {
	"attack": Color("D63031"),
	"skill": Color("0984E3"),
	"ultimate": Color("6C5CE7"),
}

func _ready() -> void:
	custom_minimum_size = Vector2(CARD_WIDTH, CARD_HEIGHT)
	size = Vector2(CARD_WIDTH, CARD_HEIGHT)
	pivot_offset = size / 2.0
	mouse_filter = Control.MOUSE_FILTER_STOP
	# 保存初始边框颜色
	if border:
		_saved_border_color = border.color

## 用数据初始化卡牌显示
func setup(data: Dictionary, p_star_level: int = 1) -> void:
	card_data = data
	card_id = data.get("card_id", "")
	star_level = p_star_level
	_update_display()

## 更新卡牌显示
func _update_display() -> void:
	if card_data.is_empty():
		return
	
	var rarity: String = card_data.get("rarity", "common")
	var card_type: String = card_data.get("card_type", "attack")
	var is_upgraded: bool = card_data.get("is_upgraded", false)
	var card_name: String = card_data.get("card_name", "???")
	if is_upgraded:
		card_name += "·极"
	
	# 费用
	var energy_cost: int = card_data.get("energy_cost", 1)
	cost_label.text = str(energy_cost)
	
	# 体力费用（天蓬元帅）
	var stamina_cost: int = card_data.get("stamina_cost", 0)
	if stamina_cost > 0:
		cost_label.text = "%d/%d" % [energy_cost, stamina_cost]
	
	# 稀有度边框颜色
	var rarity_color: Color = RARITY_COLORS.get(rarity, Color.WHITE)
	border.color = rarity_color
	_saved_border_color = rarity_color
	rarity_indicator.color = rarity_color
	
	# 标题（含星级标识）
	var star_display := _get_star_display()
	title_label.text = card_name
	
	# 星级颜色
	if star_level >= 3:
		title_label.add_theme_color_override("font_color", Color("FDCB6E"))  # 金色
	elif star_level >= 2:
		title_label.add_theme_color_override("font_color", Color("00B894"))  # 翠绿
	
	# 类型
	var type_name := ""
	match card_type:
		"attack": type_name = "攻击"
		"skill": type_name = "技能"
		"ultimate": type_name = "终结技"
	type_label.text = "[%s]" % type_name
	type_label.add_theme_color_override("font_color", TYPE_COLORS.get(card_type, Color.WHITE))
	
	# 插画区域颜色
	artwork_area.color = TYPE_COLORS.get(card_type, Color.GRAY).darkened(0.6)
	artwork_label.text = card_name
	
	# 描述（根据星级显示对应效果描述）
	var desc_text: String = card_data.get("description", "")
	if star_level >= 2:
		var star_desc: String = card_data.get("star_%d_description" % star_level, "")
		if star_desc != "":
			desc_text = star_desc
	description_label.text = star_display + "\n" + desc_text

## 设置是否可打出
func set_playable(playable: bool) -> void:
	is_playable = playable
	if not playable:
		modulate = Color(0.5, 0.5, 0.5, 1.0)
	else:
		modulate = Color.WHITE

## 鼠标输入处理
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if is_playable:
					is_dragging = true
					original_position = global_position
					card_drag_started.emit(self)
					z_index = 100
			else:
				# 松开左键
				if is_dragging:
					is_dragging = false
					z_index = original_index
					card_drag_ended.emit(self)
					# 清除敌人选中状态
					_clear_drag_enemy_hover()
					# 检查是否拖到了目标区域（向上拖拽超过阈值）
					if global_position.y - original_position.y < DRAG_THRESHOLD_Y:
						card_played.emit(self, null)
					else:
						# 回到原位
						_animate_return()
	
	elif event is InputEventMouseMotion:
		if is_dragging:
			global_position += event.relative
			_update_drag_enemy_hover()

## 鼠标进入
func _on_mouse_entered() -> void:
	if is_dragging:
		return
	is_hovering = true
	_animate_hover(true)

## 鼠标离开
func _on_mouse_exited() -> void:
	if is_dragging:
		return
	is_hovering = false
	_animate_hover(false)

## 悬停动画
func _animate_hover(hover: bool) -> void:
	var tween := create_tween()
	if hover:
		tween.set_parallel(true)
		tween.tween_property(self, "scale", Vector2(HOVER_SCALE, HOVER_SCALE), 0.15)
		tween.tween_property(self, "position:y", position.y + HOVER_OFFSET_Y, 0.15)
		z_index = 50
		# 选中高亮效果：边框变亮 + 发光
		if border:
			border.color = Color(1.0, 0.85, 0.3, 1.0)  # 金色高亮
		modulate = Color(1.15, 1.15, 1.15, 1.0)  # 整体提亮
	else:
		tween.set_parallel(true)
		tween.tween_property(self, "scale", Vector2.ONE, 0.15)
		tween.tween_property(self, "position:y", position.y - HOVER_OFFSET_Y, 0.15)
		z_index = original_index
		# 恢复原始效果
		if border:
			border.color = _saved_border_color
		if is_playable:
			modulate = Color.WHITE
		else:
			modulate = Color(0.5, 0.5, 0.5, 1.0)

## 回到原位动画
func _animate_return() -> void:
	var tween := create_tween()
	tween.tween_property(self, "global_position", original_position, 0.2).set_ease(Tween.EASE_OUT)

## 打出卡牌动画（飞向目标）
func animate_play(target_pos: Vector2) -> void:
	var tween := create_tween()
	tween.tween_property(self, "global_position", target_pos, 0.3).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(self, "scale", Vector2(0.5, 0.5), 0.3)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 0.3)
	await tween.finished
	queue_free()

## 抽牌入场动画
func animate_draw(from_pos: Vector2, to_pos: Vector2) -> void:
	global_position = from_pos
	scale = Vector2(0.3, 0.3)
	modulate.a = 0.0
	
	var tween := create_tween()
	tween.tween_property(self, "global_position", to_pos, 0.3).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(self, "scale", Vector2.ONE, 0.3)
	tween.parallel().tween_property(self, "modulate:a", 1.0, 0.2)

## 弹牌动画
func animate_discard(discard_pos: Vector2) -> void:
	var tween := create_tween()
	tween.tween_property(self, "global_position", discard_pos, 0.2).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(self, "scale", Vector2(0.3, 0.3), 0.2)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 0.2)
	await tween.finished
	queue_free()

## 拖拽时检测敌人悬停状态
func _update_drag_enemy_hover() -> void:
	var battle_scene := _get_battle_scene()
	if battle_scene == null:
		return
	
	var battle_mgr = battle_scene.battle_manager
	if battle_mgr == null:
		return
	
	var mouse_pos := get_global_mouse_position()
	var new_hovered: Node = null
	
	for enemy in battle_mgr.enemies:
		if enemy == null or (enemy.has_method("is_dead") and enemy.is_dead()):
			continue
		if enemy is Control:
			var enemy_rect := Rect2(enemy.global_position, enemy.size)
			if enemy_rect.has_point(mouse_pos):
				new_hovered = enemy
				break
	
	if new_hovered != _drag_hovered_enemy:
		# 取消旧的选中状态
		if _drag_hovered_enemy != null and is_instance_valid(_drag_hovered_enemy):
			var tween := _drag_hovered_enemy.create_tween()
			tween.tween_property(_drag_hovered_enemy, "scale", Vector2.ONE, 0.1)
			_drag_hovered_enemy.set_meta("is_hovered", false)
		# 设置新的选中状态
		if new_hovered != null:
			var tween := new_hovered.create_tween()
			tween.tween_property(new_hovered, "scale", ENEMY_SELECT_SCALE, 0.1)
			new_hovered.set_meta("is_hovered", true)
		_drag_hovered_enemy = new_hovered

## 清除拖拽时的敌人选中状态
func _clear_drag_enemy_hover() -> void:
	if _drag_hovered_enemy != null and is_instance_valid(_drag_hovered_enemy):
		var tween := _drag_hovered_enemy.create_tween()
		tween.tween_property(_drag_hovered_enemy, "scale", Vector2.ONE, 0.1)
		_drag_hovered_enemy.set_meta("is_hovered", false)
	_drag_hovered_enemy = null

## 获取星级显示文本
func _get_star_display() -> String:
	match star_level:
		1: return "★☆☆"
		2: return "★★☆"
		3: return "★★★"
	return "★☆☆"

## 获取战斗场景引用
func _get_battle_scene() -> Node:
	# Card -> HandArea(HandManager) -> BattleScene
	var hand_area := get_parent()
	if hand_area != null:
		var scene := hand_area.get_parent()
		if scene != null and scene.get("battle_manager") != null:
			return scene
	return null
