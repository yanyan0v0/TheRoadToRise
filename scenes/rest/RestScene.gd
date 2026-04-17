## 節火休息场景脚本
extends Control

## Card scene for reuse
const CARD_SCENE := preload("res://scenes/battle/Card.tscn")
@onready var heal_button: Button = $CenterContainer/VBox/HealButton
@onready var enlighten_button: Button = $CenterContainer/VBox/EnlightenButton
@onready var fuse_button: Button = $CenterContainer/VBox/FuseButton
@onready var hp_label: Label = $CenterContainer/VBox/HPLabel
@onready var heal_amount_label: Label = $CenterContainer/VBox/HealAmountLabel

var heal_amount: int = 0
var _enlighten_popup: Control = null
var _fusion_popup: Control = null
## 本次竹火是否已融合过
var _has_fused: bool = false
## 是否已经选择了一项操作
var _action_chosen: bool = false
func _ready() -> void:
	GameManager.change_state(GameManager.GameState.REST)
	
	heal_amount = int(GameManager.max_hp * 0.3)
	hp_label.text = "当前生命: %d/%d" % [GameManager.current_hp, GameManager.max_hp]
	heal_amount_label.text = "恢复 %d 点生命值 (30%%)" % heal_amount
	
	heal_button.pressed.connect(_on_heal_pressed)
	enlighten_button.pressed.connect(_on_enlighten_pressed)
	fuse_button.pressed.connect(_on_fuse_pressed)
	
	# 检查是否可以悟道（劫数≥10）
	if GameManager.current_karma < 10:
		enlighten_button.disabled = true
		enlighten_button.tooltip_text = "劫数不足（需要≥10）"
	else:
		enlighten_button.tooltip_text = "消耗10点劫数，选择一张卡牌升1星"

## 恢复生命
func _on_heal_pressed() -> void:
	GameManager.modify_hp(heal_amount)
	hp_label.text = "当前生命: %d/%d" % [GameManager.current_hp, GameManager.max_hp]
	
	_disable_all_buttons()
	_action_chosen = true
	
	await get_tree().create_timer(1.0).timeout
	SceneTransition.change_scene("res://scenes/map/MapScene.tscn")

## 禁用所有按钮
func _disable_all_buttons() -> void:
	heal_button.disabled = true
	enlighten_button.disabled = true
	fuse_button.disabled = true

# ===== 悟道功能（选择卡牌升1星） =====

## 惟道按钮点击 - 显示选择弹窗
func _on_enlighten_pressed() -> void:
	if GameManager.current_karma < 10:
		return
	if _action_chosen:
		return
	_show_enlighten_popup()
## 显示悟道选择弹窗（卡牌列表）
func _show_enlighten_popup() -> void:
	if _enlighten_popup != null:
		return
	
	# 遮罩层
	_enlighten_popup = Control.new()
	_enlighten_popup.set_anchors_preset(Control.PRESET_FULL_RECT)
	_enlighten_popup.z_index = 50
	
	var overlay := ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0, 0.6)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_enlighten_popup.add_child(overlay)
	
	# 面板
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(850, 550)
	panel.position = Vector2(-425, -275)
	
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.14, 0.18, 0.95)
	style.border_color = Color(0.9, 0.7, 0.2, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(15)
	panel.add_theme_stylebox_override("panel", style)
	_enlighten_popup.add_child(panel)
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)
	
	# 标题栏
	var title_bar := HBoxContainer.new()
	var title := Label.new()
	title.text = "🧘 悟道 - 选择一张卡牌升1星（消耗10劫数）"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color("FDCB6E"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_bar.add_child(title)
	
	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.custom_minimum_size = Vector2(35, 35)
	close_btn.pressed.connect(_close_enlighten_popup)
	title_bar.add_child(close_btn)
	vbox.add_child(title_bar)
	
	# 滚动容器
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 420)
	vbox.add_child(scroll)
	
	# 网格布局
	var grid := GridContainer.new()
	grid.name = "EnlightenGrid"
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(grid)
	
	# 显示卡牌列表
	_populate_enlighten_cards(grid)
	
	add_child(_enlighten_popup)

