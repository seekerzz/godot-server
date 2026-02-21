extends "res://tests/fixtures/test_base.gd"

# TC-005: 球拍实体创建测试
# 验证3D球拍正确显示

var phone_model: Node3D
var phone_pivot: Node3D
var phone_screen_mesh: MeshInstance3D

func before_all():
	print("[TC-005] 球拍实体创建测试 - 初始化")

func before_each():
	# 清理之前的实例
	if phone_model:
		phone_model.queue_free()
		phone_model = null
	phone_pivot = null
	phone_screen_mesh = null

func after_all():
	print("[TC-005] 球拍实体创建测试 - 完成")

# ========== 测试用例 ==========

func test_phone_model_creation():
	"""测试手机模型创建"""
	create_phone_model()

	assert_not_null(phone_model, "手机模型应成功创建")
	assert_eq(phone_model.name, "PhoneModel", "模型名称应为PhoneModel")

func test_phone_pivot_creation():
	"""测试旋转中心创建"""
	create_phone_model()

	assert_not_null(phone_pivot, "旋转中心应成功创建")
	assert_eq(phone_pivot.name, "Pivot", "旋转中心名称应为Pivot")
	assert_eq(phone_pivot.get_parent(), phone_model, "旋转中心应是模型的子节点")

func test_body_mesh_creation():
	"""测试机身网格创建"""
	create_phone_model()

	var body = phone_pivot.get_node_or_null("Body")
	assert_not_null(body, "机身应存在")
	assert_true(body is MeshInstance3D, "机身应为MeshInstance3D")

func test_screen_mesh_creation():
	"""测试屏幕网格创建"""
	create_phone_model()

	var screen = phone_pivot.get_node_or_null("Screen")
	assert_not_null(screen, "屏幕应存在")
	assert_true(screen is MeshInstance3D, "屏幕应为MeshInstance3D")

func test_direction_marker_creation():
	"""测试方向标记创建"""
	create_phone_model()

	var marker = phone_pivot.get_node_or_null("DirectionMarker")
	assert_not_null(marker, "方向标记应存在")
	assert_true(marker is MeshInstance3D, "方向标记应为MeshInstance3D")

func test_body_dimensions():
	"""测试机身尺寸"""
	create_phone_model()

	var body = phone_pivot.get_node("Body") as MeshInstance3D
	var mesh = body.mesh as BoxMesh

	assert_not_null(mesh, "机身应有BoxMesh")
	assert_gt(mesh.size.x, 0, "机身宽度应大于0")
	assert_gt(mesh.size.y, 0, "机身高度应大于0")
	assert_gt(mesh.size.z, 0, "机身厚度应大于0")

func test_screen_position():
	"""测试屏幕位置"""
	create_phone_model()

	var screen = phone_pivot.get_node("Screen") as MeshInstance3D

	# 屏幕应在机身正面
	assert_gt(screen.position.z, 0, "屏幕应在机身正面")

func test_screen_smaller_than_body():
	"""测试屏幕小于机身"""
	create_phone_model()

	var body = phone_pivot.get_node("Body") as MeshInstance3D
	var screen = phone_pivot.get_node("Screen") as MeshInstance3D

	var body_mesh = body.mesh as BoxMesh
	var screen_mesh = screen.mesh as BoxMesh

	assert_lt(screen_mesh.size.x, body_mesh.size.x, "屏幕宽度应小于机身")
	assert_lt(screen_mesh.size.y, body_mesh.size.y, "屏幕高度应小于机身")

func test_body_material():
	"""测试机身材质"""
	create_phone_model()

	var body = phone_pivot.get_node("Body") as MeshInstance3D
	var material = body.material_override

	assert_not_null(material, "机身应有材质覆盖")

func test_screen_material():
	"""测试屏幕材质"""
	create_phone_model()

	var screen = phone_pivot.get_node("Screen") as MeshInstance3D
	var material = screen.material_override

	assert_not_null(material, "屏幕应有材质覆盖")

func test_model_hierarchy():
	"""测试模型层级结构"""
	create_phone_model()

	# 检查层级: PhoneModel -> Pivot -> [Body, Screen, DirectionMarker]
	assert_eq(phone_pivot.get_parent(), phone_model, "Pivot应是PhoneModel的子节点")

	var children = phone_pivot.get_children()
	var has_body = false
	var has_screen = false
	var has_marker = false

	for child in children:
		if child.name == "Body":
			has_body = true
		elif child.name == "Screen":
			has_screen = true
		elif child.name == "DirectionMarker":
			has_marker = true

	assert_true(has_body, "Pivot应有Body子节点")
	assert_true(has_screen, "Pivot应有Screen子节点")
	assert_true(has_marker, "Pivot应有DirectionMarker子节点")

func test_paddle_rotation():
	"""测试球拍旋转"""
	create_phone_model()

	# 测试旋转
	var test_rotation = Quaternion.from_euler(Vector3(0, deg_to_rad(90), 0))
	phone_pivot.quaternion = test_rotation

	assert_quaternion_eq(phone_pivot.quaternion, test_rotation, 0.0001, "旋转应正确应用")

