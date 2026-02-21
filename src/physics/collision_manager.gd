class_name CollisionManager
extends Node3D

## 碰撞管理器
## 处理球与球拍、球台、球网之间的碰撞检测

# 信号
signal paddle_hit(paddle: Node3D, ball: Node3D, hit_point: Vector3)
signal table_bounce(ball: Node3D, bounce_point: Vector3, is_valid: bool)
signal net_collision(ball: Node3D, contact_point: Vector3)
signal ball_out_of_bounds(ball: Node3D, position: Vector3)

# 碰撞层定义
enum CollisionLayer {
    BALL = 1,
    PADDLE = 2,
    TABLE = 4,
    NET = 8,
    WALL = 16
}

# 场景对象引用
@export var ball: Node3D = null
@export var player_paddle: Node3D = null
@export var ai_paddle: Node3D = null
@export var table: Node3D = null
@export var net: Node3D = null

# 碰撞检测参数
@export_group("Collision Detection")
@export var continuous_collision_steps: int = 4  # 连续碰撞检测步数
@export var hit_sphere_radius: float = 0.15      # 击球范围半径 (米)
@export var table_height: float = 0.76           # 球台高度

# 击球判定参数
@export_group("Hit Detection")
@export var pre_hit_window: float = 0.1          # 提前判定窗口 (秒)
@export var post_hit_window: float = 0.05        # 延后判定窗口 (秒)
@export var min_approach_velocity: float = 1.0   # 最小接近速度

# 状态
var hit_cooldown: float = 0.0
const HIT_COOLDOWN_TIME: float = 0.2

# 帧计数
var frame_count := 0


func _ready():
    print("[CollisionManager] 碰撞管理器已初始化")
    _find_scene_objects()


func _physics_process(delta: float):
    if ball == null:
        return
    # 检查球是否激活（通过has_method检查，因为ball是Node3D类型）
    if ball.has_method("is_active") and not ball.is_active:
        return
    if ball.has_method("get") and not ball.get("is_active"):
        return

    frame_count += 1

    # 更新冷却时间
    if hit_cooldown > 0:
        hit_cooldown -= delta

    # 连续碰撞检测
    for i in range(continuous_collision_steps):
        _check_paddle_collision()
        _check_table_collision()
        _check_net_collision()
        _check_boundary_collision()


## 查找场景中的对象
func _find_scene_objects():
    # 尝试自动查找
    if ball == null:
        ball = get_node_or_null("../Ball")
    if player_paddle == null:
        player_paddle = get_node_or_null("../PlayerPaddle")
    if ai_paddle == null:
        ai_paddle = get_node_or_null("../AIPaddle")
    if table == null:
        table = get_node_or_null("../Table")
    if net == null:
        net = get_node_or_null("../Net")


## 获取球的半径（安全访问）
func _get_ball_radius() -> float:
    if ball.has_method("get"):
        var r = ball.get("ball_radius")
        if r != null:
            return r
    return 0.02  # 默认半径

## 获取球的速度（安全访问）
func _get_ball_velocity() -> Vector3:
    if ball.has_method("get"):
        var v = ball.get("current_velocity")
        if v != null:
            return v
    return Vector3.ZERO

## 获取球的属性（安全访问）
func _get_ball_property(prop_name: String, default_value):
    if ball.has_method("get"):
        var val = ball.get(prop_name)
        if val != null:
            return val
    return default_value

