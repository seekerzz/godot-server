extends RefCounted
class_name MockSensorData

# 模拟传感器数据生成器
# 用于测试时生成各种传感器数据场景

# ========== 静态数据 ==========

static func create_static_data() -> Dictionary:
	"""创建静态数据（手机静止）"""
	return {
		"timestamp": Time.get_unix_time_from_system(),
		"user_accel": Vector3.ZERO,
		"quaternion": Quaternion.IDENTITY
	}

static func create_static_data_with_noise(noise_level: float = 0.01) -> Dictionary:
	"""创建带微小噪声的静态数据"""
	var noise = Vector3(
		randf_range(-noise_level, noise_level),
		randf_range(-noise_level, noise_level),
		randf_range(-noise_level, noise_level)
	)
	return {
		"timestamp": Time.get_unix_time_from_system(),
		"user_accel": noise,
		"quaternion": Quaternion.IDENTITY
	}

# ========== 挥拍数据 ==========

static func create_swing_data(frames: int = 30) -> Array[Dictionary]:
	"""创建匀速挥拍数据序列"""
	var data: Array[Dictionary] = []
	var start_time = Time.get_unix_time_from_system()

	for i in range(frames):
		var t = float(i) / frames
		# 模拟向前挥拍
		var accel = Vector3(0, 0, 5.0 * sin(t * PI))  # 先加速后减速
		var quat = Quaternion.IDENTITY

		data.append({
			"timestamp": start_time + i * 0.016,
			"user_accel": accel,
			"quaternion": quat
		})

	return data

static func create_fast_swing_data(frames: int = 20) -> Array[Dictionary]:
	"""创建快速击球挥拍数据序列"""
	var data: Array[Dictionary] = []
	var start_time = Time.get_unix_time_from_system()

	for i in range(frames):
		var t = float(i) / frames
		# 模拟快速向前挥拍（扣杀）
		var accel = Vector3(0, -2.0, 15.0 * sin(t * PI * 0.8))
		var quat = Quaternion.from_euler(Vector3(-0.5, 0, 0))  # 前倾

		data.append({
			"timestamp": start_time + i * 0.016,
			"user_accel": accel,
			"quaternion": quat
		})

	return data

static func create_slow_push_data(frames: int = 40) -> Array[Dictionary]:
	"""创建轻推挥拍数据序列"""
	var data: Array[Dictionary] = []
	var start_time = Time.get_unix_time_from_system()

	for i in range(frames):
		var t = float(i) / frames
		# 模拟轻推
		var accel = Vector3(0, 0, 2.0 * sin(t * PI))
		var quat = Quaternion.IDENTITY

		data.append({
			"timestamp": start_time + i * 0.016,
			"user_accel": accel,
			"quaternion": quat
		})

	return data

# ========== 旋转数据 ==========

static func create_rotation_data_x(angle_degrees: float) -> Dictionary:
	"""创建绕X轴旋转的数据"""
	var angle_rad = deg_to_rad(angle_degrees)
	var quat = Quaternion.from_euler(Vector3(angle_rad, 0, 0))
	return {
		"timestamp": Time.get_unix_time_from_system(),
		"user_accel": Vector3.ZERO,
		"quaternion": quat
	}

static func create_rotation_data_y(angle_degrees: float) -> Dictionary:
	"""创建绕Y轴旋转的数据"""
	var angle_rad = deg_to_rad(angle_degrees)
	var quat = Quaternion.from_euler(Vector3(0, angle_rad, 0))
	return {
		"timestamp": Time.get_unix_time_from_system(),
		"user_accel": Vector3.ZERO,
		"quaternion": quat
	}

static func create_rotation_data_z(angle_degrees: float) -> Dictionary:
	"""创建绕Z轴旋转的数据"""
	var angle_rad = deg_to_rad(angle_degrees)
	var quat = Quaternion.from_euler(Vector3(0, 0, angle_rad))
	return {
		"timestamp": Time.get_unix_time_from_system(),
		"user_accel": Vector3.ZERO,
		"quaternion": quat
	}

