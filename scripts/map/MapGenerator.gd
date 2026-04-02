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
	0: {"name": "取经缘起", "layers": 9},
	1: {"name": "妖魔纵横", "layers": 11},
	2: {"name": "心魔迷障", "layers": 11},
	3: {"name": "西天真经", "layers": 13},
}

## BOSS敌人池（从enemies.json中所有boss类型的敌人）
const BOSS_POOL := [
	"bai_gu_jing",
	"sheng_ying_da_wang",
	"niu_mo_wang",
	"liu_er_mi_hou",
	"si_guai",
	"huang_mei_lao_fo",
	"da_peng_jin_chi_diao",
	"jiu_ling_yuan_sheng",
]

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

## 普通战斗敌人池（按章节）
const NORMAL_ENEMY_POOLS := {
	0: [
		["hun_shi_mo_wang", "yin_jiang_jun"],
		["xiong_shan_jun", "te_chu_shi"],
		["hei_feng_guai", "bai_yi_xiu_shi"],
		["ling_xu_zi", "yin_jiang_jun", "te_chu_shi"],
		["hun_shi_mo_wang", "xiong_shan_jun"],
		["hei_feng_guai", "ling_xu_zi"],
	],
	1: [
		["huang_feng_guai", "jing_xi_gui"],
		["bai_gu_jing", "yin_jiao"],
		["ling_li_chong", "shi_li_guai"],
		["huang_pao_guai", "jing_xi_gui", "ling_li_chong"],
		["tuo_long", "shi_li_guai"],
	],
	2: [
		["hu_li_da_xian", "lu_li_da_xian"],
		["yang_li_da_xian", "jin_yu_guai"],
		["ru_yi_zhen_xian", "hu_li_da_xian", "tuo_long"],
		["tie_shan_gong_zhu", "yu_mian_hu_li"],
		["jin_yu_guai", "lu_li_da_xian", "yang_li_da_xian"],
	],
	3: [
		["ben_bo_er_ba", "ba_bo_er_ben", "gu_zhi_gong"],
		["xing_xian", "ju_mang_guai"],
		["qi_zhi_zhu_jing", "mi_ma_lu_ban"],
		["bai_lu_guai", "bai_mian_hu_li", "jin_bi_lao_shu_jing"],
	],
}

## 精英敌人池
const ELITE_ENEMY_POOLS := [
	"sheng_ying_da_wang", "pi_pa_jing", "liu_er_mi_hou",
	"jiu_tou_chong", "sai_tai_sui", "bai_yan_mo_jun",
	"shi_wang", "xiang_wang", "jiu_ling_yuan_sheng", "pi_han_da_wang",
]

