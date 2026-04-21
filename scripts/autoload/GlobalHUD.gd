## 全局HUD - 在除了主菜单和角色选择界面外的所有场景中显示状态栏、法宝和设置按钮
extends CanvasLayer

## RelicTooltip class reference
const RelicTooltip = preload("res://scripts/relics/RelicTooltip.gd")

## 不显示HUD的场景列表
const HIDDEN_SCENES := [
	"MainMenuScene",
	"CharacterSelectScene",
	"AchievementScene",
]

var _hud_container: Control = null
var _chapter_label: Label = null
var _hp_icon: TextureRect = null
var _hp_label: Label = null
var _gold_icon: TextureRect = null
var _gold_label: Label = null
var _karma_label: Label = null
var _relic_container: HBoxContainer = null
var _consumable_container: HBoxContainer = null
var _timer_label: Label = null
var _settings_button: Button = null
var _map_button: Button = null
var _deck_button: Button = null
var _deck_count_label: Label = null
var _deck_popup: Control = null
var _settings_popup: PanelContainer = null
var _settings_panel: Control = null
var _tooltip: PanelContainer = null
var _relic_tooltip: PanelContainer = null
var _avatar_bubble: PanelContainer = null
var _avatar_btn: TextureRect = null
var _is_refreshing: bool = false

## 缓存当前显示的数据，避免不必要的重建导致频闪
var _cached_relic_ids: Array = []
var _cached_consumable_ids: Array = []

## Track current scene name for visibility updates
var _last_scene_name: String = ""

## 计时器
var _elapsed_time: float = 0.0
var _timer_running: bool = false

## 丹药拖拽状态
var _dragging_consumable: bool = false
var _drag_consumable_id: String = ""
var _drag_consumable_data: Dictionary = {}
var _drag_icon: ColorRect = null
var _drag_source_btn: ColorRect = null

func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	_build_hud()
	
	# 监听场景切换
	get_tree().node_added.connect(_on_node_added)
	
	# 监听数据变化
	EventBus.health_changed.connect(_on_health_changed)
	EventBus.gold_changed.connect(_on_gold_changed)
	EventBus.karma_changed.connect(_on_karma_changed)
	EventBus.consumable_capacity_changed.connect(_on_consumable_changed)
	EventBus.relic_acquired.connect(_on_relic_acquired)
	EventBus.next_chapter_entered.connect(_on_next_chapter_entered)
	
	# 初始隐藏（主菜单）
	_update_visibility()

func _process(delta: float) -> void:
	# Check for scene changes to update visibility reliably
	var current_scene := get_tree().current_scene
	var scene_name: String = current_scene.name if current_scene != null else ""
	if scene_name != _last_scene_name:
		_last_scene_name = scene_name
		_update_visibility()
	
	# 更新计时器
	if _timer_running and _hud_container != null and _hud_container.visible:
		_elapsed_time += delta
		_update_timer_display()
	
	# 拖拽图标跟随鼠标
	if _dragging_consumable and _drag_icon != null:
		_drag_icon.global_position = _hud_container.get_global_mouse_position() - Vector2(15, 15)

func _on_node_added(_node: Node) -> void:
	# 刷新期间忽略所有node_added信号，防止死循环
	if _is_refreshing:
		return
	# 忽略HUD自身子节点的添加
	if _hud_container != null and _hud_container.is_ancestor_of(_node):
		return
	# 延迟检查，等场景树稳定
	call_deferred("_update_visibility")

## 更新HUD可见性
func _update_visibility() -> void:
	if _hud_container == null:
		return
	
	var current_scene := get_tree().current_scene
	if current_scene == null:
		_hud_container.visible = false
		return
	
	var scene_name: String = current_scene.name
	_hud_container.visible = scene_name not in HIDDEN_SCENES
	
	if _hud_container.visible:
		_timer_running = true
		_update_avatar_texture()
		_refresh_all()
	else:
		_timer_running = false

