## Battle reward scene - "搜刮！" styled reward panel (see attached image)
extends Control

## RelicTooltip class reference
const RelicTooltip = preload("res://scripts/relics/RelicTooltip.gd")

# === Card scene for reuse (runtime-loaded to avoid parse-time dependency failures) ===
const CARD_SCENE_PATH := "res://scenes/battle/Card.tscn"
var _card_scene_cache: PackedScene = null

func _get_card_scene() -> PackedScene:
	if _card_scene_cache == null and ResourceLoader.exists(CARD_SCENE_PATH):
		_card_scene_cache = load(CARD_SCENE_PATH)
	return _card_scene_cache

# === State ===
var gold_reward: int = 0
var card_choices: Array = []
var relic_reward: Dictionary = {}
var has_claimed_gold: bool = false
var has_chosen_card: bool = false
var has_handled_relic: bool = false
var skipped_all: bool = false

# === Root dynamic nodes ===
var _panel_root: Control = null        # main scroll panel
var _entries_vbox: VBoxContainer = null # reward entries list
var _skip_ribbon: Control = null        # red ribbon skip button (bottom-right)

# === Popups (built on demand) ===
var _card_choices_popup: Control = null
var _relic_popup: Control = null

# === Theme colors (match the attached image) ===
const COLOR_PAPER_BG := Color(0.20, 0.28, 0.32, 1.0)     # dark teal/slate paper
const COLOR_PAPER_BORDER := Color(0.08, 0.12, 0.14, 1.0)
const COLOR_INNER_BG := Color(0.13, 0.20, 0.24, 1.0)     # inner darker frame
const COLOR_RIBBON := Color(0.82, 0.72, 0.52, 1.0)       # beige ribbon
const COLOR_RIBBON_DARK := Color(0.60, 0.50, 0.34, 1.0)
const COLOR_ENTRY_TEAL := Color(0.24, 0.56, 0.60, 1.0)   # teal button
const COLOR_ENTRY_TEAL_LIGHT := Color(0.40, 0.76, 0.78, 1.0)
const COLOR_ENTRY_BORDER := Color(0.85, 0.90, 0.90, 0.9)
const COLOR_RED_RIBBON := Color(0.82, 0.18, 0.18, 1.0)
const COLOR_RED_RIBBON_DARK := Color(0.55, 0.08, 0.08, 1.0)

func _ready() -> void:
	GameManager.change_state(GameManager.GameState.REWARD)
	
	# Make sure we cover/receive input but let world behind show through
	mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Generate rewards (gold/card/relic) first
	_generate_rewards()
	
	# Build UI based on rewards
	_build_ui()
	
	# Fade-in animation
	modulate = Color(1, 1, 1, 0)
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.4)

# ===== Reward Generation =====

## Generate all rewards based on battle type
func _generate_rewards() -> void:
	var battle_type: String = GameManager.current_battle_type
	
	match battle_type:
		"normal":
			gold_reward = randi_range(15, 30)
			_generate_card_choices(3, "common")
			_try_drop_enemy_relic(0.2)
		"elite":
			gold_reward = randi_range(30, 50)
			_generate_card_choices(3, "uncommon")
			_try_drop_enemy_relic(0.5)
		"boss":
			gold_reward = randi_range(50, 80)
			_generate_card_choices(3, "rare")
			_try_drop_enemy_relic(1.0)
		"tribulation":
			gold_reward = randi_range(80, 120)
			_generate_card_choices(3, "rare")
			_try_drop_enemy_relic(1.0)
		_:
			gold_reward = randi_range(15, 30)
			_generate_card_choices(3, "common")
	
	# Karma system: gold bonus based on tribulation level
	var karma_level := GameManager.get_tribulation_level()
	var gold_bonus := 0.0
	match karma_level:
		"微劫": gold_bonus = 0.20
		"小劫": gold_bonus = 0.50
		"大劫": gold_bonus = 1.00
		"天罚": gold_bonus = 2.00
	if gold_bonus > 0.0:
		gold_reward += int(gold_reward * gold_bonus)

