## 设置面板脚本
extends Control

@onready var bgm_slider: HSlider = $PanelContainer/VBox/BGMContainer/BGMSlider
@onready var sfx_slider: HSlider = $PanelContainer/VBox/SFXContainer/SFXSlider
@onready var fullscreen_check: CheckButton = $PanelContainer/VBox/FullscreenCheck
@onready var close_button: Button = $PanelContainer/VBox/CloseButton

func _ready() -> void:
	# 初始化滑块值
	bgm_slider.value = AudioManager.bgm_volume
	sfx_slider.value = AudioManager.sfx_volume
	fullscreen_check.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	
	# 连接信号
	bgm_slider.value_changed.connect(_on_bgm_changed)
	sfx_slider.value_changed.connect(_on_sfx_changed)
	fullscreen_check.toggled.connect(_on_fullscreen_toggled)
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

func _on_close_pressed() -> void:
	visible = false
