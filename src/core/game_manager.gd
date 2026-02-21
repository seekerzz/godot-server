class_name GameManager
extends Node

## 游戏管理器
## 核心管理器，负责协调传感器、球拍、物理系统和游戏状态

# 信号
signal game_started()
signal game_paused()
signal game_resumed()
signal game_ended()
signal sensor_connected()
signal sensor_disconnected()

# 子系统引用
@onready var sensor_server = $SensorServerCore
@onready var sensor_fusion = $SensorFusion
@onready var paddle_calibration = $PaddleCalibration
@onready var player_paddle = $PlayerPaddle
@onready var ball = $Ball
@onready var collision_manager = $CollisionManager

# UI引用
@onready var status_label: Label = get_node_or_null("/root/MainGame/CanvasLayer/Control/StatusLabel")
@onready var debug_label: Label = get_node_or_null("/root/MainGame/CanvasLayer/Control/DebugLabel")

# 游戏状态
var is_game_running := false
var is_paused := false
var frame_count := 0

# 传感器数据缓存
var last_sensor_data: SensorFusion.MotionData = null


func _ready():
    print("[GameManager] 游戏管理器已初始化")
    _initialize_systems()
    _connect_signals()
    _start_server()


func _initialize_systems():
    """初始化所有子系统"""
    # 确保子系统存在
    if sensor_server == null:
        sensor_server = Node.new()
        sensor_server.set_script(load("res://src/sensor/sensor_server_core.gd"))
        sensor_server.name = "SensorServerCore"
        add_child(sensor_server)

    if sensor_fusion == null:
        sensor_fusion = Node.new()
        sensor_fusion.set_script(load("res://src/sensor/sensor_fusion.gd"))
        sensor_fusion.name = "SensorFusion"
        add_child(sensor_fusion)

    if paddle_calibration == null:
        paddle_calibration = Node.new()
        paddle_calibration.set_script(load("res://src/sensor/paddle_calibration.gd"))
        paddle_calibration.name = "PaddleCalibration"
        add_child(paddle_calibration)

    if player_paddle == null:
        player_paddle = Node3D.new()
        player_paddle.set_script(load("res://src/entities/paddle.gd"))
        player_paddle.name = "PlayerPaddle"
        add_child(player_paddle)

    if ball == null:
        ball = RigidBody3D.new()
        ball.set_script(load("res://src/physics/ball.gd"))
        ball.name = "Ball"
        add_child(ball)

    if collision_manager == null:
        collision_manager = Node3D.new()
        collision_manager.set_script(load("res://src/physics/collision_manager.gd"))
        collision_manager.name = "CollisionManager"
        add_child(collision_manager)
        collision_manager.ball = ball
        collision_manager.player_paddle = player_paddle


func _connect_signals():
    """连接所有信号"""
    # 传感器数据流
    if sensor_server:
        if sensor_server.has_signal("sensor_data_received"):
            sensor_server.sensor_data_received.connect(_on_sensor_data_received)

    # 校准系统
    if paddle_calibration:
        if paddle_calibration.has_signal("calibration_started"):
            paddle_calibration.calibration_started.connect(_on_calibration_started)
        if paddle_calibration.has_signal("calibration_step_changed"):
            paddle_calibration.calibration_step_changed.connect(_on_calibration_step_changed)
        if paddle_calibration.has_signal("calibration_completed"):
            paddle_calibration.calibration_completed.connect(_on_calibration_completed)

    # 球拍信号
    if player_paddle:
        if player_paddle.has_signal("swing_detected"):
            player_paddle.swing_detected.connect(_on_paddle_swing)

    # 碰撞信号
    if collision_manager:
        if collision_manager.has_signal("paddle_hit"):
            collision_manager.paddle_hit.connect(_on_paddle_hit)
        if collision_manager.has_signal("table_bounce"):
            collision_manager.table_bounce.connect(_on_table_bounce)
        if collision_manager.has_signal("ball_out_of_bounds"):
            collision_manager.ball_out_of_bounds.connect(_on_ball_out)


func _start_server():
    """启动传感器服务器"""
    if sensor_server:
        var success = sensor_server.start_server()
        if success:
            _update_status("等待手机连接...", Color.YELLOW)
        else:
            _update_status("服务器启动失败", Color.RED)


func _process(delta):
    frame_count += 1

    # 检查传感器连接状态
    if sensor_server and frame_count % 60 == 0:
        var stats = sensor_server.get_stats()
        if stats.packets_received > 0 and stats.last_packet_time < 1.0:
            _update_status("已连接 | 接收: %d 包" % stats.packets_received, Color.GREEN)


