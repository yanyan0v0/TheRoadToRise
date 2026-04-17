## Alchemy scene script - Spend gold to craft pills
extends Control

## Alchemy tier config: {cost, quality probabilities}
const ALCHEMY_TIERS := {
	"low": {"cost": 40, "name": "初级炼丹", "success_rate": 0.85, "probs": {"low": 0.65, "mid": 0.25, "high": 0.08, "extreme": 0.02}},
	"mid": {"cost": 70, "name": "中级炼丹", "success_rate": 0.70, "probs": {"low": 0.25, "mid": 0.45, "high": 0.22, "extreme": 0.08}},
	"high": {"cost": 100, "name": "高级炼丹", "success_rate": 0.55, "probs": {"low": 0.10, "mid": 0.25, "high": 0.40, "extreme": 0.25}},
}

## Tier panel style colors
const TIER_COLORS := {
	"low": Color(0.529, 0.808, 0.922),   # Blue
	"mid": Color(0.753, 0.753, 0.753),    # Silver
	"high": Color(0.992, 0.796, 0.431),   # Gold
}

## Cached node references
@onready var _gold_label: Label = %GoldLabel
@onready var _pill_label: Label = %PillLabel
@onready var _leave_button: Button = %LeaveButton

@onready var _low_tier: PanelContainer = %LowTier
@onready var _mid_tier: PanelContainer = %MidTier
@onready var _high_tier: PanelContainer = %HighTier

@onready var _low_btn: Button = %LowAlchemyBtn
@onready var _mid_btn: Button = %MidAlchemyBtn
@onready var _high_btn: Button = %HighAlchemyBtn

@onready var _result_popup: Control = %ResultPopup
@onready var _result_vbox: VBoxContainer = %VBox
@onready var _result_overlay: ColorRect = $ResultPopup/Overlay
@onready var _result_panel: PanelContainer = $ResultPopup/Center/Panel

func _ready() -> void:
	GameManager.change_state(GameManager.GameState.REST)
	_setup_panel_styles()
	_connect_signals()
	_refresh_ui()

## Apply custom StyleBox to panels (easier in code than tscn)
func _setup_panel_styles() -> void:
	# Tier panel styles
	var tier_nodes := {"low": _low_tier, "mid": _mid_tier, "high": _high_tier}
	for tier_key in tier_nodes:
		var panel: PanelContainer = tier_nodes[tier_key]
		var color: Color = TIER_COLORS[tier_key]
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.08, 0.07, 0.12, 0.85)
		style.border_color = color
		style.set_border_width_all(2)
		style.set_corner_radius_all(10)
		style.set_content_margin_all(15)
		panel.add_theme_stylebox_override("panel", style)

	# Result popup panel style (default, will be updated per result)
	var result_style := StyleBoxFlat.new()
	result_style.bg_color = Color(0.10, 0.09, 0.15, 0.95)
	result_style.set_corner_radius_all(12)
	result_style.set_content_margin_all(25)
	result_style.border_color = Color.WHITE
	result_style.set_border_width_all(2)
	_result_panel.add_theme_stylebox_override("panel", result_style)

## Connect all button signals
func _connect_signals() -> void:
	_leave_button.pressed.connect(_on_leave_pressed)
	_low_btn.pressed.connect(func(): _on_alchemy_pressed("low"))
	_mid_btn.pressed.connect(func(): _on_alchemy_pressed("mid"))
	_high_btn.pressed.connect(func(): _on_alchemy_pressed("high"))
	_result_overlay.gui_input.connect(_on_result_overlay_input)

## Refresh dynamic UI elements (gold, pill count, button states)
func _refresh_ui() -> void:
	_gold_label.text = "💰 金币: %d" % GameManager.current_gold
	_pill_label.text = "💊 丹药: %d/%d" % [GameManager.current_consumables.size(), GameManager.get_consumable_capacity()]

	# Update button states
	var is_full := GameManager.is_consumable_full()
	var buttons := {"low": _low_btn, "mid": _mid_btn, "high": _high_btn}
	for tier_key in buttons:
		var btn: Button = buttons[tier_key]
		var cost: int = ALCHEMY_TIERS[tier_key]["cost"]
		var can_afford := GameManager.current_gold >= cost
		btn.disabled = not can_afford or is_full
		if not can_afford:
			btn.tooltip_text = "金币不足"
		elif is_full:
			btn.tooltip_text = "丹药已满"
		else:
			btn.tooltip_text = ""

