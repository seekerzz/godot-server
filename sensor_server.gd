extends Node3D

# PC端传感器数据接收与3D可视化 - 乒乓球拍版本
# 通过UDP接收手机传感器数据（二进制协议）

const SERVER_PORT := 49555
const CLIENT_PORT := 9877
const MAX_TRAJECTORY_POINTS := 500
const PI := 3.14159265359
const BINARY_PACKET_SIZE := 28  # 7 floats * 4 bytes

var udp_socket: PacketPeerUDP

# 传感器数据
var user_accel_data := Vector3.ZERO  # 剔除重力后的线性加速度
var current_rotation := Quaternion.IDENTITY  # 融合后的姿态

# 运动计算 - 弹性回中算法
var velocity := Vector3.ZERO
var phone_position := Vector3.ZERO

# 导出变量 - 可调整的运动参数
@export var friction: float = 5.0  # 速度衰减系数
@export var return_speed: float = 2.0  # 回中速度
@export var origin_position: Vector3 = Vector3.ZERO  # 中心点位置
@export var max_displacement: float = 5.0  # 最大位移限制

# 校准偏移
var calibration_offset: Quaternion = Quaternion.IDENTITY

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
const PLAYBACK_FPS := 60.0  # 回放帧率

# 文件传输接收
var file_transfer_in_progress := false
var file_transfer_filename := ""
var file_transfer_total_chunks := 0
var file_transfer_chunks: Dictionary = {}
var file_transfer_buffer := ""

# UI引用
@onready var status_label: Label = %StatusLabel
@onready var accel_label: Label = %AccelLabel
@onready var rotation_label: Label = %RotationLabel
@onready var velocity_label: Label = %VelocityLabel
@onready var position_label: Label = %PositionLabel
# @onready var trajectory_container: Node3D = %TrajectoryContainer # 移除轨迹容器引用
var phone_visual: Node3D
@onready var debug_label_3d: Label3D = %DebugLabel3D

# 按钮引用
@onready var list_files_button: Button = %ListFilesButton
@onready var load_recent_button: Button = %LoadRecentButton
@onready var playback_button: Button = %PlaybackButton
@onready var clear_button: Button = %ClearButton
@onready var reset_button: Button = %ResetButton
@onready var calibrate_button: Button = %CalibrateButton
@onready var file_list_label: Label = %FileListLabel

# 帧计数
var frame_count := 0
var last_packet_time := 0.0

func _ready():
	start_server()
	create_ground_grid()
	connect_buttons()
	create_phone_visuals()
	print("[控制] 按键说明: R/Space=重置视角(Tare) | L=加载最近文件 | O=查看接收文件 | P=回放 | S=保存数据 | ESC=退出")
	print("[提示] 接收的文件保存在 received_files/ 文件夹，也可以使用右侧按钮操作")

func connect_buttons():
	if list_files_button:
		list_files_button.pressed.connect(list_received_files)
	if load_recent_button:
		load_recent_button.pressed.connect(load_most_recent_received_file)
	if playback_button:
		playback_button.pressed.connect(toggle_local_playback)
	if clear_button:
		# clear_button.pressed.connect(clear_trajectory) # 移除轨迹清除
		pass
	if reset_button:
		reset_button.pressed.connect(reset_view)
	if calibrate_button:
		calibrate_button.pressed.connect(reset_view) # 校准按钮现在只是重置/Tare

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

func _process(delta):
	frame_count += 1
	last_packet_time += delta

	# 处理本地回放
	if is_local_playing:
		local_playback_timer += delta
		if local_playback_timer >= (1.0 / PLAYBACK_FPS):
			local_playback_timer = 0.0
			process_local_playback_frame()
		update_phone_visualization(delta)
		update_ui()
		return

	# 接收UDP数据
	if udp_socket and udp_socket.is_bound():
		var packet_count = 0
		# 处理所有可用数据包
		while udp_socket.get_available_packet_count() > 0:
			var packet = udp_socket.get_packet()
			packet_count += 1
			if packet.size() > 0:
				# 调试输出包大小
				if frame_count % 60 == 0 and packet_count == 1:
					print("[接收] 包大小: %d bytes (期望: %d bytes)" % [packet.size(), BINARY_PACKET_SIZE])
				# 判断是二进制数据还是JSON控制消息
				if packet.size() == BINARY_PACKET_SIZE:
					parse_binary_sensor_data(packet)
					last_packet_time = 0.0
				else:
					# 尝试解析为JSON（控制消息）
					var data_str = packet.get_string_from_utf8()
					parse_control_message(data_str)
					if frame_count % 60 == 0:
						print("[接收] JSON消息: %s" % data_str.substr(0, 100))

	# 更新手机3D模型
	update_phone_visualization(delta)

	# 更新UI
	update_ui()

