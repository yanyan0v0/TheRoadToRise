## 全局事件总线 - 用于模块间松耦合通信
extends Node

# ===== 游戏流程信号 =====
## 游戏状态变更
signal game_state_changed(old_state: int, new_state: int)
## 场景切换请求
signal scene_change_requested(scene_path: String)
## 章节完成
signal chapter_completed(chapter_index: int)
## 游戏结束（胜利或失败）
signal game_ended(is_victory: bool)

# ===== 角色属性信号 =====
## 生命值变化
signal health_changed(current_hp: int, max_hp: int)
## 法力变化
signal mana_changed(current_mana: int, max_mana: int)
## 体力变化（天蓬元帅专属）
signal stamina_changed(current_stamina: int, max_stamina: int)
## 护甲变化
signal armor_changed(current_armor: int)
## 金币变化
signal gold_changed(current_gold: int)
## 力量变化
signal strength_changed(current_strength: int)

# ===== 战斗信号 =====
## 战斗开始
signal battle_started(enemy_data: Array)
## 战斗结束
signal battle_ended(is_victory: bool)
## 回合开始
signal turn_started(turn_number: int)
## 回合结束
signal turn_ended(turn_number: int)
## 玩家回合开始
signal player_turn_started()
## 玩家回合结束
signal player_turn_ended()
## 敌人回合开始
signal enemy_turn_started()
## 敌人回合结束
signal enemy_turn_ended()
## 造成伤害
signal damage_dealt(target: Node, amount: int, damage_type: String)
## 受到伤害
signal damage_taken(target: Node, amount: int)
## 治疗
signal healing_applied(target: Node, amount: int)
## 护甲获得
signal armor_gained(target: Node, amount: int)

# ===== 卡牌信号 =====
## 卡牌抽取
signal card_drawn(card_data: Resource)
## 卡牌打出
signal card_played(card_data: Resource, target: Node)
## 卡牌弃置
signal card_discarded(card_data: Resource)
## 卡牌添加到牌组
signal card_added_to_deck(card_data: Resource)
## 卡牌从牌组移除
signal card_removed_from_deck(card_data: Resource)
## 卡牌升级
signal card_upgraded(card_data: Resource)

# ===== 状态效果信号 =====
## 状态效果施加
signal status_effect_applied(target: Node, effect_type: String, stacks: int)
## 状态效果移除
signal status_effect_removed(target: Node, effect_type: String)
## 状态效果触发
signal status_effect_triggered(target: Node, effect_type: String)

# ===== 敌人信号 =====
## 敌人意图更新
signal enemy_intent_updated(enemy: Node, intent_type: String, value: int)
## 敌人死亡
signal enemy_died(enemy: Node)
## 敌人召唤
signal enemy_summoned(enemy_data: Resource)
## BOSS阶段转换
signal boss_phase_changed(boss: Node, new_phase: int)

# ===== 地图信号 =====
## 地图节点选择
signal map_node_selected(node_data: Dictionary)
## 地图节点完成
signal map_node_completed(node_data: Dictionary)
## 进入下一章节
signal next_chapter_entered(chapter_index: int)

# ===== 道具/法宝信号 =====
## 法宝获得
signal relic_acquired(relic_data: Resource)
## 法宝效果触发
signal relic_effect_triggered(relic_data: Resource)
## 消耗品使用
signal consumable_used(consumable_data: Resource)
## 丹药容量变化
signal consumable_capacity_changed(current_count: int, max_count: int)

# ===== 天劫系统信号 =====
## 劫数变化
signal karma_changed(current_karma: int, level: String)
## 天劫等级变化
signal tribulation_level_changed(old_level: String, new_level: String)

# ===== 商店信号 =====
## 物品购买
signal item_purchased(item_data: Resource, cost: int)
## 物品出售
signal item_sold(item_data: Resource, price: int)

# ===== 成就信号 =====
## 成就解锁
signal achievement_unlocked(achievement_id: String, achievement_name: String)
## 角色解锁
signal character_unlocked(character_id: String)

# ===== 设置信号 =====
## 开发者模式切换
signal dev_mode_changed(enabled: bool)

# ===== UI信号 =====
## 显示飘字
signal floating_text_requested(position: Vector2, text: String, color: Color)
## 显示提示
signal tooltip_requested(text: String, position: Vector2)
## 隐藏提示
signal tooltip_hidden()
## 暂停菜单切换
signal pause_menu_toggled(is_paused: bool)
