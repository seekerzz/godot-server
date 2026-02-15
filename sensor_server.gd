extends Node3D

# PC端传感器数据接收与3D可视化
# 通过配对服务接收手机传感器数据

const MAX_TRAJECTORY_POINTS := 500

# 传感器数据
var accel_data := Vector3.ZERO
var gyro_data := Vector3.ZERO
var gravity_data := Vector3.ZERO
var magneto_data := Vector3.ZERO

# 运动计算
var velocity := Vector3.ZERO
var phone_position := Vector3.ZERO
var rotation_velocity := Vector3.ZERO
var current_rotation := Vector3.ZERO

# 轨迹记录
var trajectory_points: Array[Vector3] = []
var trajectory_lines: Array[MeshInstance3D] = []

# 客户端管理
var active_clients: Dictionary = {}  # {port: {"ip": String, "accel": Vector3, ...}}

# UI引用
@onready var status_label: Label = %StatusLabel
@onready var accel_label: Label = %AccelLabel
@onready var gyro_label: Label = %GyroLabel
@onready var gravity_label: Label = %GravityLabel
@onready var position_label: Label = %PositionLabel
@onready var trajectory_container: Node3D = %TrajectoryContainer
@onready var phone_model: Node3D = $PhoneModel
@onready var pairing_info_label: Label = %PairingInfoLabel

var discovery_server: Node

func _ready():
	# 启动发现服务
	discovery_server = preload("res://discovery_server.gd").new()
	discovery_server.name = "DiscoveryServer"
	add_child(discovery_server)

	# 连接信号
	discovery_server.client_authenticated.connect(_on_client_authenticated)
	discovery_server.client_disconnected.connect(_on_client_disconnected)

	create_ground_grid()
	update_status("等待配对...")

func set_pairing_info(code: String, ports: Array[int]):
	"""由发现服务调用，更新配对信息显示"""
	if pairing_info_label:
		var port_str := ""
		for i in range(min(ports.size(), 5)):
			if i > 0:
				port_str += ", "
			port_str += str(ports[i])
		if ports.size() > 5:
			port_str += "..."
		pairing_info_label.text = "配对码: %s\n发现端口: %s" % [code, port_str]

func on_sensor_data_received(port: int, data: Dictionary):
	"""处理从发现服务转发过来的传感器数据"""
	if not active_clients.has(port):
		return

	# 解析加速度计
	if data.has("accel"):
		var a = data["accel"]
		accel_data = Vector3(a["x"], a["y"], a["z"])
		active_clients[port]["accel"] = accel_data

	# 解析陀螺仪
	if data.has("gyro"):
		var g = data["gyro"]
		gyro_data = Vector3(g["x"], g["y"], g["z"])
		active_clients[port]["gyro"] = gyro_data

	# 解析重力
	if data.has("gravity"):
		var gr = data["gravity"]
		gravity_data = Vector3(gr["x"], gr["y"], gr["z"])
		active_clients[port]["gravity"] = gravity_data

	# 解析磁力计
	if data.has("magneto"):
		var m = data["magneto"]
		magneto_data = Vector3(m["x"], m["y"], m["z"])
		active_clients[port]["magneto"] = magneto_data

func _on_client_authenticated(client_ip: String, data_port: int):
	"""客户端配对成功"""
	active_clients[data_port] = {
		"ip": client_ip,
		"accel": Vector3.ZERO,
		"gyro": Vector3.ZERO,
		"gravity": Vector3.ZERO,
		"magneto": Vector3.ZERO
	}
	update_status("已连接: " + client_ip + ":" + str(data_port))
	print("[主程序] 客户端连接: ", client_ip, ":", data_port)

func _on_client_disconnected(data_port: int):
	"""客户端断开"""
	active_clients.erase(data_port)
	update_status("客户端断开: " + str(data_port))

func update_status(text: String):
	if status_label:
		status_label.text = "状态: " + text
		status_label.modulate = Color.GREEN if text.begins_with("已连接") else Color.YELLOW

func _process(delta):
	# 更新手机3D模型（使用最新的传感器数据）
	update_phone_visualization(delta)

	# 更新UI
	update_ui()

