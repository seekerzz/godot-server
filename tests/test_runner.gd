extends Node

# GUT Test Runner - 简化版测试运行器
# 用于在没有完整GUT插件的情况下运行基础测试

const TEST_DIRS = [
	"res://tests/unit",
	"res://tests/integration",
	"res://tests/performance"
]

var test_results: Dictionary = {}
var total_tests: int = 0
var passed_tests: int = 0
var failed_tests: int = 0

func _ready():
	print("=" * 60)
	print("混合现实乒乓球游戏 - 测试运行器")
	print("=" * 60)
	print()

	var args = OS.get_cmdline_args()

	# 检查是否只运行特定测试
	var specific_test = ""
	for arg in args:
		if arg.begins_with("--test="):
			specific_test = arg.replace("--test=", "")
			break

	if specific_test != "":
		run_specific_test(specific_test)
	else:
		run_all_tests()

	print_results()

	# 如果是命令行运行，自动退出
	if "--headless" in args or "--quit" in args:
		var exit_code = 0 if failed_tests == 0 else 1
		get_tree().quit(exit_code)

func run_all_tests():
	for dir_path in TEST_DIRS:
		run_tests_in_directory(dir_path)

func run_tests_in_directory(dir_path: String):
	var dir = DirAccess.open(dir_path)
	if dir == null:
		print("[警告] 无法打开目录: %s" % dir_path)
		return

	dir.list_dir_begin()
	var file_name = dir.get_next()

	while file_name != "":
		if file_name.begins_with("test_") and file_name.ends_with(".gd"):
			var test_path = dir_path + "/" + file_name
			run_test_file(test_path)
		file_name = dir.get_next()

func run_specific_test(test_name: String):
	for dir_path in TEST_DIRS:
		var test_path = dir_path + "/test_" + test_name + ".gd"
		if FileAccess.file_exists(test_path):
			run_test_file(test_path)
			return
	print("[错误] 未找到测试: %s" % test_name)

func run_test_file(test_path: String):
	print("\n运行测试: %s" % test_path)
	print("-" * 40)

	var script = load(test_path)
	if script == null:
		print("[错误] 无法加载测试脚本: %s" % test_path)
		return

	var test_instance = script.new()
	if test_instance == null:
		print("[错误] 无法实例化测试")
		return

	# 运行测试方法
	var methods = test_instance.get_script().get_script_method_list()
	var test_methods = []

	for method in methods:
		if method["name"].begins_with("test_"):
			test_methods.append(method["name"])

	# 调用 before_all
	if test_instance.has_method("before_all"):
		test_instance.before_all()

	for method_name in test_methods:
		total_tests += 1

		# 调用 before_each
		if test_instance.has_method("before_each"):
			test_instance.before_each()

		var result = run_test_method(test_instance, method_name)

		if result:
			passed_tests += 1
			print("  [通过] %s" % method_name)
		else:
			failed_tests += 1
			print("  [失败] %s" % method_name)

		# 调用 after_each
		if test_instance.has_method("after_each"):
			test_instance.after_each()

	# 调用 after_all
	if test_instance.has_method("after_all"):
		test_instance.after_all()

	test_instance.queue_free()

func run_test_method(test_instance: Object, method_name: String) -> bool:
	var result = true

	# 设置断言回调
	var assertion_failed = false
	var error_message = ""

	# 将断言方法注入测试实例
	if not test_instance.has_method("assert_true"):
		test_instance.set_meta("_assert_failed", false)
		test_instance.set_meta("_error_message", "")

	# 调用测试方法
	var return_value = test_instance.call(method_name)

	# 检查是否有异步等待
	if return_value is GDScriptFunctionState:
		return_value = await return_value

	# 检查断言结果
	if test_instance.has_meta("_assert_failed"):
		result = not test_instance.get_meta("_assert_failed")

	return result

func print_results():
	print("\n" + "=" * 60)
	print("测试结果汇总")
	print("=" * 60)
	print("总测试数: %d" % total_tests)
	print("通过: %d" % passed_tests)
	print("失败: %d" % failed_tests)
	print("通过率: %.1f%%" % (float(passed_tests) / max(total_tests, 1) * 100))
	print("=" * 60)

	if failed_tests == 0:
		print("所有测试通过！")
	else:
		print("有测试失败，请检查日志。")