func parse_binary_sensor_data(packet: PackedByteArray):
	"""解析28字节的二进制传感器数据包
	包结构:
	- UserAccel.x (float, 4 bytes)
	- UserAccel.y (float, 4 bytes)
	- UserAccel.z (float, 4 bytes)
	- Quaternion.x (float, 4 bytes)
	- Quaternion.y (float, 4 bytes)
	- Quaternion.z (float, 4 bytes)
	- Quaternion.w (float, 4 bytes)
	"""
	# 记录原始字节用于调试
	frame_count += 1
	var show_debug = frame_count <= 10 or frame_count % 120 == 0

	if show_debug:
		print("[调试] 原始字节 (hex): ")
		var hex_str = ""
		for i in range(min(28, packet.size())):
			hex_str += "%02x " % packet[i]
			if (i + 1) % 4 == 0:
				hex_str += "| "
		print(hex_str)

	var buffer = StreamPeerBuffer.new()
	buffer.data_array = packet
	buffer.big_endian = false  # 使用小端序

	# 读取线性加速度（已剔除重力）
	var new_user_accel = Vector3(
		buffer.get_float(),
		buffer.get_float(),
		buffer.get_float()
	)

	# 读取四元数姿态
	var new_rotation = Quaternion(
		buffer.get_float(),
		buffer.get_float(),
		buffer.get_float(),
		buffer.get_float()
	)

	# 更新数据
	user_accel_data = new_user_accel
	current_rotation = new_rotation

	# 调试输出
	if show_debug:
		print("[接收#%d] UserAccel: (%.3f, %.3f, %.3f) | Rotation: (%.3f, %.3f, %.3f, %.3f)" % [
			frame_count,
			user_accel_data.x, user_accel_data.y, user_accel_data.z,
			current_rotation.x, current_rotation.y, current_rotation.z, current_rotation.w
		])
		print("[调试] 四元数模长: %.6f (应接近1.0)" % current_rotation.length())

	# 如果是录制状态，保存数据
	if is_recording:
		recorded_data.append({
			"timestamp": Time.get_unix_time_from_system(),
			"user_accel": {"x": user_accel_data.x, "y": user_accel_data.y, "z": user_accel_data.z},
			"quaternion": {"x": current_rotation.x, "y": current_rotation.y, "z": current_rotation.z, "w": current_rotation.w}
		})
		if recorded_data.size() % 60 == 0:
			status_label.text = "录制中... [%d 帧]" % recorded_data.size()

func parse_control_message(json_str: String):
	"""解析JSON控制消息（录制控制、文件传输等）"""
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
		print("[控制消息] 收到类型: ", marker_type)
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
			"file_transfer_start":
				handle_file_transfer_start(data)
				return
			"file_chunk":
				handle_file_chunk(data)
				return
			"file_transfer_end":
				handle_file_transfer_end(data)
				return

func create_phone_visuals():
	"""程序化创建手机模型"""
	if phone_visual != null:
		return

	phone_visual = Node3D.new()
	phone_visual.name = "PhoneVisual"
	add_child(phone_visual)

	# 1. 机身 Body
	var body_mesh = BoxMesh.new()
	body_mesh.size = Vector3(0.075, 0.15, 0.01) # 宽0.075, 高0.15, 厚0.01

	var body_mat = StandardMaterial3D.new()
	body_mat.albedo_color = Color(0.2, 0.2, 0.2) # 深灰色
	body_mat.metallic = 0.8
	body_mat.roughness = 0.3

	var body = MeshInstance3D.new()
	body.name = "Body"
	body.mesh = body_mesh
	body.material_override = body_mat
	phone_visual.add_child(body)

	# 2. 屏幕 Screen (Z+ 面)
	var screen_mesh = BoxMesh.new()
	screen_mesh.size = Vector3(0.07, 0.14, 0.001) # 略小

	var screen_mat = StandardMaterial3D.new()
	screen_mat.albedo_color = Color(0.0, 0.0, 0.0)
	screen_mat.emission_enabled = true
	screen_mat.emission = Color(0.1, 0.1, 0.1) # 微弱发光

	var screen = MeshInstance3D.new()
	screen.name = "Screen"
	screen.mesh = screen_mesh
	screen.material_override = screen_mat
	screen.position = Vector3(0, 0, 0.0055) # 稍微突出于机身
	phone_visual.add_child(screen)

	# 3. 标记 Notch (顶部)
	var notch_mesh = BoxMesh.new()
	notch_mesh.size = Vector3(0.02, 0.005, 0.001)

	var notch_mat = StandardMaterial3D.new()
	notch_mat.albedo_color = Color(0.1, 0.1, 0.1)

	var notch = MeshInstance3D.new()
	notch.name = "Notch"
	notch.mesh = notch_mesh
	notch.material_override = notch_mat
	notch.position = Vector3(0, 0.065, 0.006) # 位于屏幕上方
	phone_visual.add_child(notch)

