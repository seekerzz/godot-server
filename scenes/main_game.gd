extends Node3D

## 主游戏场景
## 仅用于验证场景加载

func _ready():
	print("[MainGame] 场景已加载")
	print("[MainGame] 子节点数量: " + str(get_child_count()))

	# 列出所有子节点
	for child in get_children():
		print("[MainGame] - " + child.name + " (" + child.get_class() + ")")

	# 检查原点标记
	var origin = get_node_or_null("OriginMarker")
	if origin:
		print("[MainGame] 原点标记已找到，位置: " + str(origin.position))
	else:
		print("[MainGame] 错误：原点标记未找到")

	# 检查静态球拍
	var paddle = get_node_or_null("StaticPaddle")
	if paddle:
		print("[MainGame] 静态球拍已找到，位置: " + str(paddle.position))
	else:
		print("[MainGame] 错误：静态球拍未找到")

	# 检查相机
	var camera = get_node_or_null("Camera3D")
	if camera:
		print("[MainGame] 相机已找到，位置: " + str(camera.position))
	else:
		print("[MainGame] 错误：相机未找到")
