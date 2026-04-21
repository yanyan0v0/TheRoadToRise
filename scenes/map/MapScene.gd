## 地图场景脚本 - 显示和管理分支节点地图
extends Control

const MapGenerator = preload("res://scripts/map/MapGenerator.gd")

var map_data: Dictionary = {}
var node_buttons: Dictionary = {}  # node_id -> Button
var current_node_id: int = 0
## 开发者模式：连击5次进入节点
var _dev_click_counts: Dictionary = {}  # node_id -> click_count
var _dev_click_timers: Dictionary = {}  # node_id -> last_click_time
const DEV_CLICK_THRESHOLD: int = 5
const DEV_CLICK_TIMEOUT: float = 2.0  # 2秒内连击5次

@onready var scroll_container: ScrollContainer = $ScrollContainer
@onready var map_container: Control = $ScrollContainer/MapContainer
@onready var lines_container: Control = $ScrollContainer/MapContainer/LinesContainer
@onready var nodes_container: Control = $ScrollContainer/MapContainer/NodesContainer
@onready var legend_panel: PanelContainer = $LegendPanel
@onready var legend_vbox: VBoxContainer = $LegendPanel/MarginContainer/VBox

func _ready() -> void:
	GameManager.change_state(GameManager.GameState.MAP)
	
	# 恢复当前节点ID
	current_node_id = GameManager.current_node_index
	
	# 生成或加载地图
	if GameManager.current_map_data.is_empty():
		map_data = MapGenerator.generate_map(GameManager.current_chapter)
		GameManager.current_map_data = _serialize_map(map_data)
	else:
		map_data = _deserialize_map(GameManager.current_map_data)
	
	# 同步本章BOSS到GameManager（使HUD章节名能立即显示）
	_sync_current_chapter_boss()
	
	# 创建图例悬浮窗
	_create_legend()
	
	# 等待布局完成后再渲染
	await get_tree().process_frame
	_render_map()
	
	# 恢复滚动位置（修复滚动条回到初始位置问题）
	if GameManager.current_map_scroll_x != 0.0 or GameManager.current_map_scroll_y != 0.0:
		# 等待一帧确保ScrollContainer已完全初始化
		await get_tree().process_frame
		scroll_container.scroll_horizontal = GameManager.current_map_scroll_x
		scroll_container.scroll_vertical = GameManager.current_map_scroll_y

## 从地图数据中提取BOSS节点的boss_id，同步到GameManager.current_boss_id
## 这样 HUD 的章节名（取自boss的chapter_name）在进入地图时就能立即显示
func _sync_current_chapter_boss() -> void:
	var nodes_data: Array = map_data.get("nodes", [])
	for n in nodes_data:
		if n == null:
			continue
		var node_type_val: int = -1
		var boss_id_val: String = ""
		if n is MapGenerator.MapNode:
			node_type_val = n.node_type
			boss_id_val = n.encounter_data.get("boss_id", "")
		elif n is Dictionary:
			node_type_val = n.get("node_type", -1)
			var enc: Dictionary = n.get("encounter_data", {})
			boss_id_val = enc.get("boss_id", "")
		if node_type_val == MapGenerator.NodeType.BOSS and boss_id_val != "":
			GameManager.current_boss_id = boss_id_val
			# 通知HUD刷新章节名
			EventBus.next_chapter_entered.emit(GameManager.current_chapter)
			return

## 窗口大小变化时重新渲染地图
func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and map_data and not map_data.is_empty():
		_render_map()

## 图例中需要显示的节点类型（排除起点）
const LEGEND_NODE_TYPES := [
	MapGenerator.NodeType.BATTLE,
	MapGenerator.NodeType.ELITE,
	MapGenerator.NodeType.BOSS,
	MapGenerator.NodeType.SHOP,
	MapGenerator.NodeType.REST,
	MapGenerator.NodeType.EVENT,
	MapGenerator.NodeType.MYSTERY,
	MapGenerator.NodeType.ALCHEMY,
	MapGenerator.NodeType.FORGE,
	MapGenerator.NodeType.TRIBULATION,
]

