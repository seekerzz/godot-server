class_name Paddle
extends Node3D

## 球拍实体类
## 代表游戏中的乒乓球拍，处理旋转、位置更新和视觉表现

# 信号
signal position_updated(position: Vector3)
signal rotation_updated(rotation: Quaternion)
signal swing_detected(power: float, velocity: Vector3)

# 弹性回中算法参数
@export_group("Elastic Return-to-Center")
@export var friction: float = 5.0           # 速度衰减系数
@export var return_speed: float = 2.0       # 回中速度
@export var max_displacement: float = 5.0   # 最大位移限制 (米)
@export var origin_position: Vector3 = Vector3.ZERO  # 中心点位置

# 挥拍检测参数
@export_group("Swing Detection")
@export var velocity_threshold: float = 3.0      # 最小挥拍速度 (m/s)
@export var accel_threshold: float = 15.0        # 加速度阈值 (m/s²)
@export var swing_cooldown: float = 0.3          # 挥拍冷却时间 (秒)

# 状态变量
var current_velocity := Vector3.ZERO        # 当前速度
var current_position := Vector3.ZERO        # 当前位置
var current_rotation := Quaternion.IDENTITY # 当前旋转
var calibration_offset := Quaternion.IDENTITY  # 校准偏移

# 挥拍检测状态
var is_in_swing := false
var last_swing_time: float = 0.0
var swing_power: float = 0.0

# 内部引用
var _visual_node: Node3D = null
var _hit_box: Area3D = null

# 帧计数
var frame_count := 0


func _ready():
    print("[Paddle] 球拍实体已初始化")
    _create_visual_model()
    # 确保视觉模型可见
    if _visual_node:
        _visual_node.visible = true
        print("[Paddle] 视觉模型可见性: " + str(_visual_node.visible))

    # 设置弹性回中的原点为初始位置
    origin_position = self.position
    current_position = self.position
    print("[Paddle] 弹性回中原点设置为: " + str(origin_position))


func _physics_process(delta: float):
    frame_count += 1

    # 更新位置（弹性回中算法）
    _update_position(delta)

    # 检测挥拍
    _detect_swing(delta)


## 从四元数设置旋转
func set_rotation_from_quaternion(quat: Quaternion, apply_calibration: bool = true):
    var final_quat = quat

    if apply_calibration and calibration_offset != Quaternion.IDENTITY:
        final_quat = calibration_offset * quat
        if frame_count % 120 == 0:
            print("[Paddle] 应用校准后旋转: (%.2f, %.2f, %.2f, %.2f)" % [final_quat.x, final_quat.y, final_quat.z, final_quat.w])

    current_rotation = final_quat.normalized()

    # 应用到视觉节点
    if _visual_node:
        _visual_node.quaternion = current_rotation

    emit_signal("rotation_updated", current_rotation)


## 从加速度设置位置（弹性回中算法）
func set_position_from_acceleration(accel: Vector3, delta: float):
    # 1. 速度积分 (v = v0 + a*t)
    current_velocity += accel * delta

    # 2. 高阻力衰减 (模拟空气阻力/手部阻尼)
    current_velocity = current_velocity.lerp(Vector3.ZERO, friction * delta)

    # 3. 位置积分 (p = p0 + v*t)
    current_position += current_velocity * delta

    # 4. 弹性回中 (模拟弹簧恢复力)
    current_position = current_position.lerp(origin_position, return_speed * delta)

    # 5. 限制最大位移范围
    current_position.x = clamp(current_position.x, -max_displacement, max_displacement)
    current_position.y = clamp(current_position.y, 0.0, max_displacement)
    current_position.z = clamp(current_position.z, -max_displacement, max_displacement)


## 内部位置更新
func _update_position(delta: float):
    # 应用到节点
    self.position = current_position

    emit_signal("position_updated", current_position)