## 检测球与球拍碰撞
func _check_paddle_collision():
    if ball == null:
        return

    var ball_pos = ball.global_position
    var ball_radius = _get_ball_radius()
    var ball_velocity = _get_ball_velocity()

    # 玩家球拍
    if player_paddle != null and hit_cooldown <= 0:
        var paddle_hit_point = _get_paddle_hit_point(player_paddle)
        var distance = ball_pos.distance_to(paddle_hit_point)

        if distance <= (ball_radius + hit_sphere_radius):
            # 检查球是否正在接近球拍
            var to_paddle = (paddle_hit_point - ball_pos).normalized()
            var approach_speed = ball_velocity.dot(to_paddle)

            if approach_speed > min_approach_velocity:
                _execute_hit(player_paddle, paddle_hit_point)

    # AI球拍
    if ai_paddle != null and hit_cooldown <= 0:
        var paddle_hit_point = _get_paddle_hit_point(ai_paddle)
        var distance = ball_pos.distance_to(paddle_hit_point)

        if distance <= (ball_radius + hit_sphere_radius):
            var to_paddle = (paddle_hit_point - ball_pos).normalized()
            var approach_speed = ball_velocity.dot(to_paddle)

            if approach_speed > min_approach_velocity:
                _execute_hit(ai_paddle, paddle_hit_point)


## 获取球拍击球点位置
func _get_paddle_hit_point(paddle: Node3D) -> Vector3:
    if paddle.has_method("get_hit_point"):
        return paddle.get_hit_point()

    # 默认返回球拍前方
    return paddle.global_position + paddle.global_transform.basis.z * 0.1


## 执行击球
func _execute_hit(paddle: Node3D, hit_point: Vector3):
    hit_cooldown = HIT_COOLDOWN_TIME

    # 计算击球参数
    var hit_direction = _calculate_hit_direction(paddle)
    var hit_force = _calculate_hit_force(paddle)
    var spin = _calculate_spin(paddle)

    # 获取球拍速度
    var paddle_velocity = Vector3.ZERO
    if paddle.has_method("get_current_velocity"):
        paddle_velocity = paddle.get_current_velocity()

    # 应用到球（安全调用）
    if ball.has_method("on_paddle_hit"):
        ball.on_paddle_hit(hit_direction, hit_force, spin, paddle_velocity)

    emit_signal("paddle_hit", paddle, ball, hit_point)

    if frame_count % 60 == 0:
        print("[CollisionManager] 击球执行 | 力度: %.2f" % hit_force)


## 计算击球方向
func _calculate_hit_direction(paddle: Node3D) -> Vector3:
    # 基于球拍朝向
    var paddle_forward = -paddle.global_transform.basis.z

    # 添加上升角度 (确保球过网)
    var final_direction = paddle_forward
    final_direction.y = max(final_direction.y, 0.2)

    return final_direction.normalized()


## 计算击球力度
func _calculate_hit_force(paddle: Node3D) -> float:
    var base_force = 10.0

    # 如果球拍有挥拍力度，使用它
    if paddle.has_method("get_swing_power"):
        var power = paddle.get_swing_power()
        return base_force * (1.0 + power * 2.0)

    return base_force


## 计算旋转
func _calculate_spin(paddle: Node3D) -> Vector3:
    var spin = Vector3.ZERO

    # 如果球拍有速度，基于速度计算旋转
    if paddle.has_method("get_current_velocity"):
        var paddle_vel = paddle.get_current_velocity()
        var paddle_normal = -paddle.global_transform.basis.z
        var tangent = paddle_vel - paddle_normal * paddle_vel.dot(paddle_normal)

        # 旋转轴垂直于切向和法向
        spin = tangent.cross(paddle_normal).normalized() * tangent.length() * 0.5

    return spin


## 检测球与球台碰撞
func _check_table_collision():
    if ball == null or table == null:
        return

    var ball_pos = ball.global_position
    var ball_radius = _get_ball_radius()
    var ball_velocity = _get_ball_velocity()
    var ball_bottom = ball_pos.y - ball_radius

    # 检查是否在球台范围内
    if _is_on_table(ball_pos):
        # 检查高度 (球台表面高度)
        if ball_bottom <= table_height and ball_velocity.y < 0:
            # 反弹处理
            var bounce_point = Vector3(ball_pos.x, table_height, ball_pos.z)

            # 计算反弹
            _process_table_bounce(bounce_point)

            # 判定有效性
            var is_valid = _is_valid_bounce(bounce_point)

            emit_signal("table_bounce", ball, bounce_point, is_valid)


