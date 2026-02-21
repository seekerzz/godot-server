extends "res://tests/fixtures/test_base.gd"

# TC-002: 四元数旋转映射测试
# 验证手机旋转与球拍同步

func before_all():
	print("[TC-002] 四元数旋转映射测试 - 初始化")

func after_all():
	print("[TC-002] 四元数旋转映射测试 - 完成")

# ========== 测试用例 ==========

func test_identity_quaternion():
	"""测试单位四元数"""
	var identity = Quaternion.IDENTITY
	assert_eq(identity.x, 0.0, "单位四元数X应为0")
	assert_eq(identity.y, 0.0, "单位四元数Y应为0")
	assert_eq(identity.z, 0.0, "单位四元数Z应为0")
	assert_eq(identity.w, 1.0, "单位四元数W应为1")

func test_quaternion_to_euler_identity():
	"""测试单位四元数转换为欧拉角"""
	var identity = Quaternion.IDENTITY
	var euler = identity.get_euler()

	assert_vector_eq(euler, Vector3.ZERO, 0.0001, "单位四元数应转换为0欧拉角")

func test_euler_to_quaternion_roundtrip():
	"""测试欧拉角到四元数的往返转换"""
	var original_euler = Vector3(deg_to_rad(45), deg_to_rad(30), deg_to_rad(15))
	var quat = Quaternion.from_euler(original_euler)
	var result_euler = quat.get_euler()

	assert_vector_eq(result_euler, original_euler, 0.0001, "往返转换应保持欧拉角一致")

func test_quaternion_multiplication():
	"""测试四元数乘法"""
	var q1 = Quaternion.from_euler(Vector3(deg_to_rad(90), 0, 0))
	var q2 = Quaternion.from_euler(Vector3(0, deg_to_rad(90), 0))
	var result = q1 * q2

	# 结果应为归一化四元数
	assert_almost_eq(result.length(), 1.0, 0.0001, "乘积应归一化")

func test_quaternion_inverse():
	"""测试四元数逆"""
	var quat = Quaternion.from_euler(Vector3(deg_to_rad(45), 0, 0))
	var inverse = quat.inverse()
	var product = quat * inverse

	assert_quaternion_eq(product, Quaternion.IDENTITY, 0.0001, "四元数与其逆的乘积应为单位四元数")

func test_rotation_x_90_degrees():
	"""测试X轴90度旋转"""
	var quat = Quaternion.from_euler(Vector3(deg_to_rad(90), 0, 0))
	var euler = quat.get_euler()

	assert_almost_eq(rad_to_deg(euler.x), 90.0, 0.1, "X轴旋转应为90度")

func test_rotation_y_90_degrees():
	"""测试Y轴90度旋转"""
	var quat = Quaternion.from_euler(Vector3(0, deg_to_rad(90), 0))
	var euler = quat.get_euler()

	assert_almost_eq(rad_to_deg(euler.y), 90.0, 0.1, "Y轴旋转应为90度")

func test_rotation_z_90_degrees():
	"""测试Z轴90度旋转"""
	var quat = Quaternion.from_euler(Vector3(0, 0, deg_to_rad(90)))
	var euler = quat.get_euler()

	assert_almost_eq(rad_to_deg(euler.z), 90.0, 0.1, "Z轴旋转应为90度")

func test_convert_quaternion_to_godot():
	"""测试四元数坐标系转换"""
	# 模拟从Android接收的四元数
	var android_quat = Quaternion(0.0, 0.0, 0.0, 1.0)

	# 转换为Godot坐标系（直连映射）
	var godot_quat = convert_quaternion_to_godot(android_quat)

	assert_quaternion_eq(godot_quat, android_quat, 0.0001, "直连映射应保持四元数不变")

func test_calibration_offset():
	"""测试校准偏移"""
	# 模拟校准偏移
	var base_rotation = Quaternion.from_euler(Vector3(deg_to_rad(10), 0, 0))
	var calibration_offset = base_rotation.inverse()

	# 应用校准
	var raw_rotation = Quaternion.from_euler(Vector3(deg_to_rad(10), deg_to_rad(20), 0))
	var calibrated = calibration_offset * raw_rotation

	# 校准后的旋转应去除了基础偏移
	var calibrated_euler = calibrated.get_euler()
	assert_almost_eq(rad_to_deg(calibrated_euler.x), 0.0, 0.1, "X轴偏移应被校准消除")

func test_phone_model_rotation():
	"""测试手机模型旋转"""
	# 模拟手机平放（屏幕向上）
	var flat_quat = Quaternion.IDENTITY
	var flat_euler = flat_quat.get_euler()

	assert_vector_eq(flat_euler, Vector3.ZERO, 0.0001, "平放时欧拉角应为0")

	# 模拟手机向右旋转90度
	var rotated_quat = Quaternion.from_euler(Vector3(0, deg_to_rad(90), 0))
	var rotated_euler = rotated_quat.get_euler()

	assert_almost_eq(rad_to_deg(rotated_euler.y), 90.0, 0.1, "向右旋转90度")

func test_paddle_orientation_mapping():
	"""测试球拍方向映射"""
	# 测试球拍面朝向
	var forward = Vector3.FORWARD
	var rotated_forward = Quaternion.from_euler(Vector3(0, deg_to_rad(90), 0)) * forward

	# 旋转后的前向量应指向右侧
	assert_gt(rotated_forward.x, 0.5, "向右旋转90度后，前向量应指向右侧")

func test_gimbal_lock_avoidance():
	"""测试万向节锁避免"""
	# 接近万向节锁的角度
	var euler = Vector3(deg_to_rad(89), deg_to_rad(45), 0)
	var quat = Quaternion.from_euler(euler)
	var recovered_euler = quat.get_euler()

	# 使用四元数应能正确恢复旋转
	assert_almost_eq(rad_to_deg(recovered_euler.x), 89.0, 0.5, "应正确恢复接近万向节锁的角度")

func test_rotation_sequence():
	"""测试旋转序列"""
	var sequence = MockSensorData.create_rotation_sequence("y", 0, 90, 10)

	assert_eq(sequence.size(), 10, "应生成10个旋转数据点")

	# 验证序列的第一个和最后一个
	var first_quat = sequence[0]["quaternion"]
	var last_quat = sequence[9]["quaternion"]

	var first_euler = first_quat.get_euler()
	var last_euler = last_quat.get_euler()

	assert_almost_eq(rad_to_deg(first_euler.y), 0.0, 0.5, "序列起始应为0度")
	assert_almost_eq(rad_to_deg(last_euler.y), 90.0, 0.5, "序列结束应为90度")

func test_quaternion_slerp():
	"""测试四元数球面插值"""
	var q1 = Quaternion.IDENTITY
	var q2 = Quaternion.from_euler(Vector3(0, deg_to_rad(90), 0))

	var mid = q1.slerp(q2, 0.5)
	var mid_euler = mid.get_euler()

	assert_almost_eq(rad_to_deg(mid_euler.y), 45.0, 0.5, "中点插值应为45度")

func test_rotation_delay_simulation():
	"""测试旋转延迟模拟"""
	# 模拟50ms延迟
	var delay_frames = int(0.05 * 60)  # 60fps下的帧数
	assert_eq(delay_frames, 3, "50ms延迟约等于3帧")

# ========== 辅助函数 ==========

func convert_quaternion_to_godot(q: Quaternion) -> Quaternion:
	"""将Android坐标系的四元数转换为Godot坐标系"""
	return Quaternion(q.x, q.y, q.z, q.w).normalized()
