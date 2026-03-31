## 暂停菜单脚本
extends Control

@onready var resume_button: Button = $PanelContainer/VBox/ResumeButton
@onready var settings_button: Button = $PanelContainer/VBox/SettingsButton
@onready var main_menu_button: Button = $PanelContainer/VBox/MainMenuButton
@onready var settings_panel: Control = $SettingsPanel

func _ready() -> void:
	resume_button.pressed.connect(_on_resume_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	main_menu_button.pressed.connect(_on_main_menu_pressed)
	
	if settings_panel:
		settings_panel.visible = false
	
	# 暂停菜单不受暂停影响
	process_mode = Node.PROCESS_MODE_ALWAYS

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_pause"):
		if visible:
			_on_resume_pressed()
		else:
			_show_pause_menu()

func _show_pause_menu() -> void:
	visible = true
	GameManager.toggle_pause()

func _on_resume_pressed() -> void:
	visible = false
	if settings_panel:
		settings_panel.visible = false
	GameManager.toggle_pause()

func _on_settings_pressed() -> void:
	if settings_panel:
		settings_panel.visible = true

func _on_main_menu_pressed() -> void:
	visible = false
	if GameManager.is_paused:
		GameManager.toggle_pause()
	# 保存当前进度
	SaveManager.save_game()
	SceneTransition.change_scene("res://scenes/main_menu/MainMenuScene.tscn")