func update_phone_visualization(delta: float):
	if phone_visual == null:
		return

	# 1. 姿态计算
	# display_rotation = calibration_offset * current_rotation
	var display_rotation = calibration_offset * current_rotation
	phone_visual.quaternion = display_rotation

	# 2. 物理与位移
	# 将本地加速度转换为世界加速度
	# world_accel = display_rotation * user_accel_local
	var world_accel = display_rotation * user_accel_data

	# 速度积分
	velocity += world_accel * delta

	# 阻力
	velocity = velocity.lerp(Vector3.ZERO, friction * delta)

	# 位置积分
	phone_position += velocity * delta

	# 弹性回中
	phone_position = phone_position.lerp(origin_position, return_speed * delta)

	# 范围限制 (Clamp)
	phone_position.x = clamp(phone_position.x, -max_displacement, max_displacement)
	phone_position.y = clamp(phone_position.y, -max_displacement, max_displacement) # 允许上下移动
	phone_position.z = clamp(phone_position.z, -max_displacement, max_displacement)

	# 应用位置
	phone_visual.position = phone_position

	# 更新调试标签
	if debug_label_3d:
		var accel_mag = user_accel_data.length()
		debug_label_3d.text = "Accel: %.2f" % accel_mag
		debug_label_3d.position = phone_position + Vector3(0, 0.2, 0)
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
	var accel_mag = user_accel_data.length()
	accel_label.text = "UserAccel: %.3f (%.3f, %.3f, %.3f)" % [accel_mag, user_accel_data.x, user_accel_data.y, user_accel_data.z]
	rotation_label.text = "Rotation: (%.3f, %.3f, %.3f, %.3f)" % [current_rotation.x, current_rotation.y, current_rotation.z, current_rotation.w]
	velocity_label.text = "速度: %.3f m/s" % velocity.length()
	position_label.text = "位置: X: %.3f Y: %.3f Z: %.3f" % [phone_position.x, phone_position.y, phone_position.z]

func _input(event):
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()

	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_SPACE, KEY_R:
				reset_view()
			KEY_L:
				load_most_recent_received_file()
			KEY_O:
				list_received_files()
			KEY_P:
				toggle_local_playback()
			KEY_S:
				save_playback_buffer_to_file()
			KEY_K:
				reset_view()

func reset_view():
	phone_position = Vector3.ZERO
	velocity = Vector3.ZERO
	# current_rotation = Quaternion.IDENTITY # 不要重置 current_rotation, 它来自传感器

	# 设置校准偏移 (Tare)
	calibration_offset = current_rotation.inverse()

	if phone_visual:
		phone_visual.position = phone_position
		# phone_visual.quaternion 会在下一帧 update_phone_visualization 中更新为 IDENTITY (因为 offset * rotation)

	print("[视图] 已重置 (Tare)")

# func clear_trajectory():
# 	pass

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
		print("[本地回放] 请先加载录制文件")
		return

	is_local_playing = true
	local_playback_index = 0
	local_playback_timer = 0.0
	# clear_trajectory()
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

	# 解析新的录制数据格式
	if frame.has("user_accel"):
		var ua = frame["user_accel"]
		user_accel_data = Vector3(ua["x"], ua["y"], ua["z"])

	if frame.has("quaternion"):
		var q = frame["quaternion"]
		current_rotation = Quaternion(q["x"], q["y"], q["z"], q["w"])

	# 兼容旧格式
	if frame.has("accel"):
		var a = frame["accel"]
		# 旧格式没有user_accel，使用accel代替
		user_accel_data = Vector3(a["x"], a["y"], a["z"])

	local_playback_index += 1
	status_label.text = "本地回放: %d/%d" % [local_playback_index, local_playback_frames.size()]

# ===== 文件传输接收功能 =====