## 创建图例悬浮窗
func _create_legend() -> void:
	# 设置面板半透明深色背景
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.1, 0.12, 0.85)
	panel_style.corner_radius_top_left = 6
	panel_style.corner_radius_top_right = 6
	panel_style.corner_radius_bottom_left = 6
	panel_style.corner_radius_bottom_right = 6
	panel_style.border_width_top = 1
	panel_style.border_width_bottom = 1
	panel_style.border_width_left = 1
	panel_style.border_width_right = 1
	panel_style.border_color = Color(0.3, 0.3, 0.3, 0.6)
	legend_panel.add_theme_stylebox_override("panel", panel_style)
	
	# 标题
	var title_label := Label.new()
	title_label.text = "图标说明"
	title_label.add_theme_font_size_override("font_size", 14)
	title_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.6, 1.0))
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	legend_vbox.add_child(title_label)
	
	# 分隔线
	var separator := HSeparator.new()
	separator.add_theme_constant_override("separation", 4)
	legend_vbox.add_child(separator)
	
	# 遍历节点类型，创建图例条目
	for node_type in LEGEND_NODE_TYPES:
		var icon_path: String = MapGenerator.NODE_ICONS.get(node_type, "")
		var type_name: String = MapGenerator.NODE_NAMES.get(node_type, "???")
		
		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 6)
		
		# 图标
		var icon_rect := TextureRect.new()
		if icon_path != "" and ResourceLoader.exists(icon_path):
			icon_rect.texture = load(icon_path)
		icon_rect.custom_minimum_size = Vector2(20, 20)
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		hbox.add_child(icon_rect)
		
		# 名称
		var name_label := Label.new()
		name_label.text = type_name
		name_label.add_theme_font_size_override("font_size", 12)
		name_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85, 1.0))
		hbox.add_child(name_label)
		
		legend_vbox.add_child(hbox)

## 渲染地图
func _render_map() -> void:
	# 清除旧内容
	for child in lines_container.get_children():
		child.queue_free()
	for child in nodes_container.get_children():
		child.queue_free()
	node_buttons.clear()
	# 重建时清空呼吸动画驱动表，避免悬挂引用（border panel 作为 nodes_container 子节点会随同被清理）
	_breath_entries.clear()
	
	# 根据节点实际像素坐标动态计算容器大小
	var viewport_size := get_viewport_rect().size
	var nodes_for_size: Array = map_data.get("nodes", [])
	var max_x: float = 0.0
	var max_y: float = 0.0
	for n in nodes_for_size:
		if n.position.x > max_x:
			max_x = n.position.x
		if n.position.y > max_y:
			max_y = n.position.y
	
	var nodes: Array = map_data.get("nodes", [])
	
	# 构建已走路径的边集合（visited -> visited 的连接）
	var visited_edges: Dictionary = {}  # "from_id->to_id" -> true
	for node in nodes:
		if node.visited:
			for conn_id in node.connections:
				var target_node := _find_node(nodes, conn_id)
				if target_node and target_node.visited:
					visited_edges["%d->%d" % [node.id, conn_id]] = true
	
	# 构建可达边集合（current_node -> 未访问的下一层节点的连接）
	var reachable_edges: Dictionary = {}  # "from_id->to_id" -> true
	var current_node_for_edges: MapGenerator.MapNode = _compute_current_node(nodes)
	if current_node_for_edges != null:
		for conn_id in current_node_for_edges.connections:
			var target_node := _find_node(nodes, conn_id)
			if target_node and not target_node.visited:
				reachable_edges["%d->%d" % [current_node_for_edges.id, conn_id]] = true
	
	# 先绘制普通分支（灰），再绘制已走/可达（金），保证高亮边在上层
	# Pass 1: 非高亮边
	for node in nodes:
		for conn_id in node.connections:
			var target_node := _find_node(nodes, conn_id)
			if target_node == null:
				continue
			var edge_key := "%d->%d" % [node.id, conn_id]
			if visited_edges.has(edge_key) or reachable_edges.has(edge_key):
				continue
			_draw_connection_line(node.position, target_node.position, false, false)
	# Pass 2: 高亮边（已走 + 当前→可达）
	for node in nodes:
		for conn_id in node.connections:
			var target_node := _find_node(nodes, conn_id)
			if target_node == null:
				continue
			var edge_key := "%d->%d" % [node.id, conn_id]
			var is_visited_edge: bool = visited_edges.has(edge_key)
			var is_reachable_edge: bool = reachable_edges.has(edge_key)
			if is_visited_edge or is_reachable_edge:
				_draw_connection_line(node.position, target_node.position, is_visited_edge, is_reachable_edge)
	
	# 再绘制节点
	for node in nodes:
		_create_node_button(node)
	
	# 更新可达状态
	_update_reachable_nodes()

## 节点按钮尺寸
const NODE_BUTTON_SIZE := Vector2(40, 40)

## 节点类型描述（用于hover气泡框）
const NODE_DESCRIPTIONS := {
	MapGenerator.NodeType.BATTLE: "与妖魔鬼怪战斗，获取经验和战利品",
	MapGenerator.NodeType.ELITE: "挑战强大的精英敌人，获取丰厚奖励",
	MapGenerator.NodeType.SHOP: "购买卡牌、丹药和法宝",
	MapGenerator.NodeType.REST: "在篝火旁休息，恢复生命值/悟道/融合卡牌",
	MapGenerator.NodeType.MYSTERY: "神秘商人出没，可能有稀有物品",
	MapGenerator.NodeType.EVENT: "触发随机事件，可能是机遇也可能是危险",
	MapGenerator.NodeType.BOSS: "挑战本章最终BOSS",
	MapGenerator.NodeType.START: "旅途的起点",
	MapGenerator.NodeType.ALCHEMY: "炼制丹药，提升属性",
	MapGenerator.NodeType.FORGE: "锻造强化法宝",
	MapGenerator.NodeType.TRIBULATION: "渡劫试炼，突破修为瓶颈",
}