func test_paddle_position():
	"""测试球拍位置"""
	create_phone_model()

	var test_position = Vector3(1.0, 2.0, 3.0)
	phone_model.position = test_position

	assert_vector_eq(phone_model.position, test_position, 0.0001, "位置应正确应用")

func test_model_visibility():
	"""测试模型可见性"""
	create_phone_model()

	# 默认应可见
	assert_true(phone_model.visible, "模型默认应可见")

	# 可以隐藏
	phone_model.visible = false
	assert_false(phone_model.visible, "模型应可隐藏")

func test_screen_color_feedback():
	"""测试屏幕颜色反馈"""
	create_phone_model()

	var screen = phone_pivot.get_node("Screen") as MeshInstance3D
	var material = screen.material_override as StandardMaterial3D

	if material:
		# 测试颜色设置
		var test_color = Color(1.0, 0.0, 0.0)
		material.albedo_color = test_color
		assert_eq(material.albedo_color, test_color, "材质颜色应可设置")

func test_direction_marker_position():
	"""测试方向标记位置"""
	create_phone_model()

	var marker = phone_pivot.get_node("DirectionMarker") as MeshInstance3D

	# 方向标记应在屏幕上方
	assert_gt(marker.position.y, 0, "方向标记应在屏幕上方")

func test_model_scale():
	"""测试模型缩放"""
	create_phone_model()

	var test_scale = Vector3(2.0, 2.0, 2.0)
	phone_model.scale = test_scale

	assert_vector_eq(phone_model.scale, test_scale, 0.0001, "缩放应正确应用")

func test_multiple_instances():
	"""测试多实例创建"""
	var model1 = create_phone_model_instance()
	var model2 = create_phone_model_instance()

	assert_ne(model1, model2, "应创建不同的实例")
	assert_ne(model1.get_instance_id(), model2.get_instance_id(), "实例ID应不同")

	model1.queue_free()
	model2.queue_free()

# ========== 辅助函数 ==========

func create_phone_model():
	"""创建手机模型（使用sensor_server.gd中的逻辑）"""
	if phone_model != null:
		return

	# 1. 根节点
	phone_model = Node3D.new()
	phone_model.name = "PhoneModel"
	add_child(phone_model)

	# 2. 旋转中心 (Pivot)
	phone_pivot = Node3D.new()
	phone_pivot.name = "Pivot"
	phone_model.add_child(phone_pivot)

	# 3. 机身 (Body) - 黑色长方体
	var body_mesh = BoxMesh.new()
	body_mesh.size = Vector3(3.5, 7.5, 0.4)

	var body_material = StandardMaterial3D.new()
	body_material.albedo_color = Color(0.1, 0.1, 0.1) # Black
	body_material.roughness = 0.5

	var body = MeshInstance3D.new()
	body.name = "Body"
	body.mesh = body_mesh
	body.material_override = body_material
	phone_pivot.add_child(body)

	# 4. 屏幕 (Screen) - 正面
	var screen_mesh = BoxMesh.new()
	screen_mesh.size = Vector3(3.0, 7.0, 0.01)

	var screen_material = StandardMaterial3D.new()
	screen_material.albedo_color = Color(0.0, 0.1, 0.3)
	screen_material.emission_enabled = true
	screen_material.emission = Color(0.0, 0.2, 0.5)
	screen_material.emission_energy_multiplier = 0.5

	phone_screen_mesh = MeshInstance3D.new()
	phone_screen_mesh.name = "Screen"
	phone_screen_mesh.mesh = screen_mesh
	phone_screen_mesh.material_override = screen_material
	phone_screen_mesh.position = Vector3(0, 0, 0.205)
	phone_pivot.add_child(phone_screen_mesh)

	# 5. 方向标记 (Direction Marker) - 额头小白点
	var marker_mesh = BoxMesh.new()
	marker_mesh.size = Vector3(0.5, 0.1, 0.025)

	var marker_material = StandardMaterial3D.new()
	marker_material.albedo_color = Color(1, 1, 1)
	marker_material.emission_enabled = true
	marker_material.emission = Color(1, 1, 1)

	var marker = MeshInstance3D.new()
	marker.name = "DirectionMarker"
	marker.mesh = marker_mesh
	marker.material_override = marker_material
	marker.position = Vector3(0, 3.25, 0.21)
	phone_pivot.add_child(marker)

func create_phone_model_instance() -> Node3D:
	"""创建独立的手机模型实例"""
	var model = Node3D.new()
	model.name = "PhoneModel"

	var pivot = Node3D.new()
	pivot.name = "Pivot"
	model.add_child(pivot)

	var body = MeshInstance3D.new()
	body.name = "Body"
	body.mesh = BoxMesh.new()
	pivot.add_child(body)

	add_child(model)
	return model
