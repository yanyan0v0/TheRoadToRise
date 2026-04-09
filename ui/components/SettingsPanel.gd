## 设置面板脚本
extends Control

## Signal emitted when the panel is closed
signal panel_closed

@onready var bgm_slider: HSlider = $PanelContainer/VBox/BGMContainer/BGMSlider
@onready var sfx_slider: HSlider = $PanelContainer/VBox/SFXContainer/SFXSlider
@onready var fullscreen_check: CheckButton = $PanelContainer/VBox/FullscreenCheck
@onready var dev_mode_check: CheckButton = get_node_or_null("PanelContainer/VBox/DevModeCheck")
@onready var close_button: Button = $PanelContainer/VBox/CloseButton

func _ready() -> void:
	# Initialize slider values
	bgm_slider.value = AudioManager.bgm_volume
	sfx_slider.value = AudioManager.sfx_volume
	fullscreen_check.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	if dev_mode_check:
		dev_mode_check.button_pressed = GameManager.dev_mode
	
	# Connect signals
	bgm_slider.value_changed.connect(_on_bgm_changed)
	sfx_slider.value_changed.connect(_on_sfx_changed)
	fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	if dev_mode_check:
		dev_mode_check.toggled.connect(_on_dev_mode_toggled)
	close_button.pressed.connect(_on_close_pressed)

func _on_bgm_changed(value: float) -> void:
	AudioManager.bgm_volume = value
	AudioManager.save_volume_settings()

func _on_sfx_changed(value: float) -> void:
	AudioManager.sfx_volume = value
	AudioManager.save_volume_settings()

func _on_fullscreen_toggled(is_fullscreen: bool) -> void:
	if is_fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

## Toggle developer mode and unlock all characters if enabled
func _on_dev_mode_toggled(enabled: bool) -> void:
	GameManager.dev_mode = enabled
	if enabled:
		# Unlock all characters
		var all_characters := DataManager.get_all_characters()
		for char_data in all_characters:
			var char_id: String = char_data.get("character_id", "")
			if char_id != "" and not SaveManager.is_character_unlocked(char_id):
				SaveManager.unlock_character(char_id)
		print("[开发者模式] 已开启，全部角色已解锁")
	else:
		print("[开发者模式] 已关闭")

func _on_close_pressed() -> void:
	visible = false
	panel_closed.emit()
