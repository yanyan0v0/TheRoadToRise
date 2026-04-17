## 主菜单场景脚本
extends Control

@onready var start_button: Button = $ButtonContainer/StartButton
@onready var continue_button: Button = $ButtonContainer/ContinueButton
@onready var settings_button: Button = $ButtonContainer/SettingsButton
@onready var achievement_button: Button = $ButtonContainer/AchievementButton
@onready var quit_button: Button = $ButtonContainer/QuitButton
@onready var button_container: VBoxContainer = $ButtonContainer

func _ready() -> void:
	GameManager.change_state(GameManager.GameState.MENU)
	
	# 检查存档状态
	continue_button.disabled = not SaveManager.has_valid_save
	
	# 连接按钮信号
	start_button.pressed.connect(_on_start_pressed)
	continue_button.pressed.connect(_on_continue_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	achievement_button.pressed.connect(_on_achievement_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	
	# Hide the embedded SettingsPanel (no longer used)
	var settings_panel := get_node_or_null("SettingsPanel")
	if settings_panel:
		settings_panel.visible = false

## 开始新游戏
func _on_start_pressed() -> void:
	SceneTransition.change_scene("res://scenes/character_select/CharacterSelectScene.tscn")

## 继续游戏
func _on_continue_pressed() -> void:
	if SaveManager.load_game():
		# 根据存档中的游戏状态跳转到对应场景
		var state := GameManager.current_state
		match state:
			GameManager.GameState.BATTLE:
				SceneTransition.change_scene("res://scenes/battle/BattleScene.tscn")
			GameManager.GameState.SHOP:
				SceneTransition.change_scene("res://scenes/shop/ShopScene.tscn")
			_:
				SceneTransition.change_scene("res://scenes/map/MapScene.tscn")

## 打开设置（使用GlobalHUD的设置弹窗）
func _on_settings_pressed() -> void:
	GlobalHUD.show_settings_panel()

## 打开成就界面
func _on_achievement_pressed() -> void:
	SceneTransition.change_scene("res://scenes/achievement/AchievementScene.tscn")

## 退出游戏
func _on_quit_pressed() -> void:
	get_tree().quit()
