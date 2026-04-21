## 角色选择场景脚本（重构版）
## 参考：大立绘背景 + 左侧信息面板 + 底部缩略图栏
extends Control

const CHARACTER_IDS: Array[String] = ["sun_wukong", "zhu_bajie", "sha_wujing", "tang_seng"]

## 缩略图尺寸
const THUMB_SIZE := Vector2(90, 120)
## 缩略图选中边框颜色
const THUMB_SELECTED_COLOR := Color(1.0, 0.78, 0.25, 1.0)
## 缩略图默认边框颜色
const THUMB_DEFAULT_COLOR := Color(0.3, 0.25, 0.2, 0.0)
## 背景淡入时长
const BG_FADE_DURATION := 0.35
## 缩略图选中缩放
const THUMB_SELECTED_SCALE := Vector2(1.15, 1.15)
## 缩略图默认缩放
const THUMB_DEFAULT_SCALE := Vector2(1.0, 1.0)
## 呼吸动画 - 边框亮度最小倍数（低谷）
const BREATH_MIN_INTENSITY := 0.55
## 呼吸动画 - 边框亮度最大倍数（高峰）
const BREATH_MAX_INTENSITY := 1.15
## 呼吸动画 - 阴影最小尺寸
const BREATH_SHADOW_MIN := 6.0
## 呼吸动画 - 阴影最大尺寸
const BREATH_SHADOW_MAX := 16.0
## 呼吸动画 - 单次（半周期）时长
const BREATH_DURATION := 0.9

var _thumb_cards: Array[Panel] = []
var _selected_index: int = -1
var _bg_tween: Tween = null
## 选中缩略图呼吸动画 Tween
var _breath_tween: Tween = null

@onready var bg_texture: TextureRect = $BackgroundTextureRect
@onready var bg_fade_texture: TextureRect = $BackgroundFadeRect
@onready var info_panel: Panel = $InfoPanel
@onready var info_content: VBoxContainer = $InfoPanel/InfoContent
@onready var thumbnail_bar: HBoxContainer = $ThumbnailBar
@onready var prev_button: Button = $ThumbnailBar/PrevButton
@onready var next_button: Button = $ThumbnailBar/NextButton
@onready var start_button: Button = $InfoPanel/StartButton
@onready var back_button: Button = $BackButton

func _ready() -> void:
	GameManager.change_state(GameManager.GameState.CHARACTER_SELECT)
	_setup_static_styles()
	start_button.disabled = true
	start_button.pressed.connect(_on_start_pressed)
	back_button.pressed.connect(_on_back_pressed)
	prev_button.pressed.connect(_on_prev_pressed)
	next_button.pressed.connect(_on_next_pressed)
	_create_thumbnails()
	# 默认选中第一个可用角色
	var default_index := 0
	for i in range(CHARACTER_IDS.size()):
		var cid := CHARACTER_IDS[i]
		if SaveManager.is_character_unlocked(cid) or GameManager.dev_mode:
			default_index = i
			break
	_on_thumb_selected(default_index, true)
	EventBus.dev_mode_changed.connect(_on_dev_mode_changed)

func _exit_tree() -> void:
	_stop_breath_animation()
	if EventBus.dev_mode_changed.is_connected(_on_dev_mode_changed):
		EventBus.dev_mode_changed.disconnect(_on_dev_mode_changed)

## dev_mode 切换时刷新缩略图解锁态
func _on_dev_mode_changed(_enabled: bool) -> void:
	_create_thumbnails()
	_selected_index = -1
	start_button.disabled = true
	for i in range(CHARACTER_IDS.size()):
		var cid := CHARACTER_IDS[i]
		if SaveManager.is_character_unlocked(cid) or GameManager.dev_mode:
			_on_thumb_selected(i, true)
			break

