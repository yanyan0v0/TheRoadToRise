## Forge scene script - Enhance relics
extends Control

## Base enhancement cost (for enhance_level 0 -> 1)
const BASE_ENHANCE_COST: int = 10
## Cost increment per enhance level
const COST_INCREMENT: int = 10
## Base success rate (for enhance_level 0 -> 1)
const BASE_SUCCESS_RATE: float = 1.0
## Success rate decrement per enhance level
const RATE_DECREMENT: float = 0.1
## Minimum success rate floor
const MIN_SUCCESS_RATE: float = 0.2

## Rarity cost multiplier: higher rarity = higher cost
const RARITY_COST_MULTIPLIER := {
	"common": 1.0,
	"uncommon": 1.5,
	"rare": 2.0,
	"legendary": 3.0,
}
## Rarity rate penalty: higher rarity = lower success rate
const RARITY_RATE_PENALTY := {
	"common": 0.0,
	"uncommon": 0.05,
	"rare": 0.1,
	"legendary": 0.15,
}

## Cached node references (unique names)
@onready var _gold_label: Label = %GoldLabel
@onready var _relic_grid: GridContainer = %RelicGrid
@onready var _empty_hint: CenterContainer = %EmptyHint
@onready var _leave_button: Button = %LeaveButton

@onready var _enhance_popup: Control = %EnhancePopup
@onready var _compare_hbox: HBoxContainer = %CompareHBox
@onready var _cost_label: Label = %CostLabel
@onready var _enhance_button: Button = %EnhanceButton
@onready var _cancel_button: Button = $EnhancePopup/Panel/VBox/ButtonHBox/CancelButton
@onready var _enhance_overlay: ColorRect = $EnhancePopup/Overlay



@onready var _description_label: Label = $CenterContainer/MainVBox/Description

## Currently selected relic index for enhancement
var _current_enhance_index: int = -1

## Calculate enhancement cost based on current enhance_level and rarity
func _get_enhance_cost(enhance_level: int, rarity: String) -> int:
	var base := BASE_ENHANCE_COST + enhance_level * COST_INCREMENT
	var multiplier: float = RARITY_COST_MULTIPLIER.get(rarity, 1.0)
	return int(ceil(base * multiplier))

## Calculate success rate based on current enhance_level and rarity
func _get_success_rate(enhance_level: int, rarity: String) -> float:
	var rate := BASE_SUCCESS_RATE - enhance_level * RATE_DECREMENT
	var penalty: float = RARITY_RATE_PENALTY.get(rarity, 0.0)
	rate -= penalty
	return maxf(rate, MIN_SUCCESS_RATE)

func _ready() -> void:
	GameManager.change_state(GameManager.GameState.REST)
	_setup_panel_styles()
	_connect_signals()
	_refresh_ui()

## Apply custom StyleBox to popup panels (cannot be done in tscn easily)
func _setup_panel_styles() -> void:
	# Enhance popup panel style
	var enhance_panel: PanelContainer = $EnhancePopup/Panel
	var enhance_style := StyleBoxFlat.new()
	enhance_style.bg_color = Color(0.10, 0.08, 0.05, 0.98)
	enhance_style.border_color = Color("E67E22")
	enhance_style.set_border_width_all(2)
	enhance_style.set_corner_radius_all(10)
	enhance_style.set_content_margin_all(20)
	enhance_panel.add_theme_stylebox_override("panel", enhance_style)

## Connect all button signals
func _connect_signals() -> void:
	_leave_button.pressed.connect(_on_leave_pressed)
	_enhance_button.pressed.connect(_on_enhance_pressed)
	_cancel_button.pressed.connect(_close_enhance_popup)
	_enhance_overlay.gui_input.connect(_on_enhance_overlay_input)