## 填充悟道卡牌列表
func _populate_enlighten_cards(grid: GridContainer) -> void:
	for child in grid.get_children():
		child.queue_free()
	
	for i in range(GameManager.current_deck.size()):
		var entry: Dictionary = GameManager.current_deck[i] if GameManager.current_deck[i] is Dictionary else {"card_id": str(GameManager.current_deck[i]), "star_level": 1}
		var card_id: String = entry.get("card_id", "")
		var star_level: int = entry.get("star_level", 1)
		var card_data: Dictionary = DataManager.get_card(card_id)
		if card_data.is_empty():
			continue
		
		var is_max_star: bool = star_level >= 3
		var item := _create_enlighten_card_item(card_data, i, star_level, is_max_star)
		grid.add_child(item)


## 创建悟道卡牌条目
func _create_enlighten_card_item(card_data: Dictionary, deck_index: int, star_level: int, is_max_star: bool) -> Control:
	var container := Control.new()
	container.custom_minimum_size = Vector2(185, 130)
	
	var bg := ColorRect.new()
	bg.position = Vector2.ZERO
	bg.size = Vector2(185, 130)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	
	var rarity: String = card_data.get("rarity", "common")
	var base_color: Color
	match rarity:
		"common": base_color = Color(0.25, 0.25, 0.3)
		"uncommon": base_color = Color(0.0, 0.35, 0.28)
		"rare": base_color = Color(0.04, 0.25, 0.45)
		"legendary": base_color = Color(0.4, 0.32, 0.08)
		_: base_color = Color(0.25, 0.25, 0.3)
	
	if is_max_star:
		base_color = base_color.darkened(0.5)
	bg.color = base_color
	container.add_child(bg)
	
	# 卡牌名称 + 星级
	var star_text := _get_star_text(star_level)
	var name_label := Label.new()
	name_label.text = "%s %s" % [card_data.get("card_name", "???"), star_text]
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 13)
	name_label.position = Vector2(5, 8)
	name_label.size = Vector2(175, 20)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	match star_level:
		3: name_label.add_theme_color_override("font_color", Color("FF6B6B"))
		2: name_label.add_theme_color_override("font_color", Color("74B9FF"))
		_: name_label.add_theme_color_override("font_color", Color("FDCB6E"))
	bg.add_child(name_label)
	
	# 描述
	var desc_label := Label.new()
	desc_label.text = card_data.get("description", "")
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc_label.add_theme_font_size_override("font_size", 10)
	desc_label.position = Vector2(5, 32)
	desc_label.size = Vector2(175, 55)
	desc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.add_child(desc_label)
	
	# 状态标签
	if is_max_star:
		var status_label := Label.new()
		status_label.text = "已满星"
		status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		status_label.add_theme_font_size_override("font_size", 12)
		status_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		status_label.position = Vector2(5, 100)
		status_label.size = Vector2(175, 20)
		status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bg.add_child(status_label)
	else:
		# 升星预览
		var preview_label := Label.new()
		preview_label.text = "→ %s" % _get_star_text(star_level + 1)
		preview_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		preview_label.add_theme_font_size_override("font_size", 12)
		preview_label.add_theme_color_override("font_color", Color("A29BFE"))
		preview_label.position = Vector2(5, 100)
		preview_label.size = Vector2(175, 20)
		preview_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bg.add_child(preview_label)
		
		# hover效果
		bg.mouse_entered.connect(func():
			container.modulate = Color(1.2, 1.2, 1.2)
			bg.color = base_color.lightened(0.2)
		)
		bg.mouse_exited.connect(func():
			container.modulate = Color.WHITE
			bg.color = base_color
		)
		
		# 点击升星
		bg.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				_enlighten_card(deck_index)
		)
	
	return container



## 执行悟道升星卡牌
func _enlighten_card(deck_index: int) -> void:
	if deck_index < 0 or deck_index >= GameManager.current_deck.size():
		return
	
	var entry: Dictionary = GameManager.current_deck[deck_index] if GameManager.current_deck[deck_index] is Dictionary else {"card_id": str(GameManager.current_deck[deck_index]), "star_level": 1}
	var star: int = entry.get("star_level", 1)
	if star >= 3:
		return
	
	# 消耗10点劫数
	GameManager.modify_karma(-10)
	
	entry["star_level"] = star + 1
	GameManager.current_deck[deck_index] = entry
	
	var card_data := DataManager.get_card(entry.get("card_id", ""))
	var card_name: String = card_data.get("card_name", "???")
	
	_close_enlighten_popup()
	_disable_all_buttons()
	_action_chosen = true
	
	hp_label.text = "惟道成功！%s 升至 %s" % [card_name, _get_star_text(star + 1)]	
	await get_tree().create_timer(1.5).timeout
	SceneTransition.change_scene("res://scenes/map/MapScene.tscn")