## 给信息面板与按钮配置静态样式
func _setup_static_styles() -> void:
	# 信息面板：半透明深色 + 金色细边 + 圆角
	var info_style := StyleBoxFlat.new()
	info_style.bg_color = Color(0.08, 0.06, 0.05, 0.60)
	info_style.corner_radius_top_left = 14
	info_style.corner_radius_top_right = 14
	info_style.corner_radius_bottom_left = 14
	info_style.corner_radius_bottom_right = 14
	#info_style.border_color = Color(0.78, 0.55, 0.22, 0.85)
	#info_style.border_width_left = 2
	#info_style.border_width_right = 2
	#info_style.border_width_top = 2
	#info_style.border_width_bottom = 2
	info_style.shadow_color = Color(0, 0, 0, 0.55)
	info_style.shadow_size = 4
	info_panel.add_theme_stylebox_override("panel", info_style)

## 创建底部缩略图
func _create_thumbnails() -> void:
	# 先清理旧的缩略图，但保留 Prev/Next 两个切换按钮
	for child in thumbnail_bar.get_children():
		if child == prev_button or child == next_button:
			continue
		child.queue_free()
	_thumb_cards.clear()
	for i in range(CHARACTER_IDS.size()):
		var char_id := CHARACTER_IDS[i]
		var char_data: Dictionary = DataManager.get_character(char_id)
		if char_data.is_empty():
			continue
		var thumb := _create_thumb(char_id, i)
		thumbnail_bar.add_child(thumb)
		_thumb_cards.append(thumb)
	# 保证顺序：PrevButton -> 缩略图们 -> NextButton
	thumbnail_bar.move_child(prev_button, 0)
	thumbnail_bar.move_child(next_button, thumbnail_bar.get_child_count() - 1)

## 创建单个缩略图卡
func _create_thumb(char_id: String, index: int) -> Panel:
	var thumb := Panel.new()
	thumb.custom_minimum_size = THUMB_SIZE
	thumb.clip_contents = true
	thumb.mouse_filter = Control.MOUSE_FILTER_STOP
	thumb.pivot_offset = THUMB_SIZE / 2.0

	var is_unlocked := SaveManager.is_character_unlocked(char_id) or GameManager.dev_mode

	# 样式边框
	var style := _make_thumb_style(false)
	thumb.add_theme_stylebox_override("panel", style)
	thumb.set_meta("style", style)

	# 缩略图
	var mini_path := _resolve_mini_path(char_id)
	var pic := TextureRect.new()
	pic.set_anchors_preset(Control.PRESET_FULL_RECT)
	pic.offset_left = 3
	pic.offset_top = 3
	pic.offset_right = -3
	pic.offset_bottom = -3
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	if mini_path != "" and ResourceLoader.exists(mini_path):
		pic.texture = load(mini_path)
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not is_unlocked:
		pic.modulate = Color(0.25, 0.25, 0.3, 1.0)  # 变暗
	thumb.add_child(pic)

	# 锁图标（未解锁时覆盖一个"?"）
	if not is_unlocked:
		var lock_label := Label.new()
		lock_label.text = "?"
		lock_label.set_anchors_preset(Control.PRESET_CENTER)
		lock_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
		lock_label.grow_vertical = Control.GROW_DIRECTION_BOTH
		lock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lock_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lock_label.add_theme_font_size_override("font_size", 48)
		lock_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
		lock_label.add_theme_constant_override("outline_size", 4)
		lock_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		lock_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		thumb.add_child(lock_label)

	# 点击
	thumb.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_on_thumb_selected(index, false)
	)
	return thumb

## 缩略图样式（选中/非选中）
func _make_thumb_style(selected: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.06, 0.05, 0.85)
	sb.corner_radius_top_left = 8
	sb.corner_radius_top_right = 8
	sb.corner_radius_bottom_left = 8
	sb.corner_radius_bottom_right = 8
	# 提高圆角细分，保证呼吸动画放大阴影时边框/阴影的圆角依然平滑
	sb.corner_detail = 16
	sb.anti_aliasing = true
	sb.anti_aliasing_size = 1.0
	if selected:
		sb.border_color = THUMB_SELECTED_COLOR
		sb.border_width_left = 3
		sb.border_width_right = 3
		sb.border_width_top = 3
		sb.border_width_bottom = 3
		sb.shadow_color = Color(THUMB_SELECTED_COLOR.r, THUMB_SELECTED_COLOR.g, THUMB_SELECTED_COLOR.b, 0.6)
		sb.shadow_size = 10
	else:
		sb.border_color = THUMB_DEFAULT_COLOR
		sb.border_width_left = 2
		sb.border_width_right = 2
		sb.border_width_top = 2
		sb.border_width_bottom = 2
	return sb