## Refresh the entire UI (gold label + relic grid)
func _refresh_ui() -> void:
	_gold_label.text = "💰 金币: %d" % GameManager.current_gold

	# Clear old relic cards
	for child in _relic_grid.get_children():
		child.queue_free()

	if GameManager.current_relics.is_empty():
		_empty_hint.visible = true
	else:
		_empty_hint.visible = false
		for i in range(GameManager.current_relics.size()):
			var entry: Dictionary = GameManager.current_relics[i]
			var relic_id: String = entry.get("relic_id", "")
			var enhance_level: int = entry.get("enhance_level", 0)
			var relic_data: Dictionary = DataManager.get_relic(relic_id)
			if relic_data.is_empty():
				continue
			var card := _create_relic_card(i, relic_data, enhance_level)
			_relic_grid.add_child(card)

## Create a relic card button for the grid list
func _create_relic_card(index: int, relic_data: Dictionary, enhance_level: int) -> Control:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(150, 150)
	btn.flat = false
	btn.focus_mode = Control.FOCUS_NONE

	var rarity: String = relic_data.get("rarity", "common")
	var rarity_color: Color = RelicTooltip.get_rarity_color(rarity)
	var relic_name: String = relic_data.get("relic_name", "???")

	# Custom button styles
	var normal_style := StyleBoxFlat.new()
	normal_style.bg_color = Color(0.15, 0.17, 0.22, 0.9)
	normal_style.border_color = rarity_color.darkened(0.3)
	normal_style.set_border_width_all(2)
	normal_style.set_corner_radius_all(6)
	normal_style.set_content_margin_all(8)
	btn.add_theme_stylebox_override("normal", normal_style)

	var hover_style := normal_style.duplicate() as StyleBoxFlat
	hover_style.bg_color = Color(0.20, 0.22, 0.28, 0.95)
	hover_style.border_color = rarity_color
	btn.add_theme_stylebox_override("hover", hover_style)

	var pressed_style := normal_style.duplicate() as StyleBoxFlat
	pressed_style.bg_color = Color(0.12, 0.14, 0.18, 0.95)
	btn.add_theme_stylebox_override("pressed", pressed_style)

	# Button content
	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 10
	vbox.offset_top = 6
	vbox.offset_right = -10
	vbox.offset_bottom = -6
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 2)
	btn.add_child(vbox)

	# Name + enhance level
	var name_label := Label.new()
	var prefix := "[+%d] " % enhance_level if enhance_level > 0 else ""
	name_label.text = "%s%s" % [prefix, relic_name]
	name_label.add_theme_font_size_override("font_size", 15)
	name_label.add_theme_color_override("font_color", rarity_color)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(name_label)

	# 图标显示区域（名字下方）
	var icon_container := ColorRect.new()
	icon_container.custom_minimum_size = Vector2(40, 40)
	icon_container.color = Color(0.25, 0.2, 0.1, 0.8)  # 棕色背景
	
	# 边框样式
	var icon_border := StyleBoxFlat.new()
	icon_border.bg_color = Color(0, 0, 0, 0)  # 透明背景
	icon_border.border_color = Color(0.6, 0.5, 0.3, 0.8)  # 金色边框
	icon_border.set_border_width_all(2)
	icon_border.set_corner_radius_all(4)
	icon_container.add_theme_stylebox_override("panel", icon_border)
	
	# 法宝图标
	var relic_icon := TextureRect.new()
	relic_icon.custom_minimum_size = Vector2(32, 32)
	relic_icon.size = Vector2(32, 32)
	relic_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	relic_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	relic_icon.position = Vector2(4, 4)
	relic_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# 尝试加载法宝图标
	var icon_path := "res://ui/images/global/relic.png"
	if ResourceLoader.exists(icon_path):
		relic_icon.texture = load(icon_path)
	else:
		# 如果图标不存在，使用文字作为后备
		var fallback_label := Label.new()
		fallback_label.text = relic_name.left(1)
		fallback_label.add_theme_font_size_override("font_size", 16)
		fallback_label.add_theme_color_override("font_color", Color("FDCB6E"))
		fallback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		fallback_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		fallback_label.position = Vector2.ZERO
		fallback_label.size = Vector2(32, 32)
		fallback_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_container.add_child(fallback_label)
	else:
		icon_container.add_child(relic_icon)
	
	vbox.add_child(icon_container)

	# Short description
	var desc_label := Label.new()
	desc_label.text = RelicTooltip.get_enhanced_description(relic_data, enhance_level)
	desc_label.add_theme_font_size_override("font_size", 10)
	desc_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(desc_label)

	var idx := index
	btn.pressed.connect(func(): _on_relic_clicked(idx))
	return btn

