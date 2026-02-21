extends Node3D

## 演示场景
## 用于测试传感器连接、球拍控制和基础物理

# 子系统
var sensor_server: SensorServerCore
var sensor_fusion: SensorFusion
var paddle_calibration: PaddleCalibration
var player_paddle: Paddle
var ball: Ball
var collision_manager: CollisionManager

# UI
@onready var status_label: Label = %StatusLabel
@onready var debug_label: Label = %DebugLabel
@onready var calibrate_button: Button = %CalibrateButton
@onready var confirm_button: Button = %ConfirmButton
@onready var start_button: Button = %StartButton
@onready var reset_button: Button = %ResetButton

# 状态
var is_calibrating := false
var last_sensor_data = null
var frame_count := 0


func _ready():
    print("[DemoScene] 演示场景已加载")
    _setup_systems()
    _setup_ui()
    _create_environment()


func _setup_systems():
    """设置所有子系统"""

    # 传感器服务器
    sensor_server = SensorServerCore.new()
    sensor_server.name = "SensorServerCore"
    add_child(sensor_server)
    sensor_server.sensor_data_received.connect(_on_sensor_data_received)

    # 传感器融合
    sensor_fusion = SensorFusion.new()
    sensor_fusion.name = "SensorFusion"
    add_child(sensor_fusion)

    # 校准系统
    paddle_calibration = PaddleCalibration.new()
    paddle_calibration.name = "PaddleCalibration"
    add_child(paddle_calibration)
    paddle_calibration.calibration_started.connect(_on_calibration_started)
    paddle_calibration.calibration_completed.connect(_on_calibration_completed)

    # 玩家球拍
    player_paddle = Paddle.new()
    player_paddle.name = "PlayerPaddle"
    add_child(player_paddle)
    player_paddle.position = Vector3(0, 1.2, -1.0)  # 抬高位置避免被地面挡住

    # 球
    ball = Ball.new()
    ball.name = "Ball"
    add_child(ball)

    # 碰撞管理器
    collision_manager = CollisionManager.new()
    collision_manager.name = "CollisionManager"
    add_child(collision_manager)
    collision_manager.ball = ball
    collision_manager.player_paddle = player_paddle

    # 启动服务器
    var success = sensor_server.start_server()
    if success:
        _update_status("等待手机连接... (端口49555)", Color.YELLOW)
    else:
        _update_status("服务器启动失败!", Color.RED)


func _setup_ui():
    """设置UI连接"""
    if calibrate_button:
        calibrate_button.pressed.connect(_on_calibrate_button_pressed)
    if confirm_button:
        confirm_button.pressed.connect(_on_confirm_button_pressed)
        confirm_button.disabled = true
    if start_button:
        start_button.pressed.connect(_on_start_button_pressed)
    if reset_button:
        reset_button.pressed.connect(_on_reset_button_pressed)


func _create_environment():
    """创建3D环境"""

    # 相机
    var camera = Camera3D.new()
    camera.name = "Camera3D"
    camera.position = Vector3(0, 1.8, 2.0)  # 靠近球台以便看清球拍
    camera.rotation = Vector3(-0.4, 0, 0)   # 稍微俯视
    add_child(camera)

    # 灯光
    var light = DirectionalLight3D.new()
    light.name = "DirectionalLight"
    light.position = Vector3(5, 10, 5)
    light.look_at(Vector3.ZERO)
    light.shadow_enabled = true
    add_child(light)

    # 环境光
    var world_env = WorldEnvironment.new()
    world_env.name = "WorldEnvironment"
    var env = Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color(0.1, 0.1, 0.15)
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color(0.3, 0.3, 0.4)
    world_env.environment = env
    add_child(world_env)

    # 地面网格
    _create_ground_grid()

    # 球台
    _create_table()


func _create_ground_grid():
    """创建地面网格"""
    for i in range(-10, 11):
        _create_line(Vector3(i, 0, -10), Vector3(i, 0, 10), Color(0.3, 0.3, 0.3, 0.5))
        _create_line(Vector3(-10, 0, i), Vector3(10, 0, i), Color(0.3, 0.3, 0.3, 0.5))


func _create_line(start: Vector3, end: Vector3, color: Color):
    """创建线条"""
    var mesh_instance = MeshInstance3D.new()
    var mesh = ImmediateMesh.new()
    mesh_instance.mesh = mesh

    mesh.surface_begin(Mesh.PRIMITIVE_LINES)
    mesh.surface_set_color(color)
    mesh.surface_add_vertex(start)
    mesh.surface_add_vertex(end)
    mesh.surface_end()

    var material = StandardMaterial3D.new()
    material.albedo_color = color
    mesh_instance.material_override = material

    add_child(mesh_instance)


