## 地图生成器 - 生成分支节点地图
class_name MapGenerator
extends RefCounted

## 节点类型
enum NodeType {
	BATTLE,        # 普通战斗
	ELITE,         # 精英战斗
	SHOP,          # 商店
	REST,          # 篝火休息
	MYSTERY,       # 神秘商人
	EVENT,         # 未知事件
	BOSS,          # BOSS
	START,         # 起点
	ALCHEMY,       # 炼丹阁
	FORGE,         # 炼器坊
	TRIBULATION,   # 渡劫
}

## 章节配置
const CHAPTER_CONFIG := {
	0: {"name": "取经路", "layers": 8, "boss_id": "bai_gu_furen"},
	1: {"name": "三打白骨", "layers": 10, "boss_id": "hong_hai_er"},
	2: {"name": "火焰山", "layers": 10, "boss_id": "niu_mo_wang"},
	3: {"name": "西天真经", "layers": 12, "boss_id": "liu_er_mihou"},
}

## 节点类型颜色
const NODE_COLORS := {
	NodeType.BATTLE: Color("D63031"),
	NodeType.ELITE: Color("6C5CE7"),
	NodeType.SHOP: Color("FDCB6E"),
	NodeType.REST: Color("00B894"),
	NodeType.MYSTERY: Color("0984E3"),
	NodeType.EVENT: Color("636E72"),
	NodeType.BOSS: Color("E17055"),
	NodeType.START: Color.WHITE,
	NodeType.ALCHEMY: Color("A29BFE"),
	NodeType.FORGE: Color("E67E22"),
	NodeType.TRIBULATION: Color("FF6B6B"),
}

## 节点类型名称
const NODE_NAMES := {
	NodeType.BATTLE: "战斗",
	NodeType.ELITE: "精英",
	NodeType.SHOP: "商店",
	NodeType.REST: "篝火",
	NodeType.MYSTERY: "神秘商人",
	NodeType.EVENT: "未知事件",
	NodeType.BOSS: "BOSS",
	NodeType.START: "起点",
	NodeType.ALCHEMY: "炼丹阁",
	NodeType.FORGE: "炼器坊",
	NodeType.TRIBULATION: "渡劫",
}

## 节点类型图标
const NODE_ICONS := {
	NodeType.BATTLE: "⚔️",
	NodeType.ELITE: "💀",
	NodeType.SHOP: "🏪",
	NodeType.REST: "🔥",
	NodeType.MYSTERY: "❓",
	NodeType.EVENT: "❗",
	NodeType.BOSS: "👹",
	NodeType.START: "🏠",
	NodeType.ALCHEMY: "🧪",
	NodeType.FORGE: "🔨",
	NodeType.TRIBULATION: "⚡",
}

## 地图节点数据结构
class MapNode:
	var id: int = 0
	var layer: int = 0
	var column: int = 0
	var node_type: int = NodeType.BATTLE
	var connections: Array[int] = []  # 连接到的下一层节点ID
	var visited: bool = false
	var reachable: bool = false
	var position: Vector2 = Vector2.ZERO
	
	## 关联的敌人/事件数据
	var encounter_data: Dictionary = {}

## 生成地图
static func generate_map(chapter: int) -> Dictionary:
	var config: Dictionary = CHAPTER_CONFIG.get(chapter, CHAPTER_CONFIG[0])
	var layers: int = config.get("layers", 8)
	var boss_id: String = config.get("boss_id", "")
	
	var nodes: Array = []
	var node_id_counter := 0
	
	# 起点层（1个节点）
	var start_node := MapNode.new()
	start_node.id = node_id_counter
	start_node.layer = 0
	start_node.column = 1
	start_node.node_type = NodeType.START
	start_node.visited = true
	start_node.reachable = true
	nodes.append(start_node)
	node_id_counter += 1
	
	# 中间层
	var prev_layer_nodes: Array = [start_node]
	
	for layer_idx in range(1, layers + 1):
		var layer_nodes: Array = []
		var num_nodes := _get_layer_node_count(layer_idx, layers)
		
		for col in range(num_nodes):
			var node := MapNode.new()
			node.id = node_id_counter
			node.layer = layer_idx
			node.column = col
			node.node_type = _decide_node_type(layer_idx, layers, chapter)
			nodes.append(node)
			layer_nodes.append(node)
			node_id_counter += 1
		
		# 建立连接（确保每个前层节点至少连接一个后层节点）
		_connect_layers(prev_layer_nodes, layer_nodes)
		
		prev_layer_nodes = layer_nodes
	
	# BOSS层（1个节点）
	var boss_node := MapNode.new()
	boss_node.id = node_id_counter
	boss_node.layer = layers + 1
	boss_node.column = 0
	boss_node.node_type = NodeType.BOSS
	boss_node.encounter_data = {"boss_id": boss_id}
	nodes.append(boss_node)
	
	# 所有最后一层节点连接到BOSS
	for node in prev_layer_nodes:
		node.connections.append(boss_node.id)
	
	# 标记起点可达的节点
	_mark_reachable(nodes, start_node)
	
	# 计算节点位置
	_calculate_positions(nodes, layers + 2)
	
	return {
		"chapter": chapter,
		"chapter_name": config.get("name", ""),
		"nodes": nodes,
		"total_layers": layers + 2,
	}

