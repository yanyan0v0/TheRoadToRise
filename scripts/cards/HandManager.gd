## 手牌管理器 - 管理底部手牌区域的排列和交互
extends Control

signal card_selected(card: Control)
signal card_play_requested(card: Control, target: Node)

const CARD_SCENE := preload("res://scenes/battle/Card.tscn")
const MAX_HAND_SIZE := 10
const CARD_SPACING := 0
const HAND_Y_OFFSET := 0  # 手牌区域Y偏移
const FAN_ANGLE := 5.0  # 扇形排列角度（度）
const FAN_ARC_HEIGHT := 40.0  # 扇形弧度高度（像素）

var hand_cards: Array[Control] = []
var _draw_pile_pos: Vector2 = Vector2.ZERO
var _discard_pile_pos: Vector2 = Vector2.ZERO
var _animating_cards: Array[Control] = []  # 正在播放抽牌动画的卡牌

func _ready() -> void:
	# 手牌区域本身不拦截鼠标事件，让卡牌子节点处理
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 等待布局完成后再初始化位置，确保size已正确计算
	await get_tree().process_frame
	await get_tree().process_frame
	_update_pile_positions()

func _update_pile_positions() -> void:
	# 抽牌堆位置：手牌区域下方居中
	var center_x := size.x / 2.0
	var bottom_y := size.y
	_draw_pile_pos = Vector2(center_x - 90, bottom_y)
	_discard_pile_pos = Vector2(center_x + 90, bottom_y)

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_update_pile_positions()

## 添加卡牌到手牌
func add_card(card_data: Dictionary, animate: bool = true) -> Control:
	var card := CARD_SCENE.instantiate()
	add_child(card)
	card.setup(card_data, card_data.get("star_level", 1))
	card.original_index = hand_cards.size()
	
	# 连接信号
	card.card_played.connect(_on_card_played)
	card.mouse_entered.connect(func(): _on_card_hover(card, true))
	card.mouse_exited.connect(func(): _on_card_hover(card, false))
	
	hand_cards.append(card)
	
	if animate:
		# 标记该卡牌正在播放抽牌动画，排列时跳过它
		_animating_cards.append(card)
	
	# 重新排列其他卡牌的位置
	_rearrange_cards()
	
	if animate:
		# 使用本地坐标进行抽牌动画，避免与_rearrange_cards的position tween冲突
		var target_pos := _calculate_card_position(hand_cards.size() - 1)
		var local_from := _draw_pile_pos
		card.position = local_from
		card.scale = Vector2(0.3, 0.3)
		card.modulate.a = 0.0
		
		var tween := card.create_tween()
		tween.tween_property(card, "position", target_pos, 0.3).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(card, "scale", Vector2.ONE, 0.3)
		tween.parallel().tween_property(card, "modulate:a", 1.0, 0.2)
		tween.finished.connect(func():
			_animating_cards.erase(card)
			# 动画完成后重新排列，确保所有卡牌位置正确
			if _animating_cards.is_empty():
				_rearrange_cards()
		)
	
	return card

## 移除手牌（打出）
func remove_card(card: Control, animate: bool = true) -> void:
	var idx := hand_cards.find(card)
	if idx < 0:
		return
	
	hand_cards.remove_at(idx)
	
	if animate:
		# 打出动画由BattleManager控制
		pass
	else:
		card.queue_free()
	
	_rearrange_cards()

## 弃掉所有手牌
func discard_all(animate: bool = true) -> void:
	for card in hand_cards.duplicate():
		if animate:
			# 将本地坐标转换为全局坐标
			card.animate_discard(global_position + _discard_pile_pos)
		else:
			card.queue_free()
	hand_cards.clear()

## 弃掉指定卡牌
func discard_card(card: Control, animate: bool = true) -> void:
	var idx := hand_cards.find(card)
	if idx < 0:
		return
	
	hand_cards.remove_at(idx)
	
	if animate:
		# 将本地坐标转换为全局坐标
		card.animate_discard(global_position + _discard_pile_pos)
	else:
		card.queue_free()
	
	_rearrange_cards()

## 更新所有卡牌的可打出状态
func update_playable_states(current_mana: int, current_stamina: int = 0) -> void:
	for card in hand_cards:
		var energy_cost: int = CardData.get_card_energy_cost(card.card_data)
		var stamina_cost: int = card.card_data.get("stamina_cost", 0)
		var playable := energy_cost <= current_mana
		if stamina_cost > 0:
			playable = playable and stamina_cost <= current_stamina
		card.set_playable(playable)

## 获取手牌数量
func get_hand_size() -> int:
	return hand_cards.size()

## 重新排列手牌（扇形排列）
func _rearrange_cards() -> void:
	var count := hand_cards.size()
	if count == 0:
		return
	
	for i in range(count):
		var card := hand_cards[i]
		var target_pos := _calculate_card_position(i)
		var target_rotation := _calculate_card_rotation(i, count)
		
		card.original_index = i
		card.z_index = i
		
		# 跳过正在播放抽牌动画的卡牌，避免tween冲突
		if card in _animating_cards:
			continue
		
		var tween := card.create_tween()
		tween.set_parallel(true)
		tween.tween_property(card, "position", target_pos, 0.2).set_ease(Tween.EASE_OUT)
		tween.tween_property(card, "rotation_degrees", target_rotation, 0.2)

## 计算卡牌位置
func _calculate_card_position(index: int) -> Vector2:
	var count := hand_cards.size()
	var card_width := 180
	var spacing := CARD_SPACING
	# 当卡牌过多时缩小间距
	var available_width := size.x - 200  # 留出两侧边距
	var total_step: float = card_width + spacing
	# Ensure spacing between cards is at most 0 (cards can overlap but not spread apart)
	if total_step > card_width:
		total_step = card_width
	var needed_width: float = (count - 1) * total_step
	if needed_width > available_width and count > 1:
		total_step = available_width / float(count - 1)
		if total_step < 30:
			total_step = 30
		needed_width = (count - 1) * total_step
	
	# total_width = 从第一张卡牌左边缘到最后一张卡牌右边缘
	var total_width: float = needed_width + card_width
	# 居中：start_x 是第一张卡牌的左边缘 x 坐标
	var start_x: float = (size.x - total_width) / 2.0
	
	var x := start_x + index * total_step
	var y: float = 20.0  # 手牌区域内的基础Y偏移，留出顶部空间
	
	# 扇形弧度偏移：中间最高，两端最低，形成弧形
	if count > 1:
		var normalized := float(index) / float(count - 1) - 0.5  # -0.5 到 0.5
		y += abs(normalized) * FAN_ARC_HEIGHT  # 两端略低，弧形效果
	
	return Vector2(x, y)

## 计算卡牌旋转角度
func _calculate_card_rotation(index: int, count: int) -> float:
	if count <= 1:
		return 0.0
	var normalized := float(index) / float(count - 1) - 0.5
	return normalized * FAN_ANGLE * 2.0

## 卡牌悬停处理
func _on_card_hover(card: Control, is_hovering: bool) -> void:
	if is_hovering:
		card_selected.emit(card)

## 卡牌打出请求
func _on_card_played(card: Control, target: Node) -> void:
	card_play_requested.emit(card, target)

## 设置牌堆位置（用于动画起点/终点）
func set_pile_positions(draw_pos: Vector2, discard_pos: Vector2) -> void:
	_draw_pile_pos = draw_pos
	_discard_pile_pos = discard_pos