## 构建HUD界面
func _build_hud() -> void:
	_hud_container = Control.new()
	_hud_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hud_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hud_container)
	
	# ===== 第一行：顶部状态栏 =====
	var screen_w := get_viewport().get_visible_rect().size.x
	if screen_w < 100:
		screen_w = 1920.0  # 默认安全值
	
	var top_bg := ColorRect.new()
	top_bg.position = Vector2(0, 0)
	top_bg.size = Vector2(screen_w, 54)
	top_bg.color = Color(0.05, 0.05, 0.08, 0.85)
	top_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_container.add_child(top_bg)
	
	# 状态栏容器
	var top_bar := HBoxContainer.new()
	top_bar.position = Vector2(10, 8)
	top_bar.size = Vector2(screen_w - 20, 38)
	top_bar.add_theme_constant_override("separation", 20)
	top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_container.add_child(top_bar)
	
	# 章节名
	_chapter_label = Label.new()
	_chapter_label.text = GameManager.get_current_chapter_name()
	_chapter_label.add_theme_font_size_override("font_size", 20)
	_chapter_label.add_theme_color_override("font_color", Color("DCDCDC"))
	_chapter_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_bar.add_child(_chapter_label)
	
	# 角色头像（章节名和HP中间）
	_avatar_btn = TextureRect.new()
	_avatar_btn.custom_minimum_size = Vector2(24, 24)
	_avatar_btn.size = Vector2(24, 24)
	_avatar_btn.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_avatar_btn.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_avatar_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	_avatar_btn.mouse_entered.connect(_on_avatar_hover_enter)
	_avatar_btn.mouse_exited.connect(_on_avatar_hover_exit)
	_avatar_btn.gui_input.connect(_on_avatar_clicked)
	_update_avatar_texture()
	top_bar.add_child(_avatar_btn)
	
	# HP（心形图标 + 数值）
	var hp_box := HBoxContainer.new()
	hp_box.add_theme_constant_override("separation", 4)
	hp_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	_hp_icon = TextureRect.new()
	_hp_icon.custom_minimum_size = Vector2(16, 16)
	_hp_icon.size = Vector2(16, 16)
	_hp_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_hp_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_hp_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var heart_path := "res://ui/images/global/heart.png"
	if ResourceLoader.exists(heart_path):
		_hp_icon.texture = load(heart_path)
	hp_box.add_child(_hp_icon)
	
	_hp_label = Label.new()
	_hp_label.text = "%d/%d" % [GameManager.current_hp, GameManager.max_hp]
	_hp_label.add_theme_font_size_override("font_size", 20)
	_hp_label.add_theme_color_override("font_color", Color("FF6B6B"))
	_hp_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp_box.add_child(_hp_label)
	
	top_bar.add_child(hp_box)
	
	# 金币（图标 + 数值）
	var gold_box := HBoxContainer.new()
	gold_box.add_theme_constant_override("separation", 4)
	gold_box.mouse_filter = Control.MOUSE_FILTER_STOP
	gold_box.gui_input.connect(_on_gold_label_input)
	
	_gold_icon = TextureRect.new()
	_gold_icon.custom_minimum_size = Vector2(16, 16)
	_gold_icon.size = Vector2(16, 16)
	_gold_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_gold_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_gold_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gold_icon_path := "res://ui/images/global/coin.png"
	if ResourceLoader.exists(gold_icon_path):
		_gold_icon.texture = load(gold_icon_path)
	gold_box.add_child(_gold_icon)
	
	_gold_label = Label.new()
	_gold_label.text = "%d" % GameManager.current_gold
	_gold_label.add_theme_font_size_override("font_size", 20)
	_gold_label.add_theme_color_override("font_color", Color("FDCB6E"))
	_gold_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gold_box.add_child(_gold_label)
	
	top_bar.add_child(gold_box)
	
	# 劫数
	_karma_label = Label.new()
	_karma_label.text = "劫: %d [%s]" % [GameManager.current_karma, GameManager.get_tribulation_level()]
	_karma_label.add_theme_font_size_override("font_size", 20)
	_karma_label.add_theme_color_override("font_color", Color("A29BFE"))
	_karma_label.mouse_filter = Control.MOUSE_FILTER_STOP
	_karma_label.mouse_entered.connect(_on_karma_hover_enter)
	_karma_label.mouse_exited.connect(_on_karma_hover_exit)
	_karma_label.gui_input.connect(_on_karma_label_input)
	top_bar.add_child(_karma_label)
	
	# 丹药显示（在劫数后面）
	_consumable_container = HBoxContainer.new()
	_consumable_container.add_theme_constant_override("separation", 4)
	_consumable_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_bar.add_child(_consumable_container)
	
	# 弹性空间
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_bar.add_child(spacer)
	
	# 计时显示（设置按钮左边）
	_timer_label = Label.new()
	_timer_label.text = "00:00"
	_timer_label.add_theme_font_size_override("font_size", 18)
	_timer_label.add_theme_color_override("font_color", Color("B2BEC3"))
	_timer_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_bar.add_child(_timer_label)
	
	# 地图按钮（计时器和设置按钮之间）
	_map_button = Button.new()
	_map_button.custom_minimum_size = Vector2(40, 40)
	var map_icon := load("res://ui/images/global/map.png") as Texture2D
	if map_icon != null:
		_map_button.icon = map_icon
		_map_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_map_button.expand_icon = true
	else:
		_map_button.text = "🗺"
		_map_button.add_theme_font_size_override("font_size", 20)
	_map_button.pressed.connect(_on_map_button_pressed)
	top_bar.add_child(_map_button)
	
	# 卡牌按钮（地图按钮右边）
	_deck_button = Button.new()
	_deck_button.custom_minimum_size = Vector2(40, 40)
	var cards_icon := load("res://ui/images/global/cards.png") as Texture2D
	if cards_icon != null:
		_deck_button.icon = cards_icon
		_deck_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_deck_button.expand_icon = true
	else:
		_deck_button.text = "📋"
		_deck_button.add_theme_font_size_override("font_size", 20)
	_deck_button.pressed.connect(_on_deck_button_pressed)
	
	# Deck card count badge (bottom-right corner)
	_deck_count_label = Label.new()
	_deck_count_label.text = str(GameManager.current_deck.size())
	_deck_count_label.add_theme_font_size_override("font_size", 10)
	_deck_count_label.add_theme_color_override("font_color", Color(1, 1, 1))
	_deck_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_deck_count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_deck_count_label.custom_minimum_size = Vector2(18, 18)
	_deck_count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var badge_bg := Panel.new()
	badge_bg.name = "DeckBadge"
	badge_bg.custom_minimum_size = Vector2(18, 18)
	badge_bg.size = Vector2(18, 18)
	badge_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var badge_style := StyleBoxFlat.new()
	badge_style.bg_color = Color(0.8, 0.2, 0.2, 0.9)
	badge_style.set_corner_radius_all(9)
	badge_bg.add_theme_stylebox_override("panel", badge_style)
	badge_bg.add_child(_deck_count_label)
	_deck_button.add_child(badge_bg)
	# Position badge at bottom-right of button
	badge_bg.position = Vector2(22, 22)
	
	top_bar.add_child(_deck_button)
	
	# 设置按钮
	_settings_button = Button.new()
	_settings_button.custom_minimum_size = Vector2(40, 40)
	var setting_icon := load("res://ui/images/global/setting.png") as Texture2D
	if setting_icon != null:
		_settings_button.icon = setting_icon
		_settings_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_settings_button.expand_icon = true
	else:
		_settings_button.text = "⚙"
		_settings_button.add_theme_font_size_override("font_size", 22)
	_settings_button.pressed.connect(_on_settings_pressed)
	top_bar.add_child(_settings_button)
	
	# ===== 第二行：法宝栏（透明背景） =====
	var relic_bg := ColorRect.new()
	relic_bg.position = Vector2(0, 54)
	relic_bg.size = Vector2(screen_w, 54)
	# 透明背景
	relic_bg.color = Color(0, 0, 0, 0)
	relic_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_container.add_child(relic_bg)
	
	_relic_container = HBoxContainer.new()
	_relic_container.position = Vector2(10, 57)
	_relic_container.size = Vector2(screen_w - 20, 48)
	_relic_container.add_theme_constant_override("separation", 4)
	_relic_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_container.add_child(_relic_container)

## 刷新所有显示
func _refresh_all() -> void:
	_is_refreshing = true
	_update_hp_display()
	_update_gold_display()
	_update_karma_display()
	_update_relic_display()
	_update_consumable_display()
	_update_deck_count()
	_is_refreshing = false

## 更新卡牌数量角标
func _update_deck_count() -> void:
	if _deck_count_label != null:
		_deck_count_label.text = str(GameManager.current_deck.size())

## 更新HP显示
func _update_hp_display() -> void:
	if _chapter_label:
		_chapter_label.text = GameManager.get_current_chapter_name()
	if _hp_label:
		_hp_label.text = "%d/%d" % [GameManager.current_hp, GameManager.max_hp]

## 更新金币显示
func _update_gold_display() -> void:
	if _gold_label:
		_gold_label.text = "%d" % GameManager.current_gold