## 挥拍检测
func _detect_swing(delta: float):
    var current_time = Time.get_unix_time_from_system()
    var velocity_magnitude = current_velocity.length()
    var accel_magnitude = current_velocity.length() / delta  # 估算加速度

    # 冷却检查
    if current_time - last_swing_time < swing_cooldown:
        return

    if not is_in_swing:
        # 进入挥拍：高速度 + 明显加速度
        if velocity_magnitude > velocity_threshold and accel_magnitude > accel_threshold:
            is_in_swing = true
            _on_swing_start()
    else:
        # 退出挥拍：速度衰减
        if velocity_magnitude < velocity_threshold * 0.5:
            is_in_swing = false
            _on_swing_end()
            last_swing_time = current_time


func _on_swing_start():
    """挥拍开始"""
    swing_power = calculate_swing_power()
    emit_signal("swing_detected", swing_power, current_velocity)

    if frame_count % 60 == 0:
        print("[Paddle] 挥拍开始 | 力度: %.2f" % swing_power)


func _on_swing_end():
    """挥拍结束"""
    if frame_count % 60 == 0:
        print("[Paddle] 挥拍结束 | 最终力度: %.2f" % swing_power)


## 计算挥拍力度 (0-1范围)
func calculate_swing_power() -> float:
    var velocity_factor = clamp(current_velocity.length() / 10.0, 0.0, 1.0)
    return velocity_factor


## 设置校准偏移
func set_calibration_offset(offset: Quaternion):
    calibration_offset = offset
    print("[Paddle] 校准偏移已设置: (%.4f, %.4f, %.4f, %.4f)" % [offset.x, offset.y, offset.z, offset.w])
    print("[Paddle] 当前视觉旋转将被重置为校准姿态")


## 重置位置和速度
func reset():
    current_velocity = Vector3.ZERO
    current_position = origin_position
    self.position = current_position
    print("[Paddle] 位置和速度已重置")


