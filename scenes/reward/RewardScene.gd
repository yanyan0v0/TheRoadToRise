## Battle reward scene - Victory screen with card and relic choices
extends Control

# === Node references ===
@onready var gold_reward_label: Label = $GoldRewardLabel
@onready var card_click_area: Button = $CardClickArea
@onready var relic_click_area: Button = $RelicClickArea
@onready var card_choices_panel: PanelContainer = $CardChoicesPanel
@onready var card_choices_container: HBoxContainer = $CardChoicesPanel/CardChoicesVBox/CardChoicesContainer
@onready var skip_card_button: Button = $CardChoicesPanel/CardChoicesVBox/SkipButton
@onready var relic_popup_panel: PanelContainer = $RelicPopupPanel
@onready var relic_popup_title: Label = $RelicPopupPanel/RelicPopupVBox/RelicPopupTitle
@onready var relic_detail_container: HBoxContainer = $RelicPopupPanel/RelicPopupVBox/RelicDetailContainer
@onready var take_relic_button: Button = $RelicPopupPanel/RelicPopupVBox/RelicActionButtons/TakeRelicButton
@onready var skip_relic_button: Button = $RelicPopupPanel/RelicPopupVBox/RelicActionButtons/SkipRelicButton
@onready var continue_button: Button = $ContinueButton

# === State ===
var gold_reward: int = 0
var card_choices: Array = []
var relic_reward: Dictionary = {}
var has_chosen_card: bool = false
var has_handled_relic: bool = false

# === Card scene for reuse ===
const CARD_SCENE := preload("res://scenes/battle/Card.tscn")

func _ready() -> void:
	GameManager.change_state(GameManager.GameState.REWARD)
	
	# Hide panels initially
	card_choices_panel.visible = false
	
	# Connect buttons
	card_click_area.pressed.connect(_on_card_area_pressed)
	relic_click_area.pressed.connect(_on_relic_area_pressed)
	skip_card_button.pressed.connect(_on_skip_card_pressed)
	take_relic_button.pressed.connect(_on_take_relic_pressed)
	skip_relic_button.pressed.connect(_on_skip_relic_pressed)
	continue_button.pressed.connect(_on_continue_pressed)
	
	# Close panels when clicking background
	$CardChoicesPanel/CardChoicesBg.gui_input.connect(_on_card_panel_bg_input)
	$RelicPopupPanel/RelicPopupBg.gui_input.connect(_on_relic_panel_bg_input)
	
	# Generate and display rewards
	_generate_rewards()
	_display_gold_reward()
	
	# Fade-in animation
	modulate = Color(1, 1, 1, 0)
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.5)

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
	
	# Karma system: gold bonus based on tribulation level
	var karma_level := GameManager.get_tribulation_level()
	var gold_bonus := 0.0
	match karma_level:
		"微劫": gold_bonus = 0.20
		"小劫": gold_bonus = 0.50
		"大劫": gold_bonus = 1.00
		"天罚": gold_bonus = 2.00
	if gold_bonus > 0.0:
		var bonus_gold := int(gold_reward * gold_bonus)
		gold_reward += bonus_gold
	
	GameManager.modify_gold(gold_reward)

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

# ===== Display =====

## Display gold reward
func _display_gold_reward() -> void:
	gold_reward_label.text = "获得 %d 金币" % gold_reward

# ===== Card Area =====

## When player clicks the card area on the victory screen
func _on_card_area_pressed() -> void:
	if has_chosen_card:
		return
	_show_card_choices_panel()

## Show the card choices overlay panel
func _show_card_choices_panel() -> void:
	# Clear previous cards
	for child in card_choices_container.get_children():
		child.queue_free()
	
	# Wait a frame for queue_free to take effect
	await get_tree().process_frame
	
	# Create card choice buttons directly in the container
	for choice_data in card_choices:
		await _create_card_choice_button(choice_data)
	
	card_choices_panel.visible = true
	
	# Fade in
	card_choices_panel.modulate = Color(1, 1, 1, 0)
	var tween := create_tween()
	tween.tween_property(card_choices_panel, "modulate:a", 1.0, 0.3)