## Relic card clicked - open enhance popup
func _on_relic_clicked(index: int) -> void:
	if index < 0 or index >= GameManager.current_relics.size():
		return
	_show_enhance_popup(index)

## Show the enhance comparison popup
func _show_enhance_popup(index: int) -> void:
	_current_enhance_index = index

	var entry: Dictionary = GameManager.current_relics[index]
	var relic_id: String = entry.get("relic_id", "")
	var enhance_level: int = entry.get("enhance_level", 0)
	var relic_data: Dictionary = DataManager.get_relic(relic_id)
	if relic_data.is_empty():
		return

	# Clear old comparison content
	for child in _compare_hbox.get_children():
		child.queue_free()

	# Build comparison: current | arrow | enhanced
	var old_section := _build_compare_section("当前", relic_data, enhance_level, Color(0.8, 0.8, 0.8))
	_compare_hbox.add_child(old_section)

	# Arrow
	var arrow_center := CenterContainer.new()
	arrow_center.custom_minimum_size = Vector2(40, 0)
	var arrow_label := Label.new()
	arrow_label.text = "➜"
	arrow_label.add_theme_font_size_override("font_size", 32)
	arrow_label.add_theme_color_override("font_color", Color("E67E22"))
	arrow_center.add_child(arrow_label)
	_compare_hbox.add_child(arrow_center)

	# Enhanced version
	var new_section := _build_compare_section("强化后", relic_data, enhance_level + 1, Color("00B894"))
	_compare_hbox.add_child(new_section)

	# Calculate dynamic cost and rate
	var rarity: String = relic_data.get("rarity", "common")
	var cost := _get_enhance_cost(enhance_level, rarity)
	var rate := _get_success_rate(enhance_level, rarity)

	# Update cost label and enhance button
	_cost_label.text = "花费: 💰%d    成功率: %d%%" % [cost, int(rate * 100)]
	_enhance_button.text = "⚒️ 强化 💰%d" % cost
	_enhance_button.disabled = GameManager.current_gold < cost
	if _enhance_button.disabled:
		_enhance_button.tooltip_text = "金币不足"
	else:
		_enhance_button.tooltip_text = ""

	_enhance_popup.visible = true

## Build one side of the comparison display (uses RelicTooltip style)
func _build_compare_section(section_title: String, relic_data: Dictionary, enhance_level: int, title_color: Color) -> Control:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)

	# Section title
	var label := Label.new()
	label.text = section_title
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", title_color)
	vbox.add_child(label)

	# Use unified tooltip builder
	var tooltip_panel := RelicTooltip.build_tooltip(relic_data, enhance_level)
	vbox.add_child(tooltip_panel)

	return vbox

## Close enhance popup
func _close_enhance_popup() -> void:
	_enhance_popup.visible = false

## Enhance overlay click - close popup
func _on_enhance_overlay_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_close_enhance_popup()

## Enhance button pressed
func _on_enhance_pressed() -> void:
	if _current_enhance_index < 0:
		return

	var entry: Dictionary = GameManager.current_relics[_current_enhance_index]
	var relic_id: String = entry.get("relic_id", "")
	var enhance_level: int = entry.get("enhance_level", 0)
	var relic_data: Dictionary = DataManager.get_relic(relic_id)
	var rarity: String = relic_data.get("rarity", "common")

	var cost := _get_enhance_cost(enhance_level, rarity)
	var rate := _get_success_rate(enhance_level, rarity)

	if GameManager.current_gold < cost:
		return

	GameManager.modify_gold(-cost)

	var success := GameManager.enhance_relic(_current_enhance_index, rate)
	# Re-read entry after enhancement (enhance_level may have changed)
	entry = GameManager.current_relics[_current_enhance_index]
	enhance_level = entry.get("enhance_level", 0)

	# Track forge count for achievements
	SaveManager.increment_stat("relics_forged")
	AchievementManager.check_forge_achievement()

	# Show floating result hint on the compare popup (do NOT close it)
	_show_floating_result(success, relic_data, enhance_level)

	# If success, refresh the compare popup content to reflect new level
	if success:
		_refresh_compare_popup()

	# Recalculate cost/rate after enhancement for button state
	var new_cost := _get_enhance_cost(enhance_level, rarity)
	var new_rate := _get_success_rate(enhance_level, rarity)
	_cost_label.text = "花费: 💰%d    成功率: %d%%" % [new_cost, int(new_rate * 100)]
	_enhance_button.text = "⚒️ 强化 💰%d" % new_cost
	_enhance_button.disabled = GameManager.current_gold < new_cost
	if _enhance_button.disabled:
		_enhance_button.tooltip_text = "金币不足"
	else:
		_enhance_button.tooltip_text = ""

	# Refresh background relic grid and gold label
	_refresh_ui()