## 更新劫数显示
func _update_karma_display() -> void:
	if _karma_label:
		_karma_label.text = "劫: %d [%s]" % [GameManager.current_karma, GameManager.get_tribulation_level()]

## 更新计时显示
func _update_timer_display() -> void:
	if _timer_label == null:
		return
	var total_sec := int(_elapsed_time)
	var minutes := total_sec / 60
	var seconds := total_sec % 60
	_timer_label.text = "%02d:%02d" % [minutes, seconds]

## 更新法宝显示（第二行）
func _update_relic_display() -> void:
	if _relic_container == null:
		return
	
	# 比对数据，无变化则跳过，避免频闪
	var new_ids: Array = []
	for entry in GameManager.current_relics:
		var rid: String = entry.get("relic_id", "") if entry is Dictionary else str(entry)
		var elv: int = entry.get("enhance_level", 0) if entry is Dictionary else 0
		new_ids.append("%s_%d" % [rid, elv])
	if new_ids == _cached_relic_ids:
		return
	_cached_relic_ids = new_ids
	
	# 立即删除旧节点（倒序），防止queue_free延迟导致频闪
	var children := _relic_container.get_children()
	for i in range(children.size() - 1, -1, -1):
		_relic_container.remove_child(children[i])
		children[i].free()
	
	for relic_entry in GameManager.current_relics:
		var relic_id: String = relic_entry.get("relic_id", "") if relic_entry is Dictionary else str(relic_entry)
		var enhance_level: int = relic_entry.get("enhance_level", 0) if relic_entry is Dictionary else 0
		var relic_data: Dictionary = DataManager.get_relic(relic_id)
		if relic_data.is_empty():
			continue
		
		var relic_btn := ColorRect.new()
		relic_btn.custom_minimum_size = Vector2(48, 48)
		relic_btn.color = Color(0, 0, 0, 0)
		relic_btn.mouse_filter = Control.MOUSE_FILTER_STOP
		
		# 使用法宝图标代替文字
		var relic_icon := TextureRect.new()
		relic_icon.custom_minimum_size = Vector2(44, 44)
		relic_icon.size = Vector2(44, 44)
		relic_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		relic_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		relic_icon.position = Vector2(2, 2)
		relic_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		
		# 尝试加载法宝图标（按 relic_id 命名）
		var icon_path := "res://ui/images/global/relic/%s.png" % relic_id
		if ResourceLoader.exists(icon_path):
			relic_icon.texture = load(icon_path)
			relic_btn.add_child(relic_icon)
		else:
			# 如果图标不存在，使用文字作为后备
			var fallback_label := Label.new()
			fallback_label.text = relic_data.get("relic_name", relic_id).left(1)
			fallback_label.add_theme_font_size_override("font_size", 18)
			fallback_label.add_theme_color_override("font_color", Color("FDCB6E"))
			fallback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			fallback_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			fallback_label.position = Vector2.ZERO
			fallback_label.size = Vector2(48, 48)
			fallback_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			relic_btn.add_child(fallback_label)
		
		# hover显示法宝详情（统一气泡框）
		var rd: Dictionary = relic_data
		var el: int = enhance_level
		relic_btn.mouse_entered.connect(func(): _show_relic_tooltip_at(relic_btn, rd, el))
		relic_btn.mouse_exited.connect(func(): _hide_relic_tooltip())
		
		_relic_container.add_child(relic_btn)

## 更新丹药显示（支持战斗中拖拽）
func _update_consumable_display() -> void:
	if _consumable_container == null:
		return
	
	# 比对数据，无变化则跳过，避免频闪
	var new_ids: Array = GameManager.current_consumables.duplicate()
	if new_ids == _cached_consumable_ids:
		return
	_cached_consumable_ids = new_ids
	
	# 立即删除旧节点（倒序），防止queue_free延迟导致频闪
	var children := _consumable_container.get_children()
	for i in range(children.size() - 1, -1, -1):
		_consumable_container.remove_child(children[i])
		children[i].free()
	
	for consumable_id in GameManager.current_consumables:
		var data: Dictionary = DataManager.get_consumable(consumable_id)
		if data.is_empty():
			continue
		var btn := ColorRect.new()
		btn.custom_minimum_size = Vector2(26, 26)
		btn.color = Color(0.15, 0.3, 0.2, 0.9)
		btn.mouse_filter = Control.MOUSE_FILTER_STOP
		
		var label := Label.new()
		label.text = data.get("consumable_name", "?").left(1)
		label.add_theme_font_size_override("font_size", 12)
		label.add_theme_color_override("font_color", Color("00B894"))
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.position = Vector2.ZERO
		label.size = Vector2(26, 26)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(label)
		
		# hover显示丹药详情
		var c_name: String = data.get("consumable_name", "")
		var c_desc: String = data.get("description", "")
		var tooltip_text := "%s\n%s\n使用方式：%s" % [c_name, c_desc, _get_consumable_use_hint(data)]
		btn.mouse_entered.connect(func():
			if not _dragging_consumable:
				_show_tooltip_at(btn, tooltip_text)
		)
		btn.mouse_exited.connect(func():
			if not _dragging_consumable:
				_hide_tooltip()
		)
		
		# 战斗场景中支持拖拽
		var cid: String = consumable_id
		var cdata: Dictionary = data
		btn.gui_input.connect(func(event: InputEvent): _on_consumable_gui_input(event, btn, cid, cdata))
		
		_consumable_container.add_child(btn)

## 获取丹药使用方式提示
func _get_consumable_use_hint(data: Dictionary) -> String:
	var use_scene: String = data.get("use_scene", "anytime")
	var effects: Array = data.get("effects", [])
	
	# 被动丹药
	if use_scene == "passive":
		return "被动触发"
	
	# 分析效果的目标类型
	var has_self_effect := false
	var has_enemy_effect := false
	for effect in effects:
		var etype: String = effect.get("type", "")
		var target_type: String = effect.get("target", "")
		# 明确指定了target的效果
		if target_type == "enemy" or target_type == "all_enemies":
			has_enemy_effect = true
		elif target_type == "self":
			has_self_effect = true
		else:
			# 根据效果类型推断目标
			match etype:
				"heal", "heal_percent", "max_hp", "battle_hp", "armor", "strength", "mana", "draw", "remove_debuffs", "revive", "card_limit":
					has_self_effect = true
				"damage", "remove_armor":
					has_enemy_effect = true
				"status":
					var status_type: String = effect.get("status_type", "")
					if status_type in ["bleed", "weak", "burn", "poison"]:
						has_enemy_effect = true
					else:
						has_self_effect = true
	
	if has_self_effect and has_enemy_effect:
		return "👤 拖拽到角色/敌人使用"
	elif has_enemy_effect:
		return "👹 拖拽到敌人使用"
	else:
		return "👤 拖拽到角色使用"

