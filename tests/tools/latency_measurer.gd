extends Node
class_name LatencyMeasurer

# 延迟测量工具
# 测量传感器数据从发送到显示的端到端延迟

@export var sample_count: int = 100  # 采样数量

# 测量数据
var samples: Array[Dictionary] = []
var is_measuring: bool = false
var current_sample_id: int = 0

# 统计结果
var results: Dictionary = {
	"avg_latency_ms": 0.0,
	"min_latency_ms": 9999.0,
	"max_latency_ms": 0.0,
	"p50_latency_ms": 0.0,
	"p95_latency_ms": 0.0,
	"p99_latency_ms": 0.0,
	"packet_loss_rate": 0.0
}

signal measurement_complete(final_results: Dictionary)
signal sample_recorded(sample_id: int, latency_ms: float)

func _ready():
	print("[LatencyMeasurer] 延迟测量工具已初始化")

func start_measurement():
	"""开始测量"""
	is_measuring = true
	samples.clear()
	current_sample_id = 0
	results = {
		"avg_latency_ms": 0.0,
		"min_latency_ms": 9999.0,
		"max_latency_ms": 0.0,
		"p50_latency_ms": 0.0,
		"p95_latency_ms": 0.0,
		"p99_latency_ms": 0.0,
		"packet_loss_rate": 0.0
	}
	print("[LatencyMeasurer] 开始延迟测量，目标采样数: %d" % sample_count)

func stop_measurement() -> Dictionary:
	"""停止测量并返回结果"""
	is_measuring = false
	_calculate_results()
	print("[LatencyMeasurer] 测量完成，共采样 %d 个" % samples.size())
	print_results()
	emit_signal("measurement_complete", results.duplicate())
	return results.duplicate()

func record_send_time(sample_id: int = -1) -> int:
	"""记录发送时间"""
	if not is_measuring:
		return -1

	if sample_id < 0:
		sample_id = current_sample_id
		current_sample_id += 1

	var sample = {
		"id": sample_id,
		"send_time": Time.get_unix_time_from_system(),
		"receive_time": 0.0,
		"latency_ms": -1.0
	}
	samples.append(sample)

	return sample_id

func record_receive_time(sample_id: int):
	"""记录接收时间"""
	if not is_measuring:
		return

	for sample in samples:
		if sample["id"] == sample_id:
			if sample["receive_time"] == 0.0:  # 避免重复记录
				sample["receive_time"] = Time.get_unix_time_from_system()
				sample["latency_ms"] = (sample["receive_time"] - sample["send_time"]) * 1000.0
				emit_signal("sample_recorded", sample_id, sample["latency_ms"])
			return

func _calculate_results():
	"""计算测量结果"""
	if samples.is_empty():
		return

	var latencies: Array[float] = []
	var lost_packets = 0

	for sample in samples:
		if sample["latency_ms"] > 0:
			latencies.append(sample["latency_ms"])
		else:
			lost_packets += 1

	if latencies.is_empty():
		return

	# 排序用于计算百分位数
	latencies.sort()

	# 基本统计
	var sum = 0.0
	var min_lat = 9999.0
	var max_lat = 0.0

	for lat in latencies:
		sum += lat
		min_lat = min(min_lat, lat)
		max_lat = max(max_lat, lat)

	results["avg_latency_ms"] = sum / latencies.size()
	results["min_latency_ms"] = min_lat
	results["max_latency_ms"] = max_lat

	# 百分位数
	results["p50_latency_ms"] = _get_percentile(latencies, 0.50)
	results["p95_latency_ms"] = _get_percentile(latencies, 0.95)
	results["p99_latency_ms"] = _get_percentile(latencies, 0.99)

	# 丢包率
	results["packet_loss_rate"] = float(lost_packets) / samples.size() * 100.0

func _get_percentile(sorted_array: Array[float], percentile: float) -> float:
	"""获取百分位数"""
	if sorted_array.is_empty():
		return 0.0

	var index = int((sorted_array.size() - 1) * percentile)
	return sorted_array[index]

func print_results():
	"""打印测量结果"""
	print("\n========== 延迟测量报告 ==========")
	print("总采样数: %d" % samples.size())
	print("有效样本: %d" % (samples.size() - int(results["packet_loss_rate"] * samples.size() / 100.0)))
	print("丢包率: %.2f%%" % results["packet_loss_rate"])
	print("---")
	print("平均延迟: %.2f ms" % results["avg_latency_ms"])
	print("最小延迟: %.2f ms" % results["min_latency_ms"])
	print("最大延迟: %.2f ms" % results["max_latency_ms"])
	print("P50 延迟: %.2f ms" % results["p50_latency_ms"])
	print("P95 延迟: %.2f ms" % results["p95_latency_ms"])
	print("P99 延迟: %.2f ms" % results["p99_latency_ms"])

	# 评估
	if results["avg_latency_ms"] < 20.0:
		print("评估: 优秀 (延迟 < 20ms)")
	elif results["avg_latency_ms"] < 50.0:
		print("评估: 良好 (延迟 < 50ms)")
	elif results["avg_latency_ms"] < 100.0:
		print("评估: 可接受 (延迟 < 100ms)")
	else:
		print("评估: 需要优化 (延迟 >= 100ms)")

	print("===================================\n")

# ========== 公共接口 ==========

func get_results() -> Dictionary:
	"""获取测量结果"""
	_calculate_results()
	return results.duplicate()

func is_measuring_active() -> bool:
	"""检查是否正在测量"""
	return is_measuring

func get_progress() -> float:
	"""获取测量进度 (0.0 - 1.0)"""
	if sample_count <= 0:
		return 0.0
	return float(samples.size()) / sample_count

func reset():
	"""重置测量器"""
	is_measuring = false
	samples.clear()
	current_sample_id = 0

func is_latency_acceptable() -> bool:
	"""检查延迟是否可接受"""
	_calculate_results()
	return results["avg_latency_ms"] < 50.0 and results["p95_latency_ms"] < 100.0