func update_phone_visualization(delta: float):
	# 使用陀螺仪积分计算旋转
	rotation_velocity = gyro_data
	current_rotation += rotation_velocity * delta

	# 应用旋转到手机模型 (注意坐标系转换)
	phone_model.rotation = Vector3(
		current_rotation.x,
		-current_rotation.z,  # Godot的Y轴对应手机的Z轴旋转
		current_rotation.y
	)

	# 使用加速度计计算位置 (双重积分)
	var linear_accel = accel_data - gravity_data

	# 低通滤波去除噪声
	linear_accel = linear_accel * 0.1

	# 速度积分
	velocity += linear_accel * delta * 2.0

	# 阻尼衰减，防止漂移
	velocity *= 0.98

	# 位置积分
	phone_position += velocity * delta * 0.5

	# 限制运动范围
	phone_position.x = clamp(phone_position.x, -10, 10)
	phone_position.y = clamp(phone_position.y, 0.5, 10)
	phone_position.z = clamp(phone_position.z, -10, 10)

	# 更新手机模型位置
	phone_model.position = phone_position

	# 记录轨迹
	if trajectory_points.is_empty() or phone_position.distance_to(trajectory_points[-1]) > 0.1:
		add_trajectory_point(phone_position)

func add_trajectory_point(pos: Vector3):
	trajectory_points.append(pos)

	# 限制轨迹点数量
	if trajectory_points.size() > MAX_TRAJECTORY_POINTS:
		trajectory_points.pop_front()
		if trajectory_lines.size() > 0:
			var old_line = trajectory_lines.pop_front()
			old_line.queue_free()

	# 创建轨迹线段
	if trajectory_points.size() >= 2:
		var start_pos = trajectory_points[-2]
		var end_pos = trajectory_points[-1]
		create_trajectory_line(start_pos, end_pos)

func create_trajectory_line(start_pos: Vector3, end_pos: Vector3):
	var mesh_instance = MeshInstance3D.new()
	var mesh = ImmediateMesh.new()
	mesh_instance.mesh = mesh

	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	mesh.surface_set_color(Color(0, 1, 1, 0.8))
	mesh.surface_add_vertex(start_pos)
	mesh.surface_add_vertex(end_pos)
	mesh.surface_end()

	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0, 0.8, 1, 0.6)
	material.emission_enabled = true
	material.emission = Color(0, 0.5, 0.8, 1)
	material.emission_energy = 0.3
	mesh_instance.material_override = material

	trajectory_container.add_child(mesh_instance)
	trajectory_lines.append(mesh_instance)

func create_ground_grid():
	# 创建地面网格
	for i in range(-10, 11):
		# X方向线
		create_grid_line(Vector3(i, 0, -10), Vector3(i, 0, 10), Color(0.3, 0.3, 0.3, 0.5))
		# Z方向线
		create_grid_line(Vector3(-10, 0, i), Vector3(10, 0, i), Color(0.3, 0.3, 0.3, 0.5))

func create_grid_line(start_pos: Vector3, end_pos: Vector3, color: Color):
	var mesh_instance = MeshInstance3D.new()
	var mesh = ImmediateMesh.new()
	mesh_instance.mesh = mesh

	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	mesh.surface_set_color(color)
	mesh.surface_add_vertex(start_pos)
	mesh.surface_add_vertex(end_pos)
	mesh.surface_end()

	var material = StandardMaterial3D.new()
	material.albedo_color = color
	mesh_instance.material_override = material

	add_child(mesh_instance)

func update_ui():
	accel_label.text = "加速度: X: %.3f Y: %.3f Z: %.3f" % [accel_data.x, accel_data.y, accel_data.z]
	gyro_label.text = "陀螺仪: X: %.3f Y: %.3f Z: %.3f" % [gyro_data.x, gyro_data.y, gyro_data.z]
	gravity_label.text = "重力: X: %.3f Y: %.3f Z: %.3f" % [gravity_data.x, gravity_data.y, gravity_data.z]
	position_label.text = "位置: X: %.3f Y: %.3f Z: %.3f" % [phone_position.x, phone_position.y, phone_position.z]

func _input(event):
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()

	if event.is_action_pressed("ui_accept"):
		reset_view()

	if event is InputEventKey:
		if event.pressed and event.keycode == KEY_C:
			clear_trajectory()

		if event.pressed and event.keycode == KEY_R:
			# 重新生成配对码
			if discovery_server:
				discovery_server.regenerate_pairing_code()

func reset_view():
	phone_position = Vector3.ZERO
	velocity = Vector3.ZERO
	current_rotation = Vector3.ZERO
	phone_model.position = phone_position
	phone_model.rotation = Vector3.ZERO

func clear_trajectory():
	trajectory_points.clear()
	for line in trajectory_lines:
		line.queue_free()
	trajectory_lines.clear()
