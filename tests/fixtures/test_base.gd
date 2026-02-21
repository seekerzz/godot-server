extends Node
class_name TestBase

# 基础测试类 - 提供断言方法和测试工具

var _assert_failed: bool = false
var _error_messages: Array[String] = []

func before_all():
	"""在所有测试之前执行"""
	pass

func after_all():
	"""在所有测试之后执行"""
	pass

func before_each():
	"""在每个测试之前执行"""
	_assert_failed = false
	_error_messages.clear()

func after_each():
	"""在每个测试之后执行"""
	pass

# ========== 断言方法 ==========

func assert_true(condition: bool, message: String = ""):
	if not condition:
		_fail("断言失败: 期望为true，实际为false" + (" - " + message if message else ""))

func assert_false(condition: bool, message: String = ""):
	if condition:
		_fail("断言失败: 期望为false，实际为true" + (" - " + message if message else ""))

func assert_eq(actual, expected, message: String = ""):
	if actual != expected:
		_fail("断言失败: 期望 %s，实际 %s" % [str(expected), str(actual)] + (" - " + message if message else ""))

func assert_ne(actual, expected, message: String = ""):
	if actual == expected:
		_fail("断言失败: 期望不等于 %s" % str(expected) + (" - " + message if message else ""))

func assert_almost_eq(actual: float, expected: float, tolerance: float, message: String = ""):
	if abs(actual - expected) > tolerance:
		_fail("断言失败: 期望约等于 %f (容差 %f)，实际 %f" % [expected, tolerance, actual] + (" - " + message if message else ""))

func assert_gt(actual, expected, message: String = ""):
	if not (actual > expected):
		_fail("断言失败: 期望 %s > %s" % [str(actual), str(expected)] + (" - " + message if message else ""))

func assert_lt(actual, expected, message: String = ""):
	if not (actual < expected):
		_fail("断言失败: 期望 %s < %s" % [str(actual), str(expected)] + (" - " + message if message else ""))

func assert_ge(actual, expected, message: String = ""):
	if not (actual >= expected):
		_fail("断言失败: 期望 %s >= %s" % [str(actual), str(expected)] + (" - " + message if message else ""))

func assert_le(actual, expected, message: String = ""):
	if not (actual <= expected):
		_fail("断言失败: 期望 %s <= %s" % [str(actual), str(expected)] + (" - " + message if message else ""))

func assert_null(value, message: String = ""):
	if value != null:
		_fail("断言失败: 期望为null，实际为 %s" % str(value) + (" - " + message if message else ""))

func assert_not_null(value, message: String = ""):
	if value == null:
		_fail("断言失败: 期望不为null" + (" - " + message if message else ""))

func assert_string_contains(string: String, substring: String, message: String = ""):
	if not string.contains(substring):
		_fail("断言失败: 期望字符串包含 '%s'" % substring + (" - " + message if message else ""))

func assert_array_contains(arr: Array, value, message: String = ""):
	if not arr.has(value):
		_fail("断言失败: 期望数组包含 %s" % str(value) + (" - " + message if message else ""))

func assert_array_size(arr: Array, expected_size: int, message: String = ""):
	if arr.size() != expected_size:
		_fail("断言失败: 期望数组大小为 %d，实际为 %d" % [expected_size, arr.size()] + (" - " + message if message else ""))

func assert_vector_eq(actual: Vector3, expected: Vector3, tolerance: float = 0.001, message: String = ""):
	if actual.distance_to(expected) > tolerance:
		_fail("断言失败: 期望向量 %s，实际 %s (容差 %f)" % [str(expected), str(actual), tolerance] + (" - " + message if message else ""))

func assert_quaternion_eq(actual: Quaternion, expected: Quaternion, tolerance: float = 0.001, message: String = ""):
	var diff = actual - expected
	if abs(diff.x) > tolerance or abs(diff.y) > tolerance or abs(diff.z) > tolerance or abs(diff.w) > tolerance:
		_fail("断言失败: 期望四元数 %s，实际 %s" % [str(expected), str(actual)] + (" - " + message if message else ""))

func fail(message: String = ""):
	_fail("测试失败: " + message)

# ========== 辅助方法 ==========

func _fail(message: String):
	_assert_failed = true
	_error_messages.append(message)
	push_error(message)

func has_failed() -> bool:
	return _assert_failed

func get_error_messages() -> Array[String]:
	return _error_messages

func wait_seconds(seconds: float):
	"""等待指定秒数（用于异步测试）"""
	await get_tree().create_timer(seconds).timeout

func wait_frames(frame_count: int):
	"""等待指定帧数"""
	for i in range(frame_count):
		await get_tree().process_frame
