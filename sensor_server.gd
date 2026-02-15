extends Node3D

# PC端传感器数据接收与3D可视化
# 通过UDP接收手机传感器数据

const SERVER_PORT := 49555
const CLIENT_PORT := 9877
const MAX_TRAJECTORY_POINTS := 500

var udp_socket: PacketPeerUDP

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

# UI引用
@onready var status_label: Label = %StatusLabel
@onready var accel_label: Label = %AccelLabel
@onready var gyro_label: Label = %GyroLabel
@onready var gravity_label: Label = %GravityLabel
@onready var position_label: Label = %PositionLabel
@onready var trajectory_container: Node3D = %TrajectoryContainer
@onready var phone_model: Node3D = $PhoneModel

func _ready():
	start_server()
	create_ground_grid()

func start_server():
	udp_socket = PacketPeerUDP.new()
	var err = udp_socket.bind(SERVER_PORT, "0.0.0.0")
	if err == OK:
		status_label.text = "状态: 服务器已启动 (端口 %d)" % SERVER_PORT
		status_label.modulate = Color.GREEN
		print("[服务器] 已在端口 ", SERVER_PORT, " 启动")
		print("[服务器] 已绑定: ", udp_socket.is_bound())
	else:
		status_label.text = "状态: 服务器启动失败 (%d)" % err
		status_label.modulate = Color.RED
		print("[服务器] 启动失败: ", err)

var frame_count := 0

func _process(delta):
	frame_count += 1
	# 接收UDP数据
	if udp_socket and udp_socket.is_bound():
		# 直接尝试获取数据包
		var packet = udp_socket.get_packet()
		if packet.size() > 0:
			var data = packet.get_string_from_utf8()
			print("[接收] 数据大小: ", packet.size(), ", 数据: ", data)
			parse_sensor_data(data)
		elif frame_count % 60 == 0:
			print("[帧", frame_count, "] 等待数据...")

	# 更新手机3D模型
	update_phone_visualization(delta)

	# 更新UI
	update_ui()

func parse_sensor_data(json_str: String):
	var json = JSON.new()
	var err = json.parse(json_str)
	if err != OK:
		return

	var data = json.get_data()
	if typeof(data) != TYPE_DICTIONARY:
		return

	# 解析加速度计
	if data.has("accel"):
		var a = data["accel"]
		accel_data = Vector3(a["x"], a["y"], a["z"])

	# 解析陀螺仪
	if data.has("gyro"):
		var g = data["gyro"]
		gyro_data = Vector3(g["x"], g["y"], g["z"])

	# 解析重力
	if data.has("gravity"):
		var gr = data["gravity"]
		gravity_data = Vector3(gr["x"], gr["y"], gr["z"])

	# 解析磁力计
	if data.has("magneto"):
		var m = data["magneto"]
		magneto_data = Vector3(m["x"], m["y"], m["z"])

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
	# 减去重力得到线性加速度
	var linear_accel = accel_data - gravity_data

	# 低通滤波去除噪声
	linear_accel = linear_accel * 0.1

	# 速度积分
	velocity += linear_accel * delta * 2.0  # 缩放因子

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

func _on_timer_timeout():
	# 定时发送心跳给客户端（可选）
	pass
