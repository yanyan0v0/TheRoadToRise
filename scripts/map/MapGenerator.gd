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

## 章节配置（chapter 1/2/3 对应三章）
const CHAPTER_CONFIG := {
	1: {"name": "取经缘起", "layers": 9},
	2: {"name": "妖魔纵横", "layers": 11},
	3: {"name": "西天真经", "layers": 13},
}

## BOSS敌人池（从DataManager缓存获取）
static var _boss_pool_cache: Array[String] = []

static func _get_boss_pool() -> Array[String]:
	if _boss_pool_cache.is_empty():
		_boss_pool_cache = DataManager.get_boss_pool()
	return _boss_pool_cache

## 已分配的BOSS（用于确保不同章节不重复）
static var _assigned_bosses: Array[String] = []

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

## 节点类型图标（48x48 png图片路径）
const NODE_ICONS := {
	NodeType.BATTLE: "res://ui/images/map/icon/battle.png",
	NodeType.ELITE: "res://ui/images/map/icon/elite.png",
	NodeType.SHOP: "res://ui/images/map/icon/shop.png",
	NodeType.REST: "res://ui/images/map/icon/rest.png",
	NodeType.MYSTERY: "res://ui/images/map/icon/mystery.png",
	NodeType.EVENT: "res://ui/images/map/icon/event.png",
	NodeType.BOSS: "res://ui/images/map/icon/boss.png",
	NodeType.START: "res://ui/images/map/icon/start.png",
	NodeType.ALCHEMY: "res://ui/images/map/icon/alchemy.png",
	NodeType.FORGE: "res://ui/images/map/icon/forge.png",
	NodeType.TRIBULATION: "res://ui/images/map/icon/tribulation.png",
}

## 普通战斗敌人池缓存（从DataManager按chapter动态获取）
static var _normal_pools_cache: Dictionary = {}

static func _get_normal_enemy_pools(chapter: int) -> Array:
	if not _normal_pools_cache.has(chapter):
		_normal_pools_cache[chapter] = DataManager.get_normal_enemy_pools(chapter)
	return _normal_pools_cache.get(chapter, [])

## 精英敌人池缓存（从DataManager动态获取）
static var _elite_pool_cache: Array[String] = []

static func _get_elite_pool() -> Array[String]:
	if _elite_pool_cache.is_empty():
		_elite_pool_cache = DataManager.get_elite_pool()
	return _elite_pool_cache

