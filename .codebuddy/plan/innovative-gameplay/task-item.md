# 《卡牌西游》创新玩法 - 实施计划

---

- [ ] 1. 卡牌星级数据模型与融合核心逻辑
   - 修改 `scripts/cards/CardData.gd`，新增 `star_level: int`（1-3）属性，新增 `star_2_effects` 和 `star_3_effects` 数组字段，新增 `get_star_display()` 方法返回星级标识（★☆☆/★★☆/★★★）
   - 修改 `data/cards.json`，为每张卡牌补充 `star_2_effects` 和 `star_3_effects` 数据（2星属性×1.5，3星属性×2.0+额外特效）
   - 修改 `scripts/autoload/GameManager.gd`，将 `current_deck: Array[String]` 改为支持星级信息的结构（如 `Array[Dictionary]`，每项含 `card_id` 和 `star_level`），同步修改 `add_card_to_deck()`、`remove_card_from_deck()` 等方法
   - 新建 `scripts/cards/CardFusionManager.gd`，实现融合核心逻辑：`get_fusable_groups()` 按卡牌名+星级分组、`can_fuse()` 校验（相同卡牌+相同星级+星级<3）、`fuse_cards()` 移除2张原卡并生成升星卡
   - 修改 `scripts/cards/Card.gd`，在卡牌UI上显示星级标识和对应星级的效果数值
   - _需求：2.1, 2.4, 2.5, 2.6, 2.7, 2.9, 2.10_

- [ ] 2. 篝火融合界面与特殊事件融合入口
   - 修改 `scenes/rest/RestScene.gd`，在篝火选项中新增「融合」按钮（与现有「恢复」「升级」并列）
   - 在 `RestScene.gd` 中实现 `_show_fusion_popup()` 融合界面：按卡牌名称分组显示可融合卡牌，每组标注持有数量和可融合次数，点击后预览融合结果并确认
   - 修改 `scenes/rest/RestScene.tscn`，在 VBox 中添加融合按钮节点
   - 修改 `scenes/event/EventScene.gd`，在「仙人指路」类事件中新增融合选项作为可选奖励
   - 修改 `data/events.json`，添加包含融合奖励的新事件数据
   - _需求：2.2, 2.3, 2.8, 2.11_

- [ ] 3. 丹药数据模型与消耗品系统改造
   - 修改 `scripts/relics/ConsumableData.gd`，重命名为丹药体系：新增 `quality`（普通/稀有/传说）、`use_scene`（battle/anytime/passive）字段，新增 `get_quality_color()` 方法
   - 修改 `data/consumables.json`，将现有消耗品全部改为丹药命名和数据格式（回春丹、铁骨丹、清心丹等），按品质分类
   - 修改 `scripts/autoload/GameManager.gd`，新增 `max_consumable_slots: int = 3` 丹药上限属性，新增 `get_consumable_capacity()` 方法（检测炼丹瓶法宝后返回6），修改 `add_consumable()` 增加上限校验
   - 修改 `scripts/autoload/EventBus.gd`，新增 `consumable_capacity_changed` 信号
   - 修改战斗场景 `scenes/battle/BattleScene.gd`，在战斗UI中添加丹药栏显示（当前数量/上限），实现战斗中使用丹药的逻辑（不消耗法力，立即生效）
   - 修改 `scenes/map/MapScene.gd`，在地图界面支持使用治疗类丹药（非战斗增益类）
   - _需求：3.1, 3.2, 3.5, 3.6, 3.7, 3.8, 3.10_

- [ ] 4. 炼丹阁节点场景与炼丹逻辑
   - 修改 `scripts/map/MapGenerator.gd`，在 `NodeType` 枚举中新增 `ALCHEMY`（炼丹阁），在 `NODE_COLORS`、`NODE_NAMES`、`NODE_ICONS` 中添加对应配置，修改 `_decide_node_type()` 使炼丹阁在中后期出现
   - 新建 `scenes/alchemy/AlchemyScene.gd` 和 `scenes/alchemy/AlchemyScene.tscn`，实现炼丹阁界面：显示3档金币花费（40/70/100）对应不同品质概率，点击炼丹后随机生成丹药，丹药满时提示丢弃
   - 修改 `scenes/map/MapScene.gd`，在节点点击逻辑中添加炼丹阁节点的跳转处理
   - 修改 `scenes/shop/ShopScene.gd`，在商店中添加1-2颗随机丹药供购买
   - _需求：3.3, 3.4, 3.5, 3.9_

