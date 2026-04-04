## 全局HUD - 在除了主菜单和角色选择界面外的所有场景中显示状态栏、法宝和设置按钮
extends CanvasLayer

## 不显示HUD的场景列表
const HIDDEN_SCENES := [
	"MainMenuScene",
	"CharacterSelectScene",
]

var _hud_container: Control = null
var _chapter_label: Label = null
var _hp_icon: TextureRect = null
var _hp_label: Label = null
var _gold_icon: TextureRect = null
var _gold_label: Label = null
var _mana_container: HBoxContainer = null
var _mana_label: Label = null
var _karma_label: Label = null
var _relic_container: HBoxContainer = null
var _consumable_container: HBoxContainer = null
var _timer_label: Label = null
var _settings_button: Button = null
var _settings_popup: PanelContainer = null
var _tooltip: PanelContainer = null
var _avatar_bubble: PanelContainer = null
var _avatar_btn: TextureRect = null
var _is_refreshing: bool = false

## 缓存当前显示的数据，避免不必要的重建导致频闪
var _cached_relic_ids: Array = []
var _cached_consumable_ids: Array = []

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
	EventBus.mana_changed.connect(_on_mana_changed)
	EventBus.karma_changed.connect(_on_karma_changed)
	EventBus.consumable_capacity_changed.connect(_on_consumable_changed)
	EventBus.relic_acquired.connect(_on_relic_acquired)
	
	# 初始隐藏（主菜单）
	_update_visibility()

func _process(delta: float) -> void:
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
	var _init_chapter_name := ""
	if GameManager.current_chapter < GameManager.CHAPTER_NAMES.size():
		_init_chapter_name = GameManager.CHAPTER_NAMES[GameManager.current_chapter]
	_chapter_label.text = _init_chapter_name
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
	
	# 法力值（仅战斗场景可见，图标+数值）
	_mana_container = HBoxContainer.new()
	_mana_container.add_theme_constant_override("separation", 4)
	_mana_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mana_container.visible = false
	
	var mana_icon := TextureRect.new()
	mana_icon.custom_minimum_size = Vector2(16, 16)
	mana_icon.size = Vector2(16, 16)
	mana_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mana_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mana_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var power_path := "res://ui/images/global/power.png"
	if ResourceLoader.exists(power_path):
		mana_icon.texture = load(power_path)
	_mana_container.add_child(mana_icon)
	
	_mana_label = Label.new()
	_mana_label.text = "%d/%d" % [GameManager.current_mana, GameManager.max_mana]
	_mana_label.add_theme_font_size_override("font_size", 20)
	_mana_label.add_theme_color_override("font_color", Color("74B9FF"))
	_mana_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mana_container.add_child(_mana_label)
	
	top_bar.add_child(_mana_container)
	
	# 劫数
	_karma_label = Label.new()
	_karma_label.text = "劫: %d [%s]" % [GameManager.current_karma, GameManager.get_tribulation_level()]
	_karma_label.add_theme_font_size_override("font_size", 20)
	_karma_label.add_theme_color_override("font_color", Color("A29BFE"))
	_karma_label.mouse_filter = Control.MOUSE_FILTER_STOP
	_karma_label.mouse_entered.connect(_on_karma_hover_enter)
	_karma_label.mouse_exited.connect(_on_karma_hover_exit)
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
	
	# 设置按钮
	_settings_button = Button.new()
	_settings_button.text = "⚙"
	_settings_button.custom_minimum_size = Vector2(40, 40)
	_settings_button.add_theme_font_size_override("font_size", 22)
	_settings_button.pressed.connect(_on_settings_pressed)
	top_bar.add_child(_settings_button)
	
	# ===== 第二行：法宝栏（透明背景） =====
	var relic_bg := ColorRect.new()
	relic_bg.position = Vector2(0, 54)
	relic_bg.size = Vector2(screen_w, 30)
	# 透明背景
	relic_bg.color = Color(0, 0, 0, 0)
	relic_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_container.add_child(relic_bg)
	
	_relic_container = HBoxContainer.new()
	_relic_container.position = Vector2(10, 56)
	_relic_container.size = Vector2(screen_w - 20, 26)
	_relic_container.add_theme_constant_override("separation", 4)
	_relic_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_container.add_child(_relic_container)

## 刷新所有显示
func _refresh_all() -> void:
	_is_refreshing = true
	_update_hp_display()
	_update_gold_display()
	_update_mana_display()
	_update_karma_display()
	_update_relic_display()
	_update_consumable_display()
	_is_refreshing = false

## 更新HP显示
func _update_hp_display() -> void:
	if _chapter_label:
		var chapter_name := ""
		if GameManager.current_chapter < GameManager.CHAPTER_NAMES.size():
			chapter_name = GameManager.CHAPTER_NAMES[GameManager.current_chapter]
		_chapter_label.text = chapter_name
	if _hp_label:
		_hp_label.text = "%d/%d" % [GameManager.current_hp, GameManager.max_hp]

## 更新金币显示
func _update_gold_display() -> void:
	if _gold_label:
		_gold_label.text = "%d" % GameManager.current_gold

