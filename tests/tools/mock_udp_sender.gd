extends Node
class_name MockUDPSender

# 模拟UDP发送器
# 用于无手机情况下测试服务器数据接收

@export var target_port: int = 49555
@export var target_address: String = "127.0.0.1"
@export var send_rate: float = 60.0  # fps

var udp_socket: PacketPeerUDP
var is_running: bool = false
var send_timer: float = 0.0
var frame_count: int = 0

# 数据生成模式
enum DataMode {
	STATIC,      # 静态数据
	SWING,       # 挥拍数据
	ROTATION,    # 旋转数据
	RANDOM,      # 随机数据
	RECORDED     # 录制数据回放
}

var current_mode: DataMode = DataMode.STATIC
var recorded_data: Array[Dictionary] = []
var recorded_index: int = 0

signal packet_sent(packet_data: Dictionary)
signal sequence_completed

func _ready():
	print("[MockUDPSender] 模拟UDP发送器已初始化")
	print("[MockUDPSender] 目标: %s:%d" % [target_address, target_port])

func start_sending(mode: DataMode = DataMode.STATIC, duration: float = -1.0):
	"""开始发送数据"""
	if is_running:
		return

	current_mode = mode
	is_running = true
	frame_count = 0

	# 创建UDP套接字
	udp_socket = PacketPeerUDP.new()
	var err = udp_socket.set_dest_address(target_address, target_port)
	if err != OK:
		push_error("[MockUDPSender] 设置目标地址失败: %d" % err)
		return

	print("[MockUDPSender] 开始发送数据，模式: %s" % _get_mode_name(mode))

	# 如果指定了时长，设置定时停止
	if duration > 0:
		await get_tree().create_timer(duration).timeout
		stop_sending()

func stop_sending():
	"""停止发送数据"""
	is_running = false
	if udp_socket:
		udp_socket.close()
		udp_socket = null
	print("[MockUDPSender] 停止发送，共发送 %d 帧" % frame_count)
	emit_signal("sequence_completed")

func _process(delta: float):
	if not is_running:
		return

	send_timer += delta
	var interval = 1.0 / send_rate

	while send_timer >= interval:
		send_timer -= interval
		_send_packet()

func _send_packet():
	"""发送单个数据包"""
	if not udp_socket:
		return

	var data = _generate_data()
	var packet = _create_binary_packet(data)

	udp_socket.put_packet(packet)
	frame_count += 1

	emit_signal("packet_sent", data)

func _generate_data() -> Dictionary:
	"""根据当前模式生成数据"""
	match current_mode:
		DataMode.STATIC:
			return MockSensorData.create_static_data()
		DataMode.SWING:
			return _generate_swing_data()
		DataMode.ROTATION:
			return _generate_rotation_data()
		DataMode.RANDOM:
			return _generate_random_data()
		DataMode.RECORDED:
			return _get_recorded_data()
		_:
			return MockSensorData.create_static_data()

func _generate_swing_data() -> Dictionary:
	"""生成挥拍数据"""
	var t = float(frame_count % 60) / 60.0
	var accel = Vector3(0, 0, 5.0 * sin(t * PI))
	return {
		"timestamp": Time.get_unix_time_from_system(),
		"user_accel": accel,
		"quaternion": Quaternion.IDENTITY
	}

func _generate_rotation_data() -> Dictionary:
	"""生成旋转数据"""
	var angle = deg_to_rad(frame_count * 6 % 360)  # 每秒转一圈
	var quat = Quaternion.from_euler(Vector3(0, angle, 0))
	return {
		"timestamp": Time.get_unix_time_from_system(),
		"user_accel": Vector3.ZERO,
		"quaternion": quat
	}

func _generate_random_data() -> Dictionary:
	"""生成随机数据"""
	return {
		"timestamp": Time.get_unix_time_from_system(),
		"user_accel": Vector3(randf_range(-5, 5), randf_range(-5, 5), randf_range(-5, 5)),
		"quaternion": Quaternion(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)).normalized()
	}

func _get_recorded_data() -> Dictionary:
	"""获取录制数据"""
	if recorded_data.is_empty():
		return MockSensorData.create_static_data()

	if recorded_index >= recorded_data.size():
		recorded_index = 0
		emit_signal("sequence_completed")

	var data = recorded_data[recorded_index]
	recorded_index += 1
	return data

func _create_binary_packet(data: Dictionary) -> PackedByteArray:
	"""创建二进制数据包"""
	var accel = data["user_accel"]
	var quat = data["quaternion"]
	return MockSensorData.create_binary_packet(accel, quat)

func _get_mode_name(mode: DataMode) -> String:
	match mode:
		DataMode.STATIC: return "静态"
		DataMode.SWING: return "挥拍"
		DataMode.ROTATION: return "旋转"
		DataMode.RANDOM: return "随机"
		DataMode.RECORDED: return "录制回放"
		_: return "未知"

# ========== 公共接口 ==========

func load_recorded_data(data: Array[Dictionary]):
	"""加载录制数据"""
	recorded_data = data
	recorded_index = 0
	print("[MockUDPSender] 已加载 %d 帧录制数据" % data.size())

func set_send_rate(rate: float):
	"""设置发送频率"""
	send_rate = clamp(rate, 1.0, 120.0)
	print("[MockUDPSender] 发送频率设置为 %.1f fps" % send_rate)

func get_stats() -> Dictionary:
	"""获取统计信息"""
	return {
		"frame_count": frame_count,
		"is_running": is_running,
		"mode": _get_mode_name(current_mode),
		"send_rate": send_rate
	}
