extends "res://tests/fixtures/test_base.gd"

# TC-004: 校准流程测试
# 验证单次校准可完成

var calibration_offset: Quaternion

func before_all():
	print("[TC-004] 校准流程测试 - 初始化")

func before_each():
	calibration_offset = Quaternion.IDENTITY

func after_all():
	print("[TC-004] 校准流程测试 - 完成")

# ========== 测试用例 ==========

func test_single_calibration():
	"""测试单次校准"""
	# 模拟当前姿态
	var current_quat = Quaternion.from_euler(Vector3(deg_to_rad(10), deg_to_rad(5), 0))

	# 计算校准偏移（将当前姿态设为基准）
	calibration_offset = current_quat.inverse()

	# 应用偏移后，当前姿态应变为单位旋转
	var calibrated = calibration_offset * current_quat
	assert_quaternion_eq(calibrated, Quaternion.IDENTITY, 0.0001, "校准后应为单位旋转")

func test_calibration_offset_calculation():
	"""测试校准偏移计算"""
	# 模拟手机平放在桌面上时的姿态
	var base_quat = Quaternion.from_euler(Vector3(deg_to_rad(10), 0, 0))

	# 计算偏移
	calibration_offset = base_quat.inverse()

	# 应用偏移到相同的旋转应得到单位四元数
	var calibrated = calibration_offset * base_quat
	assert_quaternion_eq(calibrated, Quaternion.IDENTITY, 0.0001, "基准姿势校准后应为单位四元数")

func test_apply_calibration():
	"""测试应用校准"""
	# 设置校准偏移
	var offset = Quaternion.from_euler(Vector3(deg_to_rad(10), 0, 0))
	calibration_offset = offset.inverse()

	# 应用校准到原始数据
	var raw_rotation = Quaternion.from_euler(Vector3(deg_to_rad(10), deg_to_rad(20), 0))
	var calibrated = calibration_offset * raw_rotation

	# 结果应去除了偏移
	var calibrated_euler = calibrated.get_euler()
	assert_almost_eq(rad_to_deg(calibrated_euler.x), 0.0, 0.1, "X轴偏移应被消除")
	assert_almost_eq(rad_to_deg(calibrated_euler.y), 20.0, 0.1, "Y轴应保持不变")

func test_skip_calibration():
	"""测试跳过校准"""
	# 跳过校准应使用默认校准（单位四元数）
	calibration_offset = Quaternion.IDENTITY

	var raw_rotation = Quaternion.from_euler(Vector3(deg_to_rad(45), 0, 0))
	var calibrated = calibration_offset * raw_rotation

	assert_quaternion_eq(calibrated, raw_rotation, 0.0001, "跳过校准时应使用原始旋转")

func test_reset_calibration():
	"""测试重置校准"""
	# 设置一个非默认的偏移
	calibration_offset = Quaternion.from_euler(Vector3(deg_to_rad(30), 0, 0))

	# 重置
	calibration_offset = Quaternion.IDENTITY

	assert_quaternion_eq(calibration_offset, Quaternion.IDENTITY, 0.0001, "重置后应为单位四元数")

func test_calibration_with_different_poses():
	"""测试不同姿势的校准"""
	var test_poses = [
		Quaternion.IDENTITY,
		Quaternion.from_euler(Vector3(deg_to_rad(90), 0, 0)),
		Quaternion.from_euler(Vector3(0, deg_to_rad(90), 0)),
		Quaternion.from_euler(Vector3(0, 0, deg_to_rad(90))),
	]

	for pose in test_poses:
		calibration_offset = pose.inverse()
		var calibrated = calibration_offset * pose
		assert_quaternion_eq(calibrated, Quaternion.IDENTITY, 0.0001, "任意姿势校准后应为单位旋转")

func test_calibration_persistence_format():
	"""测试校准数据持久化格式"""
	var calibration_output = {
		"calibration_date": "2026-02-21 10:30:00",
		"calibration_offset": {
			"x": 0.0,
			"y": 0.0,
			"z": 0.0,
			"w": 1.0
		},
		"base_pose": {
			"x": 0.0,
			"y": 0.0,
			"z": 0.0,
			"w": 1.0
		}
	}

	# 验证JSON序列化
	var json_string = JSON.stringify(calibration_output, "\t")
	assert_true(json_string.length() > 0, "应能序列化为JSON")
	assert_string_contains(json_string, "calibration_date", "JSON应包含日期字段")
	assert_string_contains(json_string, "calibration_offset", "JSON应包含偏移字段")

func test_quaternion_normalization():
	"""测试四元数归一化"""
	var raw_quat = Quaternion(1.0, 2.0, 3.0, 4.0)
	var normalized = raw_quat.normalized()

	# 归一化后的模长应为1
	var length = sqrt(normalized.x * normalized.x + normalized.y * normalized.y + normalized.z * normalized.z + normalized.w * normalized.w)
	assert_almost_eq(length, 1.0, 0.0001, "四元数应归一化")

func test_multiple_calibrations():
	"""测试多次校准"""
	# 第一次校准
	var first_pose = Quaternion.from_euler(Vector3(deg_to_rad(10), 0, 0))
	var first_offset = first_pose.inverse()

	# 第二次校准（不同姿势）
	var second_pose = Quaternion.from_euler(Vector3(deg_to_rad(20), 0, 0))
	var second_offset = second_pose.inverse()

	# 两次校准的偏移应该不同
	assert_false(first_offset.is_equal_approx(second_offset), "不同姿势的校准偏移应不同")

func sqrt(x: float) -> float:
	return pow(x, 0.5)