## 关闭悟道弹窗
func _close_enlighten_popup() -> void:
	if _enlighten_popup != null:
		_enlighten_popup.queue_free()
		_enlighten_popup = null

# ===== 融合功能（选择两个相同的卡牌/法宝进行融合） =====

## 融合选中状态
var _fusion_first_selection: Dictionary = {}  # {"type": "card"/"relic", "index": int, "id": String, "star": int}
var _fusion_confirm_popup: Control = null

## 融合按钮点击
func _on_fuse_pressed() -> void:
	if _action_chosen:
		return
	_show_fusion_popup()

## 显示融合界面弹窗
func _show_fusion_popup() -> void:
	if _fusion_popup != null:
		return
	
	_fusion_first_selection = {}
	
	# 遮罩层
	_fusion_popup = Control.new()
	_fusion_popup.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fusion_popup.z_index = 50
	
	var overlay := ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0, 0.6)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_fusion_popup.add_child(overlay)
	
	# 面板
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(900, 580)
	panel.position = Vector2(-450, -290)
	
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.14, 0.18, 0.95)
	style.border_color = Color(0.6, 0.3, 0.8, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(15)
	panel.add_theme_stylebox_override("panel", style)
	_fusion_popup.add_child(panel)
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)
	
	# 标题栏
	var title_bar := HBoxContainer.new()
	var title := Label.new()
	title.text = "🔮 融合 - 选择两张相同的卡牌进行融合"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color("A29BFE"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_bar.add_child(title)
	
	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.custom_minimum_size = Vector2(35, 35)
	close_btn.pressed.connect(_close_fusion_popup)
	title_bar.add_child(close_btn)
	vbox.add_child(title_bar)
	
	# 提示
	var hint := Label.new()
	hint.name = "FusionHint"
	hint.text = "点击选择第一张卡牌（相同名称+相同星级才能融合，最高3星）"
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	vbox.add_child(hint)
	
	# 滚动容器（直接显示卡牌，不需要标签页）
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 430)
	vbox.add_child(scroll)
	
	var grid := GridContainer.new()
	grid.name = "FusionGrid"
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(grid)
	
	# 直接显示卡牌列表
	_populate_fusion_cards(grid)
	
	add_child(_fusion_popup)

## 填充融合卡牌列表
func _populate_fusion_cards(grid: GridContainer) -> void:
	for child in grid.get_children():
		child.queue_free()
	
	for i in range(GameManager.current_deck.size()):
		var entry: Dictionary = GameManager.current_deck[i] if GameManager.current_deck[i] is Dictionary else {"card_id": str(GameManager.current_deck[i]), "star_level": 1}
		var card_id: String = entry.get("card_id", "")
		var star_level: int = entry.get("star_level", 1)
		var card_data: Dictionary = DataManager.get_card(card_id)
		if card_data.is_empty():
			continue
		
		var is_max_star: bool = star_level >= 3
		# 检查是否被选中为第一张
		var is_first_selected: bool = (not _fusion_first_selection.is_empty() and _fusion_first_selection.get("type", "") == "card" and _fusion_first_selection.get("index", -1) == i)
		# 检查是否可作为第二张（与第一张相同id+相同星级）
		var can_be_second: bool = false
		if not _fusion_first_selection.is_empty() and _fusion_first_selection.get("type", "") == "card":
			can_be_second = (_fusion_first_selection.get("id", "") == card_id and _fusion_first_selection.get("star", 0) == star_level and _fusion_first_selection.get("index", -1) != i)
		
		var item := _create_fusion_card_item(card_data, i, star_level, is_max_star, is_first_selected, can_be_second)
		grid.add_child(item)