func handle_file_transfer_start(data: Dictionary):
	file_transfer_in_progress = true
	file_transfer_filename = data.get("filename", "unknown.json")
	file_transfer_total_chunks = data.get("total_chunks", 0)
	file_transfer_chunks.clear()
	file_transfer_buffer = ""

	print("[文件接收] ============================")
	print("[文件接收] 开始接收文件")
	print("[文件接收] 文件名: ", file_transfer_filename)
	print("[文件接收] 总分片数: ", file_transfer_total_chunks)
	print("[文件接收] ============================")

	status_label.text = "接收文件: " + file_transfer_filename
	status_label.modulate = Color.CYAN

func handle_file_chunk(data: Dictionary):
	if not file_transfer_in_progress:
		print("[文件接收] 警告: 收到文件分片但传输未开始")
		return

	var chunk_index = int(data.get("chunk_index", 0))
	var chunk_data = data.get("data", "")
	var filename = data.get("filename", "unknown")

	# 打印每个分片的接收日志（仅打印前5个和每10个）
	if chunk_index < 5 or chunk_index % 10 == 0:
		print("[文件接收] 收到分片 #", chunk_index, " 大小: ", chunk_data.length(), " 字节")

	file_transfer_chunks[chunk_index] = chunk_data

	var progress = int(float(file_transfer_chunks.size()) / file_transfer_total_chunks * 100)
	status_label.text = "接收文件... %d%% [%d/%d]" % [progress, file_transfer_chunks.size(), file_transfer_total_chunks]

	if file_transfer_chunks.size() % 10 == 0 or file_transfer_chunks.size() == file_transfer_total_chunks:
		print("[文件接收] 进度: ", file_transfer_chunks.size(), "/", file_transfer_total_chunks, " (", progress, "%)")

func handle_file_transfer_end(data: Dictionary):
	if not file_transfer_in_progress:
		return

	file_transfer_in_progress = false

	# 统计丢失的分片
	var missing_chunks: Array[int] = []
	for i in range(file_transfer_total_chunks):
		if not file_transfer_chunks.has(i):
			missing_chunks.append(i)

	var received_count = file_transfer_chunks.size()
	var total_count = file_transfer_total_chunks
	var missing_count = missing_chunks.size()

	print("[文件接收] ============================")
	print("[文件接收] 传输完成统计")
	print("[文件接收] 总分片: ", total_count)
	print("[文件接收] 已接收: ", received_count)
	print("[文件接收] 丢失: ", missing_count)
	if missing_count > 0:
		print("[文件接收] 丢失分片编号: ", missing_chunks)
	print("[文件接收] ============================")

	# 即使丢失分片也尝试重组文件
	file_transfer_buffer = ""
	for i in range(file_transfer_total_chunks):
		if file_transfer_chunks.has(i):
			file_transfer_buffer += file_transfer_chunks[i]

	print("[文件接收] 文件内容重组完成，大小: ", file_transfer_buffer.length(), " 字节")

	# 保存文件到项目目录下的 received_files 文件夹
	var save_dir = "res://received_files/"
	var save_filename = save_dir + "received_" + file_transfer_filename.get_file()

	# 确保目录存在
	var dir = DirAccess.open("res://")
	if dir and not dir.dir_exists("received_files"):
		dir.make_dir("received_files")
		print("[文件接收] 创建目录: " + save_dir)

	var file = FileAccess.open(save_filename, FileAccess.WRITE)
	if file:
		file.store_string(file_transfer_buffer)
		file.close()
		print("[文件接收] 文件已保存: ", save_filename)
	else:
		print("[文件接收] 错误: 保存文件失败")
		status_label.text = "保存文件失败"
		return

	# 保存传输记录
	var transfer_record = {
		"filename": file_transfer_filename,
		"saved_path": save_filename,
		"total_chunks": total_count,
		"received_chunks": received_count,
		"missing_chunks": missing_chunks,
		"file_size": file_transfer_buffer.length(),
		"timestamp": Time.get_unix_time_from_system(),
		"complete": missing_count == 0
	}
	append_transfer_log(transfer_record)

	if missing_count == 0:
		status_label.text = "文件接收完成: " + save_filename.get_file()
		status_label.modulate = Color.GREEN
		print("[文件接收] 准备自动回放...")
		load_and_play_file(save_filename)
	else:
		status_label.text = "文件已保存(不完整): 丢失 %d 分片" % missing_count
		status_label.modulate = Color.ORANGE
		print("[文件接收] 警告: 文件不完整，已保存但不回放")
		print("[提示] 按 O 键查看接收文件列表，按 L 键加载最近文件")