## 创建视觉模型（程序化生成）
## 设计思路：
## 1. 手机屏幕（长方形）作为球拍的"核心"
## 2. 乒乓球拍板面（椭圆形）覆盖在手机后面
## 3. 手柄从手机底部延伸
## 4. 整体呈现出"手机+球拍"的混合现实感
func _create_visual_model():
    if _visual_node != null:
        print("[Paddle] 视觉模型已存在，跳过创建")
        return

    print("[Paddle] 开始创建真实乒乓球拍视觉模型...")

    # 创建根节点
    _visual_node = Node3D.new()
    _visual_node.name = "PaddleVisual"
    add_child(_visual_node)

    # ========== 1. 手机模型（核心控制单元） ==========
    # 手机本体（黑色金属质感）
    var phone_body = MeshInstance3D.new()
    phone_body.name = "PhoneBody"
    var phone_mesh = BoxMesh.new()
    phone_mesh.size = Vector3(0.075, 0.16, 0.008)  # 真实手机尺寸：7.5cm x 16cm x 0.8cm
    phone_body.mesh = phone_mesh

    var phone_mat = StandardMaterial3D.new()
    phone_mat.albedo_color = Color(0.1, 0.1, 0.12)
    phone_mat.roughness = 0.2
    phone_mat.metallic = 0.8
    phone_body.material_override = phone_mat
    _visual_node.add_child(phone_body)

    # 手机屏幕（发光效果，模拟真实屏幕）
    var phone_screen = MeshInstance3D.new()
    phone_screen.name = "PhoneScreen"
    var screen_mesh = BoxMesh.new()
    screen_mesh.size = Vector3(0.068, 0.145, 0.001)  # 稍小于机身
    phone_screen.mesh = screen_mesh
    phone_screen.position = Vector3(0, 0, 0.0045)  # 在机身正面

    var screen_mat = StandardMaterial3D.new()
    screen_mat.albedo_color = Color(0.0, 0.1, 0.3)
    screen_mat.emission_enabled = true
    screen_mat.emission = Color(0.0, 0.2, 0.6)
    screen_mat.emission_energy_multiplier = 0.8
    phone_screen.material_override = screen_mat
    _visual_node.add_child(phone_screen)

    # 手机底部指示条（模拟home条，用于方向识别）
    var home_indicator = MeshInstance3D.new()
    home_indicator.name = "HomeIndicator"
    var indicator_mesh = BoxMesh.new()
    indicator_mesh.size = Vector3(0.03, 0.003, 0.002)
    home_indicator.mesh = indicator_mesh
    home_indicator.position = Vector3(0, -0.07, 0.005)

    var home_mat = StandardMaterial3D.new()
    home_mat.albedo_color = Color(0.8, 0.8, 0.8)
    home_indicator.material_override = home_mat
    _visual_node.add_child(home_indicator)

    print("[Paddle] 手机模型已创建")

    # ========== 2. 乒乓球拍板面（椭圆形，贴在手机背面） ==========
    # 使用圆柱体压扁创建椭圆板面
    var blade = MeshInstance3D.new()
    blade.name = "Blade"
    var blade_mesh = CylinderMesh.new()
    blade_mesh.top_radius = 0.075      # 椭圆宽度 15cm
    blade_mesh.bottom_radius = 0.075
    blade_mesh.height = 0.005          # 板面厚度 5mm
    blade_mesh.radial_segments = 32    # 更圆滑
    blade.mesh = blade_mesh

    # 压扁并旋转使椭圆方向正确（长轴对应手机长边）
    blade.scale = Vector3(1.0, 1.0, 1.33)  # 压扁成椭圆（16cm / 12cm 比例）
    blade.rotation_degrees = Vector3(90, 0, 0)  # 旋转使圆柱面朝前
    blade.position = Vector3(0, 0, -0.015)  # 在手机背面

    var blade_mat = StandardMaterial3D.new()
    blade_mat.albedo_color = Color(0.75, 0.15, 0.15)  # 深红色胶皮
    blade_mat.roughness = 0.6
    blade_mat.emission_enabled = true
    blade_mat.emission = Color(0.3, 0.05, 0.05)
    blade_mat.emission_energy_multiplier = 0.3
    blade.material_override = blade_mat
    _visual_node.add_child(blade)

    # 板面边缘装饰（白色边线，像真实球拍）
    var blade_edge = MeshInstance3D.new()
    blade_edge.name = "BladeEdge"
    var edge_mesh = CylinderMesh.new()
    edge_mesh.top_radius = 0.076
    edge_mesh.bottom_radius = 0.076
    edge_mesh.height = 0.002
    edge_mesh.radial_segments = 32
    blade_edge.mesh = edge_mesh
    blade_edge.scale = Vector3(1.0, 1.0, 1.33)
    blade_edge.rotation_degrees = Vector3(90, 0, 0)
    blade_edge.position = Vector3(0, 0, -0.018)

    var edge_mat = StandardMaterial3D.new()
    edge_mat.albedo_color = Color(0.9, 0.9, 0.9)  # 白色边线
    blade_edge.material_override = edge_mat
    _visual_node.add_child(blade_edge)

    print("[Paddle] 乒乓球拍板面已创建")

    # ========== 3. 木质手柄（从手机底部延伸） ==========
    var handle = MeshInstance3D.new()
    handle.name = "Handle"
    var handle_mesh = BoxMesh.new()
    handle_mesh.size = Vector3(0.035, 0.10, 0.025)  # 3.5cm x 10cm x 2.5cm
    handle.mesh = handle_mesh
    handle.position = Vector3(0, -0.13, -0.008)  # 从手机底部向下延伸

    var handle_mat = StandardMaterial3D.new()
    handle_mat.albedo_color = Color(0.45, 0.28, 0.15)  # 木质颜色
    handle_mat.roughness = 0.8
    handle.material_override = handle_mat
    _visual_node.add_child(handle)

    # 手柄装饰线
    var handle_line = MeshInstance3D.new()
    handle_line.name = "HandleLine"
    var line_mesh = BoxMesh.new()
    line_mesh.size = Vector3(0.036, 0.002, 0.026)
    handle_line.mesh = line_mesh
    handle_line.position = Vector3(0, -0.09, -0.008)

    var line_mat = StandardMaterial3D.new()
    line_mat.albedo_color = Color(0.2, 0.1, 0.05)
    handle_line.material_override = line_mat
    _visual_node.add_child(handle_line)

    print("[Paddle] 手柄已创建")

    # ========== 4. 击球区域指示器（可视化击球点） ==========
    var hit_zone = MeshInstance3D.new()
    hit_zone.name = "HitZone"
    var zone_mesh = CylinderMesh.new()
    zone_mesh.top_radius = 0.04
    zone_mesh.bottom_radius = 0.04
    zone_mesh.height = 0.001
    zone_mesh.radial_segments = 16
    hit_zone.mesh = zone_mesh
    hit_zone.scale = Vector3(1.0, 1.0, 1.33)
    hit_zone.rotation_degrees = Vector3(90, 0, 0)
    hit_zone.position = Vector3(0, 0.02, -0.012)  # 在板面甜区位置

    var zone_mat = StandardMaterial3D.new()
    zone_mat.albedo_color = Color(1.0, 1.0, 0.0, 0.4)
    zone_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    zone_mat.emission_enabled = true
    zone_mat.emission = Color(0.5, 0.5, 0.0)
    zone_mat.emission_energy_multiplier = 0.5
    hit_zone.material_override = zone_mat
    _visual_node.add_child(hit_zone)

    print("[Paddle] 击球区域指示器已创建")

    # ========== 5. 环境光效 ==========
    # 添加点光源增强球拍存在感
    var glow_light = OmniLight3D.new()
    glow_light.name = "GlowLight"
    glow_light.light_color = Color(0.8, 0.9, 1.0)
    glow_light.light_energy = 0.3
    glow_light.omni_range = 1.0
    glow_light.position = Vector3(0, 0, 0.1)
    _visual_node.add_child(glow_light)

    # 确保所有子节点都可见并启用阴影
    for child in _visual_node.get_children():
        if child is MeshInstance3D:
            child.visible = true
            child.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON

    print("[Paddle] 真实乒乓球拍视觉模型已创建完成！")
    print("[Paddle] - 手机模型：7.5x16cm（竖直握持时屏幕朝向你）")
    print("[Paddle] - 球拍板面：椭圆15x20cm（贴在手机背面）")
    print("[Paddle] - 手柄：从手机底部延伸")
    print("[Paddle] 使用方式：像握乒乓球拍一样握住手机，屏幕朝向你")


## 获取击球点位置（世界坐标）
## 击球点在球拍板面的甜区位置（靠近手机顶部）
func get_hit_point() -> Vector3:
    # 甜区位置：板面上方三分之一处，前方略微突出
    var local_hit_point = Vector3(0, 0.02, -0.05)
    return to_global(local_hit_point)


## 获取击球方向（基于球拍朝向）
func get_hit_direction() -> Vector3:
    # 球拍正面朝向（Z轴负方向）
    return -global_transform.basis.z


## 获取当前速度（用于碰撞检测）
func get_current_velocity() -> Vector3:
    return current_velocity


## 获取当前旋转（用于碰撞检测）
func get_current_rotation() -> Quaternion:
    return current_rotation


## 获取挥拍力度
func get_swing_power() -> float:
    return swing_power


## 设置视觉可见性
func set_visual_visible(visible: bool):
    if _visual_node:
        _visual_node.visible = visible


## 获取调试信息
func get_debug_info() -> Dictionary:
    return {
        "position": current_position,
        "velocity": current_velocity,
        "velocity_magnitude": current_velocity.length(),
        "rotation": current_rotation,
        "is_in_swing": is_in_swing,
        "swing_power": swing_power
    }
