extends Node
class_name SensorDataGenerator

# 传感器数据生成器
# 生成各种类型的传感器模拟数据用于测试

# 数据类型枚举
enum DataType {
	STATIC,              # 静止数据
	SLOW_MOVEMENT,       # 缓慢移动
	NORMAL_SWING,        # 正常挥拍
	FAST_SWING,          # 快速挥拍
	ROTATION_ONLY,       # 仅旋转
	SHAKE,               # 抖动
	SPIKE,               # 尖峰异常
	CALIBRATION_SEQUENCE # 校准序列
}

# 生成参数
@export var noise_level: float = 0.01
@export var sample_rate: float = 60.0  # Hz

# ========== 数据生成方法 ==========

func generate_static_data(duration: float = 1.0) -> Array[Dictionary]:
	"""生成静止数据"""
	var frames = int(duration * sample_rate)
	var data: Array[Dictionary] = []

	for i in range(frames):
		data.append(MockSensorData.create_static_data_with_noise(noise_level))

	return data

func generate_slow_movement_data(duration: float = 2.0) -> Array[Dictionary]:
	"""生成缓慢移动数据"""
	var frames = int(duration * sample_rate)
	var data: Array[Dictionary] = []
	var start_time = Time.get_unix_time_from_system()

	for i in range(frames):
		var t = float(i) / frames
		# 缓慢的正弦波运动
		var accel = Vector3(
			sin(t * PI * 2) * 0.5,
			0,
			cos(t * PI * 2) * 0.5
		)

		data.append({
			"timestamp": start_time + i / sample_rate,
			"user_accel": accel,
			"quaternion": Quaternion.IDENTITY
		})

	return data

func generate_normal_swing_data() -> Array[Dictionary]:
	"""生成正常挥拍数据"""
	return MockSensorData.create_swing_data(30)

func generate_fast_swing_data() -> Array[Dictionary]:
	"""生成快速挥拍数据"""
	return MockSensorData.create_fast_swing_data(20)

func generate_rotation_data(axis: String, angle_range: float = 360.0, duration: float = 2.0) -> Array[Dictionary]:
	"""生成旋转数据"""
	var frames = int(duration * sample_rate)
	return MockSensorData.create_rotation_sequence(axis, 0, angle_range, frames)

func generate_shake_data(duration: float = 1.0, intensity: float = 5.0) -> Array[Dictionary]:
	"""生成抖动数据"""
	var frames = int(duration * sample_rate)
	var data: Array[Dictionary] = []
	var start_time = Time.get_unix_time_from_system()

	for i in range(frames):
		var accel = Vector3(
			randf_range(-intensity, intensity),
			randf_range(-intensity, intensity),
			randf_range(-intensity, intensity)
		)

		data.append({
			"timestamp": start_time + i / sample_rate,
			"user_accel": accel,
			"quaternion": Quaternion.IDENTITY
		})

	return data

func generate_spike_data(normal_frames: int = 10, spike_count: int = 3) -> Array[Dictionary]:
	"""生成带尖峰的数据"""
	var data: Array[Dictionary] = []
	var start_time = Time.get_unix_time_from_system()

	for i in range(normal_frames):
		data.append(MockSensorData.create_static_data())

	# 插入尖峰
	for i in range(spike_count):
		data.append(MockSensorData.create_spike_data())
		data.append(MockSensorData.create_static_data())

	return data

func generate_calibration_sequence() -> Array[Dictionary]:
	"""生成完整校准序列"""
	return MockSensorData.create_full_calibration_sequence()

func generate_by_type(type: DataType, duration: float = 1.0) -> Array[Dictionary]:
	"""根据类型生成数据"""
	match type:
		DataType.STATIC:
			return generate_static_data(duration)
		DataType.SLOW_MOVEMENT:
			return generate_slow_movement_data(duration)
		DataType.NORMAL_SWING:
			return generate_normal_swing_data()
		DataType.FAST_SWING:
			return generate_fast_swing_data()
		DataType.ROTATION_ONLY:
			return generate_rotation_data("y", 360.0, duration)
		DataType.SHAKE:
			return generate_shake_data(duration)
		DataType.SPIKE:
			return generate_spike_data()
		DataType.CALIBRATION_SEQUENCE:
			return generate_calibration_sequence()
		_:
			return generate_static_data(duration)

# ========== 数据导出 ==========

func export_to_json(data: Array[Dictionary], filename: String) -> bool:
	"""导出数据到JSON文件"""
	var output = {
		"version": "1.0",
		"sample_rate": sample_rate,
		"frame_count": data.size(),
		"data": data
	}

	var file = FileAccess.open(filename, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(output, "\t"))
		file.close()
		print("[SensorDataGenerator] 数据已导出到: %s" % filename)
		return true
	else:
		push_error("[SensorDataGenerator] 无法写入文件: %s" % filename)
		return false

func export_to_binary(data: Array[Dictionary], filename: String) -> bool:
	"""导出数据到二进制文件"""
	var file = FileAccess.open(filename, FileAccess.WRITE)
	if not file:
		push_error("[SensorDataGenerator] 无法写入文件: %s" % filename)
		return false

	# 写入文件头
	file.store_32(data.size())  # 帧数
	file.store_float(sample_rate)  # 采样率

	# 写入数据帧
	for frame in data:
		var accel = frame["user_accel"]
		var quat = frame["quaternion"]

		file.store_float(accel.x)
		file.store_float(accel.y)
		file.store_float(accel.z)
		file.store_float(quat.x)
		file.store_float(quat.y)
		file.store_float(quat.z)
		file.store_float(quat.w)

	file.close()
	print("[SensorDataGenerator] 二进制数据已导出到: %s" % filename)
	return true

# ========== 预设数据 ==========

func generate_test_suite() -> Dictionary:
	"""生成完整的测试数据集"""
	return {
		"static_1s": generate_static_data(1.0),
		"static_10s": generate_static_data(10.0),
		"slow_movement": generate_slow_movement_data(2.0),
		"normal_swing": generate_normal_swing_data(),
		"fast_swing": generate_fast_swing_data(),
		"rotation_x": generate_rotation_data("x", 90.0, 1.0),
		"rotation_y": generate_rotation_data("y", 360.0, 2.0),
		"rotation_z": generate_rotation_data("z", 45.0, 0.5),
		"shake": generate_shake_data(1.0, 3.0),
		"spike": generate_spike_data(10, 3),
		"calibration": generate_calibration_sequence()
	}

func save_test_suite(directory: String = "res://tests/fixtures/data/"):
	"""保存完整测试数据集"""
	var suite = generate_test_suite()

	# 确保目录存在
	var dir = DirAccess.open("res://")
	if dir and not dir.dir_exists("tests/fixtures/data"):
		dir.make_dir_recursive("tests/fixtures/data")

	for name in suite.keys():
		var filename = directory + name + ".json"
		export_to_json(suite[name], filename)

	print("[SensorDataGenerator] 测试数据集已保存到: %s" % directory)