## Generate card choices
func _generate_card_choices(count: int, min_rarity: String) -> void:
	var all_cards := DataManager.get_all_cards()
	var current_char_id: String = GameManager.current_character_id
	
	var rarity_order := ["common", "uncommon", "rare", "legendary"]
	var min_idx := rarity_order.find(min_rarity)
	if min_idx < 0:
		min_idx = 0
	
	var eligible_cards: Array = []
	for card in all_cards:
		var card_rarity: String = card.get("rarity", "common")
		var rarity_idx := rarity_order.find(card_rarity)
		var exclusive: String = card.get("character_exclusive", "all")
		if exclusive != "all" and exclusive != current_char_id:
			continue
		if rarity_idx >= min_idx:
			eligible_cards.append(card)
	
	if eligible_cards.size() < count:
		eligible_cards.clear()
		for card in all_cards:
			var exclusive: String = card.get("character_exclusive", "all")
			if exclusive == "all" or exclusive == current_char_id:
				eligible_cards.append(card)
	
	eligible_cards.shuffle()
	card_choices = eligible_cards.slice(0, mini(count, eligible_cards.size()))

## Try to drop enemy relic based on probability
func _try_drop_enemy_relic(drop_chance: float) -> void:
	var enemy_ids: Array[String] = GameManager.current_enemy_ids
	if enemy_ids.is_empty():
		return
	
	var droppable_relics: Array = []
	for enemy_id in enemy_ids:
		var enemy_data: Dictionary = DataManager.get_enemy(enemy_id)
		if enemy_data.is_empty():
			continue
		var enemy_relics: Array = enemy_data.get("relics", [])
		for relic_id in enemy_relics:
			if not GameManager.has_relic(relic_id):
				droppable_relics.append(relic_id)
	
	if droppable_relics.is_empty():
		return
	
	if randf() < drop_chance:
		var dropped_id: String = droppable_relics[randi() % droppable_relics.size()]
		var relic_data: Dictionary = DataManager.get_relic(dropped_id)
		if not relic_data.is_empty():
			relic_reward = relic_data

# ===== UI Building =====

## Build the main reward panel UI (matches the attached image)
func _build_ui() -> void:
	var screen_size := get_viewport_rect().size
	
	# ---- Main panel (centered) ----
	_panel_root = Control.new()
	_panel_root.custom_minimum_size = Vector2(420, 470)
	_panel_root.size = Vector2(420, 470)
	_panel_root.position = Vector2(
		(screen_size.x - 420) / 2.0,
		(screen_size.y - 470) / 2.0
	)
	_panel_root.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_panel_root)
	
	# --- Paper background (rounded rect) ---
	var paper_bg := Panel.new()
	paper_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	var paper_style := StyleBoxFlat.new()
	paper_style.bg_color = COLOR_PAPER_BG
	paper_style.border_color = COLOR_PAPER_BORDER
	paper_style.set_border_width_all(3)
	paper_style.set_corner_radius_all(14)
	paper_style.shadow_color = Color(0, 0, 0, 0.6)
	paper_style.shadow_size = 8
	paper_bg.add_theme_stylebox_override("panel", paper_style)
	_panel_root.add_child(paper_bg)
	
	# --- Inner darker frame (where entries live) ---
	var inner_frame := Panel.new()
	inner_frame.position = Vector2(18, 70)
	inner_frame.size = Vector2(384, 382)
	var inner_style := StyleBoxFlat.new()
	inner_style.bg_color = COLOR_INNER_BG
	inner_style.border_color = Color(0.05, 0.08, 0.10, 1.0)
	inner_style.set_border_width_all(2)
	inner_style.set_corner_radius_all(8)
	inner_frame.add_theme_stylebox_override("panel", inner_style)
	_panel_root.add_child(inner_frame)
	
	# --- Top ribbon banner with "搜刮！" title ---
	var ribbon := _build_ribbon_banner("搜刮！")
	ribbon.position = Vector2(-30, -22)
	ribbon.size = Vector2(480, 66)
	_panel_root.add_child(ribbon)
	
	# --- Entries VBox (inside inner frame) ---
	_entries_vbox = VBoxContainer.new()
	_entries_vbox.position = Vector2(12, 12)
	_entries_vbox.size = Vector2(360, 358)
	_entries_vbox.add_theme_constant_override("separation", 10)
	inner_frame.add_child(_entries_vbox)
	
	# --- Build entry rows based on rewards ---
	_build_entries()
	
	# --- Bottom-right skip ribbon ---
	_skip_ribbon = _build_skip_ribbon()
	var skip_size := Vector2(240, 90)
	_skip_ribbon.position = Vector2(screen_size.x - skip_size.x - 20, screen_size.y - skip_size.y - 40)
	add_child(_skip_ribbon)