func _create_table():
    """创建球台"""
    # 球台面
    var table_mesh = BoxMesh.new()
    table_mesh.size = Vector3(1.525, 0.05, 2.74)  # 标准乒乓球台尺寸

    var table_material = StandardMaterial3D.new()
    table_material.albedo_color = Color(0.1, 0.4, 0.2)  # 绿色球台
    table_material.roughness = 0.6

    var table = MeshInstance3D.new()
    table.name = "Table"
    table.mesh = table_mesh
    table.material_override = table_material
    table.position = Vector3(0, 0.76, 0)  # 标准高度76cm
    add_child(table)

    # 球网
    var net_mesh = BoxMesh.new()
    net_mesh.size = Vector3(1.525, 0.1525, 0.01)

    var net_material = StandardMaterial3D.new()
    net_material.albedo_color = Color(0.9, 0.9, 0.9, 0.5)
    net_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

    var net = MeshInstance3D.new()
    net.name = "Net"
    net.mesh = net_mesh
    net.material_override = net_material
    net.position = Vector3(0, 0.76 + 0.07625, 0)
    add_child(net)


func _process(delta):
    frame_count += 1

    # 更新连接状态显示
    if sensor_server and frame_count % 60 == 0:
        var stats = sensor_server.get_stats()
        if stats.packets_received > 0:
            var status_text = "已连接 | 接收: %d 包 | %.1f 包/秒" % [
                stats.packets_received, stats.packet_rate
            ]
            _update_status(status_text, Color.GREEN)


func _on_sensor_data_received(data):
    """传感器数据接收回调"""
    # 数据融合
    var motion_data = sensor_fusion.process_sensor_data(
        data.linear_accel,
        data.quaternion,
        1.0 / 60.0
    )

    last_sensor_data = motion_data

    # 更新球拍
    if player_paddle:
        var calibrated_quat = paddle_calibration.apply_calibration(motion_data.quaternion)
        player_paddle.set_rotation_from_quaternion(calibrated_quat)
        player_paddle.set_position_from_acceleration(motion_data.linear_accel, 1.0 / 60.0)


func _on_calibration_started():
    """校准开始"""
    is_calibrating = true
    _update_status("请保持标准姿势，按确认完成校准", Color.YELLOW)
    if calibrate_button:
        calibrate_button.disabled = true
    if confirm_button:
        confirm_button.disabled = false
    if debug_label:
        debug_label.text = "校准说明:\n请将手机保持标准握持姿势，然后按确认按钮完成校准"


func _on_calibration_completed(success: bool, offset: Quaternion):
    """校准完成"""
    is_calibrating = false
    if success:
        _update_status("校准完成!", Color.GREEN)
        if player_paddle:
            player_paddle.set_calibration_offset(offset)
    else:
        _update_status("校准失败", Color.RED)

    if calibrate_button:
        calibrate_button.disabled = false
        calibrate_button.text = "开始校准"
    if confirm_button:
        confirm_button.disabled = true


func _on_calibrate_button_pressed():
    """校准按钮按下"""
    if not is_calibrating:
        paddle_calibration.start_calibration()
        if calibrate_button:
            calibrate_button.text = "校准中..."


func _on_confirm_button_pressed():
    """确认按钮按下"""
    if is_calibrating and last_sensor_data:
        paddle_calibration.record_calibration_sample(
            last_sensor_data.quaternion,
            last_sensor_data.linear_accel
        )


func _on_start_button_pressed():
    """开始游戏按钮按下"""
    if ball:
        ball.activate(Vector3(0, 1.5, 0))
        # 给球一个初始速度
        ball.current_velocity = Vector3(randf_range(-1, 1), 0, randf_range(3, 5))
        _update_status("游戏开始!", Color.GREEN)


func _on_reset_button_pressed():
    """重置按钮按下"""
    if player_paddle:
        player_paddle.reset()
    if ball:
        ball.reset(Vector3(0, 1.5, 0))
    _update_status("已重置", Color.WHITE)


func _update_status(text: String, color: Color):
    """更新状态标签"""
    if status_label:
        status_label.text = "状态: " + text
        status_label.modulate = color


func _input(event):
    """输入处理"""
    if event is InputEventKey and event.pressed:
        match event.keycode:
            KEY_K:
                _on_calibrate_button_pressed()
            KEY_ENTER:
                _on_confirm_button_pressed()
            KEY_SPACE:
                _on_start_button_pressed()
            KEY_R:
                _on_reset_button_pressed()
            KEY_ESCAPE:
                get_tree().quit()


func _exit_tree():
    """退出时清理"""
    if sensor_server:
        sensor_server.stop_server()