## 检查是否在球台范围内
func _is_on_table(point: Vector3) -> bool:
    # 标准乒乓球台尺寸: 2.74m x 1.525m
    var half_width = 1.525 / 2
    var half_length = 2.74 / 2

    return abs(point.x) <= half_width and abs(point.z) <= half_length


## 检查是否为有效反弹
func _is_valid_bounce(point: Vector3) -> bool:
    # 简化版：只要在球台范围内就有效
    # 实际应该根据游戏规则判断（如是否二次反弹等）
    return _is_on_table(point)


## 处理球台反弹
func _process_table_bounce(bounce_point: Vector3):
    # 安全获取球属性
    var current_velocity = _get_ball_velocity()
    var current_spin = _get_ball_property("current_spin", Vector3.ZERO)
    var ball_radius = _get_ball_radius()
    var table_restitution = _get_ball_property("table_restitution", 0.85)
    var table_friction = _get_ball_property("table_friction", 0.3)

    # 速度分解为法向和切向
    var normal = Vector3.UP
    var normal_component = normal * current_velocity.dot(normal)
    var tangent_component = current_velocity - normal_component

    # 法向反弹
    var new_normal = -normal_component * table_restitution

    # 切向摩擦
    var spin_effect = current_spin.cross(normal) * ball_radius
    var new_tangent = (tangent_component + spin_effect) * (1.0 - table_friction)

    # 更新旋转
    var new_spin = current_spin - tangent_component.cross(normal) * table_friction / ball_radius

    # 合成新速度
    var new_velocity = new_normal + new_tangent

    # 设置回球对象（安全调用）
    if ball.has_method("set"):
        ball.set("current_velocity", new_velocity)
        ball.set("current_spin", new_spin)

    # 修正位置
    ball.global_position.y = table_height + ball_radius + 0.001


## 检测球与球网碰撞
func _check_net_collision():
    if ball == null or net == null:
        return

    var ball_pos = ball.global_position

    # 球网位置 (球台中央)
    var net_z = 0.0
    var net_height = 0.1525  # 标准球网高度 15.25cm

    # 检查是否在球网附近
    if abs(ball_pos.z - net_z) < 0.05 and ball_pos.y < net_height + 0.1:
        var distance_to_net = abs(ball_pos.z - net_z)

        var ball_radius = _get_ball_radius()
        if distance_to_net <= ball_radius:
            # 球网碰撞处理
            var net_normal = Vector3.FORWARD if ball_pos.z > 0 else Vector3.BACK
            var current_velocity = _get_ball_velocity()
            var net_restitution = _get_ball_property("net_restitution", 0.1)
            var new_velocity = current_velocity.bounce(net_normal) * net_restitution

            if ball.has_method("set"):
                ball.set("current_velocity", new_velocity)

            emit_signal("net_collision", ball, ball_pos)

            if frame_count % 60 == 0:
                print("[CollisionManager] 球击中球网")


## 检测边界碰撞
func _check_boundary_collision():
    if ball == null:
        return

    var ball_pos = ball.global_position

    # 地面检测 (出界)
    if ball_pos.y < -0.5:
        emit_signal("ball_out_of_bounds", ball, ball_pos)
        if ball.has_method("deactivate"):
            ball.deactivate()
        return

    # 墙壁检测
    if ball_pos.x < -10 or ball_pos.x > 10 or ball_pos.z < -10 or ball_pos.z > 10:
        emit_signal("ball_out_of_bounds", ball, ball_pos)
        if ball.has_method("deactivate"):
            ball.deactivate()
        return


## 设置碰撞对象
func set_ball(new_ball: Node3D):
    ball = new_ball

func set_player_paddle(paddle: Node3D):
    player_paddle = paddle

func set_ai_paddle(paddle: Node3D):
    ai_paddle = paddle

func set_table(new_table: Node3D):
    table = new_table

func set_net(new_net: Node3D):
    net = new_net


## 重置碰撞管理器
func reset():
    hit_cooldown = 0.0
    frame_count = 0