## Build the individual reward entry rows
func _build_entries() -> void:
	# Gold entry
	var gold_entry := _build_entry_button(
		"res://ui/images/global/coin.png",
		"%d金币" % gold_reward,
		"gold"
	)
	_entries_vbox.add_child(gold_entry)
	
	# Card entry
	var card_entry := _build_entry_button(
		"res://ui/images/global/cards.png",
		"将一张牌添加到你的牌组。",
		"card"
	)
	_entries_vbox.add_child(card_entry)
	
	# Relic entry (only if a relic was dropped)
	if not relic_reward.is_empty():
		var relic_id: String = relic_reward.get("relic_id", "")
		var relic_name: String = relic_reward.get("relic_name", "法宝")
		var icon_path := "res://ui/images/global/relic/%s.png" % relic_id
		var relic_entry := _build_entry_button(
			icon_path,
			"获得法宝：%s" % relic_name,
			"relic"
		)
		_entries_vbox.add_child(relic_entry)

## Build a single reward entry button (teal gradient bar with icon + label)
func _build_entry_button(icon_path: String, text: String, entry_type: String) -> Control:
	var btn := Control.new()
	btn.custom_minimum_size = Vector2(360, 44)
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Background panel (teal)
	var bg := Panel.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_ENTRY_TEAL
	style.border_color = COLOR_ENTRY_BORDER
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	bg.add_theme_stylebox_override("panel", style)
	btn.add_child(bg)
	
	# Top highlight strip (lighter teal at top for "glossy" feel)
	var highlight := Panel.new()
	highlight.position = Vector2(4, 3)
	highlight.size = Vector2(352, 10)
	var hl_style := StyleBoxFlat.new()
	hl_style.bg_color = COLOR_ENTRY_TEAL_LIGHT
	hl_style.set_corner_radius_all(5)
	highlight.add_theme_stylebox_override("panel", hl_style)
	highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(highlight)
	
	# Icon
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(28, 28)
	icon.size = Vector2(28, 28)
	icon.position = Vector2(10, 8)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ResourceLoader.exists(icon_path):
		icon.texture = load(icon_path)
	btn.add_child(icon)
	
	# Label
	var label := Label.new()
	label.text = text
	label.position = Vector2(50, 0)
	label.size = Vector2(300, 44)
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(label)
	
	# Hover / click handling
	btn.mouse_entered.connect(func():
		if not _entry_is_consumed(entry_type, btn):
			style.bg_color = COLOR_ENTRY_TEAL.lightened(0.08)
			bg.add_theme_stylebox_override("panel", style)
	)
	btn.mouse_exited.connect(func():
		style.bg_color = COLOR_ENTRY_TEAL
		bg.add_theme_stylebox_override("panel", style)
	)
	btn.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_on_entry_clicked(entry_type, btn, label)
	)
	
	# Store type & label reference as metadata
	btn.set_meta("entry_type", entry_type)
	btn.set_meta("label", label)
	btn.set_meta("bg_style", style)
	btn.set_meta("bg_panel", bg)
	
	return btn

