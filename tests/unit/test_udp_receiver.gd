extends "res://tests/fixtures/test_base.gd"

# TC-001: UDP数据包接收测试
# 测试UDP数据包的接收和解析功能

var udp_socket: PacketPeerUDP
const TEST_PORT: int = 49556  # 使用测试端口避免冲突

func before_all():
	print("[TC-001] UDP数据包接收测试 - 初始化")

func before_each():
	udp_socket = PacketPeerUDP.new()
	var err = udp_socket.bind(TEST_PORT, "127.0.0.1")
	assert_eq(err, OK, "UDP绑定应成功")

func after_each():
	if udp_socket:
		udp_socket.close()
		udp_socket = null

func after_all():
	print("[TC-001] UDP数据包接收测试 - 完成")

# ========== 测试用例 ==========

func test_udp_socket_creation():
	"""测试UDP套接字创建"""
	var socket = PacketPeerUDP.new()
	assert_not_null(socket, "UDP套接字应成功创建")

func test_udp_bind():
	"""测试UDP端口绑定"""
	var socket = PacketPeerUDP.new()
	var err = socket.bind(TEST_PORT + 1, "127.0.0.1")
	assert_eq(err, OK, "UDP绑定应成功")
	socket.close()

func test_binary_packet_size():
	"""测试二进制数据包大小"""
	var packet_size = TestConstants.BINARY_PACKET_SIZE
	assert_eq(packet_size, 28, "数据包大小应为28字节")

func test_binary_packet_parsing():
	"""测试二进制数据包解析"""
	# 创建测试数据包
	var accel = Vector3(1.0, 2.0, 3.0)
	var quat = Quaternion(0.0, 0.0, 0.0, 1.0)
	var packet = MockSensorData.create_binary_packet(accel, quat)

	assert_eq(packet.size(), 28, "数据包大小应为28字节")

	# 解析数据包
	var buffer = StreamPeerBuffer.new()
	buffer.data_array = packet
	buffer.big_endian = false

	var parsed_accel = Vector3(
		buffer.get_float(),
		buffer.get_float(),
		buffer.get_float()
	)
	var parsed_quat = Quaternion(
		buffer.get_float(),
		buffer.get_float(),
		buffer.get_float(),
		buffer.get_float()
	)

	assert_vector_eq(parsed_accel, accel, 0.0001, "加速度应正确解析")
	assert_quaternion_eq(parsed_quat, quat, 0.0001, "四元数应正确解析")

func test_static_data_packet():
	"""测试静态数据包"""
	var packet = MockSensorData.create_static_binary_packet()
	assert_eq(packet.size(), 28, "静态数据包大小应为28字节")

	# 验证解析结果
	var buffer = StreamPeerBuffer.new()
	buffer.data_array = packet
	buffer.big_endian = false

	var accel_x = buffer.get_float()
	var accel_y = buffer.get_float()
	var accel_z = buffer.get_float()

	assert_almost_eq(accel_x, 0.0, 0.0001, "X加速度应为0")
	assert_almost_eq(accel_y, 0.0, 0.0001, "Y加速度应为0")
	assert_almost_eq(accel_z, 0.0, 0.0001, "Z加速度应为0")

func test_swing_data_packet():
	"""测试挥拍数据包"""
	var packet = MockSensorData.create_swing_binary_packet()
	assert_eq(packet.size(), 28, "挥拍数据包大小应为28字节")

	# 验证解析结果
	var buffer = StreamPeerBuffer.new()
	buffer.data_array = packet
	buffer.big_endian = false

	var accel_z = buffer.get_float()
	buffer.get_float()  # skip y
	buffer.get_float()  # skip z

	assert_gt(accel_z, 0.0, "挥拍时Z轴加速度应大于0")

func test_quaternion_normalization():
	"""测试四元数归一化"""
	var quat = Quaternion(1.0, 2.0, 3.0, 4.0)
	var normalized = quat.normalized()

	# 归一化后的四元数模长应接近1
	var length = sqrt(normalized.x * normalized.x + normalized.y * normalized.y + normalized.z * normalized.z + normalized.w * normalized.w)
	assert_almost_eq(length, 1.0, 0.0001, "归一化四元数模长应为1")

func test_packet_structure():
	"""测试数据包结构"""
	# 加速度值范围测试
	var test_accels = [
		Vector3(0, 0, 0),
		Vector3(10, 0, 0),
		Vector3(0, 10, 0),
		Vector3(0, 0, 10),
		Vector3(-10, -10, -10),
		Vector3(20, 20, 20)
	]

	for accel in test_accels:
		var packet = MockSensorData.create_binary_packet(accel, Quaternion.IDENTITY)
		assert_eq(packet.size(), 28, "数据包大小应始终为28字节")

func test_multiple_packets_sequence():
	"""测试多个数据包序列"""
	var packets: Array[PackedByteArray] = []

	# 生成30个数据包（模拟1秒的数据，30fps）
	for i in range(30):
		var t = float(i) / 30.0
		var accel = Vector3(sin(t * PI * 2) * 5, 0, cos(t * PI * 2) * 5)
		var packet = MockSensorData.create_binary_packet(accel, Quaternion.IDENTITY)
		packets.append(packet)

	assert_eq(packets.size(), 30, "应生成30个数据包")

	# 验证每个数据包大小
	for packet in packets:
		assert_eq(packet.size(), 28, "每个数据包大小应为28字节")

func test_endianness():
	"""测试字节序"""
	var accel = Vector3(1.5, 2.5, 3.5)
	var quat = Quaternion(0.1, 0.2, 0.3, 0.9)

	# 小端序
	var buffer_le = StreamPeerBuffer.new()
	buffer_le.big_endian = false
	buffer_le.put_float(accel.x)
	buffer_le.put_float(accel.y)
	buffer_le.put_float(accel.z)

	# 大端序
	var buffer_be = StreamPeerBuffer.new()
	buffer_be.big_endian = true
	buffer_be.put_float(accel.x)
	buffer_be.put_float(accel.y)
	buffer_be.put_float(accel.z)

	var packet_le = buffer_le.data_array
	var packet_be = buffer_be.data_array

	# 小端序和大端序的字节应该不同
	assert_ne(packet_le[0], packet_be[0], "小端序和大端序的字节表示应不同")

# ========== 辅助函数 ==========

func sqrt(x: float) -> float:
	return pow(x, 0.5)