## 天劫等级对应的显示颜色
const TRIBULATION_COLORS := {
	"清净": "#55efc4",
	"微劫": "#fdcb6e",
	"小劫": "#e17055",
	"大劫": "#d63031",
	"天罚": "#6c5ce7",
}

## 劫数hover显示详细数据（富文本，不同等级不同颜色）
func _on_karma_hover_enter() -> void:
	var current_level := GameManager.get_tribulation_level()
	var karma := GameManager.current_karma
	var cur_color: String = TRIBULATION_COLORS.get(current_level, "#ffffff")
	
	var bbcode := "[b]天劫系统详情[/b]\n"
	bbcode += "──────────────\n"
	bbcode += "当前劫数：[color=%s]%d[/color]\n" % [cur_color, karma]
	bbcode += "当前等级：[color=%s]%s[/color]\n\n" % [cur_color, current_level]
	
	# 显示所有等级及其效果
	var levels := ["清净", "微劫", "小劫", "大劫", "天罚"]
	for level_name in levels:
		var threshold: int = GameManager.TRIBULATION_LEVELS[level_name]
		var buff: float = GameManager.TRIBULATION_ENEMY_BUFF[level_name]
		var buff_percent := int(buff * 100)
		var lv_color: String = TRIBULATION_COLORS.get(level_name, "#ffffff")
		var marker := " ◀" if level_name == current_level else ""
		bbcode += "[color=%s]%s[/color] (劫数≥%d) 敌人伤害+%d%%%s\n" % [lv_color, level_name, threshold, buff_percent, marker]
	
	bbcode += "\n[color=#b2bec3]劫数来源：[/color]\n"
	bbcode += "[color=#b2bec3]• 击败普通敌人 +1[/color]\n"
	bbcode += "[color=#b2bec3]• 击败精英敌人 +2[/color]\n"
	bbcode += "[color=#b2bec3]• 击败BOSS +5[/color]\n"
	bbcode += "[color=#b2bec3]• 购买卡牌/法宝 +1[/color]\n"
	bbcode += "[color=#b2bec3]• 渡劫战胜利后归零[/color]"
	
	_show_rich_tooltip_at(_karma_label, bbcode)

func _on_karma_hover_exit() -> void:
	_hide_tooltip()

## ===== 丹药拖拽系统 =====

## 消耗品拖拽输入处理
func _on_consumable_gui_input(event: InputEvent, btn: ColorRect, consumable_id: String, data: Dictionary) -> void:
	# 仅在战斗场景中允许拖拽
	var current_scene := get_tree().current_scene
	if current_scene == null or current_scene.name != "BattleScene":
		return
	
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_start_consumable_drag(btn, consumable_id, data)
			elif _dragging_consumable:
				_end_consumable_drag()

## 开始消耗品拖拽
func _start_consumable_drag(btn: ColorRect, consumable_id: String, data: Dictionary) -> void:
	_dragging_consumable = true
	_drag_consumable_id = consumable_id
	_drag_consumable_data = data
	_drag_source_btn = btn
	_hide_tooltip()
	
	# 创建跟随鼠标的拖拽图标
	_drag_icon = ColorRect.new()
	_drag_icon.size = Vector2(30, 30)
	_drag_icon.color = Color(0.15, 0.3, 0.2, 0.8)
	_drag_icon.z_index = 300
	_drag_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var drag_label := Label.new()
	drag_label.text = data.get("consumable_name", "?").left(1)
	drag_label.add_theme_font_size_override("font_size", 14)
	drag_label.add_theme_color_override("font_color", Color("00B894"))
	drag_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	drag_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	drag_label.position = Vector2.ZERO
	drag_label.size = Vector2(30, 30)
	drag_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_drag_icon.add_child(drag_label)
	
	_hud_container.add_child(_drag_icon)
	_drag_icon.global_position = _hud_container.get_global_mouse_position() - Vector2(15, 15)
	
	# 半透明原按钮
	btn.modulate = Color(1, 1, 1, 0.4)

## 结束消耗品拖拽
func _end_consumable_drag() -> void:
	if not _dragging_consumable:
		return
	
	# 获取战斗场景引用
	var battle_scene := get_tree().current_scene
	if battle_scene != null and battle_scene.name == "BattleScene":
		var mouse_pos := _hud_container.get_global_mouse_position()
		
		# 检测是否拖到角色区域
		if battle_scene.has_node("BattleArea/PlayerArea"):
			var player_area: Control = battle_scene.get_node("BattleArea/PlayerArea")
			var player_rect := Rect2(player_area.global_position, player_area.size)
			if player_rect.has_point(mouse_pos):
				if battle_scene.has_method("apply_consumable_on_player"):
					battle_scene.apply_consumable_on_player(_drag_consumable_id, _drag_consumable_data)
		
		# 检测是否拖到敌人区域
		if battle_scene.has_method("get_enemy_at_position"):
			var target_enemy: Node = battle_scene.get_enemy_at_position(mouse_pos)
			if target_enemy != null:
				if battle_scene.has_method("apply_consumable_on_enemy"):
					battle_scene.apply_consumable_on_enemy(_drag_consumable_id, _drag_consumable_data, target_enemy)
	
	# 清理拖拽状态
	if _drag_icon != null:
		_drag_icon.queue_free()
		_drag_icon = null
	
	if _drag_source_btn != null and is_instance_valid(_drag_source_btn):
		_drag_source_btn.modulate = Color(1, 1, 1, 1)
	
	_dragging_consumable = false
	_drag_consumable_id = ""
	_drag_consumable_data = {}
	_drag_source_btn = null

## 全局输入处理（拖拽释放兜底）
func _input(event: InputEvent) -> void:
	if _dragging_consumable and event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			_end_consumable_drag()

## ===== 信号回调 =====

func _on_health_changed(_hp: int, _max_hp: int) -> void:
	_update_hp_display()

func _on_gold_changed(_gold: int) -> void:
	_update_gold_display()

func _on_karma_changed(_karma: int, _level: String) -> void:
	_update_karma_display()

func _on_consumable_changed(_current_count: int, _max_count: int) -> void:
	_is_refreshing = true
	_update_consumable_display()
	_is_refreshing = false