## 解析缩略图路径
func _resolve_mini_path(char_id: String) -> String:
	var jpg_path := "res://ui/images/character_select/%s_mini.jpg" % char_id
	if ResourceLoader.exists(jpg_path):
		return jpg_path
	var png_path := "res://ui/images/character_select/%s_mini.png" % char_id
	if ResourceLoader.exists(png_path):
		return png_path
	return ""

## 缩略图选中
func _on_thumb_selected(index: int, is_initial: bool) -> void:
	if index < 0 or index >= CHARACTER_IDS.size():
		return
	var char_id := CHARACTER_IDS[index]
	var is_unlocked := SaveManager.is_character_unlocked(char_id) or GameManager.dev_mode

	# 停止之前的呼吸动画
	_stop_breath_animation()

	# 更新缩略图视觉选中态
	var selected_style: StyleBoxFlat = null
	for i in range(_thumb_cards.size()):
		var tc := _thumb_cards[i]
		var new_style := _make_thumb_style(i == index)
		tc.add_theme_stylebox_override("panel", new_style)
		tc.set_meta("style", new_style)
		if i == index:
			selected_style = new_style
		var tween := create_tween()
		tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		tween.tween_property(tc, "scale", THUMB_SELECTED_SCALE if i == index else THUMB_DEFAULT_SCALE, 0.18)

	# 给当前选中缩略图启动呼吸动画
	if selected_style != null:
		_start_breath_animation(selected_style)

	_selected_index = index
	_update_background(char_id, is_initial)
	_update_info_panel(char_id, is_unlocked)
	start_button.disabled = not is_unlocked

## 启动选中缩略图边框的呼吸动画（循环脉动 border_color 亮度 + shadow_size）
func _start_breath_animation(style: StyleBoxFlat) -> void:
	if style == null:
		return
	_breath_tween = create_tween()
	_breath_tween.set_loops()  # 无限循环
	_breath_tween.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	var base := THUMB_SELECTED_COLOR
	var dim_color := Color(
		clamp(base.r * BREATH_MIN_INTENSITY, 0.0, 1.0),
		clamp(base.g * BREATH_MIN_INTENSITY, 0.0, 1.0),
		clamp(base.b * BREATH_MIN_INTENSITY, 0.0, 1.0),
		base.a
	)
	var bright_color := Color(
		clamp(base.r * BREATH_MAX_INTENSITY, 0.0, 1.0),
		clamp(base.g * BREATH_MAX_INTENSITY, 0.0, 1.0),
		clamp(base.b * BREATH_MAX_INTENSITY, 0.0, 1.0),
		base.a
	)
	var dim_shadow := Color(bright_color.r, bright_color.g, bright_color.b, 0.35)
	var bright_shadow := Color(bright_color.r, bright_color.g, bright_color.b, 0.85)
	# 初始设置为低谷
	style.border_color = dim_color
	style.shadow_color = dim_shadow
	style.shadow_size = BREATH_SHADOW_MIN
	# 低谷 -> 高峰
	_breath_tween.tween_property(style, "border_color", bright_color, BREATH_DURATION)
	_breath_tween.parallel().tween_property(style, "shadow_color", bright_shadow, BREATH_DURATION)
	_breath_tween.parallel().tween_property(style, "shadow_size", BREATH_SHADOW_MAX, BREATH_DURATION)
	# 高峰 -> 低谷
	_breath_tween.tween_property(style, "border_color", dim_color, BREATH_DURATION)
	_breath_tween.parallel().tween_property(style, "shadow_color", dim_shadow, BREATH_DURATION)
	_breath_tween.parallel().tween_property(style, "shadow_size", BREATH_SHADOW_MIN, BREATH_DURATION)

