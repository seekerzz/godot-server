# 混合现实乒乓球游戏 - 技术架构方案

**版本**: 1.0
**日期**: 2026-02-21
**作者**: 技术架构组

---

## 目录

1. [系统概述](#1-系统概述)
2. [传感器数据映射算法](#2-传感器数据映射算法)
3. [乒乓球物理系统](#3-乒乓球物理系统)
4. [游戏状态管理架构](#4-游戏状态管理架构)
5. [AI算法方案](#5-ai算法方案)
6. [代码模块划分](#6-代码模块划分)
7. [与现有代码集成方案](#7-与现有代码集成方案)

---

## 1. 系统概述

### 1.1 项目架构图

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              PC端 (Godot 4)                                  │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────────────────┐  │
│  │   网络通信层     │  │   传感器处理层   │  │        游戏逻辑层            │  │
│  │  ┌───────────┐  │  │  ┌───────────┐  │  │  ┌─────────┐ ┌───────────┐ │  │
│  │  │UDP Server │  │  │  │数据映射算法│  │  │  │物理引擎 │ │  AI系统   │ │  │
│  │  │Discovery  │  │  │  │姿态融合   │  │  │  │碰撞检测 │ │ 状态机    │ │  │
│  │  └───────────┘  │  │  └───────────┘  │  │  └─────────┘ └───────────┘ │  │
│  └─────────────────┘  └─────────────────┘  └─────────────────────────────┘  │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────────────────┐  │
│  │   渲染表现层     │  │   音频反馈层     │  │        数据持久化层          │  │
│  │  ┌───────────┐  │  │  ┌───────────┐  │  │  ┌─────────────────────┐   │  │
│  │  │3D场景渲染 │  │  │  │击球音效   │  │  │  │设置/高分/回放数据   │   │  │
│  │  │Shader特效 │  │  │  │触觉反馈   │  │  │  └─────────────────────┘   │  │
│  │  └───────────┘  │  │  └───────────┘  │  └─────────────────────────────┘  │
│  └─────────────────┘  └─────────────────┘                                   │
└─────────────────────────────────────────────────────────────────────────────┘
                                       │
                                       │ UDP (60fps, 28字节/帧)
                                       ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                              手机端 (传感器)                                 │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐    │
│  │ 线性加速度计  │  │   陀螺仪      │  │  磁力计(可选) │  │  振动马达     │    │
│  │ (m/s²)       │  │ (rad/s)      │  │              │  │              │    │
│  └──────────────┘  └──────────────┘  └──────────────┘  └──────────────┘    │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 1.2 传感器数据格式

| 字段 | 类型 | 字节范围 | 说明 |
|------|------|----------|------|
| accel_x | float32 | 0-3 | 线性加速度X (m/s²) |
| accel_y | float32 | 4-7 | 线性加速度Y (m/s²) |
| accel_z | float32 | 8-11 | 线性加速度Z (m/s²) |
| quat_x | float32 | 12-15 | 四元数X分量 |
| quat_y | float32 | 16-19 | 四元数Y分量 |
| quat_z | float32 | 20-23 | 四元数Z分量 |
| quat_w | float32 | 24-27 | 四元数W分量 |

**总包大小**: 28字节
**更新频率**: 约60fps (16.67ms/帧)

---

## 2. 传感器数据映射算法

### 2.1 核心挑战分析

传感器数据映射是本项目的技术核心，面临以下挑战：

1. **加速度积分漂移**: 双重积分误差累积导致位置估算失效
2. **坐标系转换**: Android传感器坐标系与Godot坐标系的映射
3. **击球检测**: 从噪声数据中准确识别击球动作
4. **延迟补偿**: 网络传输与渲染的时序同步

### 2.2 弹性回中位置算法

由于纯积分会导致严重漂移，我们采用**弹性回中(Elastic Return-to-Center)**算法：

```gdscript
# 核心参数
@export var friction: float = 5.0           # 速度衰减系数
@export var return_speed: float = 2.0       # 回中速度
@export var max_displacement: float = 5.0   # 最大位移限制

# 状态变量
var velocity := Vector3.ZERO                # 当前速度
var phone_position := Vector3.ZERO          # 当前位置
var origin_position := Vector3.ZERO         # 中心点位置

func _update_phone_position(delta: float):
    # 1. 转换加速度到Godot坐标系
    var godot_accel = convert_vector_to_godot(user_accel_data)

    # 2. 速度积分 (v = v0 + a*t)
    velocity += godot_accel * delta

    # 3. 高阻力衰减 (模拟空气阻力/手部阻尼)
    velocity = velocity.lerp(Vector3.ZERO, friction * delta)

    # 4. 位置积分 (p = p0 + v*t)
    phone_position += velocity * delta

    # 5. 弹性回中 (模拟弹簧恢复力)
    phone_position = phone_position.lerp(origin_position, return_speed * delta)

    # 6. 限制最大位移范围
    phone_position.x = clamp(phone_position.x, -max_displacement, max_displacement)
    phone_position.y = clamp(phone_position.y, 0.0, max_displacement)
    phone_position.z = clamp(phone_position.z, -max_displacement, max_displacement)
```

**算法原理**:
- 速度积分获取瞬时运动趋势
- 高摩擦系数快速衰减速度，防止漂移
- 弹性回中力确保球拍始终趋向中心位置
- 物理上模拟了"手持球拍"的体感

### 2.3 四元数到球拍旋转的转换

#### 2.3.1 坐标系映射

```gdscript
# Android传感器坐标系 -> Godot坐标系
# Android: X向右, Y向上, Z向外(屏幕方向)
# Godot: X向右, Y向上, Z向内(屏幕方向)

func convert_quaternion_to_godot(q: Quaternion) -> Quaternion:
    """将Android坐标系的四元数转换为Godot坐标系"""
    # 直连映射，根据实际校准结果可能需要调整符号
    return Quaternion(q.x, q.y, q.z, q.w).normalized()

func convert_vector_to_godot(v: Vector3) -> Vector3:
    """将Android坐标系的向量转换为Godot坐标系"""
    return Vector3(v.x, v.y, v.z)
```

#### 2.3.2 姿态校准系统

```gdscript
class_name PaddleCalibration
extends Node

# 校准数据存储
var calibration_offset := Quaternion.IDENTITY
var calibration_matrix: Basis = Basis.IDENTITY
var use_calibration_matrix := false

# 校准流程状态
var is_calibrating := false
var calibration_step := 0
var calibration_data: Array[Dictionary] = []

# 校准步骤定义
const CALIBRATION_POSES = [
    "标准平放",      # 手机平放桌面，屏幕向上
    "向右旋转",      # 手机向右旋转90度
    "向左旋转",      # 手机向左旋转90度
    "竖直握持",      # 竖直握持，屏幕朝前
]

func start_calibration():
    """启动校准流程"""
    is_calibrating = true
    calibration_step = 0
    calibration_data.clear()
    # 显示UI提示用户执行校准姿势

func record_calibration_sample(raw_quaternion: Quaternion, accel: Vector3):
    """记录当前校准样本"""
    calibration_data.append({
        "step": calibration_step,
        "pose_name": CALIBRATION_POSES[calibration_step],
        "raw_quaternion": {"x": raw_quaternion.x, "y": raw_quaternion.y,
                          "z": raw_quaternion.z, "w": raw_quaternion.w},
        "user_accel": {"x": accel.x, "y": accel.y, "z": accel.z}
    })

    calibration_step += 1
    if calibration_step >= CALIBRATION_POSES.size():
        finish_calibration()

func finish_calibration():
    """完成校准并计算偏移"""
    is_calibrating = false

    # 计算校准偏移：将第一个姿态设为基准
    if calibration_data.size() > 0:
        var first_sample = calibration_data[0]
        var q = first_sample["raw_quaternion"]
        var base_quat = Quaternion(q["x"], q["y"], q["z"], q["w"])
        calibration_offset = base_quat.inverse()

    save_calibration_data()

func apply_calibration(raw_rotation: Quaternion) -> Quaternion:
    """应用校准到原始旋转"""
    return calibration_offset * raw_rotation
```

### 2.4 挥拍速度检测算法

挥拍速度是击球力度的关键指标，采用多维度检测：

```gdscript
class_name SwingDetector
extends Node

# 检测参数
@export var velocity_threshold: float = 3.0      # 最小挥拍速度 (m/s)
@export var accel_threshold: float = 15.0        # 加速度阈值 (m/s²)
@export var swing_cooldown: float = 0.3          # 挥拍冷却时间 (秒)
@export var direction_change_threshold: float = 0.7  # 方向变化阈值

# 状态
var swing_history: Array[Dictionary] = []        # 挥拍历史
var last_swing_time: float = 0.0
var is_in_swing := false

# 滑动窗口数据
var accel_window: Array[Vector3] = []
var velocity_window: Array[Vector3] = []
const WINDOW_SIZE := 10

func update(current_accel: Vector3, current_velocity: Vector3, delta: float):
    # 维护滑动窗口
    accel_window.append(current_accel)
    velocity_window.append(current_velocity)
    if accel_window.size() > WINDOW_SIZE:
        accel_window.pop_front()
        velocity_window.pop_front()

    # 检测挥拍动作
    detect_swing(delta)

func detect_swing(delta: float):
    var current_time = Time.get_unix_time_from_system()

    # 冷却检查
    if current_time - last_swing_time < swing_cooldown:
        return

    # 计算窗口统计
    var avg_accel = calculate_average(accel_window)
    var avg_velocity = calculate_average(velocity_window)
    var accel_magnitude = avg_accel.length()
    var velocity_magnitude = avg_velocity.length()

    # 挥拍检测逻辑
    if not is_in_swing:
        # 进入挥拍：高加速度 + 明显速度
        if accel_magnitude > accel_threshold and velocity_magnitude > velocity_threshold:
            is_in_swing = true
            on_swing_start(avg_velocity, accel_magnitude)
    else:
        # 退出挥拍：速度衰减或方向反转
        var velocity_change = calculate_velocity_change()
        if velocity_magnitude < velocity_threshold * 0.5 or velocity_change > direction_change_threshold:
            is_in_swing = false
            on_swing_end(avg_velocity, accel_magnitude)
            last_swing_time = current_time

func on_swing_start(velocity: Vector3, accel_mag: float):
    """挥拍开始回调"""
    emit_signal("swing_started", velocity, accel_mag)

func on_swing_end(velocity: Vector3, accel_mag: float):
    """挥拍结束回调 - 可能产生击球"""
    var swing_power = calculate_swing_power(velocity, accel_mag)
    emit_signal("swing_ended", velocity, swing_power)

func calculate_swing_power(velocity: Vector3, accel_mag: float) -> float:
    """计算挥拍力度 (0-1范围)"""
    var velocity_factor = clamp(velocity.length() / 10.0, 0.0, 1.0)
    var accel_factor = clamp(accel_mag / 30.0, 0.0, 1.0)
    # 加权平均，速度权重更高
    return velocity_factor * 0.7 + accel_factor * 0.3
```

### 2.5 击球时机判定算法

击球判定结合空间碰撞和时间窗口：

```gdscript
class_name HitDetector
extends Node

# 击球区域定义
@export var paddle_hit_box: Area3D
@export var hit_sphere_radius: float = 0.15  # 击球范围半径 (米)

# 击球判定参数
@export var pre_hit_window: float = 0.1      # 提前判定窗口 (秒)
@export var post_hit_window: float = 0.05    # 延后判定窗口 (秒)
@export var min_approach_velocity: float = 1.0  # 最小接近速度

# 状态
var ball: Ball                              # 球引用
var pending_hit: Dictionary = {}            # 待处理击球
var hit_cooldown: float = 0.0

func _physics_process(delta: float):
    if ball == null:
        return

    # 更新冷却
    if hit_cooldown > 0:
        hit_cooldown -= delta
        return

    # 检查球是否在击球范围内
    var ball_pos = ball.global_position
    var paddle_pos = paddle_hit_box.global_position
    var distance = ball_pos.distance_to(paddle_pos)

    if distance <= hit_sphere_radius:
        # 预测球与球拍的相对运动
        var relative_velocity = ball.velocity - paddle_velocity
        var to_paddle = (paddle_pos - ball_pos).normalized()
        var approach_speed = relative_velocity.dot(to_paddle)

        # 判定条件：球正在接近且速度足够
        if approach_speed > min_approach_velocity:
            evaluate_hit_opportunity(ball_pos, paddle_pos, relative_velocity)

func evaluate_hit_opportunity(ball_pos: Vector3, paddle_pos: Vector3, relative_vel: Vector3):
    """评估击球机会"""
    var distance = ball_pos.distance_to(paddle_pos)
    var time_to_impact = distance / relative_vel.length()

    # 时间窗口判定
    if time_to_impact <= pre_hit_window and time_to_impact >= -post_hit_window:
        # 检查是否有挥拍动作
        var swing_data = get_swing_detector().get_current_swing()
        if swing_data.is_active and swing_data.power > 0.3:
            execute_hit(ball, swing_data)

func execute_hit(ball: Ball, swing_data: Dictionary):
    """执行击球"""
    hit_cooldown = 0.2  # 防止连击

    # 计算击球参数
    var hit_direction = calculate_hit_direction(swing_data)
    var hit_force = calculate_hit_force(swing_data)
    var spin = calculate_spin(swing_data)

    # 应用到球
    ball.on_paddle_hit(hit_direction, hit_force, spin, paddle_velocity)

    # 触发效果
    emit_signal("ball_hit", hit_direction, hit_force)
    trigger_hit_effects()

func calculate_hit_direction(swing_data: Dictionary) -> Vector3:
    """计算击球方向"""
    # 基于球拍朝向和挥拍方向
    var paddle_forward = -paddle_hit_box.global_transform.basis.z
    var swing_direction = swing_data.velocity.normalized()

    # 混合球拍朝向和挥拍方向
    var final_direction = paddle_forward.lerp(swing_direction, 0.3).normalized()

    # 添加上升角度 (确保球过网)
    final_direction.y = max(final_direction.y, 0.2)

    return final_direction.normalized()

func calculate_hit_force(swing_data: Dictionary) -> float:
    """计算击球力度"""
    var base_force = 10.0  # 基础力度
    var power_multiplier = 1.0 + swing_data.power * 2.0  # 1.0 - 3.0倍
    return base_force * power_multiplier

func calculate_spin(swing_data: Dictionary) -> Vector3:
    """计算旋转 (马格努斯效应)"""
    # 基于挥拍切向分量计算旋转轴
    var paddle_normal = -paddle_hit_box.global_transform.basis.z
    var tangent_component = swing_data.velocity - paddle_normal * swing_data.velocity.dot(paddle_normal)

    # 旋转轴垂直于切向和法向
    var spin_axis = tangent_component.cross(paddle_normal).normalized()
    var spin_magnitude = tangent_component.length() * 0.5

    return spin_axis * spin_magnitude
```

### 2.6 传感器数据融合与滤波

```gdscript
class_name SensorFusion
extends Node

# 滤波器参数
@export var accel_low_pass_alpha: float = 0.3   # 加速度低通系数
@export var velocity_smooth_factor: float = 0.2 # 速度平滑系数

# 状态
var filtered_accel := Vector3.ZERO
var smoothed_velocity := Vector3.ZERO
var last_raw_accel := Vector3.ZERO

# 异常检测
var spike_threshold: float = 50.0               # 尖峰阈值
var consecutive_spikes: int = 0
const MAX_CONSECUTIVE_SPIKES = 3

func process_sensor_data(raw_accel: Vector3, raw_quat: Quaternion, delta: float) -> Dictionary:
    # 1. 异常值检测与处理
    var accel_delta = (raw_accel - last_raw_accel).length()
    if accel_delta > spike_threshold:
        consecutive_spikes += 1
        if consecutive_spikes > MAX_CONSECUTIVE_SPIKES:
            # 重置滤波器
            filtered_accel = raw_accel
            consecutive_spikes = 0
        else:
            # 忽略本次异常值
            raw_accel = filtered_accel
    else:
        consecutive_spikes = 0

    last_raw_accel = raw_accel

    # 2. 低通滤波 (去除高频噪声)
    filtered_accel = filtered_accel.lerp(raw_accel, accel_low_pass_alpha)

    # 3. 速度积分与平滑
    var raw_velocity = smoothed_velocity + filtered_accel * delta
    smoothed_velocity = smoothed_velocity.lerp(raw_velocity, velocity_smooth_factor)

    # 4. 四元数归一化与平滑
    var normalized_quat = raw_quat.normalized()

    return {
        "acceleration": filtered_accel,
        "velocity": smoothed_velocity,
        "rotation": normalized_quat
    }
```

---

## 3. 乒乓球物理系统

### 3.1 球体运动模型

```gdscript
class_name Ball
extends RigidBody3D

# 物理参数
@export var base_mass: float = 0.0027          # 乒乓球质量 (2.7g)
@export var ball_radius: float = 0.02          # 球半径 (20mm)
@export var drag_coefficient: float = 0.47     # 空气阻力系数
@export var air_density: float = 1.225         # 空气密度 (kg/m³)
@export var gravity: float = 9.81              # 重力加速度

# 旋转物理参数
@export var magnus_coefficient: float = 0.25   # 马格努斯效应系数
@export var spin_decay_rate: float = 0.98      # 旋转衰减率

# 状态
var current_velocity := Vector3.ZERO
var current_spin := Vector3.ZERO               # 旋转角速度 (rad/s)
var is_active := false

func _physics_process(delta: float):
    if not is_active:
        return

    # 1. 应用重力
    var gravity_force = Vector3.DOWN * gravity * base_mass

    # 2. 计算空气阻力
    var speed = current_velocity.length()
    var drag_force_magnitude = 0.5 * air_density * speed * speed * drag_coefficient * PI * ball_radius * ball_radius
    var drag_force = -current_velocity.normalized() * drag_force_magnitude

    # 3. 计算马格努斯力 (旋转效应)
    var magnus_force = calculate_magnus_force()

    # 4. 合力计算
    var total_force = gravity_force + drag_force + magnus_force
    var acceleration = total_force / base_mass

    # 5. 速度更新
    current_velocity += acceleration * delta

    # 6. 旋转衰减
    current_spin *= spin_decay_rate

    # 7. 位置更新
    move_and_collide(current_velocity * delta)

func calculate_magnus_force() -> Vector3:
    """计算马格努斯力 (升力/侧向力)"""
    if current_spin.length() < 0.1:
        return Vector3.ZERO

    # F_magnus = S * (ω × v)
    # S为马格努斯系数，ω为旋转角速度，v为线速度
    var cross_product = current_spin.cross(current_velocity)
    return cross_product * magnus_coefficient * air_density * ball_radius * ball_radius * ball_radius

func on_paddle_hit(hit_direction: Vector3, hit_force: float, spin: Vector3, paddle_velocity: Vector3):
    """处理球拍击球"""
    # 计算击球后的速度
    var impulse = hit_direction * hit_force / base_mass

    # 添加球拍速度传递 (动量传递)
    var velocity_transfer = paddle_velocity * 0.3  # 30%速度传递

    current_velocity = impulse + velocity_transfer
    current_spin = spin

    # 触发击球效果
    emit_signal("paddle_hit", global_position, current_velocity.length())

func on_table_bounce(bounce_point: Vector3, surface_normal: Vector3):
    """处理球台反弹"""
    # 速度分解为法向和切向
    var normal_component = surface_normal * current_velocity.dot(surface_normal)
    var tangent_component = current_velocity - normal_component

    # 法向反弹 (带能量损失)
    var restitution = 0.85  # 恢复系数
    var new_normal = -normal_component * restitution

    # 切向摩擦 (旋转与表面交互)
    var friction_coefficient = 0.3
    var spin_effect = current_spin.cross(surface_normal) * ball_radius
    var new_tangent = (tangent_component + spin_effect) * (1.0 - friction_coefficient)

    # 更新旋转 (摩擦导致旋转变化)
    current_spin -= tangent_component.cross(surface_normal) * friction_coefficient / ball_radius

    # 合成新速度
    current_velocity = new_normal + new_tangent

    emit_signal("table_bounce", bounce_point, current_velocity.length())
```

### 3.2 碰撞检测系统

```gdscript
class_name CollisionManager
extends Node3D

# 碰撞层定义
enum CollisionLayer {
    BALL = 1,
    PADDLE = 2,
    TABLE = 4,
    NET = 8,
    WALL = 16
}

# 场景对象引用
@onready var ball: Ball
@onready var player_paddle: Paddle
@onready var ai_paddle: Paddle
@onready var table: Table
@onready var net: Net

# 碰撞检测参数
@export var continuous_collision_steps: int = 4  # 连续碰撞检测步数

func _physics_process(delta: float):
    if ball == null:
        return

    # 连续碰撞检测 (防止高速穿模)
    var step_delta = delta / continuous_collision_steps

    for i in range(continuous_collision_steps):
        check_paddle_collision()
        check_table_collision()
        check_net_collision()
        check_boundary_collision()

        # 子步进位置更新
        ball.move_and_collide(ball.current_velocity * step_delta)

func check_paddle_collision():
    """检测球与球拍碰撞"""
    var ball_pos = ball.global_position

    # 玩家球拍
    if player_paddle.is_active:
        var distance = ball_pos.distance_to(player_paddle.hit_point)
        if distance <= (ball.ball_radius + player_paddle.hit_radius):
            var hit_normal = (ball_pos - player_paddle.hit_point).normalized()
            player_paddle.on_ball_contact(ball, hit_normal)

    # AI球拍
    if ai_paddle.is_active:
        var distance = ball_pos.distance_to(ai_paddle.hit_point)
        if distance <= (ball.ball_radius + ai_paddle.hit_radius):
            var hit_normal = (ball_pos - ai_paddle.hit_point).normalized()
            ai_paddle.on_ball_contact(ball, hit_normal)

func check_table_collision():
    """检测球与球台碰撞"""
    var ball_pos = ball.global_position

    # 检查是否在球台范围内
    if table.is_point_on_table(ball_pos):
        # 检查高度 (球台表面高度)
        var table_height = table.surface_height
        var ball_bottom = ball_pos.y - ball.ball_radius

        if ball_bottom <= table_height and ball.current_velocity.y < 0:
            # 反弹处理
            var bounce_point = Vector3(ball_pos.x, table_height, ball_pos.z)
            ball.on_table_bounce(bounce_point, Vector3.UP)

            # 判定发球/回球有效性
            evaluate_rally_validity(bounce_point)

func check_net_collision():
    """检测球与球网碰撞"""
    var ball_pos = ball.global_position

    if net.is_point_near_net(ball_pos):
        var distance_to_net = net.get_distance_to_net(ball_pos)

        if distance_to_net <= ball.ball_radius:
            # 球网碰撞处理 (弹性碰撞，能量损失大)
            var net_normal = net.get_collision_normal(ball_pos)
            ball.current_velocity = ball.current_velocity.bounce(net_normal) * 0.3
            emit_signal("net_collision", ball_pos)

func check_boundary_collision():
    """检测边界碰撞 (地面、墙壁等)"""
    var ball_pos = ball.global_position

    # 地面检测 (出界)
    if ball_pos.y < -0.5:
        on_ball_out_of_bounds()

    # 墙壁检测
    if abs(ball_pos.x) > 10.0 or abs(ball_pos.z) > 15.0:
        on_ball_out_of_bounds()

func evaluate_rally_validity(bounce_point: Vector3):
    """评估回球有效性"""
    var game_manager = get_node("/root/GameManager")
    game_manager.register_bounce(bounce_point)
```

### 3.3 物理参数调节接口

```gdscript
class_name PhysicsConfig
extends Resource

# 球体物理
@export_group("Ball Physics")
@export var ball_mass: float = 0.0027
@export var ball_radius: float = 0.02
@export var gravity_scale: float = 1.0
@export var air_resistance: float = 0.47

# 反弹系数
@export_group("Restitution")
@export var paddle_restitution: float = 0.9      # 球拍弹性
@export var table_restitution: float = 0.85      # 球台弹性
@export var net_restitution: float = 0.1         # 球网弹性

# 摩擦系数
@export_group("Friction")
@export var paddle_friction: float = 0.4
@export var table_friction: float = 0.3
@export var air_spin_decay: float = 0.98

# 游戏性调节
@export_group("Gameplay")
@export var min_hit_speed: float = 2.0           # 最小击球速度
@export var max_hit_speed: float = 25.0          # 最大击球速度
@export var spin_effect_multiplier: float = 1.0  # 旋转效果倍率

func apply_to_ball(ball: Ball):
    """应用配置到球体"""
    ball.base_mass = ball_mass
    ball.ball_radius = ball_radius
    ball.drag_coefficient = air_resistance
    ball.spin_decay_rate = air_spin_decay

func apply_to_paddle(paddle: Paddle):
    """应用配置到球拍"""
    paddle.restitution = paddle_restitution
    paddle.friction = paddle_friction
```

---

## 4. 游戏状态管理架构

### 4.1 游戏状态机设计

```gdscript
class_name GameStateMachine
extends Node

# 状态定义
enum State {
    BOOT,           # 启动中
    MAIN_MENU,      # 主菜单
    PAIRING,        # 设备配对
    CALIBRATION,    # 传感器校准
    MATCH_SETUP,    # 比赛设置
    SERVING,        # 发球准备
    PLAYING,        # 游戏进行中
    PAUSED,         # 暂停
    POINT_END,      # 回合结束
    MATCH_END,      # 比赛结束
    REPLAY          # 回放
}

# 当前状态
var current_state: State = State.BOOT
var previous_state: State = State.BOOT

# 状态处理器
var state_handlers: Dictionary = {}

# 信号
signal state_entered(state: State)
signal state_exited(state: State)
signal state_changed(from: State, to: State)

func _ready():
    register_state_handlers()
    transition_to(State.MAIN_MENU)

func register_state_handlers():
    """注册各状态的处理逻辑"""
    state_handlers[State.MAIN_MENU] = MainMenuState.new(self)
    state_handlers[State.PAIRING] = PairingState.new(self)
    state_handlers[State.CALIBRATION] = CalibrationState.new(self)
    state_handlers[State.MATCH_SETUP] = MatchSetupState.new(self)
    state_handlers[State.SERVING] = ServingState.new(self)
    state_handlers[State.PLAYING] = PlayingState.new(self)
    state_handlers[State.PAUSED] = PausedState.new(self)
    state_handlers[State.POINT_END] = PointEndState.new(self)
    state_handlers[State.MATCH_END] = MatchEndState.new(self)

func transition_to(new_state: State, data: Dictionary = {}):
    """状态转换"""
    if new_state == current_state:
        return

    # 退出当前状态
    if state_handlers.has(current_state):
        state_handlers[current_state].exit()
    emit_signal("state_exited", current_state)

    # 记录历史
    previous_state = current_state
    current_state = new_state

    # 进入新状态
    emit_signal("state_entered", current_state)
    emit_signal("state_changed", previous_state, current_state)

    if state_handlers.has(current_state):
        state_handlers[current_state].enter(data)

func _process(delta: float):
    if state_handlers.has(current_state):
        state_handlers[current_state].update(delta)

func can_transition(from: State, to: State) -> bool:
    """检查状态转换是否合法"""
    var valid_transitions = {
        State.BOOT: [State.MAIN_MENU],
        State.MAIN_MENU: [State.PAIRING, State.CALIBRATION, State.MATCH_SETUP],
        State.PAIRING: [State.MAIN_MENU, State.CALIBRATION],
        State.CALIBRATION: [State.MAIN_MENU, State.MATCH_SETUP],
        State.MATCH_SETUP: [State.MAIN_MENU, State.SERVING],
        State.SERVING: [State.PLAYING],
        State.PLAYING: [State.PAUSED, State.POINT_END],
        State.PAUSED: [State.PLAYING, State.MAIN_MENU],
        State.POINT_END: [State.SERVING, State.MATCH_END],
        State.MATCH_END: [State.MAIN_MENU, State.MATCH_SETUP],
    }

    if valid_transitions.has(from):
        return to in valid_transitions[from]
    return false

# 具体状态实现示例
class PlayingState:
    extends StateHandler

    var ball: Ball
    var player_paddle: Paddle
    var ai_paddle: Paddle
    var score_manager: ScoreManager

    func enter(data: Dictionary):
        ball.resume()
        player_paddle.enable_control()
        ai_paddle.enable_control()

    func exit():
        player_paddle.disable_control()
        ai_paddle.disable_control()

    func update(delta: float):
        # 检查得分条件
        if ball.is_out_of_bounds():
            var scorer = determine_scorer()
            score_manager.add_point(scorer)
            state_machine.transition_to(State.POINT_END, {"scorer": scorer})

        # 检查回合超时
        if get_rally_duration() > 30.0:  # 30秒回合限制
            state_machine.transition_to(State.POINT_END, {"scorer": "none", "reason": "timeout"})
```

### 4.2 场景管理方案

```gdscript
class_name SceneManager
extends Node

# 场景路径配置
const SCENES = {
    "boot": "res://scenes/boot.tscn",
    "main_menu": "res://scenes/main_menu.tscn",
    "pairing": "res://scenes/pairing.tscn",
    "calibration": "res://scenes/calibration.tscn",
    "game": "res://scenes/game.tscn",
    "match_end": "res://scenes/match_end.tscn"
}

# 场景栈 (用于返回导航)
var scene_stack: Array[String] = []

# 当前场景
var current_scene: Node = null
var current_scene_name: String = ""

# 过渡效果
@export var transition_duration: float = 0.5
var is_transitioning := false

func switch_to(scene_name: String, push_to_stack: bool = true, transition_data: Dictionary = {}):
    """切换到指定场景"""
    if is_transitioning or not SCENES.has(scene_name):
        return

    is_transitioning = true

    if push_to_stack and current_scene_name != "":
        scene_stack.append(current_scene_name)

    # 播放退出过渡动画
    await play_transition_out()

    # 卸载当前场景
    if current_scene:
        current_scene.queue_free()
        current_scene = null

    # 加载新场景
    var scene_path = SCENES[scene_name]
    var scene_resource = load(scene_path)

    if scene_resource:
        current_scene = scene_resource.instantiate()
        get_tree().root.add_child(current_scene)
        current_scene_name = scene_name

        # 传递过渡数据
        if current_scene.has_method("on_scene_enter"):
            current_scene.on_scene_enter(transition_data)

    # 播放进入过渡动画
    await play_transition_in()
    is_transitioning = false

func go_back():
    """返回上一个场景"""
    if scene_stack.size() > 0:
        var previous_scene = scene_stack.pop_back()
        switch_to(previous_scene, false)

func play_transition_out() -> Signal:
    """播放场景退出过渡"""
    var tween = create_tween()
    var overlay = get_transition_overlay()
    overlay.modulate = Color.TRANSPARENT
    tween.tween_property(overlay, "modulate", Color.BLACK, transition_duration / 2)
    return tween.finished

func play_transition_in() -> Signal:
    """播放场景进入过渡"""
    var tween = create_tween()
    var overlay = get_transition_overlay()
    tween.tween_property(overlay, "modulate", Color.TRANSPARENT, transition_duration / 2)
    return tween.finished
```

### 4.3 数据持久化系统

```gdscript
class_name DataPersistence
extends Node

const SAVE_DIR = "user://saves/"
const SETTINGS_FILE = "user://settings.json"
const HIGH_SCORE_FILE = "user://high_scores.json"
const REPLAY_DIR = "user://replays/"

# 设置数据结构
class GameSettings:
    var master_volume: float = 1.0
    var sfx_volume: float = 1.0
    var music_volume: float = 0.8
    var sensitivity: float = 1.0
    var difficulty: int = 1  # 0=简单, 1=普通, 2=困难
    var calibration_data: Dictionary = {}
    var display_resolution: Vector2i = Vector2i(1920, 1080)
    var fullscreen: bool = true

# 高分记录
class HighScoreEntry:
    var player_name: String
    var score: int
    var date: String
    var duration: float  # 比赛时长
    var difficulty: int

func _ready():
    ensure_directories()

func ensure_directories():
    """确保保存目录存在"""
    var dir = DirAccess.open("user://")
    if not dir.dir_exists("saves"):
        dir.make_dir("saves")
    if not dir.dir_exists("replays"):
        dir.make_dir("replays")

func save_settings(settings: GameSettings) -> bool:
    """保存游戏设置"""
    var data = {
        "master_volume": settings.master_volume,
        "sfx_volume": settings.sfx_volume,
        "music_volume": settings.music_volume,
        "sensitivity": settings.sensitivity,
        "difficulty": settings.difficulty,
        "calibration_data": settings.calibration_data,
        "display_resolution": [settings.display_resolution.x, settings.display_resolution.y],
        "fullscreen": settings.fullscreen
    }

    var file = FileAccess.open(SETTINGS_FILE, FileAccess.WRITE)
    if file:
        file.store_string(JSON.stringify(data, "\t"))
        file.close()
        return true
    return false

func load_settings() -> GameSettings:
    """加载游戏设置"""
    var settings = GameSettings.new()

    if FileAccess.file_exists(SETTINGS_FILE):
        var file = FileAccess.open(SETTINGS_FILE, FileAccess.READ)
        if file:
            var json = JSON.new()
            var err = json.parse(file.get_as_text())
            file.close()

            if err == OK:
                var data = json.get_data()
                settings.master_volume = data.get("master_volume", 1.0)
                settings.sfx_volume = data.get("sfx_volume", 1.0)
                settings.music_volume = data.get("music_volume", 0.8)
                settings.sensitivity = data.get("sensitivity", 1.0)
                settings.difficulty = data.get("difficulty", 1)
                settings.calibration_data = data.get("calibration_data", {})
                var res = data.get("display_resolution", [1920, 1080])
                settings.display_resolution = Vector2i(res[0], res[1])
                settings.fullscreen = data.get("fullscreen", true)

    return settings

func save_high_score(entry: HighScoreEntry) -> bool:
    """保存高分记录"""
    var scores = load_high_scores()
    scores.append({
        "player_name": entry.player_name,
        "score": entry.score,
        "date": entry.date,
        "duration": entry.duration,
        "difficulty": entry.difficulty
    })

    # 排序并保留前10
    scores.sort_custom(func(a, b): return a["score"] > b["score"])
    if scores.size() > 10:
        scores.resize(10)

    var file = FileAccess.open(HIGH_SCORE_FILE, FileAccess.WRITE)
    if file:
        file.store_string(JSON.stringify({"scores": scores}, "\t"))
        file.close()
        return true
    return false

func load_high_scores() -> Array:
    """加载高分列表"""
    if FileAccess.file_exists(HIGH_SCORE_FILE):
        var file = FileAccess.open(HIGH_SCORE_FILE, FileAccess.READ)
        if file:
            var json = JSON.new()
            var err = json.parse(file.get_as_text())
            file.close()

            if err == OK:
                var data = json.get_data()
                return data.get("scores", [])
    return []

func save_replay(match_data: Dictionary) -> String:
    """保存比赛回放"""
    var datetime = Time.get_datetime_dict_from_system()
    var filename = "replay_%04d%02d%02d_%02d%02d%02d.json" % [
        datetime.year, datetime.month, datetime.day,
        datetime.hour, datetime.minute, datetime.second
    ]
    var filepath = REPLAY_DIR + filename

    var file = FileAccess.open(filepath, FileAccess.WRITE)
    if file:
        file.store_string(JSON.stringify(match_data, "\t"))
        file.close()
        return filepath
    return ""
```

---

## 5. AI算法方案

### 5.1 AI球拍控制逻辑

```gdscript
class_name AIPaddleController
extends Node

# AI难度参数
enum Difficulty {
    EASY,       # 简单 - 反应慢，失误多
    NORMAL,     # 普通 - 平衡
    HARD,       # 困难 - 反应快，精准
    EXPERT      # 专家 - 几乎完美
}

@export var difficulty: Difficulty = Difficulty.NORMAL

# AI状态
enum AIState {
    IDLE,           # 等待
    TRACKING,       # 追踪球
    PREPARING,      # 准备击球
    SWINGING,       # 挥拍中
    RECOVERING      # 恢复位置
}

var current_state: AIState = AIState.IDLE
var paddle: Paddle
var ball: Ball

# 难度参数表 (根据难度调整)
var difficulty_params = {
    Difficulty.EASY: {
        "reaction_delay": 0.3,      # 反应延迟 (秒)
        "position_error": 0.3,      # 位置误差 (米)
        "speed_multiplier": 0.7,    # 移动速度倍率
        "prediction_accuracy": 0.6, # 预测准确度
        "swing_timing_error": 0.1   # 挥拍时机误差
    },
    Difficulty.NORMAL: {
        "reaction_delay": 0.15,
        "position_error": 0.15,
        "speed_multiplier": 0.9,
        "prediction_accuracy": 0.8,
        "swing_timing_error": 0.05
    },
    Difficulty.HARD: {
        "reaction_delay": 0.05,
        "position_error": 0.08,
        "speed_multiplier": 1.1,
        "prediction_accuracy": 0.95,
        "swing_timing_error": 0.02
    },
    Difficulty.EXPERT: {
        "reaction_delay": 0.0,
        "position_error": 0.03,
        "speed_multiplier": 1.3,
        "prediction_accuracy": 0.99,
        "swing_timing_error": 0.0
    }
}

# 战术参数
var preferred_hit_position: Vector3 = Vector3(0, 0.8, -1.5)  # 偏好的击球点
var defensive_position: Vector3 = Vector3(0, 0.8, -2.0)      # 防守位置

func _physics_process(delta: float):
    if ball == null or paddle == null:
        return

    match current_state:
        AIState.IDLE:
            update_idle_state(delta)
        AIState.TRACKING:
            update_tracking_state(delta)
        AIState.PREPARING:
            update_preparing_state(delta)
        AIState.SWINGING:
            update_swinging_state(delta)
        AIState.RECOVERING:
            update_recovering_state(delta)

func update_tracking_state(delta: float):
    """追踪状态 - 预测球路并移动"""
    var params = difficulty_params[difficulty]

    # 预测球到达AI侧的位置
    var predicted_impact = predict_ball_impact()

    # 添加误差 (模拟不完美)
    var error = Vector3(
        randf_range(-params["position_error"], params["position_error"]),
        randf_range(-params["position_error"] * 0.5, params["position_error"] * 0.5),
        0
    )
    predicted_impact += error

    # 计算目标位置
    var target_position = calculate_optimal_position(predicted_impact)

    # 移动球拍
    move_paddle_to(target_position, params["speed_multiplier"], delta)

    # 检查是否进入准备状态
    var distance_to_target = paddle.global_position.distance_to(target_position)
    var time_to_impact = get_time_to_impact()

    if distance_to_target < 0.3 and time_to_impact < 0.5:
        transition_to_state(AIState.PREPARING)

func update_preparing_state(delta: float):
    """准备状态 - 微调位置并准备挥拍"""
    var params = difficulty_params[difficulty]
    var predicted_impact = predict_ball_impact()

    # 精细调整
    move_paddle_to(predicted_impact, params["speed_multiplier"] * 0.5, delta)

    # 判断挥拍时机
    var time_to_impact = get_time_to_impact()
    var timing_error = randf_range(-params["swing_timing_error"], params["swing_timing_error"])

    if time_to_impact + timing_error <= 0:
        execute_swing()
        transition_to_state(AIState.SWINGING)

func execute_swing():
    """执行挥拍"""
    var params = difficulty_params[difficulty]

    # 计算击球目标 (基于战术)
    var target_point = select_target_point()

    # 计算需要的球速和方向
    var ball_direction = (target_point - ball.global_position).normalized()
    var hit_power = calculate_hit_power()

    # 添加旋转 (根据难度)
    var spin = calculate_intended_spin()

    # 执行击球
    paddle.execute_ai_swing(ball_direction, hit_power, spin)

func predict_ball_impact() -> Vector3:
    """预测球到达AI侧的撞击点"""
    var ball_pos = ball.global_position
    var ball_vel = ball.current_velocity
    var ai_z = paddle.global_position.z

    # 简单线性预测
    if ball_vel.z == 0:
        return ball_pos

    var time_to_reach = (ai_z - ball_pos.z) / ball_vel.z

    if time_to_reach < 0:
        return defensive_position  # 球正在远离

    # 考虑重力和空气阻力进行迭代预测
    var predicted_pos = ball_pos
    var predicted_vel = ball_vel
    var step_time = 0.016  # 16ms步进
    var remaining_time = time_to_reach

    while remaining_time > 0:
        var dt = min(step_time, remaining_time)

        # 应用重力
        predicted_vel.y -= 9.81 * dt

        # 应用空气阻力
        predicted_vel *= (1.0 - 0.01 * dt)

        # 更新位置
        predicted_pos += predicted_vel * dt
        remaining_time -= dt

    return predicted_pos

func select_target_point() -> Vector3:
    """选择击球目标点 (战术决策)"""
    var params = difficulty_params[difficulty]

    # 基于当前局势选择目标
    var player_pos = get_player_position()

    # 尝试打到玩家难以到达的位置
    var target_options = [
        Vector3(1.0, 0.3, 1.5),   # 右侧远角
        Vector3(-1.0, 0.3, 1.5),  # 左侧远角
        Vector3(0.5, 0.1, 1.0),   # 右侧近网
        Vector3(-0.5, 0.1, 1.0),  # 左侧近网
    ]

    # 根据玩家位置选择最难接的位置
    var best_target = target_options[0]
    var max_distance = 0.0

    for target in target_options:
        var distance = target.distance_to(player_pos)
        if distance > max_distance:
            max_distance = distance
            best_target = target

    # 添加随机性 (基于难度)
    var accuracy = params["prediction_accuracy"]
    var random_offset = Vector3(
        randf_range(-0.5, 0.5) * (1.0 - accuracy),
        randf_range(-0.2, 0.2) * (1.0 - accuracy),
        0
    )

    return best_target + random_offset
```

### 5.2 球的轨迹预测算法

```gdscript
class_name BallTrajectoryPredictor
extends Node

# 预测精度设置
@export var prediction_steps: int = 60      # 预测步数
@export var time_step: float = 0.016        # 每步时间 (16ms)

# 预测结果
class TrajectoryPrediction:
    var points: Array[Vector3] = []         # 预测轨迹点
    var velocities: Array[Vector3] = []     # 预测速度
    var bounces: Array[int] = []            # 反弹发生的索引
    var end_reason: String = ""             # 预测结束原因

func predict_trajectory(start_pos: Vector3, start_vel: Vector3,
                        start_spin: Vector3 = Vector3.ZERO) -> TrajectoryPrediction:
    """预测球的完整轨迹"""
    var prediction = TrajectoryPrediction.new()

    var pos = start_pos
    var vel = start_vel
    var spin = start_spin

    prediction.points.append(pos)
    prediction.velocities.append(vel)

    for i in range(prediction_steps):
        # 物理模拟步进
        var result = simulate_step(pos, vel, spin, time_step)
        pos = result.position
        vel = result.velocity
        spin = result.spin

        prediction.points.append(pos)
        prediction.velocities.append(vel)

        # 检测反弹
        if result.bounce_occurred:
            prediction.bounces.append(i)

        # 检测出界
        if is_out_of_bounds(pos):
            prediction.end_reason = "out_of_bounds"
            break

        # 检测到达对方场地
        if vel.z > 0 and pos.z > 1.5 and prediction.bounces.size() == 1:
            prediction.end_reason = "reached_opponent"
            break

    if prediction.end_reason == "":
        prediction.end_reason = "max_steps_reached"

    return prediction

func simulate_step(pos: Vector3, vel: Vector3, spin: Vector3, dt: float) -> Dictionary:
    """单步物理模拟"""
    var new_pos = pos + vel * dt
    var new_vel = vel
    var new_spin = spin
    var bounce_occurred = false

    # 重力
    new_vel.y -= 9.81 * dt

    # 空气阻力
    var speed = new_vel.length()
    var drag = 0.5 * 1.225 * speed * speed * 0.47 * PI * 0.02 * 0.02
    new_vel -= new_vel.normalized() * drag * dt

    # 马格努斯效应
    if spin.length() > 0.1:
        var magnus = spin.cross(vel) * 0.25 * dt
        new_vel += magnus

    # 旋转衰减
    new_spin *= 0.98

    # 球台碰撞检测
    if pos.y > 0.76 and new_pos.y <= 0.76:  # 球台高度0.76m
        if is_on_table(new_pos):
            # 反弹
            new_vel.y = -new_vel.y * 0.85
            new_vel.x *= 0.95
            new_vel.z *= 0.95
            new_pos.y = 0.76 + (0.76 - new_pos.y)
            bounce_occurred = true

    # 地面碰撞
    if new_pos.y < 0:
        new_pos.y = 0
        new_vel.y = -new_vel.y * 0.5

    return {
        "position": new_pos,
        "velocity": new_vel,
        "spin": new_spin,
        "bounce_occurred": bounce_occurred
    }

func get_impact_time_and_position(prediction: TrajectoryPrediction, target_z: float) -> Dictionary:
    """获取球到达指定Z坐标的时间和位置"""
    for i in range(prediction.points.size() - 1):
        var p1 = prediction.points[i]
        var p2 = prediction.points[i + 1]

        if (p1.z <= target_z and p2.z >= target_z) or (p1.z >= target_z and p2.z <= target_z):
            # 线性插值
            var t = (target_z - p1.z) / (p2.z - p1.z)
            var impact_pos = p1.lerp(p2, t)
            var impact_time = i * time_step + t * time_step

            return {
                "found": true,
                "time": impact_time,
                "position": impact_pos,
                "velocity": prediction.velocities[i]
            }

    return {"found": false}
```

### 5.3 难度调节参数

```gdscript
class_name AIDifficultyManager
extends Node

# 动态难度调整参数
@export var enable_dynamic_difficulty: bool = false
@export var score_difficulty_threshold: int = 3  # 分差阈值

# 难度调节接口
func adjust_difficulty_based_on_score(ai_score: int, player_score: int, current_difficulty: int) -> int:
    """基于比分动态调整难度"""
    if not enable_dynamic_difficulty:
        return current_difficulty

    var score_diff = player_score - ai_score

    # 玩家领先太多，降低AI难度
    if score_diff >= score_difficulty_threshold:
        return max(current_difficulty - 1, 0)

    # AI领先太多，增加AI难度 (让比赛更有挑战性)
    if score_diff <= -score_difficulty_threshold:
        return min(current_difficulty + 1, 3)

    return current_difficulty

func get_difficulty_description(difficulty: int) -> String:
    match difficulty:
        0: return "简单"
        1: return "普通"
        2: return "困难"
        3: return "专家"
        _: return "未知"

# 实时参数调节 (供策划调试)
func set_ai_parameter(difficulty: int, param_name: String, value: float):
    """设置AI参数 (运行时调节)"""
    var controller = get_ai_controller()
    if controller and controller.difficulty_params.has(difficulty):
        controller.difficulty_params[difficulty][param_name] = value
```

---

## 6. 代码模块划分

### 6.1 建议的目录结构

```
res://
├── project.godot                    # 项目配置
├── icon.svg
├── export_presets.cfg
│
├── assets/                          # 资源文件夹
│   ├── models/                      # 3D模型
│   │   ├── paddle/
│   │   ├── ball/
│   │   ├── table/
│   │   └── environment/
│   ├── textures/                    # 贴图
│   ├── materials/                   # 材质
│   ├── shaders/                     # Shader
│   ├── audio/                       # 音频
│   │   ├── sfx/
│   │   └── music/
│   └── fonts/                       # 字体
│
├── src/                             # 源代码
│   ├── core/                        # 核心系统
│   │   ├── game_manager.gd          # 游戏管理器
│   │   ├── state_machine.gd         # 状态机
│   │   ├── scene_manager.gd         # 场景管理
│   │   └── event_bus.gd             # 全局事件总线
│   │
│   ├── network/                     # 网络通信
│   │   ├── sensor_server.gd         # 传感器服务器 (现有)
│   │   ├── discovery_server.gd      # 发现服务 (现有)
│   │   ├── packet_parser.gd         # 数据包解析
│   │   └── connection_manager.gd    # 连接管理
│   │
│   ├── sensor/                      # 传感器处理
│   │   ├── sensor_fusion.gd         # 数据融合
│   │   ├── paddle_calibration.gd    # 校准系统
│   │   ├── swing_detector.gd        # 挥拍检测
│   │   ├── hit_detector.gd          # 击球检测
│   │   └── motion_predictor.gd      # 运动预测
│   │
│   ├── physics/                     # 物理系统
│   │   ├── ball.gd                  # 球体物理
│   │   ├── paddle_physics.gd        # 球拍物理
│   │   ├── collision_manager.gd     # 碰撞管理
│   │   ├── trajectory_predictor.gd  # 轨迹预测
│   │   └── physics_config.gd        # 物理配置
│   │
│   ├── ai/                          # AI系统
│   │   ├── ai_controller.gd         # AI控制器
│   │   ├── ai_difficulty.gd         # 难度管理
│   │   ├── tactical_engine.gd       # 战术引擎
│   │   └── ball_predictor.gd        # 球预测 (AI用)
│   │
│   ├── gameplay/                    # 游戏逻辑
│   │   ├── match_manager.gd         # 比赛管理
│   │   ├── score_manager.gd         # 计分系统
│   │   ├── rally_manager.gd         # 回合管理
│   │   └── rules_engine.gd          # 规则引擎
│   │
│   ├── entities/                    # 游戏实体
│   │   ├── paddle.gd                # 球拍实体
│   │   ├── ball_entity.gd           # 球实体
│   │   ├── table.gd                 # 球台
│   │   └── net.gd                   # 球网
│   │
│   ├── ui/                          # UI系统
│   │   ├── hud/
│   │   ├── menus/
│   │   ├── calibration/
│   │   └── components/
│   │
│   ├── audio/                       # 音频系统
│   │   ├── audio_manager.gd
│   │   └── sfx_player.gd
│   │
│   ├── effects/                     # 特效系统
│   │   ├── particle_manager.gd
│   │   ├── trail_renderer.gd
│   │   └── impact_effect.gd
│   │
│   └── utils/                       # 工具类
│       ├── data_persistence.gd      # 数据持久化
│       ├── math_utils.gd            # 数学工具
│       └── debug_draw.gd            # 调试绘制
│
├── scenes/                          # 场景文件
│   ├── boot.tscn
│   ├── main_menu.tscn
│   ├── pairing.tscn
│   ├── calibration.tscn
│   ├── game.tscn
│   └── match_end.tscn
│
├── resources/                       # 资源配置
│   ├── physics_configs/
│   ├── difficulty_presets/
│   └── theme.tres
│
└── docs/                            # 文档
    ├── Technical_Architecture.md    # 本文档
    ├── API_Reference.md
    └── Art_Integration_Guide.md
```

### 6.2 核心类设计 (类图)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              核心类关系图                                    │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────┐         ┌─────────────────────┐
│    GameManager      │◄────────│   StateMachine      │
│    (单例)            │         │   (状态管理)         │
├─────────────────────┤         ├─────────────────────┤
│ - current_state     │         │ - states: Dictionary│
│ - match_manager     │         │ - current_state     │
│ - scene_manager     │         │ - transition_to()   │
│ - audio_manager     │         │ - can_transition()  │
├─────────────────────┤         └─────────────────────┘
│ + start_match()     │                  ▲
│ + pause_game()      │                  │
│ + end_match()       │         ┌────────┴────────┐
└─────────────────────┘         │                 │
         ▲                      ▼                 ▼
         │           ┌─────────────────┐  ┌─────────────────┐
         │           │  MainMenuState  │  │  PlayingState   │
         │           │  PairingState   │  │  PausedState    │
         │           │  Calibration... │  │  MatchEndState  │
         │           └─────────────────┘  └─────────────────┘
         │
         │         ┌─────────────────────┐
         └────────►│   MatchManager      │
                   │   (比赛逻辑)         │
                   ├─────────────────────┤
                   │ - score_manager     │
                   │ - rally_manager     │
                   │ - rules_engine      │
                   ├─────────────────────┤
                   │ + start_rally()     │
                   │ + end_rally()       │
                   │ + check_winner()    │
                   └─────────────────────┘
                            │
           ┌────────────────┼────────────────┐
           ▼                ▼                ▼
  ┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐
  │  ScoreManager   │ │  RallyManager   │ │  RulesEngine    │
  │  (计分系统)      │ │  (回合管理)      │ │  (规则判定)      │
  └─────────────────┘ └─────────────────┘ └─────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│                              实体类关系图                                    │
└─────────────────────────────────────────────────────────────────────────────┘

                    ┌─────────────────────┐
                    │   Node3D            │
                    │   (Godot基类)        │
                    └─────────────────────┘
                              ▲
           ┌──────────────────┼──────────────────┐
           │                  │                  │
           ▼                  ▼                  ▼
  ┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐
  │     Paddle      │ │      Ball       │ │     Table       │
  │     (球拍)       │ │     (球)         │ │     (球台)       │
  ├─────────────────┤ ├─────────────────┤ ├─────────────────┤
  │ - controller    │ │ - velocity      │ │ - surface_mesh  │
  │ - hit_box       │ │ - spin          │ │ - net           │
  │ - visual        │ │ - trajectory    │ │ - bounds        │
  ├─────────────────┤ ├─────────────────┤ ├─────────────────┤
  │ + swing()       │ │ + apply_force() │ │ + check_bounce()│
  │ + calibrate()   │ │ + predict_path()│ │ + is_in_bounds()│
  └─────────────────┘ └─────────────────┘ └─────────────────┘
           ▲                  ▲
           │                  │
           │         ┌────────┴────────┐
           │         │                 │
           │         ▼                 ▼
           │  ┌─────────────────┐ ┌─────────────────┐
           │  │  PlayerPaddle   │ │   AIPaddle      │
           │  │  (玩家控制)      │ │   (AI控制)       │
           │  ├─────────────────┤ ├─────────────────┤
           │  │ - sensor_input  │ │ - ai_controller │
           │  │ - calibration   │ │ - difficulty    │
           │  ├─────────────────┤ ├─────────────────┤
           │  │ + process_input()│ │ + think()       │
           │  │ + on_sensor_data()│ │ + predict_ball()│
           │  └─────────────────┘ └─────────────────┘
           │
           └─────────────────────────────────────────┐
                                                     │
                              ┌─────────────────────┴─────┐
                              │   PaddleController        │
                              │   (抽象控制器基类)          │
                              ├───────────────────────────┤
                              │ + get_target_position()   │
                              │ + execute_swing()         │
                              │ + get_paddle_velocity()   │
                              └───────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│                              传感器处理类图                                  │
└─────────────────────────────────────────────────────────────────────────────┘

  ┌─────────────────────┐     ┌─────────────────────┐     ┌─────────────────────┐
  │   SensorServer      │────►│   SensorFusion      │────►│   SwingDetector     │
  │   (UDP接收)          │     │   (数据融合)         │     │   (挥拍检测)         │
  ├─────────────────────┤     ├─────────────────────┤     ├─────────────────────┤
  │ - udp_socket        │     │ - filter_accel      │     │ - velocity_history  │
  │ - packet_parser     │     │ - smooth_velocity   │     │ - swing_state       │
  ├─────────────────────┤     ├─────────────────────┤     ├─────────────────────┤
  │ + start_server()    │     │ + process_data()    │     │ + detect_swing()    │
  │ + parse_packet()    │     │ + get_filtered()    │     │ + get_power()       │
  └─────────────────────┘     └─────────────────────┘     └─────────────────────┘
                                                                    │
                                                                    ▼
                                                           ┌─────────────────────┐
                                                           │   HitDetector       │
                                                           │   (击球检测)         │
                                                           ├─────────────────────┤
                                                           │ - hit_sphere        │
                                                           │ - timing_window     │
                                                           ├─────────────────────┤
                                                           │ + check_collision() │
                                                           │ + execute_hit()     │
                                                           └─────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│                              物理系统类图                                    │
└─────────────────────────────────────────────────────────────────────────────┘

  ┌─────────────────────┐     ┌─────────────────────┐     ┌─────────────────────┐
  │  CollisionManager   │◄────│   BallPhysics       │◄────│ TrajectoryPredictor │
  │  (碰撞管理)          │     │   (球体物理)         │     │   (轨迹预测)         │
  ├─────────────────────┤     ├─────────────────────┤     ├─────────────────────┤
  │ - collision_layers  │     │ - mass, radius      │     │ - prediction_steps  │
  │ - spatial_hash      │     │ - velocity, spin    │     │ - physics_params    │
  ├─────────────────────┤     ├─────────────────────┤     ├─────────────────────┤
  │ + check_collisions()│     │ + integrate()       │     │ + predict_path()    │
  │ + resolve_collision()│     │ + apply_impulse()   │     │ + find_impact_point()│
  └─────────────────────┘     └─────────────────────┘     └─────────────────────┘
                                       ▲
                                       │
                              ┌────────┴────────┐
                              │                 │
                              ▼                 ▼
                     ┌─────────────────┐ ┌─────────────────┐
                     │  PaddlePhysics  │ │  TablePhysics   │
                     │  (球拍物理)      │ │  (球台物理)      │
                     ├─────────────────┤ ├─────────────────┤
                     │ - restitution   │ │ - surface_props │
                     │ - friction      │ │ - net_props     │
                     ├─────────────────┤ ├─────────────────┤
                     │ + on_ball_hit() │ │ + on_ball_bounce│
                     └─────────────────┘ └─────────────────┘
```

### 6.3 关键接口定义

#### 6.3.1 传感器输入接口

```gdscript
# ISensorInput.gd
class_name ISensorInput
extends RefCounted

# 原始传感器数据
class SensorData:
    var timestamp: float          # 时间戳
    var linear_accel: Vector3     # 线性加速度 (m/s²)
    var quaternion: Quaternion    # 旋转四元数
    var gyroscope: Vector3        # 角速度 (rad/s) - 可选

# 处理后的运动数据
class MotionData:
    var position: Vector3         # 估算位置
    var velocity: Vector3         # 估算速度
    var rotation: Quaternion      # 旋转姿态
    var angular_velocity: Vector3 # 角速度
    var is_swinging: bool         # 是否正在挥拍
    var swing_power: float        # 挥拍力度 (0-1)

# 接口方法
func process_raw_data(raw_data: SensorData) -> MotionData:
    push_error("Must implement process_raw_data")
    return null

func calibrate_zero_pose(pose_data: Array[SensorData]) -> bool:
    push_error("Must implement calibrate_zero_pose")
    return false
```

#### 6.3.2 球拍控制器接口

```gdscript
# IPaddleController.gd
class_name IPaddleController
extends Node

# 控制模式
enum ControlMode {
    PLAYER,     # 玩家控制
    AI,         # AI控制
    REPLAY,     # 回放
    NETWORK     # 网络对战
}

var control_mode: ControlMode = ControlMode.PLAYER
var is_active: bool = false

# 当前状态
var current_position: Vector3
var current_rotation: Quaternion
var current_velocity: Vector3

# 核心方法
func get_target_position() -> Vector3:
    """获取目标位置 (每帧调用)"""
    push_error("Must implement get_target_position")
    return Vector3.ZERO

func get_target_rotation() -> Quaternion:
    """获取目标旋转"""
    push_error("Must implement get_target_rotation")
    return Quaternion.IDENTITY

func on_ball_contact(ball: Ball, contact_normal: Vector3):
    """球与球拍接触回调"""
    pass

func can_hit_ball() -> bool:
    """检查当前是否可以击球"""
    return is_active

func execute_swing(direction: Vector3, power: float, spin: Vector3):
    """执行挥拍动作"""
    push_error("Must implement execute_swing")
```

#### 6.3.3 游戏事件接口

```gdscript
# IGameEventListener.gd
class_name IGameEventListener
extends RefCounted

# 比赛事件
func on_match_started(match_config: Dictionary):
    pass

func on_match_ended(winner: String, final_score: Dictionary):
    pass

func on_rally_started():
    pass

func on_rally_ended(winner: String, reason: String):
    pass

# 击球事件
func on_ball_hit_paddle(paddle: Paddle, ball: Ball, hit_data: Dictionary):
    pass

func on_ball_hit_table(bounce_point: Vector3, is_valid: bool):
    pass

func on_ball_hit_net(contact_point: Vector3):
    pass

func on_ball_out_of_bounds(ball_position: Vector3):
    pass

# 得分事件
func on_point_scored(scorer: String, new_score: Dictionary):
    pass

# 状态事件
func on_game_state_changed(from_state: int, to_state: int):
    pass

func on_game_paused():
    pass

func on_game_resumed():
    pass
```

#### 6.3.4 物理对象接口

```gdscript
# IPhysicsObject.gd
class_name IPhysicsObject
extends RigidBody3D

# 物理属性
var restitution: float = 0.8    # 恢复系数 (弹性)
var friction: float = 0.3       # 摩擦系数

# 碰撞回调
func on_collision_enter(other: Node, contact_point: Vector3, contact_normal: Vector3):
    pass

func on_collision_exit(other: Node):
    pass

# 力/冲量应用
func apply_physics_impulse(impulse: Vector3, position: Vector3 = Vector3.ZERO):
    apply_impulse(impulse, position)

func apply_physics_force(force: Vector3, position: Vector3 = Vector3.ZERO, delta: float = 1.0):
    apply_force(force, position)
```

---

## 7. 与现有代码集成方案

### 7.1 现有代码分析

| 文件 | 行数 | 功能 | 集成策略 |
|------|------|------|----------|
| `sensor_server.gd` | 1175 | UDP通信、3D可视化、数据记录 | 拆分为网络层+传感器处理层 |
| `discovery_server.gd` | 180 | 服务发现和配对 | 保留并封装为ConnectionManager |
| `phone_visualizer.gd` | 33 | 3D手机模型可视化 | 合并到Paddle视觉组件 |
| `main.tscn` | - | 主场景 | 重构为Game场景 |

### 7.2 渐进式迁移计划

#### 阶段1: 代码重组 (Week 1)

```gdscript
# 1. 将sensor_server.gd中的功能拆分

# 原sensor_server.gd保留核心UDP循环
# 新增 src/network/sensor_server_core.gd
class_name SensorServerCore
extends Node

# 只保留网络相关代码
var udp_socket: PacketPeerUDP
const SERVER_PORT := 49555

signal sensor_data_received(data: SensorData)

func start_server():
    # UDP服务器启动逻辑
    pass

func _process(delta):
    # 只处理UDP接收
    while udp_socket.get_available_packet_count() > 0:
        var packet = udp_socket.get_packet()
        var data = parse_binary_packet(packet)
        emit_signal("sensor_data_received", data)
```

#### 阶段2: 传感器处理层 (Week 1-2)

```gdscript
# src/sensor/sensor_processor.gd
class_name SensorProcessor
extends Node

@onready var server: SensorServerCore = $SensorServerCore
@onready var fusion: SensorFusion = $SensorFusion
@onready var swing_detector: SwingDetector = $SwingDetector

func _ready():
    server.sensor_data_received.connect(on_raw_data_received)

func on_raw_data_received(raw_data: Dictionary):
    # 1. 数据融合与滤波
    var fused_data = fusion.process(raw_data)

    # 2. 挥拍检测
    var swing_info = swing_detector.update(fused_data)

    # 3. 分发给游戏系统
    EventBus.emit_signal("paddle_motion_updated", fused_data)

    if swing_info.is_swing_detected:
        EventBus.emit_signal("paddle_swing_detected", swing_info)
```

#### 阶段3: 物理系统集成 (Week 2-3)

```gdscript
# src/physics/physics_world.gd
class_name PhysicsWorld
extends Node3D

@onready var ball: Ball = $Ball
@onready var collision_manager: CollisionManager = $CollisionManager

func _physics_process(delta: float):
    # 更新球物理
    ball.update_physics(delta)

    # 碰撞检测
    collision_manager.check_all_collisions(ball)

    # 同步到渲染
    sync_to_visual()
```

#### 阶段4: 游戏逻辑层 (Week 3-4)

```gdscript
# src/gameplay/match_manager.gd
class_name MatchManager
extends Node

@onready var state_machine: GameStateMachine = $StateMachine
@onready var score_manager: ScoreManager = $ScoreManager
@onready var physics_world: PhysicsWorld = $PhysicsWorld

func _ready():
    # 连接事件
    EventBus.ball_hit_paddle.connect(on_ball_hit_paddle)
    EventBus.ball_out_of_bounds.connect(on_ball_out)

func start_match(config: MatchConfig):
    state_machine.transition_to(State.SERVING)
    score_manager.reset_scores()
    physics_world.reset_ball()
```

### 7.3 向后兼容性

```gdscript
# 兼容层 - 保留原有API
# src/compat/sensor_server_compat.gd

extends "res://sensor_server.gd"

# 标记为已弃用
@warning_ignore("unused_parameter")
func _init():
    push_warning("sensor_server.gd is deprecated. Use SensorServerCore instead.")

# 转发到新系统
func update_phone_visualization(delta: float):
    # 调用新的视觉系统
    var visual_system = get_node_or_null("/root/VisualSystem")
    if visual_system:
        visual_system.update_paddle_visual(delta)
```

### 7.4 配置迁移

```gdscript
# 将现有的@export变量迁移到配置资源
# resources/physics_configs/default.tres

[resource]
script = ExtResource("1_physics")
ball_mass = 0.0027
ball_radius = 0.02
paddle_restitution = 0.9
table_restitution = 0.85
friction = 5.0
return_speed = 2.0
max_displacement = 5.0
```

---

## 8. 附录

### 8.1 性能预算

| 系统 | 目标帧时间 | 备注 |
|------|-----------|------|
| 传感器处理 | < 1ms | 60fps数据更新 |
| 物理模拟 | < 4ms | 包括碰撞检测 |
| AI计算 | < 2ms | 每帧一次预测 |
| 渲染 | < 12ms | 目标60fps |
| **总计** | **< 16.67ms** | 60fps目标 |

### 8.2 网络协议

```
UDP数据包 (28字节):
┌─────────┬─────────┬─────────┬─────────┬─────────┬─────────┬─────────┐
│ accel_x │ accel_y │ accel_z │ quat_x  │ quat_y  │ quat_z  │ quat_w  │
│ float32 │ float32 │ float32 │ float32 │ float32 │ float32 │ float32 │
│ 4 bytes │ 4 bytes │ 4 bytes │ 4 bytes │ 4 bytes │ 4 bytes │ 4 bytes │
└─────────┴─────────┴─────────┴─────────┴─────────┴─────────┴─────────┘

控制消息 (JSON):
{
    "type": "record_start" | "record_stop" | "playback_start" | ...,
    "timestamp": 1234567890,
    "data": { ... }
}
```

### 8.3 调试工具

```gdscript
# 开发调试功能
class_name DebugTools
extends Node

# 可视化选项
@export var show_trajectory_prediction: bool = true
@export var show_hit_boxes: bool = false
@export var show_sensor_data: bool = true
@export var slow_motion_factor: float = 1.0

# 实时调节
@export var physics_time_scale: float = 1.0:
    set(value):
        physics_time_scale = value
        Engine.time_scale = value

func _input(event):
    if event is InputEventKey and event.pressed:
        match event.keycode:
            KEY_F1:
                show_trajectory_prediction = !show_trajectory_prediction
            KEY_F2:
                show_hit_boxes = !show_hit_boxes
            KEY_F3:
                slow_motion_factor = 0.2 if slow_motion_factor == 1.0 else 1.0
                Engine.time_scale = slow_motion_factor
```

---

## 文档信息

- **版本**: 1.0
- **创建日期**: 2026-02-21
- **最后更新**: 2026-02-21
- **作者**: 技术架构组
- **审核状态**: 待审核

---

*本文档为混合现实乒乓球游戏项目的技术架构方案，涵盖传感器数据处理、物理系统、AI算法及代码架构设计。*