## 当前显示的hover气泡框
var _current_tooltip: PanelContainer = null
var _tooltip_target_button: Button = null

## 呼吸动画统一驱动：用累计时间 + 每个节点的相位做数学计算，避免 N 个 Tween + 每帧闭包调用
## 动画对象是“金色边框 Panel”，而非按钮本身的 scale，避免像素对齐造成的阶梯抖动
## key(panel_instance_id) -> { "panel": Panel, "style": StyleBoxFlat, "phase": float, "is_boss": bool }
var _breath_entries: Dictionary = {}
var _breath_time: float = 0.0
## 呼吸周期（秒）
const BREATH_PERIOD: float = 1.8
## 呼吸角频率 = 2π / 周期
const BREATH_OMEGA: float = TAU / BREATH_PERIOD

## 金色边框呼吸参数
const GLOW_BORDER_NAME := "_GlowBorder"
## 边框宽度范围（像素）
const GLOW_BORDER_WIDTH_MIN: float = 1.5
const GLOW_BORDER_WIDTH_MAX: float = 3.5
## 金色边框颜色（色相/亮度固定，alpha 动态变化）
const GLOW_BORDER_COLOR := Color(1.0, 0.85, 0.25, 1.0)
const GLOW_BORDER_ALPHA_MIN: float = 0.45
const GLOW_BORDER_ALPHA_MAX: float = 1.0
## 边框相对按钮的外拓像素（让边框路在按钮外围，视觉上更冲击）
const GLOW_BORDER_PADDING: float = 4.0

## 创建节点按钮
func _create_node_button(node: MapGenerator.MapNode) -> void:
	var button := Button.new()
	button.custom_minimum_size = NODE_BUTTON_SIZE
	button.size = NODE_BUTTON_SIZE
	# 直接使用像素坐标定位
	var actual_pos := node.position
	button.position = actual_pos - NODE_BUTTON_SIZE / 2.0
	
	# 圆角半径（圆形 = 尺寸/2）
	var corner_radius: int = int(NODE_BUTTON_SIZE.x / 2.0)
	
	var is_boss_node := (node.node_type == MapGenerator.NodeType.BOSS)
	
	if is_boss_node:
		# BOSS节点：只保留图片层，按图片比例显示，高度为屏幕一半
		var boss_img_path: String = node.encounter_data.get("boss_image", "")
		if boss_img_path == "" or not ResourceLoader.exists(boss_img_path):
			boss_img_path = MapGenerator.NODE_BGS.get(node.node_type, "")
		
		if boss_img_path != "" and ResourceLoader.exists(boss_img_path):
			var boss_texture: Texture2D = load(boss_img_path)
			var tex_w: float = boss_texture.get_width()
			var tex_h: float = boss_texture.get_height()
			# 高度为屏幕高度的3/4，宽度按图片比例计算
			var viewport_size := get_viewport_rect().size
			var boss_height: float = viewport_size.y * 0.75
			var boss_width: float = boss_height
			if tex_w > 0 and tex_h > 0:
				boss_width = boss_height * (tex_w / tex_h)
			var boss_size := Vector2(boss_width, boss_height)
			button.custom_minimum_size = boss_size
			button.size = boss_size
			# X坐标加上图片宽度的一半，使BOSS图片左边缘对齐节点坐标
			button.position = Vector2(actual_pos.x - boss_size.x / 2.0 + boss_width / 2.0, actual_pos.y - boss_size.y / 2.0)
			
			# 只用图片作为按钮样式，不添加底层背景色
			var boss_tex_style := StyleBoxTexture.new()
			boss_tex_style.texture = boss_texture
			boss_tex_style.region_rect = Rect2(Vector2.ZERO, Vector2(tex_w, tex_h))
			button.add_theme_stylebox_override("normal", boss_tex_style)
			button.add_theme_stylebox_override("hover", boss_tex_style.duplicate())
			button.add_theme_stylebox_override("pressed", boss_tex_style.duplicate())
			button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	else:
		# 普通节点：两层圆形结构
		# 底层：#F5F0DD 圆形背景
		var base_style := StyleBoxFlat.new()
		base_style.bg_color = Color("F5F0DD")
		base_style.corner_radius_top_left = corner_radius
		base_style.corner_radius_top_right = corner_radius
		base_style.corner_radius_bottom_left = corner_radius
		base_style.corner_radius_bottom_right = corner_radius
		button.add_theme_stylebox_override("normal", base_style)
		button.add_theme_stylebox_override("hover", base_style.duplicate())
		button.add_theme_stylebox_override("pressed", base_style.duplicate())
		button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		button.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
		
		# 上层：图片
		var img_path: String = MapGenerator.NODE_BGS.get(node.node_type, "")
		if img_path != "" and ResourceLoader.exists(img_path):
			var img_texture: Texture2D = load(img_path)
			var img_rect := TextureRect.new()
			img_rect.name = "NodeImage"
			img_rect.texture = img_texture
			img_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			img_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			img_rect.size = NODE_BUTTON_SIZE
			img_rect.position = Vector2.ZERO
			img_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			button.add_child(img_rect)
	
	# 连接点击信号
	var node_id := node.id
	button.pressed.connect(func(): _on_node_clicked(node_id))
	
	nodes_container.add_child(button)
	node_buttons[node.id] = button
	
	# 绑定hover事件，显示气泡框
	_bind_node_hover(button, node)
	
	# 为可访问节点添加金色边框呼吸动画
	if node.reachable and not node.visited:
		_apply_glow_effect(button)
	
	# 为已访问节点降低透明度（替代灰色边框）
	if node.visited and node.node_type != MapGenerator.NodeType.START:
		_apply_visited_border(button)

