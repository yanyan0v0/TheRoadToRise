## 游戏结算场景脚本 - 显示胜利/失败结算界面
extends Control

@onready var title_label: Label = $CenterContainer/VBox/TitleLabel
@onready var subtitle_label: Label = $CenterContainer/VBox/SubtitleLabel
@onready var stats_container: VBoxContainer = $CenterContainer/VBox/StatsContainer
@onready var achievement_container: VBoxContainer = $CenterContainer/VBox/AchievementContainer
@onready var main_menu_button: Button = $CenterContainer/VBox/MainMenuButton
@onready var retry_button: Button = $CenterContainer/VBox/RetryButton

var is_victory: bool = false

func _ready() -> void:
	# 判断是胜利还是失败
	is_victory = GameManager.current_state == GameManager.GameState.VICTORY or GameManager.current_chapter > GameManager.TOTAL_CHAPTERS
	
	if is_victory:
		GameManager.change_state(GameManager.GameState.VICTORY)
	else:
		GameManager.change_state(GameManager.GameState.GAME_OVER)
	
	main_menu_button.pressed.connect(_on_main_menu_pressed)
	retry_button.pressed.connect(_on_retry_pressed)
	
	_display_result()
	_check_achievements()

## 显示结算结果
func _display_result() -> void:
	if is_victory:
		title_label.text = "🎊 取得真经！"
		title_label.add_theme_color_override("font_color", Color("FDCB6E"))
		subtitle_label.text = "恭喜你完成了九九八十一难的修行之旅"
	else:
		title_label.text = "💀 修行终止"
		title_label.add_theme_color_override("font_color", Color("D63031"))
		subtitle_label.text = "取经之路道阻且长，下次再来"
	
	# 显示统计数据
	var play_time := GameManager.get_play_time()
	var minutes := play_time / 60
	var seconds := play_time % 60
	
	_add_stat_line("击败敌人", "%d" % GameManager.stats.enemies_defeated)
	_add_stat_line("获得卡牌", "%d" % GameManager.stats.cards_obtained)
	_add_stat_line("最高单次伤害", "%d" % GameManager.stats.max_single_damage)
	_add_stat_line("到达章节", "第%d章" % clampi(GameManager.current_chapter, 1, GameManager.TOTAL_CHAPTERS))
	_add_stat_line("游戏时长", "%d分%d秒" % [minutes, seconds])
	_add_stat_line("最高劫数", "%d" % GameManager.max_karma_reached)
	_add_stat_line("渡劫次数", "%d" % GameManager.tribulation_count)

## 添加统计行
func _add_stat_line(label_text: String, value_text: String) -> void:
	var hbox := HBoxContainer.new()
	hbox.custom_minimum_size = Vector2(400, 30)
	
	var label := Label.new()
	label.text = label_text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	hbox.add_child(label)
	
	var value := Label.new()
	value.text = value_text
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.add_theme_font_size_override("font_size", 16)
	value.add_theme_color_override("font_color", Color("FDCB6E"))
	hbox.add_child(value)
	
	stats_container.add_child(hbox)

## 检查成就
func _check_achievements() -> void:
	# 检查通用成就
	AchievementManager.check_achievements()
	
	# 检查战斗相关成就
	AchievementManager.check_battle_achievements()
	
	# 检查关卡进度成就
	var total_floors := GameManager.get_nodes_cleared()
	AchievementManager.check_floor_achievement(total_floors)
	
	# 仅显示"本局游戏开始之后"解锁的成就
	# 以 GameManager.stats.start_time（本局开始的Unix时间戳，秒）为界
	var run_start_ts: float = float(GameManager.stats.get("start_time", 0))
	var all_achievements := AchievementManager.get_all_achievements()
	var has_new := false
	
	for achievement in all_achievements:
		if not achievement.get("unlocked", false):
			continue
		var unlocked_at: String = achievement.get("unlocked_at", "")
		# 没有解锁时间戳信息，保守跳过（认为是历史成就）
		if unlocked_at.is_empty():
			continue
		# SaveManager 使用 Time.get_datetime_string_from_system() 写入，格式为 ISO 本地时间
		var unlocked_ts: float = Time.get_unix_time_from_datetime_string(unlocked_at)
		if unlocked_ts < run_start_ts:
			continue
		
		var label := Label.new()
		label.text = "🏆 %s - %s" % [achievement.get("name", ""), achievement.get("description", "")]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 14)
		label.add_theme_color_override("font_color", Color("FDCB6E"))
		achievement_container.add_child(label)
		has_new = true
	
	if not has_new:
		achievement_container.visible = false

## 返回主菜单
func _on_main_menu_pressed() -> void:
	# 删除当前存档（游戏结束）
	SaveManager.delete_save()
	SceneTransition.change_scene("res://scenes/main_menu/MainMenuScene.tscn")

## 重新开始
func _on_retry_pressed() -> void:
	SaveManager.delete_save()
	SceneTransition.change_scene("res://scenes/character_select/CharacterSelectScene.tscn")