## Refresh the compare popup content with current enhance data
func _refresh_compare_popup() -> void:
	if _current_enhance_index < 0 or _current_enhance_index >= GameManager.current_relics.size():
		return
	var entry: Dictionary = GameManager.current_relics[_current_enhance_index]
	var relic_id: String = entry.get("relic_id", "")
	var enhance_level: int = entry.get("enhance_level", 0)
	var relic_data: Dictionary = DataManager.get_relic(relic_id)
	if relic_data.is_empty():
		return

	# Clear old comparison content
	for child in _compare_hbox.get_children():
		child.queue_free()

	# Rebuild comparison: current | arrow | enhanced
	var old_section := _build_compare_section("当前", relic_data, enhance_level, Color(0.8, 0.8, 0.8))
	_compare_hbox.add_child(old_section)

	var arrow_center := CenterContainer.new()
	arrow_center.custom_minimum_size = Vector2(40, 0)
	var arrow_label := Label.new()
	arrow_label.text = "➜"
	arrow_label.add_theme_font_size_override("font_size", 32)
	arrow_label.add_theme_color_override("font_color", Color("E67E22"))
	arrow_center.add_child(arrow_label)
	_compare_hbox.add_child(arrow_center)

	var new_section := _build_compare_section("强化后", relic_data, enhance_level + 1, Color("00B894"))
	_compare_hbox.add_child(new_section)

	# Update cost label with dynamic values
	var rarity: String = relic_data.get("rarity", "common")
	var cost := _get_enhance_cost(enhance_level, rarity)
	var rate := _get_success_rate(enhance_level, rarity)
	_cost_label.text = "花费: 💰%d    成功率: %d%%" % [cost, int(rate * 100)]
	_enhance_button.text = "⚒️ 强化 💰%d" % cost

## Show a floating result hint label on the compare popup
func _show_floating_result(success: bool, relic_data: Dictionary, enhance_level: int) -> void:
	var hint_label := Label.new()
	if success:
		hint_label.text = "✨ 强化成功！%s +%d" % [relic_data.get("relic_name", ""), enhance_level]
		hint_label.add_theme_color_override("font_color", Color("FDCB6E"))
	else:
		hint_label.text = "❌ 强化失败..."
		hint_label.add_theme_color_override("font_color", Color("D63031"))
	hint_label.add_theme_font_size_override("font_size", 22)
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# Add to scene root with top z_index so it renders above everything
	hint_label.z_index = 2000
	hint_label.top_level = true
	add_child(hint_label)

	# Position at the center of the enhance panel
	var enhance_panel: PanelContainer = $EnhancePopup/Panel
	await get_tree().process_frame
	var panel_center := enhance_panel.global_position + enhance_panel.size * 0.5
	hint_label.global_position = Vector2(panel_center.x - hint_label.size.x * 0.5, 100)

	# Animate: float up and fade out
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(hint_label, "global_position:y", hint_label.global_position.y - 50, 1.5).set_ease(Tween.EASE_OUT)
	tween.tween_property(hint_label, "modulate:a", 0.0, 1.5).set_delay(0.6)
	tween.chain().tween_callback(hint_label.queue_free)

## Leave forge
func _on_leave_pressed() -> void:
	SceneTransition.change_scene("res://scenes/map/MapScene.tscn")