## 为可访问节点添加金色边框呼吸动画
## 实现：给按钮挂一个额外的 Panel 子节点作为边框层，_process 中更新 border_width 与 alpha
## 好处：
##   1. 按钮本身不做 scale，彻底消除小按钮缩放时因像素重对齐出现的抖动
##   2. 边框在按钮外围（padding），不遮挡节点图片也不影响点击区（mouse_filter = IGNORE）
##   3. BOSS 和普通节点统一处理，尺寸/圆角分别适配
func _apply_glow_effect(button: Button) -> void:
	# 移除旧的呼吸动画（如果有）
	_remove_glow_effect(button)
	if not is_instance_valid(button):
		return
	
	var btn_size := button.size
	# 判断是否为BOSS节点（非正方形即为BOSS）
	var is_boss: bool = abs(btn_size.x - btn_size.y) > 1.0 or btn_size.x > NODE_BUTTON_SIZE.x + 10
	
	# 创建边框样式：透明填充 + 金色边框
	var border_style := StyleBoxFlat.new()
	border_style.bg_color = Color(0, 0, 0, 0)
	border_style.border_color = GLOW_BORDER_COLOR
	var init_w: int = int(round((GLOW_BORDER_WIDTH_MIN + GLOW_BORDER_WIDTH_MAX) * 0.5))
	border_style.border_width_top = init_w
	border_style.border_width_bottom = init_w
	border_style.border_width_left = init_w
	border_style.border_width_right = init_w
	# 普通节点使用圆角，BOSS 节点使用轻圆角矩形（区别于圆形按钮）
	if is_boss:
		var boss_cr := 8
		border_style.corner_radius_top_left = boss_cr
		border_style.corner_radius_top_right = boss_cr
		border_style.corner_radius_bottom_left = boss_cr
		border_style.corner_radius_bottom_right = boss_cr
	else:
		var radius: int = int((btn_size.x + GLOW_BORDER_PADDING * 2.0) / 2.0)
		border_style.corner_radius_top_left = radius
		border_style.corner_radius_top_right = radius
		border_style.corner_radius_bottom_left = radius
		border_style.corner_radius_bottom_right = radius
	
	# 创建边框容器 Panel
	var border_panel := Panel.new()
	border_panel.name = GLOW_BORDER_NAME
	border_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	border_panel.add_theme_stylebox_override("panel", border_style)
	# 将 Panel 放到按钮外拓位置（相对按钮本地坐标系）
	border_panel.position = Vector2(-GLOW_BORDER_PADDING, -GLOW_BORDER_PADDING)
	border_panel.size = btn_size + Vector2(GLOW_BORDER_PADDING * 2.0, GLOW_BORDER_PADDING * 2.0)
	border_panel.z_index = 10  # 确保在节点图片上方
	# 不可裁剪：BOSS 节点的 clip_children 未开，普通节点开启了 clip_children
	# 为了避免边框被按钮裁剪掉，边框作为 nodes_container 的子节点而非按钮子节点
	# 但位置需转换到 nodes_container 坐标系
	border_panel.position = button.position + Vector2(-GLOW_BORDER_PADDING, -GLOW_BORDER_PADDING)
	nodes_container.add_child(border_panel)
	
	# 注册到呼吸驱动表
	var key := str(border_panel.get_instance_id())
	var phase_offset: float = randf() * TAU
	_breath_entries[key] = {
		"panel": border_panel,
		"style": border_style,
		"phase": phase_offset,
		"is_boss": is_boss,
	}
	
	# 将 panel 引用存到按钮的 meta，便于 _remove_glow_effect 定向移除
	button.set_meta("glow_border_panel_id", border_panel.get_instance_id())