## Create a card choice button and add it directly to card_choices_container
func _create_card_choice_button(p_card_data: Dictionary) -> void:
	var card_node: Control = CARD_SCENE.instantiate()
	card_node.custom_minimum_size = Vector2(180, 270)
	
	# Add to container so @onready nodes are resolved
	card_choices_container.add_child(card_node)
	
	# Wait one frame to ensure _ready() has completed and @onready vars are set
	await get_tree().process_frame
	
	# Setup card display
	card_node.setup(p_card_data, 1)
	
	# Disable battle drag/hover behavior
	card_node.is_playable = false
	card_node.modulate = Color.WHITE
	card_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	if card_node.has_node("Background"):
		card_node.get_node("Background").visible = false
	
	# Disable all input processing on the card itself
	card_node.set_process_input(false)
	card_node.set_process_unhandled_input(false)
	
	# Add transparent overlay for click capture (covers the entire card area)
	var click_overlay := ColorRect.new()
	click_overlay.color = Color(0, 0, 0, 0)
	click_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	click_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	card_node.add_child(click_overlay)
	
	# Hover highlight
	click_overlay.mouse_entered.connect(func():
		if not has_chosen_card:
			card_node.modulate = Color(1.2, 1.2, 1.2, 1.0)
			card_node.scale = Vector2(1.05, 1.05)
	)
	click_overlay.mouse_exited.connect(func():
		if not has_chosen_card:
			card_node.modulate = Color.WHITE
			card_node.scale = Vector2.ONE
	)
	
	# Click to select card
	click_overlay.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if not has_chosen_card:
				has_chosen_card = true
				var card_id: String = p_card_data.get("card_id", "")
				GameManager.current_deck.append({"card_id": card_id, "star_level": 1})
				GameManager.stats.cards_obtained += 1
				
				# Highlight selected, dim others
				for child in card_choices_container.get_children():
					if child == card_node:
						card_node.modulate = Color(1.1, 1.0, 0.8, 1.0)
						card_node.scale = Vector2.ONE
					else:
						child.modulate = Color(0.4, 0.4, 0.4, 1.0)
				
				# Close panel after a short delay
				await get_tree().create_timer(0.6).timeout
				_close_card_choices_panel()
				_check_show_continue()
	)

## Skip card selection
func _on_skip_card_pressed() -> void:
	GameManager.modify_karma(-1)
	has_chosen_card = true
	_close_card_choices_panel()
	_check_show_continue()

## Close card choices panel
func _close_card_choices_panel() -> void:
	var tween := create_tween()
	tween.tween_property(card_choices_panel, "modulate:a", 0.0, 0.2)
	tween.tween_callback(func(): card_choices_panel.visible = false)

## Close card panel when clicking background
func _on_card_panel_bg_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not has_chosen_card:
			_close_card_choices_panel()

# ===== Relic Area =====

## When player clicks the relic area on the victory screen
func _on_relic_area_pressed() -> void:
	if has_handled_relic:
		return
	
	if relic_reward.is_empty():
		# No relic available - show a "no relic" notification
		_show_no_relic_popup()
	else:
		_show_relic_popup()

## Show "no relic" notification popup
func _show_no_relic_popup() -> void:
	has_handled_relic = true
	
	# Create a temporary notification
	var popup := PanelContainer.new()
	popup.z_index = 100
	
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.15, 0.92)
	style.border_color = Color(0.5, 0.4, 0.2, 0.8)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(24)
	popup.add_theme_stylebox_override("panel", style)
	
	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 16)
	popup.add_child(vbox)
	
	var icon_label := Label.new()
	icon_label.text = "🏺"
	icon_label.add_theme_font_size_override("font_size", 48)
	icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(icon_label)
	
	var msg_label := Label.new()
	msg_label.text = "本次战斗未获得法宝"
	msg_label.add_theme_font_size_override("font_size", 20)
	msg_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	msg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(msg_label)
	
	var hint_label := Label.new()
	hint_label.text = "击败精英或BOSS有更高几率获得法宝"
	hint_label.add_theme_font_size_override("font_size", 14)
	hint_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(hint_label)
	
	add_child(popup)
	
	# Center the popup
	await get_tree().process_frame
	popup.position = (get_viewport_rect().size - popup.size) / 2.0
	
	# Fade in
	popup.modulate = Color(1, 1, 1, 0)
	var tween := create_tween()
	tween.tween_property(popup, "modulate:a", 1.0, 0.3)
	
	# Auto close after 1.5 seconds
	await get_tree().create_timer(1.5).timeout
	if is_instance_valid(popup):
		var fade_out := create_tween()
		fade_out.tween_property(popup, "modulate:a", 0.0, 0.3)
		fade_out.tween_callback(func():
			if is_instance_valid(popup):
				popup.queue_free()
		)
	
	_check_show_continue()