func _on_relic_acquired(_relic_data) -> void:
	_is_refreshing = true
	_cached_relic_ids = []  # 强制清空缓存，确保刷新
	_update_relic_display()
	_is_refreshing = false

## 进入新章节时刷新章节名
func _on_next_chapter_entered(_chapter_index: int) -> void:
	if _chapter_label:
		_chapter_label.text = GameManager.get_current_chapter_name()

## 地图按钮点击 - 在地图界面回到上一界面，其他界面跳转回地图
func _on_map_button_pressed() -> void:
	var current_scene := get_tree().current_scene
	if current_scene != null and current_scene.name == "MapScene":
		# Already on map, go back to previous scene based on previous_state
		var prev_state := GameManager.previous_state
		match prev_state:
			GameManager.GameState.BATTLE:
				SceneTransition.change_scene("res://scenes/battle/BattleScene.tscn")
			GameManager.GameState.SHOP:
				SceneTransition.change_scene("res://scenes/shop/ShopScene.tscn")
			GameManager.GameState.EVENT:
				SceneTransition.change_scene("res://scenes/event/EventScene.tscn")
			GameManager.GameState.REST:
				SceneTransition.change_scene("res://scenes/rest/RestScene.tscn")
			_:
				pass  # No previous scene to go back to
	else:
		SceneTransition.change_scene("res://scenes/map/MapScene.tscn")

## 卡牌按钮点击 - 弹框查看当前卡组
func _on_deck_button_pressed() -> void:
	if _deck_popup != null:
		_close_deck_popup()
		return
	_show_deck_popup()

## 显示卡组弹框
func _show_deck_popup() -> void:
	_close_deck_popup()
	
	_deck_popup = Control.new()
	_deck_popup.set_anchors_preset(Control.PRESET_FULL_RECT)
	_deck_popup.z_index = 150
	
	# Dark overlay
	var overlay := ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0, 0.6)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_close_deck_popup()
	)
	_deck_popup.add_child(overlay)
	
	# Center panel
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	var popup_w := 820.0
	var popup_h := 600.0
	panel.custom_minimum_size = Vector2(popup_w, popup_h)
	panel.position = Vector2(-popup_w / 2.0, -popup_h / 2.0)
	
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.1, 0.1, 0.14, 0.97)
	panel_style.border_color = Color(0.5, 0.45, 0.3, 0.8)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(8)
	panel_style.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", panel_style)
	_deck_popup.add_child(panel)
	
	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 8)
	panel.add_child(main_vbox)
	
	# Top bar: title + sort buttons + close
	var top_bar := HBoxContainer.new()
	top_bar.add_theme_constant_override("separation", 10)
	main_vbox.add_child(top_bar)
	
	var title := Label.new()
	title.text = "卡组"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(0.99, 0.85, 0.5))
	top_bar.add_child(title)
	
	# Sort buttons
	var sort_type_btn := Button.new()
	sort_type_btn.text = "按类型"
	sort_type_btn.custom_minimum_size = Vector2(70, 30)
	top_bar.add_child(sort_type_btn)
	
	var sort_rarity_btn := Button.new()
	sort_rarity_btn.text = "按稀有度"
	sort_rarity_btn.custom_minimum_size = Vector2(80, 30)
	top_bar.add_child(sort_rarity_btn)
	
	var sort_cost_btn := Button.new()
	sort_cost_btn.text = "按费用"
	sort_cost_btn.custom_minimum_size = Vector2(70, 30)
	top_bar.add_child(sort_cost_btn)
	
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(spacer)
	
	var count_label := Label.new()
	count_label.add_theme_font_size_override("font_size", 14)
	count_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	top_bar.add_child(count_label)
	
	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.custom_minimum_size = Vector2(30, 30)
	close_btn.pressed.connect(func(): _close_deck_popup())
	top_bar.add_child(close_btn)
	
	# Scroll container with card grid
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	main_vbox.add_child(scroll)
	
	var card_grid := GridContainer.new()
	card_grid.columns = 4
	card_grid.add_theme_constant_override("h_separation", 12)
	card_grid.add_theme_constant_override("v_separation", 12)
	card_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(card_grid)
	
	# Sort button connections
	sort_type_btn.pressed.connect(func(): _deck_popup_sort(card_grid, count_label, "type"))
	sort_rarity_btn.pressed.connect(func(): _deck_popup_sort(card_grid, count_label, "rarity"))
	sort_cost_btn.pressed.connect(func(): _deck_popup_sort(card_grid, count_label, "cost"))
	
	add_child(_deck_popup)
	
	# Initial display
	_deck_popup_sort(card_grid, count_label, "type")

## Sort and display cards in deck popup
func _deck_popup_sort(card_grid: GridContainer, count_label: Label, sort_by: String) -> void:
	# Clear old cards
	var children := card_grid.get_children()
	for i in range(children.size() - 1, -1, -1):
		card_grid.remove_child(children[i])
		children[i].free()
	
	# Gather deck data
	var deck_cards: Array = []
	for entry in GameManager.current_deck:
		var card_id: String = entry.get("card_id", "") if entry is Dictionary else str(entry)
		var star_level: int = entry.get("star_level", 1) if entry is Dictionary else 1
		var card_data := DataManager.get_card(card_id)
		if not card_data.is_empty():
			var display_data: Dictionary = card_data.duplicate(true)
			display_data["star_level"] = star_level
			deck_cards.append(display_data)
	
	# Sort
	match sort_by:
		"type":
			deck_cards.sort_custom(func(a, b):
				var a_type = a.get("card_type", "")
				var b_type = b.get("card_type", "")
				var a_str: String = ",".join(a_type) if a_type is Array else str(a_type)
				var b_str: String = ",".join(b_type) if b_type is Array else str(b_type)
				return a_str < b_str
			)
		"rarity":
			var rarity_order := {"common": 0, "uncommon": 1, "rare": 2, "legendary": 3}
			deck_cards.sort_custom(func(a, b):
				return rarity_order.get(a.get("rarity", ""), 0) > rarity_order.get(b.get("rarity", ""), 0)
			)
		"cost":
			deck_cards.sort_custom(func(a, b): return CardData.get_card_energy_cost(a) < CardData.get_card_energy_cost(b))
	
	# Display cards
	for card_data in deck_cards:
		var card_item := _create_deck_card_display(card_data)
		card_grid.add_child(card_item)
	
	count_label.text = "卡组: %d张" % deck_cards.size()

## Preloaded Card scene for deck popup display
const CARD_SCENE_PATH := "res://scenes/battle/Card.tscn"
const DECK_POPUP_CARD_SCALE := 1.0

