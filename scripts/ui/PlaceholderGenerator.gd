## 占位美术资源生成工具 - 程序化生成带颜色标识的占位图
class_name PlaceholderGenerator
extends RefCounted

## 生成带文字标签的矩形占位纹理
static func create_rect_texture(width: int, height: int, color: Color, text: String = "") -> ImageTexture:
	var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	
	# 填充背景色
	image.fill(color)
	
	# 绘制边框
	var border_color := color.lightened(0.3)
	for x in range(width):
		image.set_pixel(x, 0, border_color)
		image.set_pixel(x, height - 1, border_color)
	for y in range(height):
		image.set_pixel(0, y, border_color)
		image.set_pixel(width - 1, y, border_color)
	
	return ImageTexture.create_from_image(image)

## 生成圆形占位纹理
static func create_circle_texture(radius: int, color: Color) -> ImageTexture:
	var size := radius * 2
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	
	var center := Vector2(radius, radius)
	for x in range(size):
		for y in range(size):
			if Vector2(x, y).distance_to(center) <= radius:
				image.set_pixel(x, y, color)
	
	return ImageTexture.create_from_image(image)

## 生成卡牌占位纹理（180x270）
static func create_card_texture(rarity_color: Color, card_name: String = "") -> ImageTexture:
	var image := Image.create(180, 270, false, Image.FORMAT_RGBA8)
	
	# 卡牌背景
	image.fill(Color(0.15, 0.15, 0.15))
	
	# 稀有度边框（3像素宽）
	for x in range(180):
		for y in range(270):
			if x < 3 or x >= 177 or y < 3 or y >= 267:
				image.set_pixel(x, y, rarity_color)
	
	# 标题区域（顶部15%）
	for x in range(5, 175):
		for y in range(5, 40):
			image.set_pixel(x, y, Color(0.25, 0.2, 0.15))
	
	# 插画区域（中部45%）
	for x in range(10, 170):
		for y in range(45, 165):
			image.set_pixel(x, y, rarity_color.darkened(0.5))
	
	# 描述区域（底部40%）
	for x in range(5, 175):
		for y in range(175, 265):
			image.set_pixel(x, y, Color(0.1, 0.1, 0.1))
	
	return ImageTexture.create_from_image(image)

## 生成角色占位纹理
static func create_character_texture(color: Color) -> ImageTexture:
	var image := Image.create(200, 300, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	
	# 简单的人形轮廓
	var center_x := 100
	
	# 头部（圆形）
	for x in range(200):
		for y in range(300):
			var head_center := Vector2(center_x, 50)
			if Vector2(x, y).distance_to(head_center) <= 30:
				image.set_pixel(x, y, color)
			# 身体（矩形）
			elif x >= 70 and x <= 130 and y >= 80 and y <= 200:
				image.set_pixel(x, y, color.darkened(0.2))
			# 腿部
			elif (x >= 70 and x <= 95 and y >= 200 and y <= 280) or \
				 (x >= 105 and x <= 130 and y >= 200 and y <= 280):
				image.set_pixel(x, y, color.darkened(0.3))
	
	return ImageTexture.create_from_image(image)

## 生成敌人占位纹理
static func create_enemy_texture(color: Color, is_boss: bool = false) -> ImageTexture:
	var size := 250 if is_boss else 150
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	
	var center := Vector2(size / 2.0, size / 2.0)
	var radius := size / 2.0 - 5
	
	# 敌人轮廓（圆形/椭圆形）
	for x in range(size):
		for y in range(size):
			if Vector2(x, y).distance_to(center) <= radius:
				image.set_pixel(x, y, color)
	
	return ImageTexture.create_from_image(image)

## 生成地图节点占位纹理
static func create_map_node_texture(color: Color, node_type: String = "") -> ImageTexture:
	var image := Image.create(40, 40, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	
	var center := Vector2(20, 20)
	for x in range(40):
		for y in range(40):
			if Vector2(x, y).distance_to(center) <= 18:
				image.set_pixel(x, y, color)
			elif Vector2(x, y).distance_to(center) <= 20:
				image.set_pixel(x, y, color.lightened(0.3))
	
	return ImageTexture.create_from_image(image)