## Show relic reward popup with details
func _show_relic_popup() -> void:
	# Clear previous content
	for child in relic_detail_container.get_children():
		child.queue_free()
	
	# Build relic detail display
	var detail_panel := _build_relic_detail(relic_reward)
	relic_detail_container.add_child(detail_panel)
	
	var relic_name: String = relic_reward.get("relic_name", "???")
	relic_popup_title.text = "获得法宝 - %s" % relic_name
	
	take_relic_button.visible = true
	take_relic_button.disabled = false
	take_relic_button.text = "获取法宝"
	skip_relic_button.visible = true
	
	relic_popup_panel.visible = true
	
	# Fade in
	relic_popup_panel.modulate = Color(1, 1, 1, 0)
	var tween := create_tween()
	tween.tween_property(relic_popup_panel, "modulate:a", 1.0, 0.3)

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
	
	# Relic name with rarity color
	var name_label := Label.new()
	name_label.text = "🏺 %s" % relic_name
	name_label.add_theme_font_size_override("font_size", 22)
	name_label.add_theme_color_override("font_color", rarity_color)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(name_label)
	
	# Separator
	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 6)
	vbox.add_child(sep)
	
	# Rarity
	var rarity_label := Label.new()
	rarity_label.text = "等级：%s" % rarity_name
	rarity_label.add_theme_font_size_override("font_size", 16)
	rarity_label.add_theme_color_override("font_color", rarity_color)
	vbox.add_child(rarity_label)
	
	# Description
	if not description.is_empty():
		var desc_label := Label.new()
		desc_label.text = "描述：%s" % description
		desc_label.add_theme_font_size_override("font_size", 14)
		desc_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		desc_label.custom_minimum_size = Vector2(320, 0)
		vbox.add_child(desc_label)
	
	# Effect description
	if not effect_desc.is_empty():
		var effect_label := Label.new()
		effect_label.text = "效果：%s" % effect_desc
		effect_label.add_theme_font_size_override("font_size", 14)
		effect_label.add_theme_color_override("font_color", Color("00B894"))
		effect_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		effect_label.custom_minimum_size = Vector2(320, 0)
		vbox.add_child(effect_label)
	
	# Source
	if not source.is_empty():
		var source_label := Label.new()
		source_label.text = "来源：%s" % source
		source_label.add_theme_font_size_override("font_size", 14)
		source_label.add_theme_color_override("font_color", Color("74B9FF"))
		vbox.add_child(source_label)
	
	# Sell price
	var price_label := Label.new()
	price_label.text = "出售金额：%d 💰" % sell_price
	price_label.add_theme_font_size_override("font_size", 14)
	price_label.add_theme_color_override("font_color", Color("FDCB6E"))
	vbox.add_child(price_label)
	
	return panel

## Take the relic
func _on_take_relic_pressed() -> void:
	if has_handled_relic:
		return
	has_handled_relic = true
	
	var relic_id: String = relic_reward.get("relic_id", "")
	GameManager.add_relic(relic_id)
	
	take_relic_button.disabled = true
	take_relic_button.text = "已获取"
	skip_relic_button.visible = false
	
	# Close panel after a short delay
	await get_tree().create_timer(0.6).timeout
	_close_relic_popup()
	_check_show_continue()

## Skip relic
func _on_skip_relic_pressed() -> void:
	has_handled_relic = true
	_close_relic_popup()
	_check_show_continue()

## Close relic popup panel
func _close_relic_popup() -> void:
	var tween := create_tween()
	tween.tween_property(relic_popup_panel, "modulate:a", 0.0, 0.2)
	tween.tween_callback(func(): relic_popup_panel.visible = false)

## Close relic panel when clicking background
func _on_relic_panel_bg_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not has_handled_relic:
			_close_relic_popup()

# ===== Continue =====

## Check if both card and relic have been handled, then show continue button
func _check_show_continue() -> void:
	if has_chosen_card and has_handled_relic:
		continue_button.visible = true
		# Fade in continue button
		continue_button.modulate = Color(1, 1, 1, 0)
		var tween := create_tween()
		tween.tween_property(continue_button, "modulate:a", 1.0, 0.3)

## Continue to next scene
func _on_continue_pressed() -> void:
	if GameManager.current_battle_type == "boss":
		GameManager.current_chapter += 1
		GameManager.current_map_data = {}
		
		if GameManager.current_chapter >= 4:
			SceneTransition.change_scene("res://scenes/game_over/GameOverScene.tscn")
			return
	
	SceneTransition.change_scene("res://scenes/map/MapScene.tscn")