## 传感器数据处理回调
func _on_sensor_data_received(data: SensorServerCore.SensorData):
    # 数据融合处理
    var motion_data = sensor_fusion.process_sensor_data(
        data.linear_accel,
        data.quaternion,
        1.0 / 60.0  # 假设60fps
    )

    last_sensor_data = motion_data

    # 更新球拍
    if player_paddle:
        # 使用原始四元数，校准在球拍内部处理
        player_paddle.set_rotation_from_quaternion(motion_data.quaternion, true)
        player_paddle.set_position_from_acceleration(motion_data.linear_accel, 1.0 / 60.0)

        # 调试输出（每60帧一次）
        if frame_count % 60 == 0:
            var euler = motion_data.quaternion.get_euler()
            print("[GameManager] 原始旋转: pitch=%.1f yaw=%.1f roll=%.1f" % [rad_to_deg(euler.x), rad_to_deg(euler.y), rad_to_deg(euler.z)])


## 校准回调
func _on_calibration_started():
    _update_status("校准中...", Color.YELLOW)
    print("[GameManager] 校准开始")


func _on_calibration_step_changed(step: int, pose_name: String, instruction: String):
    _update_status("校准: %s" % pose_name, Color.YELLOW)
    print("[GameManager] 校准姿势: %s" % pose_name)


func _on_calibration_completed(success: bool, offset: Quaternion):
    if success:
        _update_status("校准完成", Color.GREEN)
        print("[GameManager] 校准完成，偏移: (%.4f, %.4f, %.4f, %.4f)" % [offset.x, offset.y, offset.z, offset.w])

        # 将校准偏移设置到球拍
        if player_paddle:
            player_paddle.set_calibration_offset(offset)
            # 立即应用一次旋转，将视觉模型重置为校准姿态（零点）
            player_paddle.set_rotation_from_quaternion(Quaternion.IDENTITY, false)
            print("[GameManager] 校准偏移已应用到球拍，视觉模型已重置")
    else:
        _update_status("校准失败", Color.RED)


## 游戏事件回调
func _on_paddle_swing(power: float, velocity: Vector3):
    print("[GameManager] 挥拍检测 | 力度: %.2f" % power)


func _on_paddle_hit(paddle: Node3D, hit_ball: Ball, hit_point: Vector3):
    print("[GameManager] 球被击中")


func _on_table_bounce(hit_ball: Ball, bounce_point: Vector3, is_valid: bool):
    if not is_valid:
        print("[GameManager] 无效反弹")


func _on_ball_out(hit_ball: Ball, position: Vector3):
    print("[GameManager] 球出界")
    # 重置球
    hit_ball.reset(Vector3(0, 1, 0))


## 公共接口

func start_game():
    """开始游戏"""
    is_game_running = true
    is_paused = false

    # 激活球
    if ball:
        ball.activate(Vector3(0, 1, -1))

    emit_signal("game_started")
    _update_status("游戏进行中", Color.GREEN)
    print("[GameManager] 游戏开始")


func pause_game():
    """暂停游戏"""
    if not is_game_running:
        return

    is_paused = true
    get_tree().paused = true

    emit_signal("game_paused")
    _update_status("游戏暂停", Color.YELLOW)


func resume_game():
    """恢复游戏"""
    if not is_game_running:
        return

    is_paused = false
    get_tree().paused = false

    emit_signal("game_resumed")
    _update_status("游戏进行中", Color.GREEN)


func end_game():
    """结束游戏"""
    is_game_running = false
    is_paused = false

    # 停用球
    if ball:
        ball.deactivate()

    emit_signal("game_ended")
    _update_status("游戏结束", Color.WHITE)


func start_calibration():
    """开始校准流程"""
    if paddle_calibration:
        paddle_calibration.start_calibration()


func record_calibration_sample():
    """记录校准样本"""
    if paddle_calibration and last_sensor_data:
        paddle_calibration.record_calibration_sample(
            last_sensor_data.quaternion,
            last_sensor_data.linear_accel
        )


func reset_paddle():
    """重置球拍"""
    if player_paddle:
        player_paddle.reset()


## UI更新
func _update_status(text: String, color: Color):
    if status_label:
        status_label.text = "状态: " + text
        status_label.modulate = color


## 公共方法
func is_sensor_connected() -> bool:
    """检查传感器是否已连接"""
    if sensor_server:
        var stats = sensor_server.get_stats()
        return stats.packets_received > 0 and stats.last_packet_time < 1.0
    return false

func get_sensor_stats() -> Dictionary:
    """获取传感器统计信息"""
    if sensor_server:
        return sensor_server.get_stats()
    return {}

func get_paddle_info() -> Dictionary:
    """获取球拍信息"""
    if player_paddle:
        return {
            "position": player_paddle.position,
            "rotation": player_paddle.current_rotation.get_euler(),
            "velocity": player_paddle.current_velocity
        }
    return {}

## 输入处理
func _input(event):
    if event is InputEventKey and event.pressed:
        match event.keycode:
            KEY_SPACE:
                if not is_game_running:
                    start_game()
                elif is_paused:
                    resume_game()
                else:
                    pause_game()
            KEY_R:
                reset_paddle()
            KEY_K:
                start_calibration()
            KEY_ENTER:
                if paddle_calibration and paddle_calibration.is_calibrating:
                    record_calibration_sample()
            KEY_ESCAPE:
                get_tree().quit()


func _exit_tree():
    if sensor_server:
        sensor_server.stop_server()
