extends "res://tests/fixtures/test_base.gd"

# TC-003: 弹性回中算法测试
# 测试位置漂移纠正效果

var velocity: Vector3
var phone_position: Vector3
var origin_position: Vector3

var friction: float
var return_speed: float
var max_displacement: float

func before_all():
	print("[TC-003] 弹性回中算法测试 - 初始化")

func before_each():
	# 重置状态
	velocity = Vector3.ZERO
	phone_position = Vector3.ZERO
	origin_position = Vector3.ZERO

	# 使用默认参数
	friction = TestConstants.DEFAULT_FRICTION
	return_speed = TestConstants.DEFAULT_RETURN_SPEED
	max_displacement = TestConstants.DEFAULT_MAX_DISPLACEMENT

func after_all():
	print("[TC-003] 弹性回中算法测试 - 完成")

# ========== 测试用例 ==========

func test_initial_state():
	"""测试初始状态"""
	assert_vector_eq(phone_position, Vector3.ZERO, 0.0001, "初始位置应为零")
	assert_vector_eq(velocity, Vector3.ZERO, 0.0001, "初始速度应为零")

func test_velocity_integration():
	"""测试速度积分"""
	var accel = Vector3(0, 0, 10.0)
	var delta = 0.016  # 约60fps

	# 更新速度
	velocity += accel * delta

	var expected_velocity = Vector3(0, 0, 0.16)
	assert_vector_eq(velocity, expected_velocity, 0.0001, "速度应正确积分")

func test_position_integration():
	"""测试位置积分"""
	velocity = Vector3(1.0, 0, 0)
	var delta = 0.016

	# 更新位置
	phone_position += velocity * delta

	var expected_position = Vector3(0.016, 0, 0)
	assert_vector_eq(phone_position, expected_position, 0.0001, "位置应正确积分")

func test_friction_decay():
	"""测试摩擦衰减"""
	velocity = Vector3(10.0, 0, 0)
	var delta = 0.016
	var initial_speed = velocity.length()

	# 应用摩擦
	velocity = velocity.lerp(Vector3.ZERO, friction * delta)

	var final_speed = velocity.length()
	assert_lt(final_speed, initial_speed, "摩擦应使速度衰减")

func test_return_to_center():
	"""测试回中效果"""
	phone_position = Vector3(1.0, 0, 0)
	var delta = 0.016

	# 应用回中力
	phone_position = phone_position.lerp(origin_position, return_speed * delta)

	# 位置应向原点移动
	assert_lt(abs(phone_position.x), 1.0, "位置应向原点移动")
	assert_gt(abs(phone_position.x), 0.0, "位置不应立即回到原点")

func test_max_displacement_limit():
	"""测试最大位移限制"""
	phone_position = Vector3(10.0, 10.0, 10.0)

	# 限制位移
	phone_position.x = clamp(phone_position.x, -max_displacement, max_displacement)
	phone_position.y = clamp(phone_position.y, 0.0, max_displacement)
	phone_position.z = clamp(phone_position.z, -max_displacement, max_displacement)

	assert_le(abs(phone_position.x), max_displacement, "X位移应被限制")
	assert_le(phone_position.y, max_displacement, "Y位移应被限制")
	assert_le(abs(phone_position.z), max_displacement, "Z位移应被限制")

func test_y_axis_minimum():
	"""测试Y轴最小值限制"""
	phone_position = Vector3(0, -5.0, 0)

	# Y轴不应小于0
	phone_position.y = clamp(phone_position.y, 0.0, max_displacement)

	assert_ge(phone_position.y, 0.0, "Y位置不应小于0")

func test_full_update_cycle():
	"""测试完整更新周期"""
	var accel = Vector3(5.0, 0, 0)
	var delta = 0.016

	# 模拟一帧更新
	_update_phone_position(delta, accel)

	# 速度应增加（积分）然后衰减（摩擦）
	assert_gt(velocity.x, 0.0, "速度应大于0")

func test_return_time():
	"""测试回中时间"""
	phone_position = Vector3(2.0, 0, 0)
	velocity = Vector3.ZERO

	var frame_count = 0
	var max_frames = 300  # 5秒 @ 60fps

	# 模拟回中过程
	while phone_position.length() > 0.1 and frame_count < max_frames:
		_update_phone_position(0.016, Vector3.ZERO)
		frame_count += 1

	# 应在合理时间内回中
	assert_lt(frame_count, max_frames, "应在5秒内回中")
	assert_lt(phone_position.length(), 0.5, "最终位置应接近原点")

func test_swing_and_return():
	"""测试挥拍后回中"""
	# 模拟挥拍
	for i in range(30):
		var t = float(i) / 30.0
		var accel = Vector3(0, 0, 10.0 * sin(t * PI))
		_update_phone_position(0.016, accel)

	var max_pos = phone_position.length()

	# 挥拍后应有位移
	assert_gt(max_pos, 0.0, "挥拍后应有位移")

	# 继续模拟回中
	for i in range(180):  # 3秒
		_update_phone_position(0.016, Vector3.ZERO)

	# 应回到接近原点
	assert_lt(phone_position.length(), 0.5, "3秒后应回到接近原点")

func test_no_drift_accumulation():
	"""测试无漂移累积"""
	# 模拟长时间静止
	for i in range(3600):  # 1分钟 @ 60fps
		_update_phone_position(0.016, Vector3.ZERO)

	# 位置应保持在原点
	assert_lt(phone_position.length(), 0.1, "长时间静止不应产生漂移")

func test_velocity_clamping():
	"""测试速度限制"""
	velocity = Vector3(100.0, 100.0, 100.0)

	# 模拟几帧
	for i in range(10):
		_update_phone_position(0.016, Vector3.ZERO)

	# 速度应快速衰减
	assert_lt(velocity.length(), 50.0, "速度应被快速衰减")

func test_direction_independence():
	"""测试各方向独立性"""
	var directions = [
		Vector3(10, 0, 0),
		Vector3(0, 10, 0),
		Vector3(0, 0, 10),
		Vector3(5, 5, 5)
	]

	for dir in directions:
		velocity = Vector3.ZERO
		phone_position = Vector3.ZERO

		# 施加加速度
		_update_phone_position(0.016, dir)

		# 应有相应方向的速度
		assert_gt(velocity.length(), 0.0, "%s 方向应有速度" % str(dir))

func test_energy_conservation():
	"""测试能量守恒（摩擦应消耗能量）"""
	velocity = Vector3(10.0, 0, 0)
	var initial_energy = velocity.length_squared()

	# 模拟一帧
	_update_phone_position(0.016, Vector3.ZERO)

	var final_energy = velocity.length_squared()
	assert_lt(final_energy, initial_energy, "摩擦应消耗能量")

# ========== 辅助函数 ==========

func _update_phone_position(delta: float, accel: Vector3 = Vector3.ZERO):
	"""弹性回中位置更新算法"""
	# 速度积分
	velocity += accel * delta

	# 高阻力衰减
	velocity = velocity.lerp(Vector3.ZERO, friction * delta)

	# 位置积分
	phone_position += velocity * delta

	# 弹性回中
	phone_position = phone_position.lerp(origin_position, return_speed * delta)

	# 限制最大位移范围
	phone_position.x = clamp(phone_position.x, -max_displacement, max_displacement)
	phone_position.y = clamp(phone_position.y, 0.0, max_displacement)
	phone_position.z = clamp(phone_position.z, -max_displacement, max_displacement)

func sin(x: float) -> float:
	return pow(x, 0.5) if x > 0 else -pow(-x, 0.5)