## 统一呼吸动画驱动：每帧一次性更新所有注册节点的 scale
## 相比 N 个 Tween + 闭包回调，这种写法：
##   1. 只有一次 _process 调度
##   2. 无闭包捕获开销
##   3. 无 Tween 状态机开销
##   4. 可一次性清理失效按钮
func _process(delta: float) -> void:
	if _breath_entries.is_empty():
		return
	_breath_time += delta
	# 关键：按 BREATH_PERIOD（秒）截断，而非 TAU，保证 cos(base_t + phase) 截断前后连续
	if _breath_time > BREATH_PERIOD:
		_breath_time = fmod(_breath_time, BREATH_PERIOD)
	var base_t: float = _breath_time * BREATH_OMEGA
	var invalid_keys: Array = []
	for key in _breath_entries.keys():
		var entry: Dictionary = _breath_entries[key]
		var panel: Panel = entry.get("panel")
		var style: StyleBoxFlat = entry.get("style")
		if not is_instance_valid(panel) or style == null:
			invalid_keys.append(key)
			continue
		var phase: float = entry.get("phase", 0.0)
		# breath ∈ [0, 1]，0 = 最细最淡，1 = 最粗最亮
		var breath: float = 0.5 * (1.0 - cos(base_t + phase))
		var w: float = GLOW_BORDER_WIDTH_MIN + (GLOW_BORDER_WIDTH_MAX - GLOW_BORDER_WIDTH_MIN) * breath
		var a: float = GLOW_BORDER_ALPHA_MIN + (GLOW_BORDER_ALPHA_MAX - GLOW_BORDER_ALPHA_MIN) * breath
		var iw: int = int(round(w))
		style.border_width_top = iw
		style.border_width_bottom = iw
		style.border_width_left = iw
		style.border_width_right = iw
		var c: Color = GLOW_BORDER_COLOR
		c.a = a
		style.border_color = c
	for k in invalid_keys:
		_breath_entries.erase(k)

## 移除节点上的金色边框呼吸动画，移除边框 Panel 并恢复按钮状态
func _remove_glow_effect(button: Button) -> void:
	if not is_instance_valid(button):
		return
	# 保险起见：恢复 scale（若之前版本尚有残留）
	button.scale = Vector2.ONE
	# 根据 meta 定向清除对应的边框 panel
	if button.has_meta("glow_border_panel_id"):
		var pid: int = button.get_meta("glow_border_panel_id")
		var key := str(pid)
		if _breath_entries.has(key):
			var entry: Dictionary = _breath_entries[key]
			var p: Panel = entry.get("panel")
			if is_instance_valid(p):
				p.queue_free()
			_breath_entries.erase(key)
		else:
			# 降级方案：遍历寻找同 ID 的 panel（理论上不应走到这里）
			for child in nodes_container.get_children():
				if child is Panel and child.name == GLOW_BORDER_NAME and child.get_instance_id() == pid:
					child.queue_free()
					break
		button.remove_meta("glow_border_panel_id")

## 已访问节点的透明度（用于视觉区分）
const VISITED_ALPHA := 0.45
## 节点上层图片子节点名称（与 _create_node_button 中保持一致）
const NODE_IMAGE_NAME := "NodeImage"

## 将已访问节点的视觉标记改为降低透明度
## 只降低"上层节点图片"的透明度，不影响"下层圆形底色" F5F0DD
## 这样视觉上已访问节点仍是酱白圆底，但上面的类型图标变淡
func _apply_visited_border(button: Button) -> void:
	if not is_instance_valid(button):
		return
	var btn_size := button.size
	# 判断是否为BOSS节点，BOSS节点不降透明度（保持清晰可辨）
	var is_boss: bool = abs(btn_size.x - btn_size.y) > 1.0 or btn_size.x > NODE_BUTTON_SIZE.x + 10
	if is_boss:
		return
	# 仅对上层图片应用透明度，保持按钮本身（下层圆形底色）不变
	var image_rect: TextureRect = button.get_node_or_null(NODE_IMAGE_NAME) as TextureRect
	if image_rect != null:
		var c := image_rect.modulate
		c.a = VISITED_ALPHA
		image_rect.modulate = c

## 恢复已访问节点上层图片的透明度
func _remove_visited_border(button: Button) -> void:
	if not is_instance_valid(button):
		return
	var image_rect: TextureRect = button.get_node_or_null(NODE_IMAGE_NAME) as TextureRect
	if image_rect != null:
		var c := image_rect.modulate
		c.a = 1.0
		image_rect.modulate = c

## 为节点按钮绑定hover事件，显示/隐藏气泡框
func _bind_node_hover(button: Button, node: MapGenerator.MapNode) -> void:
	button.mouse_entered.connect(func(): _show_node_tooltip(button, node))
	button.mouse_exited.connect(func(): _hide_node_tooltip(button))

