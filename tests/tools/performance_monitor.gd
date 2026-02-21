extends Node
class_name PerformanceMonitor

# 性能监控工具
# 监控帧率、延迟、内存使用等性能指标

@export var log_interval: float = 1.0  # 日志记录间隔（秒）
@export var enable_logging: bool = true

# 性能数据
var fps_history: Array[float] = []
var frame_time_history: Array[float] = []
var memory_history: Array[int] = []

# 统计数据
var stats: Dictionary = {
	"avg_fps": 0.0,
	"min_fps": 999.0,
	"max_fps": 0.0,
	"avg_frame_time": 0.0,
	"max_frame_time": 0.0,
	"avg_memory_mb": 0.0,
	"max_memory_mb": 0.0
}

# 传感器延迟测量
var latency_measurements: Array[float] = []
var last_packet_time: float = 0.0

# 监控状态
var is_monitoring: bool = false
var monitor_timer: float = 0.0
var start_time: float = 0.0

# 信号
signal stats_updated(new_stats: Dictionary)
signal fps_dropped(current_fps: float, threshold: float)
signal latency_exceeded(current_latency: float, threshold: float)

func _ready():
	print("[PerformanceMonitor] 性能监控器已初始化")

func start_monitoring():
	"""开始监控"""
	is_monitoring = true
	start_time = Time.get_unix_time_from_system()
	fps_history.clear()
	frame_time_history.clear()
	memory_history.clear()
	latency_measurements.clear()
	print("[PerformanceMonitor] 开始监控性能")

func stop_monitoring() -> Dictionary:
	"""停止监控并返回统计结果"""
	is_monitoring = false
	_calculate_stats()
	print("[PerformanceMonitor] 停止监控")
	print_stats()
	return stats.duplicate()

func _process(delta: float):
	if not is_monitoring:
		return

	# 记录帧数据
	var fps = Engine.get_frames_per_second()
	var frame_time_ms = delta * 1000.0
	var memory_static = Performance.get_monitor(Performance.MEMORY_STATIC)

	fps_history.append(fps)
	frame_time_history.append(frame_time_ms)
	memory_history.append(memory_static)

	# 限制历史记录大小
	if fps_history.size() > 3600:  # 保留最近1分钟（60fps）
		fps_history.pop_front()
		frame_time_history.pop_front()
		memory_history.pop_front()

	# 检查性能问题
	_check_performance_issues(fps, frame_time_ms)

	# 定期更新统计
	monitor_timer += delta
	if monitor_timer >= log_interval:
		monitor_timer = 0.0
		_calculate_stats()
		emit_signal("stats_updated", stats.duplicate())

		if enable_logging:
			_log_current_stats()

func _check_performance_issues(fps: float, frame_time_ms: float):
	"""检查性能问题"""
	# 检查帧率下降
	if fps < 45.0:  # 低于45fps
		emit_signal("fps_dropped", fps, 45.0)

	# 检查帧时间过长
	if frame_time_ms > 22.0:  # 超过22ms（约45fps）
		push_warning("[PerformanceMonitor] 帧时间过长: %.2f ms" % frame_time_ms)

func _calculate_stats():
	"""计算统计数据"""
	if fps_history.is_empty():
		return

	# FPS统计
	var fps_sum = 0.0
	var fps_min = 999.0
	var fps_max = 0.0
	for fps in fps_history:
		fps_sum += fps
		fps_min = min(fps_min, fps)
		fps_max = max(fps_max, fps)

	stats["avg_fps"] = fps_sum / fps_history.size()
	stats["min_fps"] = fps_min
	stats["max_fps"] = fps_max

	# 帧时间统计
	var frame_time_sum = 0.0
	var frame_time_max = 0.0
	for ft in frame_time_history:
		frame_time_sum += ft
		frame_time_max = max(frame_time_max, ft)

	stats["avg_frame_time"] = frame_time_sum / frame_time_history.size()
	stats["max_frame_time"] = frame_time_max

	# 内存统计
	var memory_sum = 0
	var memory_max = 0
	for mem in memory_history:
		memory_sum += mem
		memory_max = max(memory_max, mem)

	stats["avg_memory_mb"] = (memory_sum / memory_history.size()) / 1024.0 / 1024.0
	stats["max_memory_mb"] = memory_max / 1024.0 / 1024.0

func _log_current_stats():
	"""记录当前统计"""
	print("[Performance] FPS: %.1f (avg) / %.1f (min) | Frame: %.2f ms | Memory: %.1f MB" % [
		stats["avg_fps"],
		stats["min_fps"],
		stats["avg_frame_time"],
		stats["avg_memory_mb"]
	])

func print_stats():
	"""打印统计结果"""
	print("\n========== 性能监控报告 ==========")
	print("监控时长: %.1f 秒" % (Time.get_unix_time_from_system() - start_time))
	print("FPS - 平均: %.1f, 最低: %.1f, 最高: %.1f" % [stats["avg_fps"], stats["min_fps"], stats["max_fps"]])
	print("帧时间 - 平均: %.2f ms, 最大: %.2f ms" % [stats["avg_frame_time"], stats["max_frame_time"]])
	print("内存 - 平均: %.1f MB, 最大: %.1f MB" % [stats["avg_memory_mb"], stats["max_memory_mb"]])

	if not latency_measurements.is_empty():
		var avg_latency = _calculate_average_latency()
		print("传感器延迟 - 平均: %.1f ms" % avg_latency)

	print("===================================\n")

# ========== 延迟测量 ==========

func record_packet_sent(timestamp: float):
	"""记录数据包发送时间"""
	last_packet_time = timestamp

func record_packet_received():
	"""记录数据包接收时间并计算延迟"""
	if last_packet_time > 0:
		var latency = (Time.get_unix_time_from_system() - last_packet_time) * 1000.0
		latency_measurements.append(latency)

		if latency > 50.0:  # 超过50ms
			emit_signal("latency_exceeded", latency, 50.0)

		# 限制历史记录
		if latency_measurements.size() > 1000:
			latency_measurements.pop_front()

func _calculate_average_latency() -> float:
	if latency_measurements.is_empty():
		return 0.0

	var sum = 0.0
	for lat in latency_measurements:
		sum += lat
	return sum / latency_measurements.size()

# ========== 公共接口 ==========

func get_current_fps() -> float:
	return Engine.get_frames_per_second()

func get_current_memory_mb() -> float:
	return Performance.get_monitor(Performance.MEMORY_STATIC) / 1024.0 / 1024.0

func get_stats() -> Dictionary:
	_calculate_stats()
	return stats.duplicate()

func reset_stats():
	"""重置统计"""
	fps_history.clear()
	frame_time_history.clear()
	memory_history.clear()
	latency_measurements.clear()
	stats = {
		"avg_fps": 0.0,
		"min_fps": 999.0,
		"max_fps": 0.0,
		"avg_frame_time": 0.0,
		"max_frame_time": 0.0,
		"avg_memory_mb": 0.0,
		"max_memory_mb": 0.0
	}

func is_performance_acceptable() -> bool:
	"""检查性能是否可接受"""
	_calculate_stats()

	if stats["avg_fps"] < 45.0:
		return false
	if stats["avg_frame_time"] > 22.0:
		return false
	if stats["max_memory_mb"] > 256.0:
		return false

	return true