- [ ] 5. 法宝强化系统与炼器坊节点
   - 修改 `scripts/relics/RelicData.gd`，取消 `star_level` 属性，新增 `enhance_level: int`（初始0，无上限）属性，新增 `get_enhanced_effects()` 方法（每层强化数值效果+1，不提升百分比）
   - 修改 `data/relics.json`，移除所有 `star_2_effects`、`star_3_effects`、`star_2_description`、`star_3_description` 字段
   - 修改 `scripts/autoload/GameManager.gd`，将 `current_relics` 中的 `star_level` 改为 `enhance_level`，移除融合相关方法，新增 `enhance_relic()` 方法（成功率0.2）
   - 修改 `scripts/map/MapGenerator.gd`，在 `NodeType` 枚举中新增 `FORGE`（炼器坊），添加对应颜色/名称/图标配置
   - 修改 `scenes/forge/ForgeScene.gd`，移除融合功能，仅保留强化功能：花费金币强化法宝，每次成功概率为0.2
   - 修改 `scenes/reward/RewardScene.gd`，法宝获取改为击败敌人掉落：普通0.2/精英0.5/BOSS 1.0
   - 修改 `scenes/map/MapScene.gd`，在节点点击逻辑中添加炼器坊节点的跳转处理
   - _需求：4.1, 4.2, 4.3, 4.4, 4.5, 4.6, 4.7, 4.8, 4.9, 4.10, 4.11_

- [ ] 6. 天劫系统核心逻辑与UI
   - 修改 `scripts/autoload/GameManager.gd`，新增天劫相关属性：`current_karma: int = 0`（劫数）、`max_karma_reached: int = 0`（本局最高劫数）、`tribulation_count: int = 0`（渡劫次数），新增 `get_tribulation_level()` 方法返回天劫等级（清净/微劫/小劫/大劫/天罚），新增 `modify_karma()` 方法
   - 修改 `scripts/autoload/EventBus.gd`，新增 `karma_changed(current_karma: int, level: String)` 信号
   - 修改 `scenes/battle/BattleScene.gd`，在战斗结束时检测完美通关（未受伤）增加2点劫数；根据天劫等级对敌人属性施加增强系数（+10%/+25%/+50%/+100%）；天罚等级时战斗开始施加随机负面效果
   - 修改 `scenes/shop/ShopScene.gd`，购买卡牌或法宝时增加1点劫数
   - 修改 `scenes/reward/RewardScene.gd`，跳过奖励时减少1点劫数
   - 在地图UI（`scenes/map/MapScene.gd` 或 `scenes/battle/BattleScene.gd`）顶部添加劫数显示和天劫等级标识
   - _需求：1.1, 1.2, 1.3, 1.4, 1.5, 1.8_

- [ ] 7. 渡劫节点与篝火悟道选项
   - 修改 `scripts/map/MapGenerator.gd`，在 `NodeType` 枚举中新增 `TRIBULATION`（渡劫），添加对应配置，修改 `_decide_node_type()` 使渡劫节点在劫数≥10时有概率出现
   - 新建 `scenes/tribulation/TribulationScene.gd` 和 `scenes/tribulation/TribulationScene.tscn`，实现渡劫挑战战斗场景：生成特殊天劫BOSS，胜利后劫数归零并给予传说级奖励
   - 修改 `scenes/rest/RestScene.gd`，新增「悟道」选项：消耗10点劫数，随机升级1张卡牌（仅在劫数≥10时可用）
   - 修改 `scenes/rest/RestScene.tscn`，添加悟道按钮节点
   - 修改 `scenes/map/MapScene.gd`，在节点点击逻辑中添加渡劫节点的跳转处理
   - 修改 `scenes/game_over/GameOverScene.gd`，在结算界面显示本局最高劫数和渡劫次数
   - _需求：1.6, 1.7, 1.9, 1.10_