## Check if an entry is already consumed (disabled)
func _entry_is_consumed(entry_type: String, _btn: Control) -> bool:
	match entry_type:
		"gold": return has_claimed_gold
		"card": return has_chosen_card
		"relic": return has_handled_relic
	return false

## Mark an entry as consumed (grey out)
func _mark_entry_consumed(btn: Control, text: String) -> void:
	if not is_instance_valid(btn):
		return
	var style: StyleBoxFlat = btn.get_meta("bg_style")
	var bg: Panel = btn.get_meta("bg_panel")
	var label: Label = btn.get_meta("label")
	if style and bg:
		style.bg_color = Color(0.25, 0.28, 0.30, 1.0)
		bg.add_theme_stylebox_override("panel", style)
	if label and text != "":
		label.text = text
		label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	btn.mouse_filter = Control.MOUSE_FILTER_IGNORE

## Handle entry click: gold => take immediately, card => popup, relic => popup
func _on_entry_clicked(entry_type: String, btn: Control, _label: Label) -> void:
	match entry_type:
		"gold":
			if has_claimed_gold:
				return
			has_claimed_gold = true
			GameManager.modify_gold(gold_reward)
			_mark_entry_consumed(btn, "已获得 %d 金币" % gold_reward)
			_check_all_done()
		"card":
			if has_chosen_card:
				return
			_show_card_choices_popup()
		"relic":
			if has_handled_relic:
				return
			_show_relic_popup()

## Build the top beige ribbon banner with title
func _build_ribbon_banner(title_text: String) -> Control:
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Main ribbon body
	var body := Panel.new()
	body.position = Vector2(40, 8)
	body.size = Vector2(400, 50)
	var body_style := StyleBoxFlat.new()
	body_style.bg_color = COLOR_RIBBON
	body_style.border_color = COLOR_RIBBON_DARK
	body_style.set_border_width_all(2)
	body_style.set_corner_radius_all(6)
	body_style.shadow_color = Color(0, 0, 0, 0.45)
	body_style.shadow_size = 4
	body_style.shadow_offset = Vector2(0, 2)
	body.add_theme_stylebox_override("panel", body_style)
	root.add_child(body)
	
	# Left ribbon tail (triangle-ish panel)
	var tail_l := Panel.new()
	tail_l.position = Vector2(8, 22)
	tail_l.size = Vector2(44, 28)
	var tail_l_style := StyleBoxFlat.new()
	tail_l_style.bg_color = COLOR_RIBBON_DARK
	tail_l_style.set_corner_radius_all(4)
	tail_l.add_theme_stylebox_override("panel", tail_l_style)
	tail_l.rotation_degrees = -8
	root.add_child(tail_l)
	root.move_child(tail_l, 0)  # behind body
	
	# Right ribbon tail
	var tail_r := Panel.new()
	tail_r.position = Vector2(428, 22)
	tail_r.size = Vector2(44, 28)
	var tail_r_style := StyleBoxFlat.new()
	tail_r_style.bg_color = COLOR_RIBBON_DARK
	tail_r_style.set_corner_radius_all(4)
	tail_r.add_theme_stylebox_override("panel", tail_r_style)
	tail_r.rotation_degrees = 8
	root.add_child(tail_r)
	root.move_child(tail_r, 0)  # behind body
	
	# Title label (on top of body)
	var title := Label.new()
	title.text = title_text
	title.position = Vector2(40, 8)
	title.size = Vector2(400, 50)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(0.99, 0.95, 0.85))
	title.add_theme_color_override("font_outline_color", Color(0.3, 0.2, 0.1))
	title.add_theme_constant_override("outline_size", 4)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(title)
	
	return root

