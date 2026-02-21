class_name PaddleCalibration
extends Node

## 球拍校准系统
## 单次校准：将当前手机姿态设为基准零点

# 信号
signal calibration_started()
signal calibration_step_changed(step: int, pose_name: String, instruction: String)
signal calibration_completed(success: bool, offset: Quaternion)
signal calibration_saved(filepath: String)

# 校准状态
var is_calibrating := false

# 校准结果
var calibration_offset := Quaternion.IDENTITY

# 配置
const SAVE_DIR := "user://calibration/"


func _ready():
    print("[PaddleCalibration] 校准系统已初始化（单次校准模式）")
    _ensure_save_directory()
    # 尝试加载已保存的校准数据
    load_latest_calibration()


## 开始校准流程
func start_calibration():
    is_calibrating = true
    print("[PaddleCalibration] ========== 开始单次校准 ==========")
    print("[PaddleCalibration] 请像握乒乓球拍一样握住手机：")
    print("[PaddleCalibration] - 竖直握持手机")
    print("[PaddleCalibration] - 屏幕面向你自己")
    print("[PaddleCalibration] - 手机底部朝下（手柄方向）")
    print("[PaddleCalibration] - 然后按确认键")
    emit_signal("calibration_started")
    emit_signal("calibration_step_changed", 0, "球拍握持姿势", "像握乒乓球拍一样竖直握持手机，屏幕面向你，然后按确认")


## 记录校准样本（单次校准）
func record_calibration_sample(raw_quaternion: Quaternion, accel: Vector3 = Vector3.ZERO):
    if not is_calibrating:
        print("[PaddleCalibration] 错误：未开始校准流程")
        return false

    # 计算校准偏移：将当前姿态的逆设为偏移
    # 这样应用偏移后，当前姿态会变成单位旋转（零点）
    calibration_offset = raw_quaternion.inverse()

    print("[PaddleCalibration] 校准样本已记录")
    print("[PaddleCalibration] 原始姿态: (%.4f, %.4f, %.4f, %.4f)" % [
        raw_quaternion.x, raw_quaternion.y, raw_quaternion.z, raw_quaternion.w
    ])
    print("[PaddleCalibration] 校准偏移: (%.4f, %.4f, %.4f, %.4f)" % [
        calibration_offset.x, calibration_offset.y, calibration_offset.z, calibration_offset.w
    ])

    # 保存校准数据
    save_calibration_data(raw_quaternion)

    is_calibrating = false
    emit_signal("calibration_completed", true, calibration_offset)
    print("[PaddleCalibration] ========== 校准完成 ==========")

    return true


## 应用校准到原始旋转
func apply_calibration(raw_rotation: Quaternion) -> Quaternion:
    return (calibration_offset * raw_rotation).normalized()


## 保存校准数据到文件
func save_calibration_data(raw_quaternion: Quaternion = Quaternion.IDENTITY) -> String:
    var datetime = Time.get_datetime_dict_from_system()
    var filename = "calibration_%04d%02d%02d_%02d%02d%02d.json" % [
        datetime.year, datetime.month, datetime.day,
        datetime.hour, datetime.minute, datetime.second
    ]
    var filepath = SAVE_DIR + filename

    var output = {
        "calibration_date": "%04d-%02d-%02d %02d:%02d:%02d" % [
            datetime.year, datetime.month, datetime.day,
            datetime.hour, datetime.minute, datetime.second
        ],
        "calibration_offset": {
            "x": calibration_offset.x,
            "y": calibration_offset.y,
            "z": calibration_offset.z,
            "w": calibration_offset.w
        },
        "base_pose": {
            "x": raw_quaternion.x,
            "y": raw_quaternion.y,
            "z": raw_quaternion.z,
            "w": raw_quaternion.w
        }
    }

    var file = FileAccess.open(filepath, FileAccess.WRITE)
    if file:
        file.store_string(JSON.stringify(output, "\t"))
        file.close()
        print("[PaddleCalibration] 校准数据已保存到: %s" % filepath)

        # 同时保存一个固定名称的文件用于快速加载
        _save_latest_calibration(output)

        emit_signal("calibration_saved", filepath)
        return filepath
    else:
        print("[PaddleCalibration] 错误：保存校准数据失败")
        return ""


## 保存为最新校准文件
func _save_latest_calibration(data: Dictionary):
    var filepath = SAVE_DIR + "latest_calibration.json"
    var file = FileAccess.open(filepath, FileAccess.WRITE)
    if file:
        file.store_string(JSON.stringify(data, "\t"))
        file.close()
        print("[PaddleCalibration] 最新校准数据已保存到: %s" % filepath)


## 加载最新校准数据
func load_latest_calibration() -> bool:
    var filepath = SAVE_DIR + "latest_calibration.json"

    if not FileAccess.file_exists(filepath):
        print("[PaddleCalibration] 没有找到校准数据文件")
        return false

    var file = FileAccess.open(filepath, FileAccess.READ)
    if not file:
        print("[PaddleCalibration] 错误：无法打开校准数据文件")
        return false

    var content = file.get_as_text()
    file.close()

    var json = JSON.new()
    var err = json.parse(content)
    if err != OK:
        print("[PaddleCalibration] 错误：校准数据解析失败")
        return false

    var data = json.get_data()

    # 加载校准偏移
    if data.has("calibration_offset"):
        var q = data["calibration_offset"]
        calibration_offset = Quaternion(q["x"], q["y"], q["z"], q["w"])
        print("[PaddleCalibration] 已加载校准偏移: (%.4f, %.4f, %.4f, %.4f)" % [
            calibration_offset.x, calibration_offset.y, calibration_offset.z, calibration_offset.w
        ])
        return true

    return false


## 重置校准（清除偏移）
func reset_calibration():
    calibration_offset = Quaternion.IDENTITY
    print("[PaddleCalibration] 校准已重置")


## 确保保存目录存在
func _ensure_save_directory():
    var dir = DirAccess.open("user://")
    if dir and not dir.dir_exists("calibration"):
        dir.make_dir("calibration")
        print("[PaddleCalibration] 创建校准数据目录: %s" % SAVE_DIR)


## 获取校准偏移
func get_calibration_offset() -> Quaternion:
    return calibration_offset


## 检查是否有已保存的校准数据
func has_saved_calibration() -> bool:
    return FileAccess.file_exists(SAVE_DIR + "latest_calibration.json")
