class_name Ball
extends RigidBody3D

## 球体物理类
## 处理乒乓球的运动、重力、空气阻力、旋转效应和碰撞

# 信号
signal ball_hit_paddle(paddle: Node3D, hit_point: Vector3, velocity: Vector3)
signal ball_hit_table(bounce_point: Vector3, is_valid: bool)
signal ball_hit_net(contact_point: Vector3)
signal ball_out_of_bounds(position: Vector3)
signal ball_reset()

# 物理参数
@export_group("Ball Physics")
@export var base_mass: float = 0.0027          # 乒乓球质量 (2.7g)
@export var ball_radius: float = 0.02          # 球半径 (20mm)
@export var drag_coefficient: float = 0.47     # 空气阻力系数
@export var air_density: float = 1.225         # 空气密度 (kg/m³)
@export var ball_gravity_scale: float = 1.0    # 重力缩放 (重命名避免与RigidBody3D冲突)

# 旋转物理参数
@export_group("Spin Physics")
@export var magnus_coefficient: float = 0.25   # 马格努斯效应系数
@export var spin_decay_rate: float = 0.98      # 旋转衰减率

# 反弹系数
@export_group("Restitution")
@export var paddle_restitution: float = 0.9    # 球拍弹性
@export var table_restitution: float = 0.85    # 球台弹性
@export var net_restitution: float = 0.1       # 球网弹性

# 摩擦系数
@export_group("Friction")
@export var table_friction: float = 0.3        # 球台摩擦
@export var paddle_friction: float = 0.4       # 球拍摩擦

# 状态变量
var current_velocity := Vector3.ZERO
var current_spin := Vector3.ZERO               # 旋转角速度 (rad/s)
var is_active := false
var is_simulated := true                       # 使用自定义物理模拟

# 轨迹记录
var trajectory_points: Array[Vector3] = []
const MAX_TRAJECTORY_POINTS := 100

# 边界检测
var bounds_min := Vector3(-10, -1, -10)
var bounds_max := Vector3(10, 10, 10)

# 球台参数
var table_height: float = 0.76                 # 标准球台高度 (米)
var table_bounds := Rect2(-1.525, -2.74, 3.05, 5.48)  # 标准球台尺寸

# 帧计数
var frame_count := 0


func _ready():
    print("[Ball] 球体物理已初始化")
    mass = base_mass
    freeze = true  # 使用自定义物理
    collision_layer = 1  # BALL layer
    collision_mask = 30  # 与PADDLE(2), TABLE(4), NET(8), WALL(16)碰撞
    _create_visual_model()


func _physics_process(delta: float):
    if not is_active:
        return

    frame_count += 1

    if is_simulated:
        _update_physics(delta)

    # 记录轨迹
    _update_trajectory()

    # 边界检测
    _check_bounds()


## 更新物理状态
func _update_physics(delta: float):
    # 1. 应用重力
    var gravity_force = Vector3.DOWN * 9.81 * ball_gravity_scale * base_mass

    # 2. 计算空气阻力
    var speed = current_velocity.length()
    var drag_force_magnitude = 0.5 * air_density * speed * speed * drag_coefficient * PI * ball_radius * ball_radius
    var drag_force = -current_velocity.normalized() * drag_force_magnitude

    # 3. 计算马格努斯力 (旋转效应)
    var magnus_force = _calculate_magnus_force()

    # 4. 合力计算
    var total_force = gravity_force + drag_force + magnus_force
    var acceleration = total_force / base_mass

    # 5. 速度更新
    current_velocity += acceleration * delta

    # 6. 旋转衰减
    current_spin *= spin_decay_rate

    # 7. 位置更新
    var motion = current_velocity * delta
    var collision = move_and_collide(motion)

    if collision:
        _handle_collision(collision)


## 计算马格努斯力 (升力/侧向力)
## F_magnus = S * (ω × v)
## S为马格努斯系数，ω为旋转角速度，v为线速度
func _calculate_magnus_force() -> Vector3:
    if current_spin.length() < 0.1:
        return Vector3.ZERO

    var cross_product = current_spin.cross(current_velocity)
    return cross_product * magnus_coefficient * air_density * ball_radius * ball_radius * ball_radius


## 处理碰撞
func _handle_collision(collision: KinematicCollision3D):
    var collider = collision.get_collider()
    var normal = collision.get_normal()
    var point = collision.get_position()

    # 根据碰撞对象类型处理
    if collider.is_in_group("paddle"):
        _on_paddle_collision(collider, point, normal)
    elif collider.is_in_group("table"):
        _on_table_collision(point, normal)
    elif collider.is_in_group("net"):
        _on_net_collision(point, normal)


## 球拍碰撞处理
func _on_paddle_collision(paddle: Node3D, hit_point: Vector3, normal: Vector3):
    # 获取球拍速度
    var paddle_velocity = Vector3.ZERO
    if paddle.has_method("get_current_velocity"):
        paddle_velocity = paddle.get_current_velocity()

    # 计算相对速度
    var relative_velocity = current_velocity - paddle_velocity

    # 反弹速度
    var bounce_velocity = relative_velocity.bounce(normal) * paddle_restitution

    # 添加球拍速度传递
    bounce_velocity += paddle_velocity * 0.3

    # 应用旋转效果
    if paddle.has_method("get_current_rotation"):
        var paddle_rot = paddle.get_current_rotation()
        # 基于球拍旋转添加旋转
        current_spin += Vector3(paddle_rot.x, paddle_rot.y, paddle_rot.z) * 5.0

    current_velocity = bounce_velocity

    emit_signal("ball_hit_paddle", paddle, hit_point, current_velocity)

    if frame_count % 60 == 0:
        print("[Ball] 击中球拍 | 速度: %.2f m/s" % current_velocity.length())