## Build the bottom-right red ribbon "跳过" button
func _build_skip_ribbon() -> Control:
	var root := Control.new()
	root.custom_minimum_size = Vector2(240, 90)
	root.size = Vector2(240, 90)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Red ribbon body
	var body := Panel.new()
	body.position = Vector2(10, 20)
	body.size = Vector2(180, 52)
	var body_style := StyleBoxFlat.new()
	body_style.bg_color = COLOR_RED_RIBBON
	body_style.border_color = COLOR_RED_RIBBON_DARK
	body_style.set_border_width_all(2)
	body_style.set_corner_radius_all(6)
	body_style.shadow_color = Color(0, 0, 0, 0.5)
	body_style.shadow_size = 4
	body_style.shadow_offset = Vector2(2, 2)
	body.add_theme_stylebox_override("panel", body_style)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(body)
	
	# Right arrow tip (rotated square)
	var arrow := Panel.new()
	arrow.position = Vector2(170, 22)
	arrow.size = Vector2(50, 50)
	arrow.pivot_offset = Vector2(25, 25)
	arrow.rotation_degrees = 45
	var arrow_style := StyleBoxFlat.new()
	arrow_style.bg_color = COLOR_RED_RIBBON
	arrow_style.border_color = COLOR_RED_RIBBON_DARK
	arrow_style.set_border_width_all(2)
	arrow.add_theme_stylebox_override("panel", arrow_style)
	arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(arrow)
	
	# Left small tail (curve emulation)
	var tail := Panel.new()
	tail.position = Vector2(0, 60)
	tail.size = Vector2(30, 20)
	tail.pivot_offset = Vector2(15, 10)
	tail.rotation_degrees = -20
	var tail_style := StyleBoxFlat.new()
	tail_style.bg_color = COLOR_RED_RIBBON_DARK
	tail_style.set_corner_radius_all(4)
	tail.add_theme_stylebox_override("panel", tail_style)
	tail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(tail)
	
	# Label "跳过"
	var label := Label.new()
	label.text = "跳过"
	label.position = Vector2(10, 20)
	label.size = Vector2(180, 52)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", Color(1, 1, 1))
	label.add_theme_color_override("font_outline_color", Color(0.3, 0.0, 0.0))
	label.add_theme_constant_override("outline_size", 3)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(label)
	
	# Hover / click handling on root
	root.mouse_entered.connect(func():
		root.scale = Vector2(1.05, 1.05)
		root.pivot_offset = root.size / 2.0
	)
	root.mouse_exited.connect(func():
		root.scale = Vector2.ONE
	)
	root.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_on_skip_all_pressed()
	)
	
	return root

# ===== Card choices popup =====

func _show_card_choices_popup() -> void:
	_close_card_choices_popup()
	
	_card_choices_popup = Control.new()
	_card_choices_popup.set_anchors_preset(Control.PRESET_FULL_RECT)
	_card_choices_popup.z_index = 50
	
	# Dark overlay
	var overlay := ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0, 0.6)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if not has_chosen_card:
				_close_card_choices_popup()
	)
	_card_choices_popup.add_child(overlay)
	
	# Center container
	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.add_theme_constant_override("separation", 20)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_card_choices_popup.add_child(vbox)
	
	# Title
	var title := Label.new()
	title.text = "选择一张卡牌加入卡组"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.99, 0.80, 0.43))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	
	# Card row
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 30)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(hbox)
	
	add_child(_card_choices_popup)
	
	# Instantiate card choices
	for choice_data in card_choices:
		await _create_card_choice(hbox, choice_data)
	
	# Skip card button
	var skip_btn := Button.new()
	skip_btn.text = "跳过"
	skip_btn.custom_minimum_size = Vector2(200, 45)
	skip_btn.add_theme_font_size_override("font_size", 18)
	skip_btn.pressed.connect(_on_skip_card_pressed)
	vbox.add_child(skip_btn)
	
	# Now compute proper center position after layout
	await get_tree().process_frame
	if is_instance_valid(vbox):
		var sz := vbox.size
		var screen := get_viewport_rect().size
		vbox.position = (screen - sz) / 2.0
	
	# Fade in
	_card_choices_popup.modulate = Color(1, 1, 1, 0)
	var tween := create_tween()
	tween.tween_property(_card_choices_popup, "modulate:a", 1.0, 0.3)

