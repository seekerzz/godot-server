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

# 录制数据缓存
var is_recording := false
var recorded_data: Array[Dictionary] = []
var current_record_date := ""

# 回放数据缓存（来自手机）
var is_receiving_playback := false
var playback_data_buffer: Array[Dictionary] = []
var current_playback_filename := ""

# 本地回放
var is_local_playing := false
var local_playback_frames: Array[Dictionary] = []
var local_playback_index: int = 0
var local_playback_timer: float = 0.0
const PLAYBACK_FPS := 20.0  # 回放帧率

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
	print("[控制] 按键说明: R=重置视角 | C=清除轨迹 | L=加载录制文件 | P=本地回放 | S=保存回放数据 | ESC=退出")

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

	# 处理本地回放
	if is_local_playing:
		local_playback_timer += delta
		if local_playback_timer >= (1.0 / PLAYBACK_FPS):
			local_playback_timer = 0.0
			process_local_playback_frame()
		return

	# 接收UDP数据
	if udp_socket and udp_socket.is_bound():
		var packet = udp_socket.get_packet()
		if packet.size() > 0:
			var data_str = packet.get_string_from_utf8()
			# 只打印前100字符避免日志过长
			var log_str = data_str.substr(0, 100)
			if data_str.length() > 100:
				log_str += "..."
			print("[接收] 大小: ", packet.size(), ", 数据: ", log_str)
			parse_sensor_data(data_str)
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

	# 处理标记类型
	if data.has("type"):
		var marker_type = data["type"]
		match marker_type:
			"record_start":
				start_recording()
				return
			"record_stop":
				stop_recording()
				return
			"playback_start":
				start_receiving_playback(data)
				return
			"playback_stop":
				stop_receiving_playback()
				return
		return

	# 处理传感器数据
	if data.has("accel"):
		var a = data["accel"]
		accel_data = Vector3(a["x"], a["y"], a["z"])

	if data.has("gyro"):
		var g = data["gyro"]
		gyro_data = Vector3(g["x"], g["y"], g["z"])

	if data.has("gravity"):
		var gr = data["gravity"]
		gravity_data = Vector3(gr["x"], gr["y"], gr["z"])

	if data.has("magneto"):
		var m = data["magneto"]
		magneto_data = Vector3(m["x"], m["y"], m["z"])

	# 如果是录制数据，保存到缓存
	if data.get("recorded", false) and is_recording:
		recorded_data.append(data.duplicate())
		status_label.text = "接收中... [录制 " + str(recorded_data.size()) + " 帧]"
		status_label.modulate = Color.RED

	# 如果是回放数据，保存到回放缓存
	if data.get("playback", false):
		if is_receiving_playback:
			playback_data_buffer.append(data.duplicate())
			status_label.text = "接收回放数据... [" + str(playback_data_buffer.size()) + "/" + str(data.get("total_frames", 0)) + " 帧]"
			status_label.modulate = Color.CYAN
			print("[回放接收] 帧 " + str(data.get("frame_index", 0)) + "/" + str(data.get("total_frames", 0)))
		else:
			print("[回放接收] 警告: 收到回放数据但未处于接收状态")

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
	linear_accel = linear_accel * 0.1  # 低通滤波
	velocity += linear_accel * delta * 2.0
	velocity *= 0.98  # 阻尼
	phone_position += velocity * delta * 0.5

	# 限制运动范围
	phone_position.x = clamp(phone_position.x, -10, 10)
	phone_position.y = clamp(phone_position.y, 0.5, 10)
	phone_position.z = clamp(phone_position.z, -10, 10)

	phone_model.position = phone_position

	# 记录轨迹
	if trajectory_points.is_empty() or phone_position.distance_to(trajectory_points[-1]) > 0.1:
		add_trajectory_point(phone_position)

func add_trajectory_point(pos: Vector3):
	trajectory_points.append(pos)

	if trajectory_points.size() > MAX_TRAJECTORY_POINTS:
		trajectory_points.pop_front()
		if trajectory_lines.size() > 0:
			var old_line = trajectory_lines.pop_front()
			old_line.queue_free()

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
	for i in range(-10, 11):
		create_grid_line(Vector3(i, 0, -10), Vector3(i, 0, 10), Color(0.3, 0.3, 0.3, 0.5))
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

	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_C:
				clear_trajectory()
			KEY_L:
				load_local_recording()
			KEY_P:
				toggle_local_playback()
			KEY_S:
				save_playback_buffer_to_file()

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
	pass

# ===== 录制功能 =====

func start_recording():
	if is_recording:
		return

	is_recording = true
	recorded_data.clear()

	var datetime = Time.get_datetime_dict_from_system()
	current_record_date = "%04d%02d%02d_%02d%02d%02d" % [
		datetime.year, datetime.month, datetime.day,
		datetime.hour, datetime.minute, datetime.second
	]

	status_label.text = "开始录制..."
	status_label.modulate = Color.RED
	print("[录制] 开始录制，文件名前缀: ", current_record_date)

func stop_recording():
	if not is_recording:
		return

	is_recording = false
	status_label.text = "录制结束，保存中..."
	save_recorded_data()

func save_recorded_data():
	if recorded_data.is_empty():
		print("[录制] 没有数据需要保存")
		return

	var filename = "user://record_%s.json" % current_record_date
	var file = FileAccess.open(filename, FileAccess.WRITE)
	if file:
		var output = {
			"record_date": current_record_date,
			"frame_count": recorded_data.size(),
			"data": recorded_data
		}
		file.store_string(JSON.stringify(output, "\t"))
		file.close()
		print("[录制] 数据已保存到: ", filename, " (", recorded_data.size(), " 帧)")
		status_label.text = "录制已保存: " + filename.get_file()
		status_label.modulate = Color.GREEN
	else:
		print("[录制] 保存失败")
		status_label.text = "保存失败"