## 显示节点hover气泡框
func _show_node_tooltip(button: Button, node: MapGenerator.MapNode) -> void:
	# 如果已有气泡框，先移除
	_hide_node_tooltip(null)
	
	# 确定显示名称
	var display_name: String = ""
	var is_combat_node := node.node_type in [
		MapGenerator.NodeType.BATTLE,
		MapGenerator.NodeType.ELITE,
		MapGenerator.NodeType.BOSS,
	]
	if is_combat_node and node.encounter_data.has("display_name"):
		display_name = node.encounter_data.get("display_name", "")
	else:
		display_name = MapGenerator.NODE_NAMES.get(node.node_type, "???")
	
	var description: String = NODE_DESCRIPTIONS.get(node.node_type, "")
	
	# --- 创建气泡框面板 ---
	var tooltip := PanelContainer.new()
	tooltip.name = "NodeTooltip"
	tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tooltip.z_index = 100  # 确保在最上层
	
	# 气泡框样式：深色半透明背景 + 圆角 + 边框
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.1, 0.14, 0.92)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_color = Color(0.85, 0.7, 0.2, 0.7)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	# 阴影效果
	style.shadow_color = Color(0, 0, 0, 0.4)
	style.shadow_size = 4
	style.shadow_offset = Vector2(2, 2)
	tooltip.add_theme_stylebox_override("panel", style)
	
	# 内容布局：垂直排列
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tooltip.add_child(vbox)
	
	# 第一行：图标 + 节点名
	var title_hbox := HBoxContainer.new()
	title_hbox.add_theme_constant_override("separation", 6)
	title_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(title_hbox)
	
	var icon_path: String = MapGenerator.NODE_ICONS.get(node.node_type, "")
	if icon_path != "" and ResourceLoader.exists(icon_path):
		var icon_rect := TextureRect.new()
		icon_rect.texture = load(icon_path)
		icon_rect.custom_minimum_size = Vector2(20, 20)
		icon_rect.size = Vector2(20, 20)
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		title_hbox.add_child(icon_rect)
	
	var name_label := Label.new()
	name_label.text = display_name
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.4, 1.0))
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_hbox.add_child(name_label)
	
	# 分隔线
	var separator := HSeparator.new()
	separator.add_theme_constant_override("separation", 2)
	separator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(separator)
	
	# 第二行：描述
	var desc_label := Label.new()
	desc_label.text = description
	desc_label.add_theme_font_size_override("font_size", 12)
	desc_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8, 0.9))
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.custom_minimum_size.x = 160
	desc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(desc_label)
	
	# 将气泡框添加到 nodes_container（与按钮同级，避免被按钮裁剪）
	nodes_container.add_child(tooltip)
	_current_tooltip = tooltip
	_tooltip_target_button = button
	
	# 等待布局计算完成后定位
	await get_tree().process_frame
	if is_instance_valid(tooltip) and is_instance_valid(button):
		var btn_global_pos := button.position
		var btn_size := button.size
		var tw := tooltip.size.x
		var th := tooltip.size.y
		var tx: float
		var ty: float
		
		# BOSS节点：气泡框显示在节点左侧，垂直居中
		var is_boss_node := (node.node_type == MapGenerator.NodeType.BOSS)
		if is_boss_node:
			tx = btn_global_pos.x + tw - 12
			ty = btn_global_pos.y + (btn_size.y - th) / 2.0
			# 如果超出左边界，改为显示在节点右侧
			if tx < 0:
				tx = btn_global_pos.x + btn_size.x + 12
		else:
			# 普通节点：气泡框显示在节点上方，水平居中
			tx = btn_global_pos.x + (btn_size.x - tw) / 2.0
			ty = btn_global_pos.y - th - 8
			# 如果超出上边界，改为显示在节点下方
			if ty < 0:
				ty = btn_global_pos.y + btn_size.y + 8
		tooltip.position = Vector2(tx, ty)

## 隐藏节点hover气泡框
func _hide_node_tooltip(_button: Variant) -> void:
	if _current_tooltip and is_instance_valid(_current_tooltip):
		_current_tooltip.queue_free()
		_current_tooltip = null
		_tooltip_target_button = null