## Create a card display item for deck popup using battle Card.tscn
func _create_deck_card_display(card_data: Dictionary) -> Control:
	var star_level: int = card_data.get("star_level", 1)
	
	# Wrapper container to apply scale and clip
	var wrapper := Control.new()
	var scaled_w := int(180 * DECK_POPUP_CARD_SCALE)
	var scaled_h := int(270 * DECK_POPUP_CARD_SCALE)
	wrapper.custom_minimum_size = Vector2(scaled_w, scaled_h)
	wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrapper.clip_contents = true
	
	# Instantiate the actual Card scene
	var card_scene := load(CARD_SCENE_PATH) as PackedScene
	if card_scene == null:
		# Fallback: simple label if scene not found
		var fallback := Label.new()
		fallback.text = card_data.get("card_name", "???")
		wrapper.add_child(fallback)
		return wrapper
	
	var card_instance: Control = card_scene.instantiate()
	# Scale down to fit popup grid
	card_instance.scale = Vector2(DECK_POPUP_CARD_SCALE, DECK_POPUP_CARD_SCALE)
	# Disable all mouse interaction (view-only)
	card_instance.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Setup card data
	card_instance.setup(card_data, star_level)
	# Disable dragging and interaction
	card_instance.is_playable = false
	
	wrapper.add_child(card_instance)
	
	# Recursively disable mouse on all children to prevent hover/drag
	_disable_mouse_recursive(card_instance)
	
	return wrapper

## Recursively disable mouse filter on all children
func _disable_mouse_recursive(node: Node) -> void:
	if node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_disable_mouse_recursive(child)

## 关闭卡组弹框
func _close_deck_popup() -> void:
	if _deck_popup != null:
		_deck_popup.queue_free()
		_deck_popup = null

## 设置按钮
func _on_settings_pressed() -> void:
	if _settings_popup != null:
		_settings_popup.queue_free()
		_settings_popup = null
		_remove_settings_overlay()
		return
	
	# 创建透明遮罩层，点击其他区域关闭弹窗
	var overlay := ColorRect.new()
	overlay.name = "SettingsOverlay"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0, 0.01)  # 几乎透明，但能接收点击
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_close_settings_popup()
	)
	_hud_container.add_child(overlay)
	
	_settings_popup = PanelContainer.new()
	var popup_x := get_viewport().get_visible_rect().size.x - 180.0
	_settings_popup.position = Vector2(popup_x, 58)
	_settings_popup.z_index = 200
	
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.17, 0.2, 0.95)
	style.border_color = Color(0.4, 0.4, 0.4, 1.0)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(10)
	_settings_popup.add_theme_stylebox_override("panel", style)
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	
	# 设置（音量、全屏等）
	var settings_btn := Button.new()
	settings_btn.text = "⚙ 设置"
	settings_btn.custom_minimum_size = Vector2(150, 35)
	settings_btn.pressed.connect(func():
		_close_settings_popup()
		show_settings_panel()
	)
	vbox.add_child(settings_btn)
	
	# 战斗场景特有选项：认输和重打
	var current_scene := get_tree().current_scene
	if current_scene != null and current_scene.name == "BattleScene":
		var surrender_btn := Button.new()
		surrender_btn.text = "🏳️ 认输"
		surrender_btn.custom_minimum_size = Vector2(150, 35)
		surrender_btn.pressed.connect(func():
			_close_settings_popup()
			SceneTransition.change_scene("res://scenes/game_over/GameOverScene.tscn")
		)
		vbox.add_child(surrender_btn)
		
		var restart_btn := Button.new()
		restart_btn.text = "🔄 重打"
		restart_btn.custom_minimum_size = Vector2(150, 35)
		restart_btn.pressed.connect(func():
			_close_settings_popup()
			# 通知战斗场景重打
			if current_scene.has_method("restart_battle"):
				current_scene.restart_battle()
			else:
				SceneTransition.change_scene("res://scenes/battle/BattleScene.tscn")
		)
		vbox.add_child(restart_btn)
	
	# 返回主菜单
	var menu_btn := Button.new()
	menu_btn.text = "🏠 返回主菜单"
	menu_btn.custom_minimum_size = Vector2(150, 35)
	menu_btn.pressed.connect(func():
		# 如果在战斗场景，先保存战斗初始状态到存档
		var cs := get_tree().current_scene
		if cs != null and cs.name == "BattleScene":
			# 恢复战斗初始数据后再保存，这样继续游戏时能回到战斗初始状态
			if cs.has_method("save_battle_state_for_continue"):
				cs.save_battle_state_for_continue()
			SaveManager.save_game()
		_close_settings_popup()
		SceneTransition.change_scene("res://scenes/main_menu/MainMenuScene.tscn")
	)
	vbox.add_child(menu_btn)
	
	_settings_popup.add_child(vbox)
	_hud_container.add_child(_settings_popup)

## 关闭设置弹窗
func _close_settings_popup() -> void:
	if _settings_popup != null:
		_settings_popup.queue_free()
		_settings_popup = null
	_remove_settings_overlay()

## 移除设置遮罩层
func _remove_settings_overlay() -> void:
	if _hud_container == null:
		return
	var overlay := _hud_container.get_node_or_null("SettingsOverlay")
	if overlay != null:
		overlay.queue_free()