# ===== 回放数据接收（来自手机）=====

func start_receiving_playback(data: Dictionary):
	is_receiving_playback = true
	playback_data_buffer.clear()
	current_playback_filename = data.get("filename", "unknown")
	var fc = data.get("frame_count", 0)
	print("[回放接收] ============================")
	print("[回放接收] 开始接收回放数据")
	print("[回放接收] 文件名: ", current_playback_filename)
	print("[回放接收] 预期帧数: ", fc)
	print("[回放接收] ============================")
	status_label.text = "开始接收回放数据... [0/" + str(fc) + "]"
	status_label.modulate = Color.CYAN

func stop_receiving_playback():
	is_receiving_playback = false
	status_label.text = "回放接收完成: " + str(playback_data_buffer.size()) + " 帧"
	status_label.modulate = Color.GREEN
	print("[回放接收] 完成，共接收 ", playback_data_buffer.size(), " 帧")
	print("[提示] 按 S 键保存回放数据到文件")

func save_playback_buffer_to_file():
	if playback_data_buffer.is_empty():
		print("[回放保存] 没有回放数据可保存")
		return

	var datetime = Time.get_datetime_dict_from_system()
	var filename = "user://playback_%04d%02d%02d_%02d%02d%02d_%s.json" % [
		datetime.year, datetime.month, datetime.day,
		datetime.hour, datetime.minute, datetime.second,
		current_playback_filename.get_file().get_basename()
	]

	var file = FileAccess.open(filename, FileAccess.WRITE)
	if file:
		var output = {
			"receive_date": "%04d-%02d-%02d %02d:%02d:%02d" % [
				datetime.year, datetime.month, datetime.day,
				datetime.hour, datetime.minute, datetime.second
			],
			"source_filename": current_playback_filename,
			"frame_count": playback_data_buffer.size(),
			"frames": playback_data_buffer
		}
		file.store_string(JSON.stringify(output, "\t"))
		file.close()
		print("[回放保存] 数据已保存到: ", filename)
		status_label.text = "回放数据已保存: " + filename.get_file()
	else:
		print("[回放保存] 保存失败")

# ===== 本地回放功能 =====

func load_local_recording():
	# 查找最新的录制文件
	var dir = DirAccess.open("user://")
	if not dir:
		print("[本地回放] 无法打开用户目录")
		return

	dir.list_dir_begin()
	var file_name = dir.get_next()
	var files: Array[String] = []

	while file_name != "":
		if file_name.begins_with("record_") or file_name.begins_with("playback_"):
			if file_name.ends_with(".json"):
				files.append(file_name)
		file_name = dir.get_next()

	if files.is_empty():
		print("[本地回放] 没有找到录制文件")
		return

	files.sort()
	files.reverse()

	var latest_file = files[0]
	print("[本地回放] 加载文件: ", latest_file)

	var file = FileAccess.open("user://" + latest_file, FileAccess.READ)
	if not file:
		print("[本地回放] 无法打开文件")
		return

	var content = file.get_as_text()
	file.close()

	var json = JSON.new()
	var err = json.parse(content)
	if err != OK:
		print("[本地回放] 文件解析失败")
		return

	var data = json.get_data()
	local_playback_frames.clear()

	if data.has("frames"):
		local_playback_frames = data["frames"]
	elif data.has("data"):
		local_playback_frames = data["data"]

	if local_playback_frames.is_empty():
		print("[本地回放] 没有有效帧数据")
		return

	print("[本地回放] 加载完成，共 ", local_playback_frames.size(), " 帧")
	print("[提示] 按 P 键开始/停止本地回放")
	status_label.text = "已加载: " + latest_file.get_file() + " [" + str(local_playback_frames.size()) + " 帧]"

func toggle_local_playback():
	if is_local_playing:
		stop_local_playback()
	else:
		start_local_playback()

func start_local_playback():
	if local_playback_frames.is_empty():
		print("[本地回放] 请先按 L 键加载录制文件")
		return

	is_local_playing = true
	local_playback_index = 0
	local_playback_timer = 0.0
	clear_trajectory()
	reset_view()
	print("[本地回放] 开始回放，共 ", local_playback_frames.size(), " 帧")

func stop_local_playback():
	is_local_playing = false
	print("[本地回放] 停止回放")
	status_label.text = "回放已停止"

func process_local_playback_frame():
	if local_playback_index >= local_playback_frames.size():
		stop_local_playback()
		status_label.text = "回放完成"
		return

	var frame = local_playback_frames[local_playback_index]

	# 解析传感器数据
	if frame.has("accel"):
		var a = frame["accel"]
		accel_data = Vector3(a["x"], a["y"], a["z"])

	if frame.has("gyro"):
		var g = frame["gyro"]
		gyro_data = Vector3(g["x"], g["y"], g["z"])

	if frame.has("gravity"):
		var gr = frame["gravity"]
		gravity_data = Vector3(gr["x"], gr["y"], gr["z"])

	if frame.has("magneto"):
		var m = frame["magneto"]
		magneto_data = Vector3(m["x"], m["y"], m["z"])

	local_playback_index += 1
	status_label.text = "本地回放: %d/%d" % [local_playback_index, local_playback_frames.size()]