## 绘制连接线（加粗虚线，已走路径高亮，其他分支变浅）
func _draw_connection_line(from_pos: Vector2, to_pos: Vector2, is_visited_edge: bool = false, is_reachable_edge: bool = false) -> void:
	# 直接使用像素坐标
	var actual_from := from_pos
	var actual_to := to_pos
	
	# 使用多段短线模拟虚线效果
	var dash_length := 10.0  # 虚线段长度
	var gap_length := 6.0   # 间隔长度
	var direction := (actual_to - actual_from)
	var total_length := direction.length()
	var dir_normalized := direction.normalized()
	
	# 可达边：最亮（金黄）；已走边：金色偏暖；其他分支：浅灰半透明
	var line_color: Color
	var line_width: float
	if is_reachable_edge:
		line_color = Color(0.95, 0.8, 0.25, 1.0)  # 亮金，指引玩家下一步
		line_width = 4.0
	elif is_visited_edge:
		line_color = Color(0.7, 0.65, 0.4, 0.8)  # 金色偏暖，已走路径
		line_width = 3.5
	else:
		line_color = Color(0.4, 0.4, 0.4, 0.2)  # 浅灰半透明，未走分支
		line_width = 2.0
	
	var current_dist := 0.0
	while current_dist < total_length:
		var seg_start := actual_from + dir_normalized * current_dist
		var seg_end_dist: float = min(current_dist + dash_length, total_length)
		var seg_end: Vector2 = actual_from + dir_normalized * seg_end_dist
		
		var line := Line2D.new()
		line.add_point(seg_start)
		line.add_point(seg_end)
		line.width = line_width
		line.default_color = line_color
		lines_container.add_child(line)
		
		current_dist += dash_length + gap_length

## 查找节点
func _find_node(nodes: Array, node_id: int) -> MapGenerator.MapNode:
	for node in nodes:
		if node.id == node_id:
			return node
	return null

## 更新可达节点 - 只有当前节点连线的下一个未访问节点可选
func _update_reachable_nodes() -> void:
	var nodes: Array = map_data.get("nodes", [])
	
	# 找到最后访问的节点（当前所在位置）
	var current_node: MapGenerator.MapNode = _compute_current_node(nodes)
	
	if current_node == null:
		return
	
	current_node_id = current_node.id
	
	# 先将所有节点标记为不可达，并更新按钮外观
	for node in nodes:
		node.reachable = false
		if node_buttons.has(node.id):
			var btn: Button = node_buttons[node.id]
			# 按钮本身保持完整不透明（下层圆形底色始终不变）
			btn.modulate = Color.WHITE
			# 先恢复上层图片透明度，再根据 visited 状态决定是否降透明
			_remove_visited_border(btn)
			if node.visited and node.node_type != MapGenerator.NodeType.START:
				# 已访问节点：仅降低上层图片透明度
				_apply_visited_border(btn)
			# 停止呼吸动画，恢复原始缩放
			_remove_glow_effect(btn)
	
	# 只有当前节点直接连线的、未访问的下一层节点可达
	for conn_id in current_node.connections:
		var target := _find_node(nodes, conn_id)
		if target and not target.visited:
			target.reachable = true
			if node_buttons.has(conn_id):
				var btn: Button = node_buttons[conn_id]
				btn.modulate = Color.WHITE
				# 可访问节点不另外降透明（新和未访问节点一致，恢复上层不透明）
				_remove_visited_border(btn)
				# 为可访问节点添加缩放呼吸动画
				_apply_glow_effect(btn)

## 计算当前所在节点（用于高亮连线、可达判定等）
func _compute_current_node(nodes: Array) -> MapGenerator.MapNode:
	var current_node: MapGenerator.MapNode = null
	
	# 优先使用 current_node_id 查找
	if current_node_id > 0:
		for node in nodes:
			if node.id == current_node_id and node.visited:
				current_node = node
				break
	
	# 如果没找到，找最后一个被访问的节点（层级最深的）
	if current_node == null:
		var max_layer: int = -1
		for node in nodes:
			if node.visited and node.layer > max_layer:
				max_layer = node.layer
				current_node = node
	
	# 如果还是没有，使用起点
	if current_node == null:
		for node in nodes:
			if node.node_type == MapGenerator.NodeType.START:
				current_node = node
				break
	
	return current_node

## 节点点击处理
func _on_node_clicked(node_id: int) -> void:
	var nodes: Array = map_data.get("nodes", [])
	var node := _find_node(nodes, node_id)
	
	if node == null:
		return
	
	# 开发者模式：对不可达/已访问节点也可以连击5次进入
	if node.visited or not node.reachable:
		if GameManager.dev_mode:
			_handle_dev_click(node_id)
		return
	
	_enter_node(node)

## 开发者模式连击检测
func _handle_dev_click(node_id: int) -> void:
	var current_time := Time.get_ticks_msec() / 1000.0
	var last_time: float = _dev_click_timers.get(node_id, 0.0)
	
	# 超时重置计数
	if current_time - last_time > DEV_CLICK_TIMEOUT:
		_dev_click_counts[node_id] = 0
	
	_dev_click_counts[node_id] = _dev_click_counts.get(node_id, 0) + 1
	_dev_click_timers[node_id] = current_time
	
	if _dev_click_counts[node_id] >= DEV_CLICK_THRESHOLD:
		_dev_click_counts[node_id] = 0
		print("[开发者模式] 强制进入节点: %d" % node_id)
		var nodes: Array = map_data.get("nodes", [])
		var node := _find_node(nodes, node_id)
		if node != null:
			_enter_node(node)

