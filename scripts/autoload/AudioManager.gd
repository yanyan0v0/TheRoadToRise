## 音频管理器 - 管理BGM和SFX的播放、音量控制、淡入淡出
extends Node

# ===== 音频总线名称 =====
const BUS_MASTER := "Master"
const BUS_BGM := "BGM"
const BUS_SFX := "SFX"

# ===== 音量设置（0.0 ~ 1.0） =====
var bgm_volume: float = 0.8:
	set(value):
		bgm_volume = clampf(value, 0.0, 1.0)
		_update_bus_volume(BUS_BGM, bgm_volume)

var sfx_volume: float = 0.8:
	set(value):
		sfx_volume = clampf(value, 0.0, 1.0)
		_update_bus_volume(BUS_SFX, sfx_volume)

var master_volume: float = 1.0:
	set(value):
		master_volume = clampf(value, 0.0, 1.0)
		_update_bus_volume(BUS_MASTER, master_volume)

# ===== BGM播放器 =====
var _bgm_player: AudioStreamPlayer
var _bgm_tween: Tween
var _current_bgm_path: String = ""

# ===== SFX播放器池 =====
const MAX_SFX_PLAYERS := 8
var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_index: int = 0

# ===== 淡入淡出时长 =====
const FADE_DURATION := 0.5

func _ready() -> void:
	# 确保音频总线存在（在Godot编辑器中需要手动创建，这里做兼容处理）
	_setup_audio_buses()
	
	# 创建BGM播放器
	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.bus = BUS_BGM
	_bgm_player.name = "BGMPlayer"
	add_child(_bgm_player)
	
	# 创建SFX播放器池
	for i in range(MAX_SFX_PLAYERS):
		var player := AudioStreamPlayer.new()
		player.bus = BUS_SFX
		player.name = "SFXPlayer_%d" % i
		add_child(player)
		_sfx_players.append(player)
	
	# 加载保存的音量设置
	_load_volume_settings()

## 设置音频总线（兼容处理）
func _setup_audio_buses() -> void:
	# 检查BGM总线是否存在
	if AudioServer.get_bus_index(BUS_BGM) == -1:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, BUS_BGM)
	
	# 检查SFX总线是否存在
	if AudioServer.get_bus_index(BUS_SFX) == -1:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, BUS_SFX)

## 播放背景音乐（带淡入淡出）
func play_bgm(stream_path: String, fade: bool = true) -> void:
	if stream_path == _current_bgm_path and _bgm_player.playing:
		return
	
	var stream := load(stream_path) as AudioStream
	if stream == null:
		push_warning("[AudioManager] 无法加载BGM: %s" % stream_path)
		return
	
	_current_bgm_path = stream_path
	
	if fade and _bgm_player.playing:
		# 淡出当前BGM，然后淡入新BGM
		_fade_out_bgm(func():
			_bgm_player.stream = stream
			_bgm_player.play()
			_fade_in_bgm()
		)
	else:
		_bgm_player.stream = stream
		_bgm_player.play()
		if fade:
			_fade_in_bgm()

## 停止背景音乐
func stop_bgm(fade: bool = true) -> void:
	if not _bgm_player.playing:
		return
	
	_current_bgm_path = ""
	if fade:
		_fade_out_bgm(func(): _bgm_player.stop())
	else:
		_bgm_player.stop()

## 播放音效
func play_sfx(stream_path: String, volume_db: float = 0.0) -> void:
	var stream := load(stream_path) as AudioStream
	if stream == null:
		push_warning("[AudioManager] 无法加载SFX: %s" % stream_path)
		return
	
	# 使用轮询方式选择SFX播放器
	var player := _sfx_players[_sfx_index]
	_sfx_index = (_sfx_index + 1) % MAX_SFX_PLAYERS
	
	player.stream = stream
	player.volume_db = volume_db
	player.play()

## 播放音效（直接传入AudioStream）
func play_sfx_stream(stream: AudioStream, volume_db: float = 0.0) -> void:
	if stream == null:
		return
	
	var player := _sfx_players[_sfx_index]
	_sfx_index = (_sfx_index + 1) % MAX_SFX_PLAYERS
	
	player.stream = stream
	player.volume_db = volume_db
	player.play()

## BGM淡出
func _fade_out_bgm(callback: Callable = Callable()) -> void:
	if _bgm_tween:
		_bgm_tween.kill()
	
	_bgm_tween = create_tween()
	_bgm_tween.tween_property(_bgm_player, "volume_db", -80.0, FADE_DURATION)
	if callback.is_valid():
		_bgm_tween.tween_callback(callback)

## BGM淡入
func _fade_in_bgm() -> void:
	if _bgm_tween:
		_bgm_tween.kill()
	
	_bgm_player.volume_db = -80.0
	_bgm_tween = create_tween()
	_bgm_tween.tween_property(_bgm_player, "volume_db", 0.0, FADE_DURATION)

## 更新音频总线音量
func _update_bus_volume(bus_name: String, volume: float) -> void:
	var bus_idx := AudioServer.get_bus_index(bus_name)
	if bus_idx >= 0:
		AudioServer.set_bus_volume_db(bus_idx, linear_to_db(volume))

## 保存音量设置
func save_volume_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "master_volume", master_volume)
	config.set_value("audio", "bgm_volume", bgm_volume)
	config.set_value("audio", "sfx_volume", sfx_volume)
	config.save("user://audio_settings.cfg")

## 加载音量设置
func _load_volume_settings() -> void:
	var config := ConfigFile.new()
	if config.load("user://audio_settings.cfg") == OK:
		master_volume = config.get_value("audio", "master_volume", 1.0)
		bgm_volume = config.get_value("audio", "bgm_volume", 0.8)
		sfx_volume = config.get_value("audio", "sfx_volume", 0.8)
	else:
		# 使用默认值
		_update_bus_volume(BUS_MASTER, master_volume)
		_update_bus_volume(BUS_BGM, bgm_volume)
		_update_bus_volume(BUS_SFX, sfx_volume)