## 节点类型背景图（100x100 显示）
const NODE_BGS := {
	NodeType.BATTLE: "res://ui/images/map/bg/battle.png",
	NodeType.ELITE: "res://ui/images/map/bg/elite.png",
	NodeType.SHOP: "res://ui/images/map/bg/shop.png",
	NodeType.REST: "res://ui/images/map/bg/rest.png",
	NodeType.MYSTERY: "res://ui/images/map/bg/mystery.png",
	NodeType.EVENT: "res://ui/images/map/bg/event.png",
	NodeType.BOSS: "res://ui/images/map/bg/boss.png",
	NodeType.START: "res://ui/images/map/bg/start.png",
	NodeType.ALCHEMY: "res://ui/images/map/bg/alchemy.png",
	NodeType.FORGE: "res://ui/images/map/bg/forge.png",
	NodeType.TRIBULATION: "res://ui/images/map/bg/tribulation.png",
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
	
	# 从BOSS_POOL中随机选择一个未被其他章节使用的BOSS
	var boss_id: String = _pick_random_boss()
	
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
	
	# 确保每种节点类型至少出现一次（除了渡劫和起点和BOSS）
	_ensure_all_node_types(nodes, chapter)
	
	# BOSS层（1个节点）
	var boss_node := MapNode.new()
	boss_node.id = node_id_counter
	boss_node.layer = layers + 1
	boss_node.column = 0
	boss_node.node_type = NodeType.BOSS
	var boss_data: Dictionary = DataManager.get_enemy(boss_id)
	var boss_display_name: String = boss_data.get("enemy_name", "BOSS")
	var boss_image: String = "res://ui/images/global/boss/%s.png" % boss_id
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

## 从BOSS池中随机选择一个不重复的BOSS
static func _pick_random_boss() -> String:
	# 过滤掉已分配的BOSS
	var available: Array[String] = []
	for boss_id in BOSS_POOL:
		if boss_id not in _assigned_bosses:
			available.append(boss_id)
	# 如果所有BOSS都已分配，重置并重新选择
	if available.is_empty():
		_assigned_bosses.clear()
		for boss_id in BOSS_POOL:
			available.append(boss_id)
	return available[randi() % available.size()]

## 重置已分配的BOSS记录（新游戏时调用）
static func reset_assigned_bosses() -> void:
	_assigned_bosses.clear()

## 获取每层节点数（最少1个，最多4个）
static func _get_layer_node_count(layer: int, total_layers: int) -> int:
	# 中间层节点数较多，两端较少
	var mid := total_layers / 2
	var distance := abs(layer - mid) as int
	if distance <= 1:
		return randi_range(3, 4)
	elif distance <= 3:
		return randi_range(2, 4)
	else:
		return randi_range(1, 3)

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

## 连接两层节点（优先连接位置相近的节点，减少交叉线）
static func _connect_layers(prev_nodes: Array, next_nodes: Array) -> void:
	var prev_count := prev_nodes.size()
	var next_count := next_nodes.size()
	
	# 为每个前层节点分配最近的后层节点（按列位置比例映射）
	for i in range(prev_count):
		# 将前层节点的索引映射到后层节点的索引范围
		var mapped_idx := int(round(float(i) / float(max(prev_count - 1, 1)) * float(max(next_count - 1, 1))))
		mapped_idx = clampi(mapped_idx, 0, next_count - 1)
		prev_nodes[i].connections.append(next_nodes[mapped_idx].id)
	
	# 确保每个后层节点至少被一个前层节点连接
	for j in range(next_count):
		var is_connected := false
		for prev_node in prev_nodes:
			if next_nodes[j].id in prev_node.connections:
				is_connected = true
				break
		
		if not is_connected:
			# 选择位置最近的前层节点
			var best_idx := int(round(float(j) / float(max(next_count - 1, 1)) * float(max(prev_count - 1, 1))))
			best_idx = clampi(best_idx, 0, prev_count - 1)
			prev_nodes[best_idx].connections.append(next_nodes[j].id)
	
	# 少量随机额外连接（只连接相邻节点，避免交叉）
	for i in range(prev_count):
		if randf() < 0.2:
			var mapped_idx := int(round(float(i) / float(max(prev_count - 1, 1)) * float(max(next_count - 1, 1))))
			# 只在相邻范围内随机选择（±1）
			var offset := randi_range(-1, 1)
			var extra_idx := clampi(mapped_idx + offset, 0, next_count - 1)
			if next_nodes[extra_idx].id not in prev_nodes[i].connections:
				prev_nodes[i].connections.append(next_nodes[extra_idx].id)

## 需要保证至少出现一次的节点类型（除了渡劫、起点、BOSS）
const REQUIRED_NODE_TYPES := [
	NodeType.BATTLE,
	NodeType.ELITE,
	NodeType.SHOP,
	NodeType.REST,
	NodeType.MYSTERY,
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
		var pools: Array = NORMAL_ENEMY_POOLS.get(chapter, NORMAL_ENEMY_POOLS[0])
		var enemy_ids: Array = pools[randi() % pools.size()]
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
		var elite_id: String = ELITE_ENEMY_POOLS[randi() % ELITE_ENEMY_POOLS.size()]
		var enemy_data: Dictionary = DataManager.get_enemy(elite_id)
		var display_name: String = enemy_data.get("enemy_name", elite_id)
		node.encounter_data = {
			"enemy_ids": [elite_id],
			"display_name": display_name,
		}

## 节点间距常量（像素）
const NODE_SPACING_H := 200  # 水平层间距（像素），范围 [100, 200]
const NODE_SPACING_V := 150  # 垂直节点间距（像素），范围 [100, 200]
const NODE_MARGIN_LEFT := 250  # 左侧边距（像素）
const NODE_MARGIN_TOP_MIN := 200   # 最小上侧边距（像素）

## 计算节点位置（使用像素坐标，节点间距固定在 [100, 200] 范围内）
## 节点群在垂直方向居中显示（基于屏幕高度）
static func _calculate_positions(nodes: Array, total_layers: int) -> void:
	# 按层分组
	var layers_dict: Dictionary = {}
	for node in nodes:
		if not layers_dict.has(node.layer):
			layers_dict[node.layer] = []
		layers_dict[node.layer].append(node)
	
	# 找到最大列数，用于垂直居中对齐
	var max_count := 1
	for layer_idx in layers_dict:
		var count: int = layers_dict[layer_idx].size()
		if count > max_count:
			max_count = count
	
	# 获取屏幕高度，用于垂直居中
	var viewport_height: float = ProjectSettings.get_setting("display/window/size/viewport_height", 720)
	# 节点群总高度
	var nodes_total_height: float = (max_count - 1) * NODE_SPACING_V
	# 计算上边距，使节点群垂直居中，但不小于最小边距
	var margin_top: float = max((viewport_height - nodes_total_height) / 2.0, NODE_MARGIN_TOP_MIN)
	
	# 计算每个节点的像素位置
	for layer_idx in layers_dict:
		var layer_nodes: Array = layers_dict[layer_idx]
		var count := layer_nodes.size()
		# 垂直方向：以最大列数为基准居中对齐
		var total_height: float = (max_count - 1) * NODE_SPACING_V
		var layer_height: float = (count - 1) * NODE_SPACING_V
		var y_offset: float = margin_top + (total_height - layer_height) / 2.0
		
		for i in range(count):
			var node: MapNode = layer_nodes[i]
			# BOSS节点特殊处理：在屏幕中垂直居中
			if node.node_type == NodeType.BOSS:
				node.position = Vector2(
					NODE_MARGIN_LEFT + layer_idx * NODE_SPACING_H,
					viewport_height / 2.0
				)
			else:
				node.position = Vector2(
					NODE_MARGIN_LEFT + layer_idx * NODE_SPACING_H,
					y_offset + i * NODE_SPACING_V
				)