func _create_card_choice(parent: HBoxContainer, p_card_data: Dictionary) -> void:
	var card_scene := _get_card_scene()
	if card_scene == null:
		# Fallback: show a simple labeled button if the card scene is unavailable
		var fallback := Button.new()
		fallback.custom_minimum_size = Vector2(180, 270)
		fallback.text = p_card_data.get("card_name", "卡牌")
		fallback.add_theme_font_size_override("font_size", 18)
		parent.add_child(fallback)
		fallback.pressed.connect(func():
			if has_chosen_card:
				return
			has_chosen_card = true
			var card_id_fb: String = p_card_data.get("card_id", "")
			GameManager.current_deck.append({"card_id": card_id_fb, "star_level": 1})
			GameManager.stats.cards_obtained += 1
			_mark_card_entry_consumed(p_card_data.get("card_name", "卡牌"))
			_close_card_choices_popup()
			_check_all_done()
		)
		return
	var card_node: Control = card_scene.instantiate()
	card_node.custom_minimum_size = Vector2(180, 270)
	parent.add_child(card_node)
	
	await get_tree().process_frame
	
	card_node.setup(p_card_data, 1)
	card_node.is_playable = false
	card_node.modulate = Color.WHITE
	card_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_node.set_process_input(false)
	card_node.set_process_unhandled_input(false)
	if card_node.has_node("Background"):
		card_node.get_node("Background").visible = false
	
	var click_overlay := ColorRect.new()
	click_overlay.color = Color(0, 0, 0, 0)
	click_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	click_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	card_node.add_child(click_overlay)
	
	click_overlay.mouse_entered.connect(func():
		if not has_chosen_card:
			card_node.modulate = Color(1.2, 1.2, 1.2, 1.0)
			card_node.scale = Vector2(1.05, 1.05)
			card_node.pivot_offset = card_node.size / 2.0
	)
	click_overlay.mouse_exited.connect(func():
		if not has_chosen_card:
			card_node.modulate = Color.WHITE
			card_node.scale = Vector2.ONE
	)
	
	click_overlay.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if not has_chosen_card:
				has_chosen_card = true
				var card_id: String = p_card_data.get("card_id", "")
				GameManager.current_deck.append({"card_id": card_id, "star_level": 1})
				GameManager.stats.cards_obtained += 1
				
				# Mark the card entry as consumed
				_mark_card_entry_consumed(p_card_data.get("card_name", "卡牌"))
				
				# Highlight selected, dim others
				for child in parent.get_children():
					if child == card_node:
						card_node.modulate = Color(1.1, 1.0, 0.8, 1.0)
						card_node.scale = Vector2.ONE
					else:
						child.modulate = Color(0.4, 0.4, 0.4, 1.0)
				
				await get_tree().create_timer(0.6).timeout
				_close_card_choices_popup()
				_check_all_done()
	)

func _on_skip_card_pressed() -> void:
	GameManager.modify_karma(-1)
	has_chosen_card = true
	_mark_card_entry_consumed("已跳过卡牌")
	_close_card_choices_popup()
	_check_all_done()

func _mark_card_entry_consumed(text: String) -> void:
	for child in _entries_vbox.get_children():
		if child.has_meta("entry_type") and child.get_meta("entry_type") == "card":
			_mark_entry_consumed(child, text)
			break

func _close_card_choices_popup() -> void:
	if _card_choices_popup != null and is_instance_valid(_card_choices_popup):
		var tween := create_tween()
		tween.tween_property(_card_choices_popup, "modulate:a", 0.0, 0.2)
		tween.tween_callback(func():
			if is_instance_valid(_card_choices_popup):
				_card_choices_popup.queue_free()
			_card_choices_popup = null
		)
	else:
		_card_choices_popup = null