- [ ] 8. 妖灵收服战斗机制与召唤卡牌
   - 修改 `scripts/enemies/EnemyController.gd`，在敌人生命值降至25%以下时显示「可收服」金色光环标识
   - 新建 `scripts/cards/SpiritCaptureManager.gd`，实现收服核心逻辑：`can_capture()` 校验（非BOSS、生命≤25%、妖灵容量未满）、`capture_enemy()` 生成妖灵召唤卡、精英敌人50%成功率判定
   - 修改 `scripts/cards/CardData.gd`，新增 `CardType.SPIRIT`（妖灵召唤）类型
   - 修改 `data/cards.json`，添加妖灵召唤卡牌数据（妖灵·猛虎、妖灵·狐仙、妖灵·蛛丝等）
   - 修改 `scripts/autoload/GameManager.gd`，新增 `spirit_capacity: int = 3` 妖灵容量属性，新增 `get_spirit_count()` 方法统计当前卡组中妖灵卡数量
   - 修改 `scenes/battle/BattleScene.gd`，实现收服类卡牌的使用逻辑（对可收服敌人使用时触发收服流程）和妖灵召唤卡的使用逻辑（召唤妖灵执行攻击后消失）
   - _需求：6.1, 6.2, 6.3, 6.4, 6.5, 6.6, 6.7, 6.8_

- [ ] 9. 成就系统扩展与内容解锁机制
   - 重构 `scripts/achievements/AchievementManager.gd`，扩展 `ACHIEVEMENTS` 字典，按分类（战斗/探索/收集/挑战）添加所有成就定义，每个成就包含 `unlock_type`（new_pill/new_card/new_relic/new_event）和 `unlock_content` 字段
   - 修改 `scripts/autoload/SaveManager.gd`，新增 `unlocked_content: Dictionary`（按类型存储已解锁的内容ID列表），新增 `unlock_content()` 和 `is_content_unlocked()` 方法，确保跨局持久化
   - 修改 `scripts/autoload/DataManager.gd`，在 `get_available_cards_for_character()`、`get_all_relics()`、`get_all_consumables()` 等方法中增加成就解锁过滤——未解锁的高级内容不出现在奖励池/炼制列表中
   - 新建 `scenes/achievement/AchievementScene.gd` 和 `scenes/achievement/AchievementScene.tscn`，实现成就列表界面：按分类显示，已解锁高亮，未解锁显示条件和奖励预览
   - 修改 `scenes/main_menu/MainMenuScene.gd` 和 `scenes/main_menu/MainMenuScene.tscn`，在主菜单添加「成就」入口按钮
   - 在 `AchievementManager.gd` 的 `check_achievements()` 中添加新成就的检测逻辑（毫发无伤、渡劫成功、妖灵猎人、丹道宗师、满星大师等）
   - _需求：5.1, 5.2, 5.3, 5.4, 5.5, 5.6, 5.7, 5.8, 5.9_

- [ ] 10. 天劫奖励加成与全系统联动集成
   - 修改 `scenes/reward/RewardScene.gd`，根据天劫等级调整金币奖励加成（微劫+20%/小劫+50%/大劫+100%/天罚+200%）和卡牌稀有度提升
   - 修改 `scripts/autoload/GameManager.gd` 的 `get_save_data()` 和 `load_save_data()`，确保新增的所有属性（劫数、丹药上限、妖灵容量、卡牌星级、法宝星级等）正确序列化和反序列化
   - 修改 `scripts/autoload/DataManager.gd`，新增 `data/pills.json`（丹药数据）的加载逻辑，或复用 `consumables.json` 确保丹药品质概率表数据可配置
   - 验证各系统间联动：成就解锁→内容池扩展、天劫等级→奖励品质、炼丹瓶法宝→丹药上限、妖灵壶法宝→妖灵容量、篝火→融合/悟道选项
   - 修改 `scenes/deck_view/DeckViewScene.gd`，在卡组查看界面中正确显示卡牌星级和妖灵卡标识
   - _需求：1.5, 1.7, 3.2, 5.4, 5.5, 5.6, 5.7_