## Alchemy button pressed
func _on_alchemy_pressed(tier_key: String) -> void:
	var tier_data: Dictionary = ALCHEMY_TIERS[tier_key]
	var cost: int = tier_data["cost"]

	if GameManager.current_gold < cost:
		return
	if GameManager.is_consumable_full():
		return

	# Deduct gold
	GameManager.modify_gold(-cost)

	# Roll for success
	var success_rate: float = tier_data.get("success_rate", 0.7)
	if randf() >= success_rate:
		_show_fail_result(tier_data)
		_refresh_ui()
		return

	# Roll for quality
	var probs: Dictionary = tier_data["probs"]
	var roll := randf()
	var quality: String = "low"
	var cumulative: float = 0.0
	for q in ["extreme", "high", "mid", "low"]:
		cumulative += probs.get(q, 0.0)
		if roll < cumulative:
			quality = q
			break

	# Pick random pill of that quality
	var pill := _get_random_pill(quality)
	if pill.is_empty():
		pill = _get_random_pill("low")

	if not pill.is_empty():
		var pill_id: String = pill.get("consumable_id", "")
		GameManager.add_consumable(pill_id)
		_show_result(pill, quality)

	_refresh_ui()

## Get a random pill of given quality
func _get_random_pill(quality: String) -> Dictionary:
	var all_consumables: Array = DataManager.get_all_consumables()
	var candidates: Array = []
	for c in all_consumables:
		if c.get("quality", "low") == quality:
			candidates.append(c)
	if candidates.is_empty():
		return {}
	return candidates[randi() % candidates.size()]

## Get quality display info
func _get_quality_info(quality: String) -> Dictionary:
	match quality:
		"low": return {"text": "下品", "color": Color.WHITE, "border": Color.WHITE}
		"mid": return {"text": "中品", "color": Color("00B894"), "border": Color("00B894")}
		"high": return {"text": "上品", "color": Color("0984E3"), "border": Color("0984E3")}
		"extreme": return {"text": "极品", "color": Color("FDCB6E"), "border": Color("FDCB6E")}
		_: return {"text": "未知", "color": Color.WHITE, "border": Color.WHITE}

## Prepare the result popup with given border color
func _prepare_popup(border_color: Color) -> VBoxContainer:
	# Clear old content
	for child in _result_vbox.get_children():
		child.queue_free()

	# Update panel border color
	var style := _result_panel.get_theme_stylebox("panel") as StyleBoxFlat
	if style:
		var new_style := style.duplicate() as StyleBoxFlat
		new_style.border_color = border_color
		_result_panel.add_theme_stylebox_override("panel", new_style)

	_result_popup.visible = true
	return _result_vbox

## Add a close button to the popup
func _add_close_button(vbox: VBoxContainer) -> void:
	var ok_btn := Button.new()
	ok_btn.text = "确定"
	ok_btn.custom_minimum_size = Vector2(120, 40)
	ok_btn.add_theme_font_size_override("font_size", 16)
	ok_btn.pressed.connect(_close_result_popup)
	var btn_center := CenterContainer.new()
	btn_center.add_child(ok_btn)
	vbox.add_child(btn_center)

## Close result popup
func _close_result_popup() -> void:
	_result_popup.visible = false

## Result overlay click to close
func _on_result_overlay_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_close_result_popup()

