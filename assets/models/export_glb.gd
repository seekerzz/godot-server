@tool
extends EditorScript

## 批量导出场景为GLB格式
## 使用方法: 在Godot编辑器中运行此脚本

const SCENES = [
	"res://assets/models/paddle_player.tscn",
	"res://assets/models/paddle_ai.tscn",
	"res://assets/models/ball.tscn",
	"res://assets/models/table.tscn"
]

func _run():
	print("开始导出GLB文件...")

	for scene_path in SCENES:
		_export_scene(scene_path)

	print("导出完成!")

func _export_scene(scene_path: String):
	var file_name = scene_path.get_file().get_basename()
	var output_path = "res://assets/models/" + file_name + ".glb"

	print("导出: " + scene_path + " -> " + output_path)

	# 加载场景
	var packed_scene = load(scene_path)
	if not packed_scene:
		print("错误: 无法加载场景 " + scene_path)
		return

	# 实例化场景
	var instance = packed_scene.instantiate()

	# 创建GLTF文档
	var gltf_document = GLTFDocument.new()
	var gltf_state = GLTFState.new()

	# 导出为GLB
	var error = gltf_document.append_from_scene(instance, gltf_state)
	if error != OK:
		print("错误: 导出失败 " + scene_path + " 错误码: " + str(error))
		instance.queue_free()
		return

	# 写入文件
	error = gltf_document.write_to_filesystem(gltf_state, output_path)
	if error != OK:
		print("错误: 写入文件失败 " + output_path)
	else:
		print("成功导出: " + output_path)

	instance.queue_free()
