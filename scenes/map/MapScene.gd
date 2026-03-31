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

@onready var map_container: Control = $ScrollContainer/MapContainer
@onready var lines_container: Control = $ScrollContainer/MapContainer/LinesContainer
@onready var nodes_container: Control = $ScrollContainer/MapContainer/NodesContainer

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
	
	_render_map()

## 渲染地图
func _render_map() -> void:
	# 清除旧内容
	for child in lines_container.get_children():
		child.queue_free()
	for child in nodes_container.get_children():
		child.queue_free()
	node_buttons.clear()
	
	var nodes: Array = map_data.get("nodes", [])
	
	# 先绘制连接线
	for node in nodes:
		for conn_id in node.connections:
			var target_node := _find_node(nodes, conn_id)
			if target_node:
				_draw_connection_line(node.position, target_node.position)
	
	# 再绘制节点
	for node in nodes:
		_create_node_button(node)
	
	# 更新可达状态
	_update_reachable_nodes()

## 创建节点按钮
func _create_node_button(node: MapGenerator.MapNode) -> void:
	var button := Button.new()
	button.custom_minimum_size = Vector2(60, 60)
	button.size = Vector2(60, 60)
	button.position = node.position - Vector2(30, 30)
	
	# 设置图标文字
	var icon_text: String = MapGenerator.NODE_ICONS.get(node.node_type, "?")
	var type_name: String = MapGenerator.NODE_NAMES.get(node.node_type, "???")
	button.text = icon_text
	button.tooltip_text = type_name
	
	# 设置颜色
	var color: Color = MapGenerator.NODE_COLORS.get(node.node_type, Color.WHITE)
	
	# 已访问节点
	if node.visited:
		button.modulate = Color(0.5, 0.5, 0.5, 0.7)
	elif not node.reachable:
		button.modulate = Color(0.3, 0.3, 0.3, 0.5)
	else:
		button.modulate = color
	
	button.add_theme_font_size_override("font_size", 24)
	
	# 连接点击信号
	var node_id := node.id
	button.pressed.connect(func(): _on_node_clicked(node_id))
	
	nodes_container.add_child(button)
	node_buttons[node.id] = button

## 绘制连接线
func _draw_connection_line(from_pos: Vector2, to_pos: Vector2) -> void:
	var line := Line2D.new()
	line.add_point(from_pos)
	line.add_point(to_pos)
	line.width = 2.0
	line.default_color = Color(0.4, 0.4, 0.4, 0.6)
	lines_container.add_child(line)

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
	var current_node: MapGenerator.MapNode = null
	
	# 优先使用current_node_id查找
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
				current_node_id = node.id
				break
	
	if current_node == null:
		return
	
	current_node_id = current_node.id
	
	# 先将所有节点标记为不可达，并更新按钮外观
	for node in nodes:
		node.reachable = false
		if node_buttons.has(node.id):
			var btn: Button = node_buttons[node.id]
			if node.visited:
				btn.modulate = Color(0.5, 0.5, 0.5, 0.7)
			else:
				btn.modulate = Color(0.3, 0.3, 0.3, 0.5)
	
	# 只有当前节点直接连线的、未访问的下一层节点可达
	for conn_id in current_node.connections:
		var target := _find_node(nodes, conn_id)
		if target and not target.visited:
			target.reachable = true
			if node_buttons.has(conn_id):
				var btn: Button = node_buttons[conn_id]
				var color: Color = MapGenerator.NODE_COLORS.get(target.node_type, Color.WHITE)
				btn.modulate = color

## 节点点击处理
func _on_node_clicked(node_id: int) -> void:
	var nodes: Array = map_data.get("nodes", [])
	var node := _find_node(nodes, node_id)
	
	if node == null:
		return
	
	# 开发者模式：对不可达/已访问节点也可以连击5次进入
	if node.visited or not node.reachable:
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
	SceneTransition.change_scene("res://scenes/battle/BattleScene.tscn")

## 进入精英战斗
func _enter_elite_battle(node: MapGenerator.MapNode) -> void:
	GameManager.current_battle_type = "elite"
	SceneTransition.change_scene("res://scenes/battle/BattleScene.tscn")

## 进入BOSS战斗
func _enter_boss_battle(node: MapGenerator.MapNode) -> void:
	GameManager.current_battle_type = "boss"
	var boss_id: String = node.encounter_data.get("boss_id", "")
	GameManager.current_boss_id = boss_id
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