## 节点类型背景图
const NODE_BGS := {
	NodeType.BATTLE: "res://ui/images/map/icon/battle.png",
	NodeType.ELITE: "res://ui/images/map/icon/elite.png",
	NodeType.SHOP: "res://ui/images/map/icon/shop.png",
	NodeType.REST: "res://ui/images/map/icon/rest.png",
	NodeType.MYSTERY: "res://ui/images/map/icon/mystery.png",
	NodeType.EVENT: "res://ui/images/map/icon/event.png",
	NodeType.BOSS: "res://ui/images/map/icon/boss.png",
	NodeType.START: "res://ui/images/map/icon/start.png",
	NodeType.ALCHEMY: "res://ui/images/map/icon/alchemy.png",
	NodeType.FORGE: "res://ui/images/map/icon/forge.png",
	NodeType.TRIBULATION: "res://ui/images/map/icon/tribulation.png",
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
	var config: Dictionary = CHAPTER_CONFIG.get(chapter, CHAPTER_CONFIG[1])
	var layers: int = config.get("layers", 8)
	
	# 从BOSS_POOL中随机选择一个未被其他章节使用的BOSS
	var boss_id: String = _pick_random_boss(chapter)
	
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
			# 为战斗/精英节点分配敌人数据
			_assign_encounter_data(node, chapter)
			nodes.append(node)
			layer_nodes.append(node)
			node_id_counter += 1
		
		# 建立连接（确保每个前层节点至少连接一个后层节点）
		_connect_layers(prev_layer_nodes, layer_nodes)
		
		prev_layer_nodes = layer_nodes
	
	# 确保每种节点类型至少出现一次（除了渡劫和起点和BOSS和神秘商人）
	_ensure_all_node_types(nodes, chapter)
	
	# 神秘商人节点特殊处理：最多出现1次，多余的替换为战斗节点
	_limit_mystery_nodes(nodes, chapter)
	
	# BOSS层（1个节点）
	var boss_node := MapNode.new()
	boss_node.id = node_id_counter
	boss_node.layer = layers + 1
	boss_node.column = 0
	boss_node.node_type = NodeType.BOSS
	var boss_data: Dictionary = DataManager.get_enemy(boss_id)
	var boss_display_name: String = boss_data.get("enemy_name", "BOSS")
	var boss_image: String = "res://ui/images/battle/enemy/%s.png" % boss_id
	boss_node.encounter_data = {"boss_id": boss_id, "display_name": boss_display_name, "boss_image": boss_image}
	nodes.append(boss_node)
	
	# 所有最后一层节点连接到BOSS
	for node in prev_layer_nodes:
		node.connections.append(boss_node.id)
	
	# 标记起点可达的节点
	_mark_reachable(nodes, start_node)
	
	# 记录已分配的BOSS
	if boss_id != "" and boss_id not in _assigned_bosses:
		_assigned_bosses.append(boss_id)
	
	# 计算节点位置
	_calculate_positions(nodes, layers + 2)
	
	return {
		"chapter": chapter,
		"chapter_name": config.get("name", ""),
		"nodes": nodes,
		"total_layers": layers + 2,
	}

## 从BOSS池中随机选择一个不重复的BOSS（优先选择当前章节的BOSS）
static func _pick_random_boss(chapter: int = -1) -> String:
	var pool: Array[String] = _get_boss_pool()
	if pool.is_empty():
		return "bai_gu_jing"
	
	# Try to pick a boss matching the current chapter first
	if chapter >= 0:
		var chapter_bosses: Array[String] = []
		for boss_id in pool:
			if boss_id not in _assigned_bosses:
				var data: Dictionary = DataManager.get_enemy(boss_id)
				if data.get("chapter", -1) == chapter:
					chapter_bosses.append(boss_id)
		if not chapter_bosses.is_empty():
			return chapter_bosses[randi() % chapter_bosses.size()]
	
	# Fallback: pick any unassigned boss
	var available: Array[String] = []
	for boss_id in pool:
		if boss_id not in _assigned_bosses:
			available.append(boss_id)
	# If all bosses assigned, reset and allow all
	if available.is_empty():
		_assigned_bosses.clear()
		for boss_id in pool:
			available.append(boss_id)
	return available[randi() % available.size()]

## 重置已分配的BOSS记录和缓存（新游戏时调用）
static func reset_assigned_bosses() -> void:
	_assigned_bosses.clear()
	_boss_pool_cache.clear()
	_normal_pools_cache.clear()
	_elite_pool_cache.clear()

## 获取每层节点数（最少1个，最多6个）
static func _get_layer_node_count(layer: int, total_layers: int) -> int:
	# 中间层节点数较多，两端较少
	var mid := total_layers / 2
	var distance := abs(layer - mid) as int
	if distance <= 1:
		return randi_range(3, 6)
	elif distance <= 3:
		return randi_range(2, 6)
	else:
		return randi_range(1, 6)

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

## 连接两层节点（保证连线单调性，杜绝交叉）
## 单调性原理：若按 column 升序遍历前层，每个前层节点连接的后层节点索引也单调不减，
## 则任意两条边 (a1->b1) 和 (a2->b2) 满足 a1.col<=a2.col 时 b1.idx<=b2.idx，必然不交叉。
## 前提假设：prev_nodes/next_nodes 的数组索引 == column 顺序，而 _calculate_positions
## 会按 column 顺序自上而下排布节点（column 递增 => y 递增）。
static func _connect_layers(prev_nodes: Array, next_nodes: Array) -> void:
	var prev_count := prev_nodes.size()
	var next_count := next_nodes.size()
	if prev_count == 0 or next_count == 0:
		return
	
	# 记录每个前层节点已连接的后层索引列表（用于随机扩连时保持单调）
	var prev_connected_indices: Array = []
	for _i in range(prev_count):
		prev_connected_indices.append([] as Array)
	
	# Step 1：基础映射——前层节点 i 连接到按比例映射的后层索引
	# 由于 i 单调递增，mapped_idx 必单调不减，因此基础边全部无交叉
	var base_mapped: Array[int] = []
	for i in range(prev_count):
		var mapped_idx := int(round(float(i) / float(max(prev_count - 1, 1)) * float(max(next_count - 1, 1))))
		mapped_idx = clampi(mapped_idx, 0, next_count - 1)
		prev_nodes[i].connections.append(next_nodes[mapped_idx].id)
		prev_connected_indices[i].append(mapped_idx)
		base_mapped.append(mapped_idx)
	
	# Step 2：确保每个后层节点至少被连接一次（单调补连）
	# 对未被连接的后层节点 j，寻找一个前层节点 i，使得将 j 加入 i 的连接后，
	# 整体仍保持单调（即 i 的已连索引 min<=j<=max 之外仍满足相邻约束）
	for j in range(next_count):
		var is_connected := false
		for prev_node in prev_nodes:
			if next_nodes[j].id in prev_node.connections:
				is_connected = true
				break
		if is_connected:
			continue
		
		# 找到 base_mapped 中最接近 j 的前层节点：
		# - 若 j 大于所有 base_mapped[i] 的最大值：选择 base_mapped 最大值对应的最后一个前层
		# - 若 j 小于所有 base_mapped[i] 的最小值：选择第一个前层
		# - 否则：选择 base_mapped[i] <= j 的最大 i（保证插入后仍单调）
		var best_idx := 0
		if j <= base_mapped[0]:
			best_idx = 0
		elif j >= base_mapped[prev_count - 1]:
			best_idx = prev_count - 1
		else:
			for k in range(prev_count - 1, -1, -1):
				if base_mapped[k] <= j:
					best_idx = k
					break
		prev_nodes[best_idx].connections.append(next_nodes[j].id)
		prev_connected_indices[best_idx].append(j)
	
	# Step 3：随机额外连接（严格保持单调）
	# 对每个前层节点 i，额外连接 mapped_idx ± 1，但必须满足：
	# - extra_idx >= 前一个前层节点(i-1) 已连接的最大索引
	# - extra_idx <= 后一个前层节点(i+1) 已连接的最小索引
	# 这样可保证所有边按 (prev_col, next_idx) 排序后仍单调不减
	for i in range(prev_count):
		if randf() >= 0.2:
			continue
		var mapped_idx: int = base_mapped[i]
		var offset := randi_range(-1, 1)
		if offset == 0:
			continue
		var extra_idx: int = clampi(mapped_idx + offset, 0, next_count - 1)
		if next_nodes[extra_idx].id in prev_nodes[i].connections:
			continue
		# 单调约束：extra_idx 必须不小于 i-1 的最大已连索引
		if i > 0:
			var prev_max: int = -1
			for idx in prev_connected_indices[i - 1]:
				if idx > prev_max:
					prev_max = idx
			if extra_idx < prev_max:
				continue
		# 单调约束：extra_idx 必须不大于 i+1 的最小已连索引
		if i < prev_count - 1:
			var next_min: int = next_count
			for idx in prev_connected_indices[i + 1]:
				if idx < next_min:
					next_min = idx
			if extra_idx > next_min:
				continue
		prev_nodes[i].connections.append(next_nodes[extra_idx].id)
		prev_connected_indices[i].append(extra_idx)

## 需要保证至少出现一次的节点类型（除了渡劫、起点、BOSS）
const REQUIRED_NODE_TYPES := [
	NodeType.BATTLE,
	NodeType.ELITE,
	NodeType.SHOP,
	NodeType.REST,
	NodeType.EVENT,
	NodeType.ALCHEMY,
	NodeType.FORGE,
]

## 确保每种节点类型至少出现一次（除了渡劫）
static func _ensure_all_node_types(nodes: Array, chapter: int) -> void:
	# 统计已有的节点类型
	var existing_types: Dictionary = {}
	for node in nodes:
		existing_types[node.node_type] = true
	
	# 找出缺失的类型
	var missing_types: Array = []
	for req_type in REQUIRED_NODE_TYPES:
		if not existing_types.has(req_type):
			missing_types.append(req_type)
	
	if missing_types.is_empty():
		return
	
	# 收集可替换的中间层节点（排除起点层、BOSS前休息层、BOSS层）
	var replaceable_nodes: Array = []
	for node in nodes:
		# 跳过起点、BOSS节点
		if node.node_type == NodeType.START or node.node_type == NodeType.BOSS:
			continue
		if node.layer <= 0:
			continue
		# 跳过BOSS前休息层（最后一个中间层）
		if node.node_type == NodeType.REST:
			# 检查是否是倒数第二层的休息节点（BOSS前），保留至少一个
			var rest_count := 0
			for n in nodes:
				if n.node_type == NodeType.REST:
					rest_count += 1
			if rest_count <= 1:
				continue
		# 只替换重复出现的类型（出现次数>1的）
		var type_count := 0
		for n in nodes:
			if n.node_type == node.node_type:
				type_count += 1
		if type_count > 1:
			replaceable_nodes.append(node)
	
	# 随机替换
	for missing_type in missing_types:
		if replaceable_nodes.is_empty():
			break
		var idx := randi() % replaceable_nodes.size()
		var target_node: MapNode = replaceable_nodes[idx]
		target_node.node_type = missing_type
		_assign_encounter_data(target_node, chapter)
		replaceable_nodes.remove_at(idx)

## 限制神秘商人节点最多出现1次，多余的替换为战斗节点
static func _limit_mystery_nodes(nodes: Array, chapter: int) -> void:
	var mystery_nodes: Array = []
	for node in nodes:
		if node.node_type == NodeType.MYSTERY:
			mystery_nodes.append(node)
	
	# 如果神秘商人超过1个，随机保留1个，其余替换为战斗
	if mystery_nodes.size() > 1:
		# 随机打乱，保留第一个
		mystery_nodes.shuffle()
		for i in range(1, mystery_nodes.size()):
			mystery_nodes[i].node_type = NodeType.BATTLE
			_assign_encounter_data(mystery_nodes[i], chapter)

## 标记可达节点
static func _mark_reachable(nodes: Array, start_node: MapNode) -> void:
	start_node.reachable = true
	for conn_id in start_node.connections:
		for node in nodes:
			if node.id == conn_id:
				node.reachable = true
				break

## 为节点分配敌人/遭遇数据
static func _assign_encounter_data(node: MapNode, chapter: int) -> void:
	if node.node_type == NodeType.BATTLE:
		var pools: Array = _get_normal_enemy_pools(chapter)
		if pools.is_empty():
			pools = _get_normal_enemy_pools(1)
		var enemy_ids: Array = _pick_unique_pool(pools)
		# 拼接所有敌人的名称作为显示名
		var name_parts: Array = []
		for eid in enemy_ids:
			var edata: Dictionary = DataManager.get_enemy(eid)
			name_parts.append(edata.get("enemy_name", eid))
		var display_name: String = "、".join(name_parts)
		node.encounter_data = {
			"enemy_ids": enemy_ids,
			"display_name": display_name,
		}
	elif node.node_type == NodeType.ELITE:
		var elite_pool: Array = []
		for eid in _get_elite_pool():
			elite_pool.append([eid])
		var chosen: Array = _pick_unique_pool(elite_pool)
		var elite_id: String = chosen[0]
		var enemy_data: Dictionary = DataManager.get_enemy(elite_id)
		var display_name: String = enemy_data.get("enemy_name", elite_id)
		node.encounter_data = {
			"enemy_ids": [elite_id],
			"display_name": display_name,
		}

## Pick a unique enemy pool that hasn't been encountered yet
static func _pick_unique_pool(pools: Array) -> Array:
	# Filter out already encountered pools
	var available: Array = []
	for pool in pools:
		var pool_key: String = ",".join(PackedStringArray(pool))
		if pool_key not in GameManager.encountered_enemy_pools:
			available.append(pool)
	# If all pools have been used, reset and allow all
	if available.is_empty():
		available = pools.duplicate()
	var chosen: Array = available[randi() % available.size()]
	# Record this pool as encountered
	var chosen_key: String = ",".join(PackedStringArray(chosen))
	GameManager.encountered_enemy_pools.append(chosen_key)
	return chosen

## 节点间距常量（像素）
const NODE_SPACING_H_MIN := 170  # 水平层间距最小值（像素）
const NODE_SPACING_H_MAX := 180  # 水平层间距最大值（像素）
const NODE_SPACING_V_MIN := 110  # 垂直节点间距最小值（像素）
const NODE_SPACING_V_MAX := 120  # 垂直节点间距最大值（像素）
const NODE_MARGIN_LEFT := 250    # 左侧边距（像素）
const NODE_JITTER_X := 14.0      # 节点x方向随机错位幅度（±像素）
const NODE_JITTER_Y := 18.0      # 节点y方向随机错位幅度（±像素）
const NODE_MARGIN_TOP_MIN := 40.0  # 节点群距顶部最小边距
const NODE_MARGIN_BOTTOM_MIN := 40.0  # 节点群距底部最小边距

## NodesContainer 在 MapContainer 局部坐标系下的可视区域
## 对应 MapScene.tscn: MapContainer.custom_minimum_size.y = 666, NodesContainer.offset_bottom = -39
const NODES_CONTAINER_HEIGHT := 627.0  # 666 - 39
const NODES_CONTAINER_TOP := 0.0       # NodesContainer 顶部（局部坐标系）

## 计算节点位置（使用像素坐标，节点间距在动态范围内，并加入错位抖动）
## 节点群在垂直方向相对容器居中：绘制完成后基于实际 min/max y 再做整体偏移
static func _calculate_positions(nodes: Array, _total_layers: int) -> void:
	# 按层分组
	var layers_dict: Dictionary = {}
	for node in nodes:
		if not layers_dict.has(node.layer):
			layers_dict[node.layer] = []
		layers_dict[node.layer].append(node)
	
	# 找到最大列数
	var max_count := 1
	for layer_idx in layers_dict:
		var count: int = layers_dict[layer_idx].size()
		if count > max_count:
			max_count = count
	
	# 排序层索引，便于按序累加动态水平步长
	var sorted_layers: Array = layers_dict.keys()
	sorted_layers.sort()
	
	# 预计算每层的x基准（layer0 = NODE_MARGIN_LEFT，其后每层累加一个随机步长）
	var layer_x_base: Dictionary = {}
	var current_x: float = float(NODE_MARGIN_LEFT)
	var last_layer: int = -1
	for layer_idx in sorted_layers:
		if last_layer < 0:
			layer_x_base[layer_idx] = current_x
		else:
			var step_h: float = float(randi_range(NODE_SPACING_H_MIN, NODE_SPACING_H_MAX))
			current_x += step_h
			layer_x_base[layer_idx] = current_x
		last_layer = layer_idx
	
	# 获取 NodesContainer 的中心 y 作为参考（BOSS / 节点群居中基准）
	# 节点坐标位于 NodesContainer 局部坐标系，所以不依赖 viewport_height
	var container_height: float = NODES_CONTAINER_HEIGHT
	var container_center_y: float = NODES_CONTAINER_TOP + container_height / 2.0
	
	# Pass 1：基于最大列数先算一个"参考中心高度"，节点围绕它上下展开
	# 这里使用中间值估算每层高度，稍后通过 min/max y 再居中，不会影响最终结果
	var ref_step_v: float = float(NODE_SPACING_V_MIN + NODE_SPACING_V_MAX) / 2.0
	var ref_center_y: float = container_center_y
	
	# 记录BOSS节点，稍后单独处理
	var boss_nodes: Array = []
	
	for layer_idx in sorted_layers:
		var layer_nodes: Array = layers_dict[layer_idx]
		var count := layer_nodes.size()
		
		# 每层使用独立的动态垂直步长
		var step_v: float = float(randi_range(NODE_SPACING_V_MIN, NODE_SPACING_V_MAX))
		# 本层总高度，基于本层动态步长
		var layer_height: float = (count - 1) * step_v
		# 本层第一个节点的y起点：让本层围绕 ref_center_y 居中
		var y_start: float = ref_center_y - layer_height / 2.0
		
		var base_x: float = layer_x_base[layer_idx]
		
		for i in range(count):
			var node: MapNode = layer_nodes[i]
			if node.node_type == NodeType.BOSS:
				# BOSS暂记录，后面单独放到容器中线
				boss_nodes.append(node)
				node.position = Vector2(base_x, container_center_y)
				continue
			# 起点与终点附近列的节点，抖动略收敛（视觉更稳）
			var jitter_scale: float = 1.0
			if count == 1:
				jitter_scale = 0.5
			var jx: float = randf_range(-NODE_JITTER_X, NODE_JITTER_X) * jitter_scale
			var jy: float = randf_range(-NODE_JITTER_Y, NODE_JITTER_Y) * jitter_scale
			node.position = Vector2(
				base_x + jx,
				y_start + i * step_v + jy
			)
	
	# Pass 2：基于所有非BOSS节点的实际 min/max y，将节点群相对容器高度居中
	var min_y: float = INF
	var max_y: float = -INF
	for node in nodes:
		if node.node_type == NodeType.BOSS or node.node_type == NodeType.START:
			continue
		if node.position.y < min_y:
			min_y = node.position.y
		if node.position.y > max_y:
			max_y = node.position.y
	
	if min_y != INF and max_y != -INF:
		var cluster_height: float = max_y - min_y
		# 目标：让节点群在 NodesContainer [0, container_height] 区间内居中
		var target_min_y: float = (container_height - cluster_height) / 2.0
		# 保底顶部边距
		if target_min_y < NODE_MARGIN_TOP_MIN:
			target_min_y = NODE_MARGIN_TOP_MIN
		# 保底底部边距：若节点群底部超出容器底 - NODE_MARGIN_BOTTOM_MIN，则向上压
		var max_allowed_min_y: float = container_height - NODE_MARGIN_BOTTOM_MIN - cluster_height
		if target_min_y > max_allowed_min_y:
			target_min_y = max_allowed_min_y
		var dy: float = target_min_y - min_y
		# 对所有非BOSS节点应用整体偏移（START 一并偏移，与主节点群保持一致视觉）
		for node in nodes:
			if node.node_type == NodeType.BOSS:
				continue
			node.position.y += dy
	
	# BOSS节点：固定在 NodesContainer 垂直中线（保持原行为）
	for boss in boss_nodes:
		boss.position.y = container_center_y
	
	# Pass 3：剔除超出 NodesContainer 可视范围的节点
	# 垂直可视范围：[节点半径, container_height - 节点半径]
	# 水平下限：NODE_MARGIN_LEFT（右侧由容器动态撑开，不限制）
	_cull_out_of_bounds_nodes(nodes, container_height)

## 节点半径（按钮尺寸的一半，用于边界判定）——与 MapScene.NODE_BUTTON_SIZE 保持一致
const NODE_RADIUS := 20.0

## 剔除超出可视容器的节点，并修复连接断链
## container_height: NodesContainer 在其局部坐标系下的可视高度
static func _cull_out_of_bounds_nodes(nodes: Array, container_height: float) -> void:
	# 顶部裁剪边界：优先使用 NODE_MARGIN_TOP_MIN，再退化为节点半径
	var top_margin: float = max(NODE_MARGIN_TOP_MIN, NODE_RADIUS)
	var top_limit: float = top_margin
	# 底部裁剪边界：优先使用 NODE_MARGIN_BOTTOM_MIN，再退化为节点半径
	var bottom_margin: float = max(NODE_MARGIN_BOTTOM_MIN, NODE_RADIUS)
	var bottom_limit: float = container_height - bottom_margin
	var left_limit: float = float(NODE_MARGIN_LEFT) - NODE_RADIUS
	
	# 收集需剔除的节点ID（保留START/BOSS，不剔除关键节点）
	var culled_ids: Dictionary = {}  # id -> true
	for node in nodes:
		if node.node_type == NodeType.START or node.node_type == NodeType.BOSS:
			continue
		var p: Vector2 = node.position
		if p.y < top_limit or p.y > bottom_limit or p.x < left_limit:
			culled_ids[node.id] = true
	
	if culled_ids.is_empty():
		return
	
	# id -> node 索引，便于重连
	var id_to_node: Dictionary = {}
	for node in nodes:
		id_to_node[node.id] = node
	
	# 修复连接断链（最近原则）：
	# 对每个未被剔除节点，处理它的每一条 connection：
	#   - 若目标未被剔除：保留
	#   - 若目标被剔除：BFS 沿被剔除节点的 connections 找最近一层的未剔除后继，
	#     在其中再用"欧式距离最小"挑选一个作为替换目标
	# 这样既保证连线不会跨多层，又保证视觉上走最短路径
	for node in nodes:
		if culled_ids.has(node.id):
			continue
		var new_conns: Array[int] = []
		var seen: Dictionary = {}
		for conn_id in node.connections:
			var target_id: int = _find_nearest_valid_successor(
				conn_id, node, id_to_node, culled_ids
			)
			if target_id < 0 or target_id == node.id:
				continue
			if seen.has(target_id):
				continue
			seen[target_id] = true
			new_conns.append(target_id)
		node.connections = new_conns
	
	# 从 nodes 数组中移除被剔除节点（倒序删除）
	for i in range(nodes.size() - 1, -1, -1):
		var n: MapNode = nodes[i]
		if culled_ids.has(n.id):
			nodes.remove_at(i)
	
	# 最终兜底：消除因 BFS 桥接引入的跨层交叉线
	_remove_edge_crossings(nodes)

## 消除相邻层之间的交叉线（方案 B 兜底）
## 核心思路：两条边 (a1->b1)、(a2->b2) 交叉的充要条件是
##   a1.y < a2.y 但 b1.y > b2.y（或 a1.y > a2.y 但 b1.y < b2.y）
## 即前后两端 y 顺序相反。通过交换两条边的终点 (a1->b2, a2->b1) 即可消除交叉，
## 且不改变 a1、a2 各自的出度（可达性语义保留）。
## 由于交换后可能引发新的交叉，采用"直到稳定"的循环，最多迭代 N 次避免极端情况死循环。
static func _remove_edge_crossings(nodes: Array) -> void:
	if nodes.is_empty():
		return
	
	# 建立 id -> node 索引
	var id_to_node: Dictionary = {}
	for node in nodes:
		id_to_node[node.id] = node
	
	# 按"from.layer"收集所有边 (from_node, to_node)，分层存储便于两两比较
	# key: from.layer -> Array of [from_node, to_node_id, conn_idx_in_from]
	var edges_by_layer: Dictionary = {}
	for node in nodes:
		for ci in range(node.connections.size()):
			var to_id: int = node.connections[ci]
			if not id_to_node.has(to_id):
				continue
			if not edges_by_layer.has(node.layer):
				edges_by_layer[node.layer] = []
			edges_by_layer[node.layer].append([node, to_id, ci])
	
	var max_iterations := 8  # 兜底上限，避免异常数据导致死循环
	for _iter in range(max_iterations):
		var changed := false
		for layer_key in edges_by_layer.keys():
			var edges: Array = edges_by_layer[layer_key]
			var n_edges: int = edges.size()
			# 两两比较本层出发的所有边
			for i in range(n_edges):
				for j in range(i + 1, n_edges):
					var e1: Array = edges[i]
					var e2: Array = edges[j]
					var a1: MapNode = e1[0]
					var a2: MapNode = e2[0]
					var b1: MapNode = id_to_node.get(e1[1])
					var b2: MapNode = id_to_node.get(e2[1])
					if b1 == null or b2 == null:
						continue
					# 仅处理同一对相邻层之间的边（b1.layer 必须等于 b2.layer 才可能视觉交叉）
					if b1.layer != b2.layer:
						continue
					# 同一条边或同一起点同一终点，无需处理
					if a1 == a2 and b1 == b2:
						continue
					# 交叉检测：a 与 b 两端 y 顺序相反
					var ay_diff: float = a1.position.y - a2.position.y
					var by_diff: float = b1.position.y - b2.position.y
					if ay_diff == 0.0 or by_diff == 0.0:
						continue
					if (ay_diff > 0.0) == (by_diff > 0.0):
						continue  # 同向，不交叉
					# 交叉！交换两条边的终点：a1->b2, a2->b1
					# 但需避免交换后产生重复连接（a1 已有 b2.id，或 a2 已有 b1.id）
					if b2.id in a1.connections:
						continue
					if b1.id in a2.connections:
						continue
					var ci1: int = e1[2]
					var ci2: int = e2[2]
					a1.connections[ci1] = b2.id
					a2.connections[ci2] = b1.id
					# 更新 edges 列表中的终点引用，便于后续迭代
					edges[i] = [a1, b2.id, ci1]
					edges[j] = [a2, b1.id, ci2]
					changed = true
		if not changed:
			break
## 策略（最近原则）：
##   1. 若 start_id 本身未被剔除，直接返回 start_id
##   2. 否则从 start_id 逐层 BFS，在首次遇到未被剔除节点的"同一层"里
##      选与 from_node 欧式距离最小的一个返回
##   3. 整条链都被剔除则返回 -1
static func _find_nearest_valid_successor(
	start_id: int,
	from_node: MapNode,
	id_to_node: Dictionary,
	culled_ids: Dictionary
) -> int:
	# start_id 未被剔除：直接使用（保持原连接，不需要桥接）
	if not culled_ids.has(start_id):
		return start_id
	
	# BFS 遍历：一次扩展一层；每层收集所有"未被剔除节点"作为候选
	var visited: Dictionary = {start_id: true}
	var frontier: Array = [start_id]
	while not frontier.is_empty():
		var next_frontier: Array = []
		var candidates: Array = []  # 本层中未被剔除的节点 ID
		for cur_id in frontier:
			var cur_node: MapNode = id_to_node.get(cur_id)
			if cur_node == null:
				continue
			for succ_id in cur_node.connections:
				if visited.has(succ_id):
					continue
				visited[succ_id] = true
				if culled_ids.has(succ_id):
					next_frontier.append(succ_id)
				else:
					candidates.append(succ_id)
		# 本层若有未被剔除候选，直接按最近距离挑一个，不再继续下钻
		if not candidates.is_empty():
			var best_id: int = -1
			var best_dist_sq: float = INF
			for cid in candidates:
				var cand_node: MapNode = id_to_node.get(cid)
				if cand_node == null:
					continue
				var d: float = from_node.position.distance_squared_to(cand_node.position)
				if d < best_dist_sq:
					best_dist_sq = d
					best_id = cid
			return best_id
		frontier = next_frontier
	
	# 整条链都被剔除
	return -1