# ===== Relic popup =====

func _show_relic_popup() -> void:
	_close_relic_popup()
	
	if relic_reward.is_empty():
		return
	
	_relic_popup = Control.new()
	_relic_popup.set_anchors_preset(Control.PRESET_FULL_RECT)
	_relic_popup.z_index = 50
	
	# Dark overlay
	var overlay := ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0, 0.6)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if not has_handled_relic:
				_close_relic_popup()
	)
	_relic_popup.add_child(overlay)
	
	# Center panel
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.1, 0.1, 0.15, 0.96)
	panel_style.border_color = Color(0.5, 0.45, 0.3, 0.9)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(10)
	panel_style.set_content_margin_all(20)
	panel.add_theme_stylebox_override("panel", panel_style)
	_relic_popup.add_child(panel)
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)
	
	# Title
	var relic_name: String = relic_reward.get("relic_name", "???")
	var title := Label.new()
	title.text = "获得法宝 - %s" % relic_name
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.99, 0.80, 0.43))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	
	# Detail panel
	var detail_panel := _build_relic_detail(relic_reward)
	vbox.add_child(detail_panel)
	
	# Action buttons
	var btns := HBoxContainer.new()
	btns.add_theme_constant_override("separation", 30)
	btns.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btns)
	
	var take_btn := Button.new()
	take_btn.text = "获取法宝"
	take_btn.custom_minimum_size = Vector2(120, 45)
	take_btn.add_theme_font_size_override("font_size", 18)
	take_btn.pressed.connect(_on_take_relic_pressed)
	btns.add_child(take_btn)
	
	var skip_btn := Button.new()
	skip_btn.text = "跳过"
	skip_btn.custom_minimum_size = Vector2(100, 45)
	skip_btn.add_theme_font_size_override("font_size", 18)
	skip_btn.pressed.connect(_on_skip_relic_pressed)
	btns.add_child(skip_btn)
	
	add_child(_relic_popup)
	
	await get_tree().process_frame
	if is_instance_valid(panel):
		var sz := panel.size
		var screen := get_viewport_rect().size
		panel.position = (screen - sz) / 2.0
	
	# Fade in
	_relic_popup.modulate = Color(1, 1, 1, 0)
	var tween := create_tween()
	tween.tween_property(_relic_popup, "modulate:a", 1.0, 0.3)

## Build relic detail display panel
func _build_relic_detail(relic_data: Dictionary) -> PanelContainer:
	var rarity: String = relic_data.get("rarity", "common")
	var rarity_color: Color = RelicTooltip.get_rarity_color(rarity)
	var rarity_name: String = RelicTooltip.get_rarity_name(rarity)
	var relic_name: String = relic_data.get("relic_name", "???")
	var description: String = RelicTooltip.get_enhanced_description(relic_data)
	var effect_desc: String = relic_data.get("effect_description", "")
	var source: String = relic_data.get("source", "")
	var sell_price: int = RelicTooltip.calc_sell_price(relic_data, 0)
	
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(360, 0)
	
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.12, 0.95)
	style.border_color = rarity_color.darkened(0.2)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(20)
	panel.add_theme_stylebox_override("panel", style)
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)
	
	var name_label := Label.new()
	name_label.text = "🏺 %s" % relic_name
	name_label.add_theme_font_size_override("font_size", 22)
	name_label.add_theme_color_override("font_color", rarity_color)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(name_label)
	
	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 6)
	vbox.add_child(sep)
	
	var rarity_label := Label.new()
	rarity_label.text = "等级：%s" % rarity_name
	rarity_label.add_theme_font_size_override("font_size", 16)
	rarity_label.add_theme_color_override("font_color", rarity_color)
	vbox.add_child(rarity_label)
	
	if not description.is_empty():
		var desc_label := Label.new()
		desc_label.text = "描述：%s" % description
		desc_label.add_theme_font_size_override("font_size", 14)
		desc_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		desc_label.custom_minimum_size = Vector2(320, 0)
		vbox.add_child(desc_label)
	
	if not effect_desc.is_empty():
		var effect_label := Label.new()
		effect_label.text = "效果：%s" % effect_desc
		effect_label.add_theme_font_size_override("font_size", 14)
		effect_label.add_theme_color_override("font_color", Color("00B894"))
		effect_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		effect_label.custom_minimum_size = Vector2(320, 0)
		vbox.add_child(effect_label)
	
	if not source.is_empty():
		var source_label := Label.new()
		source_label.text = "来源：%s" % source
		source_label.add_theme_font_size_override("font_size", 14)
		source_label.add_theme_color_override("font_color", Color("74B9FF"))
		vbox.add_child(source_label)
	
	var price_label := Label.new()
	price_label.text = "出售金额：%d 💰" % sell_price
	price_label.add_theme_font_size_override("font_size", 14)
	price_label.add_theme_color_override("font_color", Color("FDCB6E"))
	vbox.add_child(price_label)
	
	return panel