## 停止呼吸动画
func _stop_breath_animation() -> void:
	if _breath_tween and _breath_tween.is_valid():
		_breath_tween.kill()
	_breath_tween = null

## 更新背景大图（切换时淡入过渡）
func _update_background(char_id: String, is_initial: bool) -> void:
	var bg_path := "res://ui/images/character_select/bg/%s.jpg" % char_id
	if not ResourceLoader.exists(bg_path):
		return
	var tex: Texture2D = load(bg_path)
	if is_initial or bg_texture.texture == null:
		bg_texture.texture = tex
		bg_fade_texture.texture = null
		bg_fade_texture.modulate.a = 0.0
		return
	# 交叉淡入
	if _bg_tween and _bg_tween.is_running():
		_bg_tween.kill()
	bg_fade_texture.texture = tex
	bg_fade_texture.modulate.a = 0.0
	_bg_tween = create_tween()
	_bg_tween.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_bg_tween.tween_property(bg_fade_texture, "modulate:a", 1.0, BG_FADE_DURATION)
	_bg_tween.tween_callback(func():
		bg_texture.texture = tex
		bg_fade_texture.modulate.a = 0.0
	)

## 更新左侧信息面板
func _update_info_panel(char_id: String, is_unlocked: bool) -> void:
	# 清空
	for child in info_content.get_children():
		child.queue_free()

	var char_data: Dictionary = DataManager.get_character(char_id)
	if char_data.is_empty():
		return

	# === 角色名 ===
	var name_label := Label.new()
	name_label.add_theme_font_size_override("font_size", 42)
	name_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.82))
	name_label.add_theme_constant_override("outline_size", 4)
	name_label.add_theme_color_override("font_outline_color", Color(0.15, 0.08, 0.04, 0.95))
	if is_unlocked:
		name_label.text = char_data.get("character_name", "")
	else:
		name_label.text = "？？？"
	info_content.add_child(name_label)

	# === 属性栏：HP / 法力 / 体力 ===
	var stats_hbox := HBoxContainer.new()
	stats_hbox.add_theme_constant_override("separation", 14)
	_append_stat_icon(stats_hbox, "res://ui/images/global/heart.png",
		"%d/%d" % [char_data.get("max_hp", 0), char_data.get("max_hp", 0)] if is_unlocked else "--")
	_append_stat_icon(stats_hbox, "res://ui/images/global/power.png",
		"%d" % char_data.get("mana", 0) if is_unlocked else "--")
	if is_unlocked and char_data.get("stamina", 0) > 0:
		_append_stat_icon(stats_hbox, "res://ui/images/global/strength.png",
			"%d" % char_data.get("stamina", 0))
	info_content.add_child(stats_hbox)

	# === 简介描述 ===
	var desc_label := Label.new()
	desc_label.add_theme_font_size_override("font_size", 16)
	desc_label.add_theme_color_override("font_color", Color(0.95, 0.9, 0.82))
	desc_label.add_theme_constant_override("outline_size", 2)
	desc_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.75))
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc_label.custom_minimum_size = Vector2(0, 60)
	if is_unlocked:
		desc_label.text = char_data.get("description", "")
	else:
		# 未解锁显示解锁条件
		var ach_id: String = char_data.get("unlock_achievement", "")
		var info := _get_unlock_info(ach_id)
		desc_label.text = "【解锁条件】%s\n%s" % [info.get("name", "???"), info.get("description", "")]
	info_content.add_child(desc_label)

	# === 分隔线 ===
	var sep := HSeparator.new()
	var sep_style := StyleBoxFlat.new()
	sep_style.bg_color = Color(0.78, 0.55, 0.22, 0.6)
	sep_style.content_margin_top = 1
	sep_style.content_margin_bottom = 1
	sep.add_theme_stylebox_override("separator", sep_style)
	sep.add_theme_constant_override("separation", 6)
	info_content.add_child(sep)

	# === 初始法宝 ===
	if is_unlocked:
		var relic_id: String = char_data.get("starter_relic", "")
		if relic_id != "":
			var relic_data: Dictionary = DataManager.get_relic(relic_id)

			# 法宝名称行（图标 + 名称）
			var relic_hbox := HBoxContainer.new()
			relic_hbox.add_theme_constant_override("separation", 8)

			var relic_icon := TextureRect.new()
			var icon_path := "res://ui/images/global/relics/%s.png" % relic_id
			if ResourceLoader.exists(icon_path):
				relic_icon.texture = load(icon_path)
			relic_icon.custom_minimum_size = Vector2(28, 28)
			relic_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			relic_icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
			relic_hbox.add_child(relic_icon)

			var relic_name_label := Label.new()
			relic_name_label.text = relic_data.get("relic_name", "")
			relic_name_label.add_theme_font_size_override("font_size", 20)
			relic_name_label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.45))
			relic_name_label.add_theme_constant_override("outline_size", 2)
			relic_name_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
			relic_hbox.add_child(relic_name_label)
			info_content.add_child(relic_hbox)

			# 法宝描述
			var relic_desc_label := Label.new()
			relic_desc_label.text = RelicTooltip.get_enhanced_description(relic_data)
			relic_desc_label.add_theme_font_size_override("font_size", 15)
			relic_desc_label.add_theme_color_override("font_color", Color(0.95, 0.9, 0.82))
			relic_desc_label.add_theme_constant_override("outline_size", 2)
			relic_desc_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.75))
			relic_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
			info_content.add_child(relic_desc_label)

