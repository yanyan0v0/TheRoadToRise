## 场景切换工具 - 支持淡入淡出过渡动画的场景切换
extends CanvasLayer

# ===== 过渡配置 =====
const TRANSITION_DURATION := 0.4

var _color_rect: ColorRect
var _is_transitioning: bool = false

func _ready() -> void:
	# 设置为最高层级，覆盖所有UI
	layer = 100
	
	# 创建全屏遮罩
	_color_rect = ColorRect.new()
	_color_rect.color = Color.BLACK
	_color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_color_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_color_rect.modulate.a = 0.0
	_color_rect.visible = false
	add_child(_color_rect)

## 切换到指定场景（带淡入淡出）
func change_scene(scene_path: String) -> void:
	if _is_transitioning:
		return
	
	_is_transitioning = true
	_color_rect.visible = true
	_color_rect.mouse_filter = Control.MOUSE_FILTER_STOP  # 阻止点击穿透
	
	# 淡出（变黑）
	var tween := create_tween()
	tween.tween_property(_color_rect, "modulate:a", 1.0, TRANSITION_DURATION)
	await tween.finished
	
	# 切换场景
	var error := get_tree().change_scene_to_file(scene_path)
	if error != OK:
		push_error("[SceneTransition] 场景切换失败: %s, 错误码: %d" % [scene_path, error])
		_is_transitioning = false
		_color_rect.visible = false
		_color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return
	
	# 等待一帧确保场景加载完成
	await get_tree().process_frame
	
	# 淡入（变透明）
	var tween2 := create_tween()
	tween2.tween_property(_color_rect, "modulate:a", 0.0, TRANSITION_DURATION)
	await tween2.finished
	
	_color_rect.visible = false
	_color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_is_transitioning = false

## 切换到指定场景（带自定义颜色过渡）
func change_scene_with_color(scene_path: String, color: Color = Color.BLACK) -> void:
	_color_rect.color = color
	await change_scene(scene_path)

## 仅执行淡出效果（用于自定义场景切换逻辑）
func fade_out(duration: float = TRANSITION_DURATION) -> void:
	_color_rect.visible = true
	_color_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	var tween := create_tween()
	tween.tween_property(_color_rect, "modulate:a", 1.0, duration)
	await tween.finished

## 仅执行淡入效果
func fade_in(duration: float = TRANSITION_DURATION) -> void:
	var tween := create_tween()
	tween.tween_property(_color_rect, "modulate:a", 0.0, duration)
	await tween.finished
	_color_rect.visible = false
	_color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

## 检查是否正在过渡中
func is_transitioning() -> bool:
	return _is_transitioning