## 显示设置面板（音量、全屏等）
func show_settings_panel() -> void:
	if _settings_panel != null:
		_settings_panel.queue_free()
		_settings_panel = null
		return
	
	_settings_panel = Control.new()
	_settings_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_settings_panel.z_index = 150
	
	# Dark overlay
	var overlay := ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0, 0.5)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_close_settings_panel()
	)
	_settings_panel.add_child(overlay)
	
	# Center panel
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(400, 0)
	panel.position = Vector2(-200, -160)
	
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.12, 0.14, 0.18, 0.95)
	panel_style.border_color = Color(0.5, 0.45, 0.3, 0.8)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(8)
	panel_style.set_content_margin_all(20)
	panel.add_theme_stylebox_override("panel", panel_style)
	_settings_panel.add_child(panel)
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	panel.add_child(vbox)
	
	# Title
	var title := Label.new()
	title.text = "设置"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.99, 0.8, 0.43))
	vbox.add_child(title)
	
	# BGM volume
	var bgm_box := HBoxContainer.new()
	var bgm_label := Label.new()
	bgm_label.text = "音乐音量"
	bgm_label.custom_minimum_size = Vector2(100, 0)
	bgm_box.add_child(bgm_label)
	
	var bgm_slider := HSlider.new()
	bgm_slider.min_value = 0.0
	bgm_slider.max_value = 1.0
	bgm_slider.step = 0.05
	bgm_slider.value = AudioManager.bgm_volume
	bgm_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var bgm_grabber_style := StyleBoxFlat.new()
	bgm_grabber_style.bg_color = Color(0, 1, 0.6, 1)
	bgm_grabber_style.set_corner_radius_all(4)
	bgm_slider.add_theme_stylebox_override("grabber_area", bgm_grabber_style)
	bgm_slider.value_changed.connect(func(value: float):
		AudioManager.bgm_volume = value
		AudioManager.save_volume_settings()
	)
	bgm_box.add_child(bgm_slider)
	vbox.add_child(bgm_box)
	
	# SFX volume
	var sfx_box := HBoxContainer.new()
	var sfx_label := Label.new()
	sfx_label.text = "音效音量"
	sfx_label.custom_minimum_size = Vector2(100, 0)
	sfx_box.add_child(sfx_label)
	
	var sfx_slider := HSlider.new()
	sfx_slider.min_value = 0.0
	sfx_slider.max_value = 1.0
	sfx_slider.step = 0.05
	sfx_slider.value = AudioManager.sfx_volume
	sfx_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sfx_grabber_style := StyleBoxFlat.new()
	sfx_grabber_style.bg_color = Color(0, 1, 0.6, 1)
	sfx_grabber_style.set_corner_radius_all(4)
	sfx_slider.add_theme_stylebox_override("grabber_area", sfx_grabber_style)
	sfx_slider.value_changed.connect(func(value: float):
		AudioManager.sfx_volume = value
		AudioManager.save_volume_settings()
	)
	sfx_box.add_child(sfx_slider)
	vbox.add_child(sfx_box)
	
	# Fullscreen toggle
	var fullscreen_check := CheckButton.new()
	fullscreen_check.text = "全屏模式"
	fullscreen_check.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	fullscreen_check.toggled.connect(func(is_fullscreen: bool):
		if is_fullscreen:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	)
	vbox.add_child(fullscreen_check)
	
	# Developer mode toggle
	var dev_check := CheckButton.new()
	dev_check.text = "开发者模式"
	dev_check.button_pressed = GameManager.dev_mode
	dev_check.toggled.connect(func(enabled: bool):
		GameManager.dev_mode = enabled
		EventBus.dev_mode_changed.emit(enabled)
		if enabled:
			print("[开发者模式] 已开启")
		else:
			print("[开发者模式] 已关闭")
	)
	vbox.add_child(dev_check)
	
	# Close button
	var close_btn := Button.new()
	close_btn.text = "关闭"
	close_btn.custom_minimum_size = Vector2(0, 40)
	close_btn.pressed.connect(func(): _close_settings_panel())
	vbox.add_child(close_btn)
	
	# Add to self (CanvasLayer) instead of _hud_container, so it works even in HIDDEN_SCENES
	add_child(_settings_panel)

## 关闭设置面板
func _close_settings_panel() -> void:
	if _settings_panel != null:
		_settings_panel.queue_free()
		_settings_panel = null

## 获取HUD总高度（供其他场景计算布局用）
func get_hud_height() -> float:
	# 第一行54px + 第二行法宝栏54px = 108px
	return 108.0

## 显示富文本tooltip（支持BBCode，默认右侧显示，超出屏幕则自动调整）
func _show_rich_tooltip_at(target: Control, bbcode: String) -> void:
	_hide_tooltip()
	
	_tooltip = PanelContainer.new()
	_tooltip.z_index = 200
	
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.15, 0.95)
	style.border_color = Color(0.5, 0.5, 0.5, 0.8)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(8)
	_tooltip.add_theme_stylebox_override("panel", style)
	
	var rich_label := RichTextLabel.new()
	rich_label.bbcode_enabled = true
	rich_label.text = bbcode
	rich_label.add_theme_font_size_override("normal_font_size", 12)
	rich_label.add_theme_font_size_override("bold_font_size", 13)
	rich_label.fit_content = true
	rich_label.scroll_active = false
	rich_label.custom_minimum_size = Vector2(200, 0)
	rich_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip.add_child(rich_label)
	
	_hud_container.add_child(_tooltip)
	
	# Wait one frame for size calculation then position
	await get_tree().process_frame
	if _tooltip == null or not is_instance_valid(_tooltip):
		return
	
	var screen_size := _hud_container.get_viewport_rect().size
	var tooltip_size := _tooltip.size
	var target_pos := target.global_position
	var target_size := target.size
	
	var pos_x := target_pos.x + target_size.x + 8
	var pos_y := target_pos.y
	
	if pos_x + tooltip_size.x > screen_size.x:
		pos_x = target_pos.x - tooltip_size.x - 8
	if pos_x < 0:
		pos_x = 4
	if pos_y + tooltip_size.y > screen_size.y:
		pos_y = screen_size.y - tooltip_size.y - 4
	if pos_y < 0:
		pos_y = 4
	
	_tooltip.position = Vector2(pos_x, pos_y)

## 显示tooltip（默认右侧显示，超出屏幕则自动调整）
func _show_tooltip_at(target: Control, text: String) -> void:
	_hide_tooltip()
	
	_tooltip = PanelContainer.new()
	_tooltip.z_index = 200
	
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.15, 0.95)
	style.border_color = Color(0.5, 0.5, 0.5, 0.8)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(8)
	_tooltip.add_theme_stylebox_override("panel", style)
	
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 12)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.custom_minimum_size = Vector2(180, 0)
	_tooltip.add_child(label)
	
	_hud_container.add_child(_tooltip)
	
	# 等一帧让PanelContainer计算出实际尺寸后再定位
	await get_tree().process_frame
	if _tooltip == null or not is_instance_valid(_tooltip):
		return
	
	# 获取屏幕尺寸
	var screen_size := _hud_container.get_viewport_rect().size
	var tooltip_size := _tooltip.size
	var target_pos := target.global_position
	var target_size := target.size
	
	# 默认定位：目标右侧
	var pos_x := target_pos.x + target_size.x + 8
	var pos_y := target_pos.y
	
	# 右侧超出屏幕 → 改为左侧
	if pos_x + tooltip_size.x > screen_size.x:
		pos_x = target_pos.x - tooltip_size.x - 8
	
	# 左侧也超出 → 贴左边缘
	if pos_x < 0:
		pos_x = 4
	
	# 下方超出屏幕 → 上移
	if pos_y + tooltip_size.y > screen_size.y:
		pos_y = screen_size.y - tooltip_size.y - 4
	
	# 上方超出 → 贴顶
	if pos_y < 0:
		pos_y = 4
	
	_tooltip.position = Vector2(pos_x, pos_y)