func _on_take_relic_pressed() -> void:
	if has_handled_relic:
		return
	has_handled_relic = true
	var relic_id: String = relic_reward.get("relic_id", "")
	var relic_name: String = relic_reward.get("relic_name", "法宝")
	GameManager.add_relic(relic_id)
	_mark_relic_entry_consumed("已获得法宝：%s" % relic_name)
	_close_relic_popup()
	_check_all_done()

func _on_skip_relic_pressed() -> void:
	has_handled_relic = true
	_mark_relic_entry_consumed("已跳过法宝")
	_close_relic_popup()
	_check_all_done()

func _mark_relic_entry_consumed(text: String) -> void:
	for child in _entries_vbox.get_children():
		if child.has_meta("entry_type") and child.get_meta("entry_type") == "relic":
			_mark_entry_consumed(child, text)
			break

func _close_relic_popup() -> void:
	if _relic_popup != null and is_instance_valid(_relic_popup):
		var tween := create_tween()
		tween.tween_property(_relic_popup, "modulate:a", 0.0, 0.2)
		tween.tween_callback(func():
			if is_instance_valid(_relic_popup):
				_relic_popup.queue_free()
			_relic_popup = null
		)
	else:
		_relic_popup = null

# ===== Skip All / Continue =====

## Skip all remaining rewards and continue
func _on_skip_all_pressed() -> void:
	if skipped_all:
		return
	skipped_all = true
	
	# Auto-claim any unclaimed gold
	if not has_claimed_gold:
		has_claimed_gold = true
		GameManager.modify_gold(gold_reward)
	
	# Mark card as skipped
	if not has_chosen_card:
		has_chosen_card = true
		GameManager.modify_karma(-1)
	
	# Mark relic as skipped
	if not relic_reward.is_empty() and not has_handled_relic:
		has_handled_relic = true
	elif relic_reward.is_empty():
		has_handled_relic = true
	
	_continue_to_next_scene()

## Check if all rewards are handled => proceed
func _check_all_done() -> void:
	var relic_done: bool = has_handled_relic if not relic_reward.is_empty() else true
	if has_claimed_gold and has_chosen_card and relic_done:
		# Small delay then continue
		await get_tree().create_timer(0.4).timeout
		_continue_to_next_scene()

func _continue_to_next_scene() -> void:
	if GameManager.current_battle_type == "boss":
		GameManager.current_chapter += 1
		GameManager.current_map_data = {}
		if GameManager.current_chapter > GameManager.TOTAL_CHAPTERS:
			SceneTransition.change_scene("res://scenes/game_over/GameOverScene.tscn")
			return
	SceneTransition.change_scene("res://scenes/map/MapScene.tscn")