## 获取每层节点数
static func _get_layer_node_count(layer: int, total_layers: int) -> int:
	# 中间层节点数较多，两端较少
	var mid := total_layers / 2
	var distance := abs(layer - mid) as int
	if distance <= 1:
		return randi_range(2, 3)
	elif distance <= 3:
		return randi_range(2, 3)
	else:
		return randi_range(1, 2)

## 决定节点类型
static func _decide_node_type(layer: int, total_layers: int, _chapter: int) -> int:
	var progress := float(layer) / float(total_layers)
	
	# 第一层固定为战斗
	if layer == 1:
		return NodeType.BATTLE
	
	# 倒数第二层固定为篝火（BOSS前休息）
	if layer == total_layers:
		return NodeType.REST
	
	# 随机决定
	var roll := randf()
	
	if progress < 0.3:
		# 前期：战斗为主
		if roll < 0.5:
			return NodeType.BATTLE
		elif roll < 0.7:
			return NodeType.EVENT
		elif roll < 0.85:
			return NodeType.SHOP
		else:
			return NodeType.REST
	elif progress < 0.7:
		# 中期：精英和事件增多，出现炼丹阁和炼器坊
		if roll < 0.25:
			return NodeType.BATTLE
		elif roll < 0.42:
			return NodeType.ELITE
		elif roll < 0.55:
			return NodeType.EVENT
		elif roll < 0.68:
			return NodeType.SHOP
		elif roll < 0.78:
			return NodeType.REST
		elif roll < 0.85:
			return NodeType.ALCHEMY
		elif roll < 0.92:
			return NodeType.FORGE
		else:
			return NodeType.MYSTERY
	else:
		# 后期：精英和休息，炼丹阁和炼器坊概率提升
		if roll < 0.25:
			return NodeType.BATTLE
		elif roll < 0.45:
			return NodeType.ELITE
		elif roll < 0.58:
			return NodeType.REST
		elif roll < 0.70:
			return NodeType.SHOP
		elif roll < 0.78:
			return NodeType.ALCHEMY
		elif roll < 0.86:
			return NodeType.FORGE
		else:
			return NodeType.EVENT

## 连接两层节点
static func _connect_layers(prev_nodes: Array, next_nodes: Array) -> void:
	# 确保每个前层节点至少连接一个后层节点
	for prev_node in prev_nodes:
		var target_idx := randi() % next_nodes.size()
		prev_node.connections.append(next_nodes[target_idx].id)
	
	# 确保每个后层节点至少被一个前层节点连接
	for next_node in next_nodes:
		var is_connected := false
		for prev_node in prev_nodes:
			if next_node.id in prev_node.connections:
				is_connected = true
				break
		
		if not is_connected:
			var source_idx := randi() % prev_nodes.size()
			prev_nodes[source_idx].connections.append(next_node.id)
	
	# 随机添加额外连接
	for prev_node in prev_nodes:
		if randf() < 0.3:
			var extra_idx := randi() % next_nodes.size()
			if extra_idx not in prev_node.connections:
				prev_node.connections.append(next_nodes[extra_idx].id)

## 标记可达节点
static func _mark_reachable(nodes: Array, start_node: MapNode) -> void:
	start_node.reachable = true
	for conn_id in start_node.connections:
		for node in nodes:
			if node.id == conn_id:
				node.reachable = true
				break

## 计算节点位置（使用比例坐标 0.0~1.0，渲染时再乘以实际容器尺寸）
static func _calculate_positions(nodes: Array, total_layers: int) -> void:
	var map_width := 1.0
	var map_height := 1.0
	var layer_spacing := map_width / float(total_layers)
	
	# 按层分组
	var layers_dict: Dictionary = {}
	for node in nodes:
		if not layers_dict.has(node.layer):
			layers_dict[node.layer] = []
		layers_dict[node.layer].append(node)
	
	# 计算每个节点位置
	for layer_idx in layers_dict:
		var layer_nodes: Array = layers_dict[layer_idx]
		var count := layer_nodes.size()
		var col_spacing := map_height / float(count + 1)
		
		for i in range(count):
			var node: MapNode = layer_nodes[i]
			node.position = Vector2(
				0.05 + layer_idx * layer_spacing,
				col_spacing * (i + 1)
			)