## 更新法力值显示（仅战斗场景可见）
func _update_mana_display() -> void:
	if _mana_container == null or _mana_label == null:
		return
	var current_scene := get_tree().current_scene
	var in_battle: bool = current_scene != null and current_scene.name == "BattleScene"
	_mana_container.visible = in_battle
	if in_battle:
		_mana_label.text = "%d/%d" % [GameManager.current_mana, GameManager.max_mana]

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
		var slv: int = entry.get("star_level", 1) if entry is Dictionary else 1
		new_ids.append("%s_%d" % [rid, slv])
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
		var star_level: int = relic_entry.get("star_level", 1) if relic_entry is Dictionary else 1
		var relic_data: Dictionary = DataManager.get_relic(relic_id)
		if relic_data.is_empty():
			continue
		
		var relic_btn := ColorRect.new()
		relic_btn.custom_minimum_size = Vector2(24, 24)
		relic_btn.color = Color(0.3, 0.25, 0.1, 0.9)
		relic_btn.mouse_filter = Control.MOUSE_FILTER_STOP
		
		var relic_label := Label.new()
		relic_label.text = relic_data.get("relic_name", relic_id).left(1)
		relic_label.add_theme_font_size_override("font_size", 11)
		relic_label.add_theme_color_override("font_color", Color("FDCB6E"))
		relic_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		relic_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		relic_label.position = Vector2.ZERO
		relic_label.size = Vector2(24, 24)
		relic_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		relic_btn.add_child(relic_label)
		
		# hover显示详情
		var relic_name: String = relic_data.get("relic_name", "")
		var star_text := ""
		match star_level:
			1: star_text = "★☆☆"
			2: star_text = "★★☆"
			3: star_text = "★★★"
		var relic_desc: String = relic_data.get("description", "")
		var tooltip_text := "%s %s\n%s" % [relic_name, star_text, relic_desc]
		relic_btn.mouse_entered.connect(func(): _show_tooltip_at(relic_btn, tooltip_text))
		relic_btn.mouse_exited.connect(func(): _hide_tooltip())
		
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
					if status_type in ["vulnerable", "weak", "burn", "poison"]:
						has_enemy_effect = true
					else:
						has_self_effect = true
	
	if has_self_effect and has_enemy_effect:
		return "👤 拖拽到角色/敌人使用"
	elif has_enemy_effect:
		return "👹 拖拽到敌人使用"
	else:
		return "👤 拖拽到角色使用"

## 劫数hover显示详细数据
func _on_karma_hover_enter() -> void:
	var current_level := GameManager.get_tribulation_level()
	var karma := GameManager.current_karma
	
	var text := "天劫系统详情\n"
	text += "──────────────\n"
	text += "当前劫数：%d\n" % karma
	text += "当前等级：%s\n\n" % current_level
	
	# 显示所有等级及其效果
	var levels := ["\u6e05\u51c0", "\u5fae\u52ab", "\u5c0f\u52ab", "\u5927\u52ab", "\u5929\u7f5a"]
	for level_name in levels:
		var threshold: int = GameManager.TRIBULATION_LEVELS[level_name]
		var buff: float = GameManager.TRIBULATION_ENEMY_BUFF[level_name]
		var buff_percent := int(buff * 100)
		var marker := " ◀" if level_name == current_level else ""
		text += "%s (劫数≥%d) 敌人+%d%%%s\n" % [level_name, threshold, buff_percent, marker]
	
	text += "\n劫数来源：\n"
	text += "• 购买卡牌/法宝 +1\n"
	text += "• 完美通关(未受伤) +2\n"
	text += "• 渡劫战胜利后归零"
	
	_show_tooltip_at(_karma_label, text)

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

func _on_mana_changed(_current_mana: int, _max_mana: int) -> void:
	_update_mana_display()

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
	
	# 查看卡组
	var deck_btn := Button.new()
	deck_btn.text = "📋 查看卡组"
	deck_btn.custom_minimum_size = Vector2(150, 35)
	deck_btn.pressed.connect(func():
		_close_settings_popup()
		SceneTransition.change_scene("res://scenes/deck_view/DeckViewScene.tscn")
	)
	vbox.add_child(deck_btn)
	
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

## 获取HUD总高度（供其他场景计算布局用）
func get_hud_height() -> float:
	# 第一行54px + 第二行法宝栏30px = 84px
	return 84.0

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
	var passive_name: String = char_data.get("passive_name", "")
	var passive_desc: String = char_data.get("passive_description", "")
	
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
	vbox.add_theme_constant_override("separation", 6)
	
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
	
	# 被动技能名称
	var passive_title := Label.new()
	passive_title.text = "被动：%s" % passive_name
	passive_title.add_theme_font_size_override("font_size", 13)
	passive_title.add_theme_color_override("font_color", Color(0.9, 0.8, 0.5))
	vbox.add_child(passive_title)
	
	# 被动技能描述
	var desc_label := Label.new()
	desc_label.text = passive_desc
	desc_label.add_theme_font_size_override("font_size", 12)
	desc_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc_label.custom_minimum_size = Vector2(180, 0)
	vbox.add_child(desc_label)
	
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