## 创建融合卡牌条目（使用战斗卡牌UI）
func _create_fusion_card_item(card_data: Dictionary, deck_index: int, star_level: int, is_max_star: bool, is_first_selected: bool, can_be_second: bool) -> Control:
	var container := VBoxContainer.new()
	container.custom_minimum_size = Vector2(195, 300)
	container.add_theme_constant_override("separation", 4)
	
	var card_id: String = card_data.get("card_id", "")
	
	# Use battle Card scene
	var card_node: Control = CARD_SCENE.instantiate()
	card_node.custom_minimum_size = Vector2(180, 270)
	container.add_child(card_node)
	card_node.setup(card_data, star_level)
	card_node.is_playable = false
	card_node.modulate = Color.WHITE
	card_node.set_process_input(false)
	# Hide background for non-battle card UI
	if card_node.has_node("Background"):
		card_node.get_node("Background").visible = false
	
	# 已满星或不可选时暗化
	var is_dimmed: bool = is_max_star
	if not _fusion_first_selection.is_empty() and not is_first_selected and not can_be_second:
		is_dimmed = true
	
	if is_first_selected:
		card_node.modulate = Color(0.8, 1.2, 0.8, 1.0)  # Green tint for selected
	elif is_dimmed:
		card_node.modulate = Color(0.4, 0.4, 0.4, 1.0)
	
	# Status label below card
	if is_first_selected:
		var sel_label := Label.new()
		sel_label.text = "✓ 已选中"
		sel_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sel_label.add_theme_font_size_override("font_size", 12)
		sel_label.add_theme_color_override("font_color", Color("00B894"))
		container.add_child(sel_label)
	elif is_max_star:
		var max_label := Label.new()
		max_label.text = "已满星"
		max_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		max_label.add_theme_font_size_override("font_size", 12)
		max_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		container.add_child(max_label)
	
	# Add click overlay
	var click_overlay := ColorRect.new()
	click_overlay.color = Color(0, 0, 0, 0)
	click_overlay.position = Vector2.ZERO
	click_overlay.size = Vector2(180, 270)
	click_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	card_node.add_child(click_overlay)
	
	# Click and hover logic
	if not is_max_star and not (is_dimmed and not is_first_selected):
		if not is_dimmed:
			click_overlay.mouse_entered.connect(func():
				card_node.modulate = Color(1.2, 1.2, 1.2)
				card_node.scale = Vector2(1.05, 1.05)
			)
			click_overlay.mouse_exited.connect(func():
				if is_first_selected:
					card_node.modulate = Color(0.8, 1.2, 0.8, 1.0)
				else:
					card_node.modulate = Color.WHITE
				card_node.scale = Vector2.ONE
			)
		
		click_overlay.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				_on_fusion_card_clicked(deck_index, card_id, star_level)
		)
	
	return container

## 融合卡牌点击处理
func _on_fusion_card_clicked(deck_index: int, card_id: String, star_level: int) -> void:
	if _fusion_first_selection.is_empty():
		# 选择第一张
		_fusion_first_selection = {"type": "card", "index": deck_index, "id": card_id, "star": star_level}
		_update_fusion_hint()
		_refresh_fusion_grid()
	elif _fusion_first_selection.get("type", "") == "card" and _fusion_first_selection.get("index", -1) == deck_index:
		# 取消选择
		_fusion_first_selection = {}
		_update_fusion_hint()
		_refresh_fusion_grid()
	elif _fusion_first_selection.get("type", "") == "card" and _fusion_first_selection.get("id", "") == card_id and _fusion_first_selection.get("star", 0) == star_level:
		# 选择第二张 -> 弹窗确认
		_show_fusion_confirm("card", _fusion_first_selection.get("index", -1), deck_index, card_id, star_level)
	else:
		# 重新选择第一张
		_fusion_first_selection = {"type": "card", "index": deck_index, "id": card_id, "star": star_level}
		_update_fusion_hint()
		_refresh_fusion_grid()

## 更新融合提示文字
func _update_fusion_hint() -> void:
	if _fusion_popup == null:
		return
	var hint_node := _fusion_popup.find_child("FusionHint", true, false)
	if hint_node == null:
		return
	if _fusion_first_selection.is_empty():
		hint_node.text = "点击选择第一张卡牌（相同名称+相同星级才能融合，最高3星）"
	else:
		var item_name: String = ""
		var card_data := DataManager.get_card(_fusion_first_selection.get("id", ""))
		item_name = card_data.get("card_name", "???")
		hint_node.text = "已选择: %s %s  →  请选择第二张相同的进行融合" % [item_name, _get_star_text(_fusion_first_selection.get("star", 1))]
		hint_node.add_theme_color_override("font_color", Color("00B894"))