func append_transfer_log(record: Dictionary):
	var log_path = "res://received_files/transfer_log.txt"
	var log_entry = "[%s] %s | 完成: %s | 分片: %d/%d | 大小: %d 字节\n" % [
		Time.get_datetime_string_from_system(),
		record["filename"],
		"是" if record["complete"] else "否",
		record["received_chunks"],
		record["total_chunks"],
		record["file_size"]
	]
	var file = FileAccess.open(log_path, FileAccess.READ_WRITE)
	if not file:
		file = FileAccess.open(log_path, FileAccess.WRITE)
	else:
		file.seek_end()
	file.store_string(log_entry)
	file.close()
	print("[日志] 已记录传输: ", record["filename"])

func list_received_files():
	print("\n========== 接收文件列表 ==========")
	var dir = DirAccess.open("res://received_files/")
	if not dir:
		print("没有接收文件目录或目录为空")
		update_file_list_ui([])
		return

	dir.list_dir_begin()
	var file_name = dir.get_next()
	var files: Array[String] = []

	while file_name != "":
		if file_name.begins_with("received_") and file_name.ends_with(".json"):
			files.append(file_name)
		file_name = dir.get_next()

	if files.is_empty():
		print("没有接收到的文件")
		update_file_list_ui([])
		return

	files.sort()
	files.reverse()

	# 更新UI显示
	update_file_list_ui(files)

	# 打印到控制台
	for i in range(files.size()):
		var f = files[i]
		var file_obj = FileAccess.open("res://received_files/" + f, FileAccess.READ)
		var size_str = "未知"
		if file_obj:
			var content = file_obj.get_as_text()
			size_str = str(content.length()) + " 字节"
			file_obj.close()
		print("[%d] %s (%s)" % [i + 1, f, size_str])

	print("====================================")

func update_file_list_ui(files: Array[String]):
	if not file_list_label:
		return

	if files.is_empty():
		file_list_label.text = "接收文件列表:\n(暂无文件)"
		return

	var text = "接收文件列表:\n"
	for i in range(min(files.size(), 5)):  # 最多显示5个
		var f = files[i]
		var file_obj = FileAccess.open("res://received_files/" + f, FileAccess.READ)
		var size_str = "未知"
		if file_obj:
			var content = file_obj.get_as_text()
			size_str = str(content.length() / 1024.0).substr(0, 4) + "KB"
			file_obj.close()
		# 简化文件名显示
		var display_name = f.replace("received_record_", "").replace(".json", "")
		text += "[%d] %s (%s)\n" % [i + 1, display_name, size_str]

	if files.size() > 5:
		text += "...还有 %d 个文件" % (files.size() - 5)

	file_list_label.text = text

func load_most_recent_received_file():
	print("\n[加载] 查找最近接收的文件...")
	var dir = DirAccess.open("res://received_files/")
	if not dir:
		print("[加载] 接收文件目录不存在")
		return

	dir.list_dir_begin()
	var file_name = dir.get_next()
	var files: Array[String] = []

	while file_name != "":
		if file_name.begins_with("received_") and file_name.ends_with(".json"):
			files.append(file_name)
		file_name = dir.get_next()

	if files.is_empty():
		print("[加载] 没有找到接收的文件")
		return

	files.sort()
	files.reverse()

	var most_recent = files[0]
	print("[加载] 找到最近文件: ", most_recent)
	load_and_play_file("res://received_files/" + most_recent)

func load_and_play_file(filepath: String):
	print("[自动回放] 加载文件: ", filepath)

	var file = FileAccess.open(filepath, FileAccess.READ)
	if not file:
		print("[自动回放] 错误: 无法打开文件")
		return

	var content = file.get_as_text()
	file.close()

	var json = JSON.new()
	var err = json.parse(content)
	if err != OK:
		print("[自动回放] 错误: JSON解析失败")
		return

	var data = json.get_data()
	local_playback_frames.clear()

	var frames_array = []
	if data.has("frames"):
		frames_array = data["frames"]
	elif data.has("data"):
		frames_array = data["data"]

	# 转换为正确类型
	for frame in frames_array:
		if typeof(frame) == TYPE_DICTIONARY:
			local_playback_frames.append(frame)

	if local_playback_frames.is_empty():
		print("[自动回放] 错误: 没有有效帧数据")
		return

	print("[自动回放] 加载完成，共 ", local_playback_frames.size(), " 帧")

	# 自动开始回放
	start_local_playback()

