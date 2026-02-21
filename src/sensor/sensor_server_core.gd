class_name SensorServerCore
extends Node

## 传感器服务器核心类
## 负责UDP数据接收和原始数据包解析

# 信号
signal sensor_data_received(data: SensorData)
signal control_message_received(message: Dictionary)
signal client_connected(ip: String, port: int)
signal client_disconnected()

# 网络配置
const SERVER_PORT := 49555
const CLIENT_PORT := 9877
const BINARY_PACKET_SIZE := 28  # 7 floats * 4 bytes

# 数据结构
class SensorData:
	var timestamp: float
	var linear_accel: Vector3     # 线性加速度 (m/s²)
	var quaternion: Quaternion    # 旋转四元数

	func _init():
		timestamp = Time.get_unix_time_from_system()

# 网络状态
var udp_socket: PacketPeerUDP = null
var is_running := false
var last_packet_time := 0.0
var packet_count := 0

# 统计信息
var stats := {
	"packets_received": 0,
	"bytes_received": 0,
	"start_time": 0.0
}

# 帧计数
var frame_count := 0


func _ready():
	print("[SensorServerCore] 传感器服务器核心已初始化")


func _process(delta):
	frame_count += 1
	last_packet_time += delta

	if not is_running or udp_socket == null:
		return

	# 处理所有可用数据包
	while udp_socket.get_available_packet_count() > 0:
		var packet = udp_socket.get_packet()
		var packet_size = packet.size()

		if packet_size == 0:
			continue

		stats.packets_received += 1
		stats.bytes_received += packet_size

		# 判断是二进制数据还是JSON控制消息
		if packet_size == BINARY_PACKET_SIZE:
			var sensor_data = parse_binary_packet(packet)
			if sensor_data != null:
				emit_signal("sensor_data_received", sensor_data)
				last_packet_time = 0.0
				packet_count += 1
		else:
			# 尝试解析为JSON控制消息
			var json_str = packet.get_string_from_utf8()
			var message = parse_control_message(json_str)
			if message != null:
				emit_signal("control_message_received", message)


## 启动服务器
func start_server() -> bool:
	if is_running:
		print("[SensorServerCore] 服务器已在运行")
		return true

	udp_socket = PacketPeerUDP.new()
	var err = udp_socket.bind(SERVER_PORT, "0.0.0.0")

	if err == OK:
		is_running = true
		stats.start_time = Time.get_unix_time_from_system()
		print("[SensorServerCore] 服务器已在端口 %d 启动" % SERVER_PORT)
		return true
	else:
		print("[SensorServerCore] 服务器启动失败: %d" % err)
		return false


## 停止服务器
func stop_server():
	if not is_running:
		return

	is_running = false
	if udp_socket:
		udp_socket.close()
		udp_socket = null

	print("[SensorServerCore] 服务器已停止")
	print("[SensorServerCore] 统计: 接收 %d 个数据包, %d 字节" % [
		stats.packets_received, stats.bytes_received
	])


## 解析二进制传感器数据包 (28字节)
## 包结构:
## - UserAccel.x (float, 4 bytes)
## - UserAccel.y (float, 4 bytes)
## - UserAccel.z (float, 4 bytes)
## - Quaternion.x (float, 4 bytes)
## - Quaternion.y (float, 4 bytes)
## - Quaternion.z (float, 4 bytes)
## - Quaternion.w (float, 4 bytes)
func parse_binary_packet(packet: PackedByteArray) -> SensorData:
	if packet.size() != BINARY_PACKET_SIZE:
		return null

	var buffer = StreamPeerBuffer.new()
	buffer.data_array = packet
	buffer.big_endian = false  # 使用小端序

	var data = SensorData.new()

	# 读取线性加速度
	data.linear_accel = Vector3(
		buffer.get_float(),
		buffer.get_float(),
		buffer.get_float()
	)

	# 读取四元数
	data.quaternion = Quaternion(
		buffer.get_float(),
		buffer.get_float(),
		buffer.get_float(),
		buffer.get_float()
	)

	# 调试输出（前10帧和每300帧）
	if packet_count <= 10 or packet_count % 300 == 0:
		print("[SensorServerCore#%d] Accel: (%.3f, %.3f, %.3f) | Quat: (%.3f, %.3f, %.3f, %.3f)" % [
			packet_count,
			data.linear_accel.x, data.linear_accel.y, data.linear_accel.z,
			data.quaternion.x, data.quaternion.y, data.quaternion.z, data.quaternion.w
		])

	return data


## 解析JSON控制消息
func parse_control_message(json_str: String) -> Dictionary:
	if json_str.is_empty():
		return {}

	var json = JSON.new()
	var err = json.parse(json_str)

	if err != OK:
		return {}

	var data = json.get_data()
	if typeof(data) != TYPE_DICTIONARY:
		return {}

	print("[SensorServerCore] 收到控制消息: %s" % json_str.substr(0, 100))
	return data


## 发送控制消息到客户端
func send_control_message(message: Dictionary) -> bool:
	if not is_running or udp_socket == null:
		return false

	var json_str = JSON.stringify(message)
	var packet = json_str.to_utf8_buffer()

	# 注意：需要知道客户端地址才能发送
	# 这里假设客户端已经发送过数据
	# 实际实现需要记录客户端地址

	return true


## 获取统计信息
func get_stats() -> Dictionary:
	var elapsed = Time.get_unix_time_from_system() - stats.start_time
	var packet_rate = 0.0
	if elapsed > 0:
		packet_rate = stats.packets_received / elapsed

	return {
		"is_running": is_running,
		"packets_received": stats.packets_received,
		"bytes_received": stats.bytes_received,
		"elapsed_time": elapsed,
		"packet_rate": packet_rate,
		"last_packet_time": last_packet_time
	}


## 重置统计信息
func reset_stats():
	stats = {
		"packets_received": 0,
		"bytes_received": 0,
		"start_time": Time.get_unix_time_from_system()
	}
	packet_count = 0


## 检查连接状态
func is_client_connected() -> bool:
	return is_running and last_packet_time < 1.0  # 1秒内收到过数据视为连接中


func _exit_tree():
	stop_server()