## 球台碰撞处理
func _on_table_collision(bounce_point: Vector3, normal: Vector3):
    # 速度分解为法向和切向
    var normal_component = normal * current_velocity.dot(normal)
    var tangent_component = current_velocity - normal_component

    # 法向反弹 (带能量损失)
    var new_normal = -normal_component * table_restitution

    # 切向摩擦 (旋转与表面交互)
    var spin_effect = current_spin.cross(normal) * ball_radius
    var new_tangent = (tangent_component + spin_effect) * (1.0 - table_friction)

    # 更新旋转 (摩擦导致旋转变化)
    current_spin -= tangent_component.cross(normal) * table_friction / ball_radius

    # 合成新速度
    current_velocity = new_normal + new_tangent

    # 确保球不会陷入球台
    global_position.y = table_height + ball_radius + 0.001

    # 检查是否在球台范围内
    var is_valid = _is_on_table(bounce_point)

    emit_signal("ball_hit_table", bounce_point, is_valid)

    if frame_count % 60 == 0:
        print("[Ball] 球台反弹 | 位置: (%.2f, %.2f, %.2f) | 有效: %s" % [
            bounce_point.x, bounce_point.y, bounce_point.z, str(is_valid)
        ])


## 球网碰撞处理
func _on_net_collision(contact_point: Vector3, normal: Vector3):
    # 球网碰撞：弹性碰撞，能量损失大
    current_velocity = current_velocity.bounce(normal) * net_restitution

    emit_signal("ball_hit_net", contact_point)

    if frame_count % 60 == 0:
        print("[Ball] 击中球网")


## 检查是否在球台范围内
func _is_on_table(point: Vector3) -> bool:
    return table_bounds.has_point(Vector2(point.x, point.z))


## 边界检测
func _check_bounds():
    var pos = global_position

    # 地面检测 (出界)
    if pos.y < -0.5:
        emit_signal("ball_out_of_bounds", pos)
        deactivate()
        return

    # 墙壁检测
    if pos.x < bounds_min.x or pos.x > bounds_max.x or \
       pos.z < bounds_min.z or pos.z > bounds_max.z:
        emit_signal("ball_out_of_bounds", pos)
        deactivate()
        return


## 更新轨迹记录
func _update_trajectory():
    trajectory_points.append(global_position)

    if trajectory_points.size() > MAX_TRAJECTORY_POINTS:
        trajectory_points.pop_front()


## 击球处理（外部调用）
func on_paddle_hit(hit_direction: Vector3, hit_force: float, spin: Vector3, paddle_velocity: Vector3):
    """处理球拍击球"""
    # 计算击球后的速度
    var impulse = hit_direction * hit_force / base_mass

    # 添加球拍速度传递
    var velocity_transfer = paddle_velocity * 0.3

    current_velocity = impulse + velocity_transfer
    current_spin = spin

    # 确保最小向上速度（过网）
    if current_velocity.y < 2.0:
        current_velocity.y = 2.0

    if frame_count % 60 == 0:
        print("[Ball] 被击球 | 方向: (%.2f, %.2f, %.2f) | 力度: %.2f" % [
            hit_direction.x, hit_direction.y, hit_direction.z, hit_force
        ])


## 激活球
func activate(start_position: Vector3 = Vector3.ZERO):
    is_active = true
    global_position = start_position
    current_velocity = Vector3.ZERO
    current_spin = Vector3.ZERO
    trajectory_points.clear()
    freeze = false

    print("[Ball] 球已激活 | 位置: (%.2f, %.2f, %.2f)" % [
        start_position.x, start_position.y, start_position.z
    ])


## 停用球
func deactivate():
    is_active = false
    current_velocity = Vector3.ZERO
    current_spin = Vector3.ZERO
    freeze = true


## 重置球
func reset(position: Vector3 = Vector3.ZERO):
    deactivate()
    global_position = position
    trajectory_points.clear()
    emit_signal("ball_reset")

    print("[Ball] 球已重置")


## 创建视觉模型
func _create_visual_model():
    var mesh_instance = MeshInstance3D.new()
    mesh_instance.name = "BallMesh"

    var sphere_mesh = SphereMesh.new()
    sphere_mesh.radius = ball_radius
    sphere_mesh.height = ball_radius * 2

    var material = StandardMaterial3D.new()
    material.albedo_color = Color(1, 0.9, 0.7)  # 乒乓球颜色
    material.roughness = 0.4

    mesh_instance.mesh = sphere_mesh
    mesh_instance.material_override = material

    add_child(mesh_instance)


## 获取轨迹点
func get_trajectory() -> Array[Vector3]:
    return trajectory_points


## 获取调试信息
func get_debug_info() -> Dictionary:
    return {
        "position": global_position,
        "velocity": current_velocity,
        "speed": current_velocity.length(),
        "spin": current_spin,
        "is_active": is_active
    }