## 进入节点（通用逻辑）
func _enter_node(node: MapGenerator.MapNode) -> void:
	# 标记为已访问
	node.visited = true
	current_node_id = node.id
	GameManager.current_node_index = node.id
	
	# 保存滚动位置（修复滚动条回到初始位置问题）
	GameManager.current_map_scroll_x = scroll_container.scroll_horizontal
	GameManager.current_map_scroll_y = scroll_container.scroll_vertical
	
	# 保存地图状态
	GameManager.current_map_data = _serialize_map(map_data)
	
	# 根据节点类型进入对应场景
	match node.node_type:
		MapGenerator.NodeType.BATTLE:
			_enter_battle(node)
		MapGenerator.NodeType.ELITE:
			_enter_elite_battle(node)
		MapGenerator.NodeType.BOSS:
			_enter_boss_battle(node)
		MapGenerator.NodeType.SHOP:
			SceneTransition.change_scene("res://scenes/shop/ShopScene.tscn")
		MapGenerator.NodeType.REST:
			SceneTransition.change_scene("res://scenes/rest/RestScene.tscn")
		MapGenerator.NodeType.EVENT:
			SceneTransition.change_scene("res://scenes/event/EventScene.tscn")
		MapGenerator.NodeType.MYSTERY:
			SceneTransition.change_scene("res://scenes/shop/ShopScene.tscn")  # 神秘商人复用商店
		MapGenerator.NodeType.ALCHEMY:
			SceneTransition.change_scene("res://scenes/alchemy/AlchemyScene.tscn")
		MapGenerator.NodeType.FORGE:
			SceneTransition.change_scene("res://scenes/forge/ForgeScene.tscn")
		MapGenerator.NodeType.TRIBULATION:
			SceneTransition.change_scene("res://scenes/tribulation/TribulationScene.tscn")
		MapGenerator.NodeType.START:
			pass  # 起点不进入任何场景

## 进入普通战斗
func _enter_battle(node: MapGenerator.MapNode) -> void:
	# 设置战斗敌人
	GameManager.current_battle_type = "normal"
	# Pass the pre-assigned enemy_ids from the map node to ensure battle matches map display
	var enemy_ids: Array[String] = []
	for eid in node.encounter_data.get("enemy_ids", []):
		enemy_ids.append(eid)
	GameManager.current_enemy_ids = enemy_ids
	SceneTransition.change_scene("res://scenes/battle/BattleScene.tscn")

## 进入精英战斗
func _enter_elite_battle(node: MapGenerator.MapNode) -> void:
	GameManager.current_battle_type = "elite"
	# Pass the pre-assigned enemy_ids from the map node to ensure battle matches map display
	var enemy_ids: Array[String] = []
	for eid in node.encounter_data.get("enemy_ids", []):
		enemy_ids.append(eid)
	GameManager.current_enemy_ids = enemy_ids
	SceneTransition.change_scene("res://scenes/battle/BattleScene.tscn")

## 进入BOSS战斗
func _enter_boss_battle(node: MapGenerator.MapNode) -> void:
	GameManager.current_battle_type = "boss"
	var boss_id: String = node.encounter_data.get("boss_id", "")
	GameManager.current_boss_id = boss_id
	# Also set current_enemy_ids for consistency
	var enemy_ids: Array[String] = [boss_id]
	GameManager.current_enemy_ids = enemy_ids
	SceneTransition.change_scene("res://scenes/battle/BattleScene.tscn")

## 序列化地图数据（用于存档）
func _serialize_map(data: Dictionary) -> Dictionary:
	var serialized := data.duplicate(true)
	var serialized_nodes: Array = []
	
	for node in data.get("nodes", []):
		serialized_nodes.append({
			"id": node.id,
			"layer": node.layer,
			"column": node.column,
			"node_type": node.node_type,
			"connections": node.connections.duplicate(),
			"visited": node.visited,
			"reachable": node.reachable,
			"position_x": node.position.x,
			"position_y": node.position.y,
			"encounter_data": node.encounter_data.duplicate(),
		})
	
	serialized["nodes"] = serialized_nodes
	return serialized

## 反序列化地图数据
func _deserialize_map(data: Dictionary) -> Dictionary:
	var deserialized := data.duplicate(true)
	var nodes: Array = []
	
	for node_data in data.get("nodes", []):
		var node := MapGenerator.MapNode.new()
		node.id = node_data.get("id", 0)
		node.layer = node_data.get("layer", 0)
		node.column = node_data.get("column", 0)
		node.node_type = node_data.get("node_type", 0)
		node.connections.assign(node_data.get("connections", []))
		node.visited = node_data.get("visited", false)
		node.reachable = node_data.get("reachable", false)
		node.position = Vector2(node_data.get("position_x", 0), node_data.get("position_y", 0))
		node.encounter_data = node_data.get("encounter_data", {})
		nodes.append(node)
	
	deserialized["nodes"] = nodes
	return deserialized