## Show alchemy success result with detailed pill info
func _show_result(pill: Dictionary, quality: String) -> void:
	var q_info := _get_quality_info(quality)
	var vbox := _prepare_popup(q_info["border"])

	# Title
	var result_title := Label.new()
	result_title.text = "✨ 炼丹成功！"
	result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_title.add_theme_font_size_override("font_size", 24)
	result_title.add_theme_color_override("font_color", Color("A29BFE"))
	vbox.add_child(result_title)

	vbox.add_child(HSeparator.new())

	# Pill name with quality tag
	var pill_name := Label.new()
	pill_name.text = "[%s] %s" % [q_info["text"], pill.get("consumable_name", "???")]
	pill_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pill_name.add_theme_font_size_override("font_size", 20)
	pill_name.add_theme_color_override("font_color", q_info["color"])
	vbox.add_child(pill_name)

	# Pill description
	var pill_desc := Label.new()
	pill_desc.text = pill.get("description", "")
	pill_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pill_desc.add_theme_font_size_override("font_size", 14)
	pill_desc.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	pill_desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(pill_desc)

	# Effects section
	var effects: Array = pill.get("effects", [])
	if not effects.is_empty():
		var effect_text := _build_effect_text(effects)
		var effect_label := Label.new()
		effect_label.text = "🔮 效果: " + effect_text
		effect_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		effect_label.add_theme_font_size_override("font_size", 14)
		effect_label.add_theme_color_override("font_color", Color("00B894"))
		effect_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		vbox.add_child(effect_label)

	# Use scene
	var use_scene: String = pill.get("use_scene", "")
	if not use_scene.is_empty():
		var scene_name := ""
		match use_scene:
			"battle": scene_name = "战斗中使用"
			"anytime": scene_name = "任意时刻使用"
			"any": scene_name = "任意时刻使用"
			"passive": scene_name = "被动生效"
			_: scene_name = use_scene
		var scene_label := Label.new()
		scene_label.text = "📋 使用场景: " + scene_name
		scene_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		scene_label.add_theme_font_size_override("font_size", 13)
		scene_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
		vbox.add_child(scene_label)

	# Price info
	var price: int = pill.get("price", 0)
	if price > 0:
		var price_label := Label.new()
		price_label.text = "💰 价值: %d 金币" % price
		price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		price_label.add_theme_font_size_override("font_size", 12)
		price_label.add_theme_color_override("font_color", Color(0.55, 0.55, 0.6))
		vbox.add_child(price_label)

	# Full capacity warning
	if GameManager.is_consumable_full():
		var full_warn := Label.new()
		full_warn.text = "⚠️ 丹药栏已满，无法继续炼丹"
		full_warn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		full_warn.add_theme_font_size_override("font_size", 14)
		full_warn.add_theme_color_override("font_color", Color("E17055"))
		vbox.add_child(full_warn)

	vbox.add_child(HSeparator.new())
	_add_close_button(vbox)

## Show alchemy failure result
func _show_fail_result(tier_data: Dictionary) -> void:
	var vbox := _prepare_popup(Color("D63031"))

	# Title
	var fail_title := Label.new()
	fail_title.text = "💥 炼丹失败！"
	fail_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fail_title.add_theme_font_size_override("font_size", 24)
	fail_title.add_theme_color_override("font_color", Color("D63031"))
	vbox.add_child(fail_title)

	vbox.add_child(HSeparator.new())

	# Fail message
	var fail_msg := Label.new()
	fail_msg.text = "丹炉震荡，灵气溃散...\n本次炼丹未能成功。"
	fail_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fail_msg.add_theme_font_size_override("font_size", 16)
	fail_msg.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	vbox.add_child(fail_msg)

	# Cost info
	var cost_info := Label.new()
	cost_info.text = "💰 消耗了 %d 金币" % tier_data["cost"]
	cost_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost_info.add_theme_font_size_override("font_size", 14)
	cost_info.add_theme_color_override("font_color", Color("E17055"))
	vbox.add_child(cost_info)

	vbox.add_child(HSeparator.new())
	_add_close_button(vbox)

## Leave alchemy
func _on_leave_pressed() -> void:
	SceneTransition.change_scene("res://scenes/map/MapScene.tscn")

## Build effect text from effects array
func _build_effect_text(effects: Array) -> String:
	var parts: Array[String] = []
	for effect in effects:
		var etype: String = effect.get("type", "")
		var value: int = effect.get("value", 0)
		match etype:
			"heal": parts.append("恢复%d生命" % value)
			"damage": parts.append("造成%d伤害" % value)
			"armor": parts.append("获得%d护甲" % value)
			"draw": parts.append("抽%d张牌" % value)
			"energy": parts.append("获得%d能量" % value)
			"strength": parts.append("力量+%d" % value)
			"max_hp": parts.append("最大生命+%d" % value)
			"heal_percent": parts.append("恢复%d%%生命" % value)
			_:
				if value != 0:
					parts.append("%s: %d" % [etype, value])
	return ", ".join(parts) if not parts.is_empty() else "无"