## 隐藏tooltip
func _hide_tooltip() -> void:
	if _tooltip != null:
		_tooltip.queue_free()
		_tooltip = null

## 显示法宝专用tooltip（统一格式）
func _show_relic_tooltip_at(target: Control, relic_data: Dictionary, enhance_level: int = 0) -> void:
	_hide_relic_tooltip()
	
	_relic_tooltip = RelicTooltip.build_tooltip(relic_data, enhance_level)
	_hud_container.add_child(_relic_tooltip)
	
	# Wait one frame for size calculation
	await get_tree().process_frame
	if _relic_tooltip == null or not is_instance_valid(_relic_tooltip):
		return
	
	var screen_size := _hud_container.get_viewport_rect().size
	RelicTooltip.position_tooltip(_relic_tooltip, target, screen_size)

## 隐藏法宝tooltip
func _hide_relic_tooltip() -> void:
	if _relic_tooltip != null:
		_relic_tooltip.queue_free()
		_relic_tooltip = null

## 更新角色头像纹理
func _update_avatar_texture() -> void:
	if _avatar_btn == null:
		return
	var char_id := GameManager.current_character_id
	if char_id == "":
		_avatar_btn.visible = false
		return
	var avatar_path := "res://ui/images/global/avatar/%s.jpg" % char_id
	if ResourceLoader.exists(avatar_path):
		_avatar_btn.texture = load(avatar_path)
		_avatar_btn.visible = true
	else:
		_avatar_btn.visible = false

## 角色头像hover进入 - 显示气泡框
func _on_avatar_hover_enter() -> void:
	_show_avatar_bubble()

## 角色头像hover离开 - 隐藏气泡框
func _on_avatar_hover_exit() -> void:
	_hide_avatar_bubble()

## 角色头像点击 - 切换气泡框显示
func _on_avatar_clicked(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _avatar_bubble != null:
			_hide_avatar_bubble()
		else:
			_show_avatar_bubble()

## 显示角色信息气泡框
func _show_avatar_bubble() -> void:
	_hide_avatar_bubble()
	
	var char_id := GameManager.current_character_id
	if char_id == "":
		return
	var char_data: Dictionary = DataManager.get_character(char_id)
	if char_data.is_empty():
		return
	
	var char_name: String = char_data.get("character_name", "")
	
	# Gather statistics
	var games_played: int = SaveManager.get_stat("games_played_%s" % char_id, 0)
	var total_play_time: int = SaveManager.get_stat("play_time_%s" % char_id, 0)
	var current_nodes: int = GameManager.get_nodes_cleared()
	var best_nodes: int = SaveManager.get_stat("best_nodes_%s" % char_id, 0)
	var gold_earned: int = GameManager.total_gold_earned
	var relic_count: int = GameManager.current_relics.size()
	var consumable_count: int = GameManager.current_consumables.size()
	
	# Format total play time (hours:minutes:seconds)
	var total_hours: int = total_play_time / 3600
	var total_minutes: int = (total_play_time % 3600) / 60
	var total_seconds: int = total_play_time % 60
	var time_str: String
	if total_hours > 0:
		time_str = "%d时%02d分%02d秒" % [total_hours, total_minutes, total_seconds]
	else:
		time_str = "%d分%02d秒" % [total_minutes, total_seconds]
	
	_avatar_bubble = PanelContainer.new()
	_avatar_bubble.z_index = 200
	
	# 气泡框样式
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.15, 0.95)
	style.border_color = Color(0.5, 0.45, 0.3, 0.8)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(10)
	_avatar_bubble.add_theme_stylebox_override("panel", style)
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	
	# 角色姓名
	var name_label := Label.new()
	name_label.text = char_name
	name_label.add_theme_font_size_override("font_size", 15)
	name_label.add_theme_color_override("font_color", Color(0.99, 0.85, 0.5))
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(name_label)
	
	# 分隔线
	var separator := HSeparator.new()
	separator.add_theme_constant_override("separation", 2)
	vbox.add_child(separator)
	
	# Statistics entries
	var stat_entries: Array[Array] = [
		["游戏次数", str(games_played)],
		["累计时间", time_str],
		["当前通关", str(current_nodes)],
		["最高通关", str(best_nodes)],
		["获取金币", str(gold_earned)],
		["法宝数量", str(relic_count)],
		["丹药数量", str(consumable_count)],
	]
	
	for entry in stat_entries:
		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 8)
		hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		
		var key_label := Label.new()
		key_label.text = entry[0]
		key_label.add_theme_font_size_override("font_size", 12)
		key_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		key_label.custom_minimum_size = Vector2(65, 0)
		key_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hbox.add_child(key_label)
		
		var val_label := Label.new()
		val_label.text = entry[1]
		val_label.add_theme_font_size_override("font_size", 12)
		val_label.add_theme_color_override("font_color", Color(0.95, 0.9, 0.75))
		val_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hbox.add_child(val_label)
		
		vbox.add_child(hbox)
	
	_avatar_bubble.add_child(vbox)
	_hud_container.add_child(_avatar_bubble)
	
	# 等一帧让PanelContainer计算出实际尺寸后再定位
	await get_tree().process_frame
	if _avatar_bubble == null or not is_instance_valid(_avatar_bubble):
		return
	
	# 定位在头像下方
	var screen_size := _hud_container.get_viewport_rect().size
	var bubble_size := _avatar_bubble.size
	var avatar_pos := _avatar_btn.global_position
	var avatar_size := _avatar_btn.size
	
	var pos_x := avatar_pos.x
	var pos_y := avatar_pos.y + avatar_size.y + 6
	
	# 右侧超出屏幕则左移
	if pos_x + bubble_size.x > screen_size.x:
		pos_x = screen_size.x - bubble_size.x - 4
	
	# 下方超出屏幕则显示在上方
	if pos_y + bubble_size.y > screen_size.y:
		pos_y = avatar_pos.y - bubble_size.y - 6
	
	_avatar_bubble.position = Vector2(pos_x, pos_y)

## 隐藏角色信息气泡框
func _hide_avatar_bubble() -> void:
	if _avatar_bubble != null:
		_avatar_bubble.queue_free()
		_avatar_bubble = null

## 开发者模式：金币连点回调（连点5次增加100金币）
func _on_gold_label_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		GameManager.dev_gold_click()

## 开发者模式：劫数连点回调（连点5次增加10点劫数）
func _on_karma_label_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		GameManager.dev_karma_click()