## 添加属性 icon + 数值（横向）
func _append_stat_icon(parent: HBoxContainer, icon_path: String, value: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)

	var icon := TextureRect.new()
	if ResourceLoader.exists(icon_path):
		icon.texture = load(icon_path)
	icon.custom_minimum_size = Vector2(22, 22)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	row.add_child(icon)

	var lbl := Label.new()
	lbl.text = value
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.95, 0.85))
	lbl.add_theme_constant_override("outline_size", 2)
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	row.add_child(lbl)

	parent.add_child(row)

## 获取解锁信息
func _get_unlock_info(achievement_id: String) -> Dictionary:
	if AchievementManager.ACHIEVEMENTS.has(achievement_id):
		var ach_data: Dictionary = AchievementManager.ACHIEVEMENTS[achievement_id]
		return {
			"name": ach_data.get("name", "???"),
			"description": ach_data.get("description", ""),
		}
	return {"name": "???", "description": ""}

## 开始游戏
func _on_start_pressed() -> void:
	if _selected_index < 0:
		return
	var char_id := CHARACTER_IDS[_selected_index]
	var is_unlocked := SaveManager.is_character_unlocked(char_id) or GameManager.dev_mode
	if not is_unlocked:
		start_button.disabled = true
		return
	var char_data: Dictionary = DataManager.get_character(char_id)
	var character := CharacterData.from_dict(char_data)
	character.apply_to_game()
	SceneTransition.change_scene("res://scenes/map/MapScene.tscn")

## 返回主菜单
func _on_back_pressed() -> void:
	SceneTransition.change_scene("res://scenes/main_menu/MainMenuScene.tscn")

## 选择上一个角色（循环）
func _on_prev_pressed() -> void:
	var n := CHARACTER_IDS.size()
	if n <= 0:
		return
	var base := _selected_index if _selected_index >= 0 else 0
	var next_index := (base - 1 + n) % n
	_on_thumb_selected(next_index, false)

## 选择下一个角色（循环）
func _on_next_pressed() -> void:
	var n := CHARACTER_IDS.size()
	if n <= 0:
		return
	var base := _selected_index if _selected_index >= 0 else 0
	var next_index := (base + 1) % n
	_on_thumb_selected(next_index, false)
