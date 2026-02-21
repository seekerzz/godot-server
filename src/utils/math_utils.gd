class_name MathUtils
extends RefCounted

## 数学工具类
## 提供常用的数学辅助函数


## 将值从一个范围映射到另一个范围
static func map_range(value: float, from_min: float, from_max: float, to_min: float, to_max: float) -> float:
    return to_min + (value - from_min) * (to_max - to_min) / (from_max - from_min)


## 将值限制在指定范围内
static func clamp_value(value: float, min_val: float, max_val: float) -> float:
    return clamp(value, min_val, max_val)


## 平滑阻尼（类似Unity的Mathf.SmoothDamp）
static func smooth_damp(current: float, target: float, current_velocity: float, smooth_time: float, delta: float) -> Dictionary:
    var omega = 2.0 / smooth_time
    var x = omega * delta
    var exp_val = 1.0 / (1.0 + x + 0.48 * x * x + 0.235 * x * x * x)
    var change = current - target
    var temp = (current_velocity + omega * change) * delta
    var new_velocity = (current_velocity - omega * temp) * exp_val
    var new_value = target + (change + temp) * exp_val

    return {
        "value": new_value,
        "velocity": new_velocity
    }


## 向量3的平滑阻尼
static func smooth_damp_vector3(current: Vector3, target: Vector3, current_velocity: Vector3, smooth_time: float, delta: float) -> Dictionary:
    var x_result = smooth_damp(current.x, target.x, current_velocity.x, smooth_time, delta)
    var y_result = smooth_damp(current.y, target.y, current_velocity.y, smooth_time, delta)
    var z_result = smooth_damp(current.z, target.z, current_velocity.z, smooth_time, delta)

    return {
        "value": Vector3(x_result["value"], y_result["value"], z_result["value"]),
        "velocity": Vector3(x_result["velocity"], y_result["velocity"], z_result["velocity"])
    }


## 计算两点之间的距离
static func distance_3d(a: Vector3, b: Vector3) -> float:
    return a.distance_to(b)


## 计算两点之间的平方距离（避免开方运算，性能更好）
static func distance_squared_3d(a: Vector3, b: Vector3) -> float:
    return a.distance_squared_to(b)


## 检查点是否在球体内
static func is_point_in_sphere(point: Vector3, sphere_center: Vector3, sphere_radius: float) -> bool:
    return distance_squared_3d(point, sphere_center) <= sphere_radius * sphere_radius


## 检查点是否在盒子内
static func is_point_in_box(point: Vector3, box_min: Vector3, box_max: Vector3) -> bool:
    return point.x >= box_min.x and point.x <= box_max.x and \
           point.y >= box_min.y and point.y <= box_max.y and \
           point.z >= box_min.z and point.z <= box_max.z


## 四元数到欧拉角（度）
static func quaternion_to_euler_degrees(q: Quaternion) -> Vector3:
    var euler = Vector3.ZERO

    # Pitch (X轴旋转)
    var sinr_cosp = 2.0 * (q.w * q.x + q.y * q.z)
    var cosr_cosp = 1.0 - 2.0 * (q.x * q.x + q.y * q.y)
    euler.x = atan2(sinr_cosp, cosr_cosp)

    # Yaw (Y轴旋转)
    var sinp = 2.0 * (q.w * q.y - q.z * q.x)
    if abs(sinp) >= 1.0:
        euler.y = copysign(PI / 2.0, sinp)
    else:
        euler.y = asin(sinp)

    # Roll (Z轴旋转)
    var siny_cosp = 2.0 * (q.w * q.z + q.x * q.y)
    var cosy_cosp = 1.0 - 2.0 * (q.y * q.y + q.z * q.z)
    euler.z = atan2(siny_cosp, cosy_cosp)

    return Vector3(rad_to_deg(euler.x), rad_to_deg(euler.y), rad_to_deg(euler.z))


## 欧拉角（度）到四元数
static func euler_degrees_to_quaternion(euler: Vector3) -> Quaternion:
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


## 带符号复制
static func copysign(magnitude: float, sign_val: float) -> float:
    if sign_val >= 0:
        return abs(magnitude)
    else:
        return -abs(magnitude)


## 线性插值
static func lerp(a: float, b: float, t: float) -> float:
    return a + (b - a) * clamp(t, 0.0, 1.0)


## 球面线性插值（四元数）
static func slerp(q1: Quaternion, q2: Quaternion, t: float) -> Quaternion:
    return q1.slerp(q2, t)


## 计算移动平均值
static func moving_average(values: Array[float], new_value: float, window_size: int) -> float:
    values.append(new_value)
    while values.size() > window_size:
        values.pop_front()

    if values.is_empty():
        return 0.0

    var sum = 0.0
    for v in values:
        sum += v
    return sum / values.size()


## 计算标准差
static func standard_deviation(values: Array[float]) -> float:
    if values.size() < 2:
        return 0.0

    var mean = 0.0
    for v in values:
        mean += v
    mean /= values.size()

    var variance = 0.0
    for v in values:
        variance += (v - mean) * (v - mean)
    variance /= values.size()

    return sqrt(variance)


## 低通滤波器
static func low_pass_filter(current: float, target: float, alpha: float) -> float:
    return current * (1.0 - alpha) + target * alpha


## 向量3的低通滤波
static func low_pass_filter_vector3(current: Vector3, target: Vector3, alpha: float) -> Vector3:
    return current.lerp(target, alpha)


## 死区处理（消除小值噪声）
static func apply_deadzone(value: float, threshold: float) -> float:
    if abs(value) < threshold:
        return 0.0
    return value


## 向量3的死区处理
static func apply_deadzone_vector3(v: Vector3, threshold: float) -> Vector3:
    return Vector3(
        apply_deadzone(v.x, threshold),
        apply_deadzone(v.y, threshold),
        apply_deadzone(v.z, threshold)
    )