static func create_rotation_sequence(axis: String, start_angle: float, end_angle: float, steps: int = 30) -> Array[Dictionary]:
	"""创建旋转序列数据"""
	var data: Array[Dictionary] = []
	var start_time = Time.get_unix_time_from_system()

	for i in range(steps):
		var t = float(i) / (steps - 1)
		var angle = lerp(start_angle, end_angle, t)
		var angle_rad = deg_to_rad(angle)

		var euler = Vector3.ZERO
		match axis.to_lower():
			"x": euler.x = angle_rad
			"y": euler.y = angle_rad
			"z": euler.z = angle_rad

		var quat = Quaternion.from_euler(euler)
		data.append({
			"timestamp": start_time + i * 0.016,
			"user_accel": Vector3.ZERO,
			"quaternion": quat
		})

	return data

# ========== 校准数据 ==========

static func create_calibration_pose_1() -> Dictionary:
	"""创建校准姿势1: 标准平放"""
	return {
		"timestamp": Time.get_unix_time_from_system(),
		"user_accel": Vector3(0, 0, 0),
		"quaternion": Quaternion.IDENTITY,
		"pose_name": "标准平放"
	}

static func create_calibration_pose_2() -> Dictionary:
	"""创建校准姿势2: 向右旋转90度"""
	var quat = Quaternion.from_euler(Vector3(0, deg_to_rad(90), 0))
	return {
		"timestamp": Time.get_unix_time_from_system(),
		"user_accel": Vector3(0, 0, 0),
		"quaternion": quat,
		"pose_name": "向右旋转"
	}

static func create_calibration_pose_3() -> Dictionary:
	"""创建校准姿势3: 向左旋转90度"""
	var quat = Quaternion.from_euler(Vector3(0, deg_to_rad(-90), 0))
	return {
		"timestamp": Time.get_unix_time_from_system(),
		"user_accel": Vector3(0, 0, 0),
		"quaternion": quat,
		"pose_name": "向左旋转"
	}

static func create_calibration_pose_4() -> Dictionary:
	"""创建校准姿势4: 竖直握持"""
	var quat = Quaternion.from_euler(Vector3(deg_to_rad(90), 0, 0))
	return {
		"timestamp": Time.get_unix_time_from_system(),
		"user_accel": Vector3(0, 0, 0),
		"quaternion": quat,
		"pose_name": "竖直握持"
	}

static func create_full_calibration_sequence() -> Array[Dictionary]:
	"""创建完整校准序列"""
	return [
		create_calibration_pose_1(),
		create_calibration_pose_2(),
		create_calibration_pose_3(),
		create_calibration_pose_4()
	]

# ========== 异常数据 ==========

static func create_spike_data() -> Dictionary:
	"""创建尖峰异常数据"""
	return {
		"timestamp": Time.get_unix_time_from_system(),
		"user_accel": Vector3(100, 100, 100),  # 异常大的加速度
		"quaternion": Quaternion.IDENTITY
	}

static func create_zero_quaternion() -> Dictionary:
	"""创建零四元数（未归一化）"""
	return {
		"timestamp": Time.get_unix_time_from_system(),
		"user_accel": Vector3.ZERO,
		"quaternion": Quaternion(0, 0, 0, 0)
	}

static func create_invalid_quaternion() -> Dictionary:
	"""创建无效四元数"""
	return {
		"timestamp": Time.get_unix_time_from_system(),
		"user_accel": Vector3.ZERO,
		"quaternion": Quaternion(NAN, NAN, NAN, NAN)
	}

# ========== 二进制数据包 ==========

static func create_binary_packet(accel: Vector3, quat: Quaternion) -> PackedByteArray:
	"""创建28字节的二进制数据包"""
	var buffer = StreamPeerBuffer.new()
	buffer.big_endian = false

	# 加速度 (12 bytes)
	buffer.put_float(accel.x)
	buffer.put_float(accel.y)
	buffer.put_float(accel.z)

	# 四元数 (16 bytes)
	buffer.put_float(quat.x)
	buffer.put_float(quat.y)
	buffer.put_float(quat.z)
	buffer.put_float(quat.w)

	return buffer.data_array

static func create_static_binary_packet() -> PackedByteArray:
	"""创建静态二进制数据包"""
	return create_binary_packet(Vector3.ZERO, Quaternion.IDENTITY)

static func create_swing_binary_packet() -> PackedByteArray:
	"""创建挥拍二进制数据包"""
	return create_binary_packet(Vector3(0, 0, 5.0), Quaternion.IDENTITY)

# ========== 辅助函数 ==========

static func lerp(a: float, b: float, t: float) -> float:
	return a + (b - a) * t
