extends Node

# 测试主入口
# 运行所有单元测试

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
	print("=" * 70)
	print("   混合现实乒乓球游戏 - 自动化测试套件")
	print("=" * 70)
	print()

	# 检查命令行参数
	var args = OS.get_cmdline_args()

	if "--help" in args or "-h" in args:
		_show_help()
		get_tree().quit(0)
		return

	# 运行测试
	if "--unit" in args or "--all" in args or args.size() <= 1:
		run_unit_tests()

	if "--integration" in args or "--all" in args:
		run_integration_tests()

	if "--performance" in args or "--all" in args:
		run_performance_tests()

	# 打印结果
	print_results()

	# 退出
	var exit_code = 0 if failed_tests == 0 else 1
	if "--headless" in args or "--quit" in args:
		get_tree().quit(exit_code)

func run_unit_tests():
	print("[单元测试]")
	print("-" * 70)
	run_tests_in_directory("res://tests/unit")
	print()

func run_integration_tests():
	print("[集成测试]")
	print("-" * 70)
	run_tests_in_directory("res://tests/integration")
	print()

func run_performance_tests():
	print("[性能测试]")
	print("-" * 70)
	run_tests_in_directory("res://tests/performance")
	print()

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

func run_test_file(test_path: String):
	var script = load(test_path)
	if script == null:
		print("[错误] 无法加载测试脚本: %s" % test_path)
		return

	var test_instance = script.new()
	if test_instance == null:
		print("[错误] 无法实例化测试")
		return

	add_child(test_instance)

	# 获取测试方法
	var methods = test_instance.get_script().get_script_method_list()
	var test_methods = []

	for method in methods:
		if method["name"].begins_with("test_"):
			test_methods.append(method["name"])

	if test_methods.is_empty():
		test_instance.queue_free()
		return

	print("\n  %s:" % test_path.get_file())

	# 调用 before_all
	if test_instance.has_method("before_all"):
		test_instance.before_all()

	for method_name in test_methods:
		total_tests += 1

		# 调用 before_each
		if test_instance.has_method("before_each"):
			test_instance.before_each()

		var result = _run_test_method(test_instance, method_name)

		if result.success:
			passed_tests += 1
			print("    [通过] %s" % method_name)
		else:
			failed_tests += 1
			print("    [失败] %s" % method_name)
			if result.message != "":
				print("      -> %s" % result.message)

		# 调用 after_each
		if test_instance.has_method("after_each"):
			test_instance.after_each()

	# 调用 after_all
	if test_instance.has_method("after_all"):
		test_instance.after_all()

	test_instance.queue_free()

func _run_test_method(test_instance: Object, method_name: String) -> Dictionary:
	var result = {"success": true, "message": ""}

	# 重置断言状态
	if test_instance.has_method("_fail"):
		test_instance._assert_failed = false
		test_instance._error_messages.clear()

	# 调用测试方法
	var return_value = test_instance.call(method_name)

	# 检查是否有异步等待
	if return_value is GDScriptFunctionState:
		return_value = await return_value

	# 检查断言结果
	if test_instance.has_method("has_failed"):
		if test_instance.has_failed():
			result.success = false
			var messages = test_instance.get_error_messages()
			if not messages.is_empty():
				result.message = messages[0]

	return result

func print_results():
	print()
	print("=" * 70)
	print("   测试结果汇总")
	print("=" * 70)
	print("  总测试数: %d" % total_tests)
	print("  通过:     %d" % passed_tests)
	print("  失败:     %d" % failed_tests)
	print("  通过率:   %.1f%%" % (float(passed_tests) / max(total_tests, 1) * 100))
	print("=" * 70)

	if failed_tests == 0:
		print("   所有测试通过！")
	else:
		print("   有测试失败，请检查日志。")
	print("=" * 70)

func _show_help():
	print("""
使用方法: godot --path . --headless tests/tests_main.tscn [选项]

选项:
  --unit          运行单元测试
  --integration   运行集成测试
  --performance   运行性能测试
  --all           运行所有测试
  --headless      无界面模式（自动退出）
  --help, -h      显示帮助

示例:
  godot --path . --headless tests/tests_main.tscn --all
  godot --path . tests/tests_main.tscn --unit
""")