## 刷新融合网格
func _refresh_fusion_grid() -> void:
	if _fusion_popup == null:
		return
	var grid := _fusion_popup.find_child("FusionGrid", true, false)
	if grid == null:
		return
	# 篱火只融合卡牌
	_populate_fusion_cards(grid)

## 显示融合确认弹窗
func _show_fusion_confirm(item_type: String, index_a: int, index_b: int, item_id: String, star_level: int) -> void:
	if _fusion_confirm_popup != null:
		_fusion_confirm_popup.queue_free()
	
	_fusion_confirm_popup = Control.new()
	_fusion_confirm_popup.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fusion_confirm_popup.z_index = 100
	
	var overlay := ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0, 0.4)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_fusion_confirm_popup.add_child(overlay)
	
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(400, 220)
	panel.position = Vector2(-200, -110)
	
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.14, 0.18, 0.98)
	style.border_color = Color("A29BFE")
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(20)
	panel.add_theme_stylebox_override("panel", style)
	_fusion_confirm_popup.add_child(panel)
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)
	
	var confirm_title := Label.new()
	confirm_title.text = "🔮 确认融合"
	confirm_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	confirm_title.add_theme_font_size_override("font_size", 22)
	confirm_title.add_theme_color_override("font_color", Color("A29BFE"))
	vbox.add_child(confirm_title)
	
	var item_name: String = ""
	var card_data := DataManager.get_card(item_id)
	item_name = card_data.get("card_name", "???")
	
	var new_star := star_level + 1
	var desc := Label.new()
	desc.text = "将2张 [%s %s] 融合为\n1张 [%s %s]" % [item_name, _get_star_text(star_level), item_name, _get_star_text(new_star)]
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.add_theme_font_size_override("font_size", 16)
	vbox.add_child(desc)
	
	var warn := Label.new()
	warn.text = "⚠️ 融合后本次篝火不能再次融合"
	warn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	warn.add_theme_font_size_override("font_size", 13)
	warn.add_theme_color_override("font_color", Color("FDCB6E"))
	vbox.add_child(warn)
	
	var btn_hbox := HBoxContainer.new()
	btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_hbox.add_theme_constant_override("separation", 20)
	vbox.add_child(btn_hbox)
	
	var confirm_btn := Button.new()
	confirm_btn.text = "确认融合"
	confirm_btn.custom_minimum_size = Vector2(140, 40)
	confirm_btn.pressed.connect(func():
		_execute_fusion(item_type, index_a, index_b)
	)
	btn_hbox.add_child(confirm_btn)
	
	var cancel_btn := Button.new()
	cancel_btn.text = "取消"
	cancel_btn.custom_minimum_size = Vector2(140, 40)
	cancel_btn.pressed.connect(func():
		_fusion_confirm_popup.queue_free()
		_fusion_confirm_popup = null
	)
	btn_hbox.add_child(cancel_btn)
	
	add_child(_fusion_confirm_popup)

## 执行融合（仅支持卡牌融合，法宝不再支持融合）
func _execute_fusion(item_type: String, index_a: int, index_b: int) -> void:
	if _fusion_confirm_popup != null:
		_fusion_confirm_popup.queue_free()
		_fusion_confirm_popup = null
	
	var result: Dictionary = {}
	if item_type == "card":
		result = CardFusionManager.fuse_cards(index_a, index_b)
	
	if result.is_empty():
		return
	
	_has_fused = true
	_action_chosen = true
	
	_close_fusion_popup()
	_disable_all_buttons()
	
	# 显示融合结果
	var item_name: String = ""
	var new_star: int = result.get("star_level", 2)
	var card_data := DataManager.get_card(result.get("card_id", ""))
	item_name = card_data.get("card_name", "???")
	
	hp_label.text = "融合成功！%s 升至 %s" % [item_name, _get_star_text(new_star)]
	
	await get_tree().create_timer(1.5).timeout
	SceneTransition.change_scene("res://scenes/map/MapScene.tscn")

## 关闭融合弹窗
func _close_fusion_popup() -> void:
	if _fusion_popup != null:
		_fusion_popup.queue_free()
		_fusion_popup = null
	_fusion_first_selection = {}

# ===== 工具方法 =====

## 获取星级文本
func _get_star_text(star: int) -> String:
	match star:
		1: return "★☆☆"
		2: return "★★☆"
		3: return "★★★"
	return "★☆☆"
