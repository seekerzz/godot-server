class_name SensorFusion
extends Node

## 传感器数据融合模块
## 负责接收原始传感器数据，进行滤波、坐标转换和数据融合

# 信号
signal data_processed(motion_data: MotionData)
signal spike_detected(accel_magnitude: float)

# 滤波器参数
@export var accel_low_pass_alpha: float = 0.3   # 加速度低通系数
@export var velocity_smooth_factor: float = 0.2 # 速度平滑系数
@export var quat_smooth_factor: float = 0.1     # 四元数平滑系数

# 异常检测参数
@export var spike_threshold: float = 50.0       # 尖峰阈值 (m/s²)
@export var max_consecutive_spikes: int = 3     # 最大连续异常数

# 状态变量
var filtered_accel := Vector3.ZERO
var smoothed_velocity := Vector3.ZERO
var smoothed_quaternion := Quaternion.IDENTITY
var last_raw_accel := Vector3.ZERO
var consecutive_spikes: int = 0

# 帧计数（用于调试）
var frame_count := 0


## 运动数据结构
class MotionData:
    var timestamp: float          # 时间戳
    var linear_accel: Vector3     # 线性加速度 (m/s²)
    var quaternion: Quaternion    # 旋转四元数
    var euler_angles: Vector3     # 欧拉角 (度)
    var velocity: Vector3         # 估算速度
    var position: Vector3         # 估算位置

    func _init():
        timestamp = Time.get_unix_time_from_system()


func _ready():
    print("[SensorFusion] 传感器融合模块已初始化")


## 处理原始传感器数据
func process_sensor_data(raw_accel: Vector3, raw_quat: Quaternion, delta: float) -> MotionData:
    frame_count += 1

    var motion_data = MotionData.new()

    # 1. 异常值检测与处理
    var processed_accel = detect_and_handle_spikes(raw_accel)

    # 2. 坐标系转换 (Android -> Godot)
    var godot_accel = convert_vector_to_godot(processed_accel)
    var godot_quat = convert_quaternion_to_godot(raw_quat)

    # 3. 低通滤波 (去除高频噪声)
    filtered_accel = filtered_accel.lerp(godot_accel, accel_low_pass_alpha)

    # 4. 速度积分与平滑
    var raw_velocity = smoothed_velocity + filtered_accel * delta
    smoothed_velocity = smoothed_velocity.lerp(raw_velocity, velocity_smooth_factor)

    # 5. 四元数平滑
    smoothed_quaternion = smoothed_quaternion.slerp(godot_quat, quat_smooth_factor)

    # 6. 填充运动数据
    motion_data.linear_accel = filtered_accel
    motion_data.quaternion = smoothed_quaternion
    motion_data.euler_angles = quaternion_to_euler(smoothed_quaternion)
    motion_data.velocity = smoothed_velocity

    # 7. 调试输出
    if frame_count <= 10 or frame_count % 300 == 0:
        print("[SensorFusion#%d] Accel: (%.3f, %.3f, %.3f) | Euler: (%.1f, %.1f, %.1f)" % [
            frame_count,
            filtered_accel.x, filtered_accel.y, filtered_accel.z,
            motion_data.euler_angles.x, motion_data.euler_angles.y, motion_data.euler_angles.z
        ])

    emit_signal("data_processed", motion_data)
    return motion_data


## 异常值检测与处理
func detect_and_handle_spikes(raw_accel: Vector3) -> Vector3:
    var accel_delta = (raw_accel - last_raw_accel).length()

    if accel_delta > spike_threshold:
        consecutive_spikes += 1
        emit_signal("spike_detected", accel_delta)

        if consecutive_spikes > max_consecutive_spikes:
            # 重置滤波器
            filtered_accel = raw_accel
            consecutive_spikes = 0
            if frame_count % 60 == 0:
                print("[SensorFusion] 滤波器重置（连续异常）")
        else:
            # 忽略本次异常值，使用上一次的滤波值
            return filtered_accel
    else:
        consecutive_spikes = 0

    last_raw_accel = raw_accel
    return raw_accel


## 将Android坐标系的向量转换为Godot坐标系
## Android: X向右, Y向上, Z向外(屏幕方向)
## Godot: X向右, Y向上, Z向内(屏幕方向)
func convert_vector_to_godot(v: Vector3) -> Vector3:
    # 直连映射，根据实际校准结果可能需要调整符号
    return Vector3(v.x, v.y, v.z)


## 将Android坐标系的四元数转换为Godot坐标系
func convert_quaternion_to_godot(q: Quaternion) -> Quaternion:
    # 直连映射，根据实际校准结果可能需要调整符号
    return Quaternion(q.x, q.y, q.z, q.w).normalized()


## 四元数转欧拉角 (度)
## 返回 Vector3(pitch, yaw, roll) 即 (X, Y, Z) 轴旋转
func quaternion_to_euler(q: Quaternion) -> Vector3:
    var euler = Vector3.ZERO

    # Pitch (X轴旋转)
    var sinr_cosp = 2.0 * (q.w * q.x + q.y * q.z)
    var cosr_cosp = 1.0 - 2.0 * (q.x * q.x + q.y * q.y)
    euler.x = atan2(sinr_cosp, cosr_cosp)

    # Yaw (Y轴旋转)
    var sinp = 2.0 * (q.w * q.y - q.z * q.x)
    if abs(sinp) >= 1.0:
        euler.y = copysign(PI / 2.0, sinp)  # 使用90度
    else:
        euler.y = asin(sinp)

    # Roll (Z轴旋转)
    var siny_cosp = 2.0 * (q.w * q.z + q.x * q.y)
    var cosy_cosp = 1.0 - 2.0 * (q.y * q.y + q.z * q.z)
    euler.z = atan2(siny_cosp, cosy_cosp)

    # 转换为度
    return Vector3(
        rad_to_deg(euler.x),
        rad_to_deg(euler.y),
        rad_to_deg(euler.z)
    )


## 欧拉角转四元数
## 输入 Vector3(pitch, yaw, roll) 单位：度
func euler_to_quaternion(euler: Vector3) -> Quaternion:
    var pitch = deg_to_rad(euler.x)
    var yaw = deg_to_rad(euler.y)
    var roll = deg_to_rad(euler.z)

    var cy = cos(yaw * 0.5)
    var sy = sin(yaw * 0.5)
    var cp = cos(pitch * 0.5)
    var sp = sin(pitch * 0.5)
    var cr = cos(roll * 0.5)
    var sr = sin(roll * 0.5)

    var q = Quaternion()
    q.w = cr * cp * cy + sr * sp * sy
    q.x = sr * cp * cy - cr * sp * sy
    q.y = cr * sp * cy + sr * cp * sy
    q.z = cr * cp * sy - sr * sp * cy

    return q.normalized()


## 辅助函数：带符号复制
func copysign(magnitude: float, sign_val: float) -> float:
    if sign_val >= 0:
        return abs(magnitude)
    else:
        return -abs(magnitude)


## 重置滤波器状态
func reset():
    filtered_accel = Vector3.ZERO
    smoothed_velocity = Vector3.ZERO
    smoothed_quaternion = Quaternion.IDENTITY
    last_raw_accel = Vector3.ZERO
    consecutive_spikes = 0
    frame_count = 0
    print("[SensorFusion] 滤波器已重置")


## 获取当前滤波状态（用于调试）
func get_debug_info() -> Dictionary:
    return {
        "frame_count": frame_count,
        "filtered_accel": filtered_accel,
        "smoothed_velocity": smoothed_velocity,
        "consecutive_spikes": consecutive_spikes
    }
