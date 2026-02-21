# 混合现实乒乓球游戏设计文档 (GDD)

**版本**: 1.0
**日期**: 2026-02-21
**引擎**: Godot 4.6
**目标平台**: PC (显示端) + Android (传感器端)

---

## 1. 核心玩法设计

### 1.1 游戏概述

混合现实乒乓球游戏是一款创新的体育竞技游戏，玩家将真实手机握在手中当作球拍，通过传感器数据控制虚拟球拍，在PC大屏幕前与AI对手进行乒乓球对战。

### 1.2 游戏流程

```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│  主菜单     │───▶│  校准流程   │───▶│  游戏对战   │───▶│  结算界面   │
│  Main Menu  │    │ Calibration │    │   Match     │    │   Result    │
└─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘
                                              │
                                              ▼
                                       ┌─────────────┐
                                       │  暂停菜单   │
                                       │   Pause     │
                                       └─────────────┘
```

#### 详细流程说明

| 阶段 | 说明 | 时长 |
|------|------|------|
| **主菜单** | 选择游戏模式、难度、查看教程 | 玩家控制 |
| **校准流程** | 玩家对准虚拟球拍位置，确认传感器零点 | 约30秒 |
| **发球阶段** | 玩家挥拍发球或AI发球 | 约3秒 |
| **对打阶段** | 双方来回击球，球速逐渐加快 | 5-30秒/回合 |
| **得分判定** | 球出界/未接到/触网 | 即时 |
| **回合间歇** | 显示比分，短暂休息 | 2秒 |
| **结算界面** | 显示最终比分、统计、返回菜单 | 玩家控制 |

### 1.3 胜负判定

#### 计分规则
- **比赛制度**: 11分制，先得11分且领先2分者获胜
- **平局处理**: 10:10后，需领先2分才能获胜（如12:10, 13:11）
- **时间限制**: 单局最长5分钟，超时则分数高者获胜

#### 得分条件
| 情况 | 得分方 | 说明 |
|------|--------|------|
| 对方未接到球 | 击球方 | 球在对方半台弹起后未被击中 |
| 球出界 | 对方 | 球落在球台外或触网后出界 |
| 连击犯规 | 对方 | 同一方连续击球两次 |
| 持球犯规 | 对方 | 球在球拍上停留超过0.5秒 |

### 1.4 难度曲线设计

#### 难度分级

| 难度 | AI反应速度 | AI移动速度 | 回球精度 | 旋转变化 | 适合人群 |
|------|-----------|-----------|---------|---------|---------|
| **简单** | 0.4s | 1.5 m/s | 60% | 无 | 新手/儿童 |
| **普通** | 0.25s | 2.5 m/s | 75% | 轻微 | 休闲玩家 |
| **困难** | 0.15s | 4.0 m/s | 90% | 中等 | 熟练玩家 |
| **专家** | 0.08s | 6.0 m/s | 98% | 强烈 | 硬核玩家 |

#### 动态难度调整 (DDA)
- 根据玩家连续得分/失分情况微调AI参数
- 连续得分3球：AI反应速度+10%
- 连续失分3球：AI反应速度-10%
- 单局最大调整幅度：±20%

---

## 2. 球拍控制方案（关键技术设计）

### 2.1 传感器数据输入

#### 数据格式
```json
{
  "user_accel": {"x": 0.0, "y": 0.0, "z": 0.0},  // 线性加速度 (m/s²)
  "quaternion": {"x": 0.0, "y": 0.0, "z": 0.0, "w": 1.0}  // 旋转四元数
}
```

#### 数据流架构
```
手机传感器 ──▶ Android采集 ──▶ UDP传输(60fps) ──▶ Godot接收 ──▶ 数据处理 ──▶ 球拍控制
```

### 2.2 位置追踪系统

#### 2.2.1 核心问题
**惯性导航的漂移问题**：加速度双重积分会产生累积误差，导致位置计算快速发散。

#### 2.2.2 弹性回中算法（推荐方案）

基于现有代码实现的位置计算方案：

```gdscript
# 弹性回中位置更新算法
func _update_paddle_position(delta: float):
    # 1. 转换加速度到Godot坐标系
    var godot_accel = convert_vector_to_godot(user_accel_data)

    # 2. 速度积分
    velocity += godot_accel * delta

    # 3. 高阻力衰减 - 快速消除漂移
    velocity = velocity.lerp(Vector3.ZERO, friction * delta)

    # 4. 位置积分
    paddle_position += velocity * delta

    # 5. 弹性回中 - 始终向中心点回归
    paddle_position = paddle_position.lerp(origin_position, return_speed * delta)

    # 6. 限制最大位移范围
    paddle_position.x = clamp(paddle_position.x, -max_displacement, max_displacement)
    paddle_position.y = clamp(paddle_position.y, 0.0, max_displacement)
    paddle_position.z = clamp(paddle_position.z, -max_displacement, max_displacement)
```

#### 2.2.3 参数配置

| 参数 | 默认值 | 说明 | 调整建议 |
|------|--------|------|---------|
| `friction` | 5.0 | 速度衰减系数 | 值越大，挥拍后越快停止 |
| `return_speed` | 2.0 | 回中速度 | 值越大，球拍越"粘"在中心 |
| `max_displacement` | 5.0 | 最大位移(m) | 根据球台尺寸调整 |

#### 2.2.4 位置映射关系

```
手机物理运动          虚拟球拍位置
─────────────        ─────────────
向前挥动    ───────▶  球拍向前移动 (Z+)
向后拉回    ───────▶  球拍向后移动 (Z-)
向左移动    ───────▶  球拍向左移动 (X-)
向右移动    ───────▶  球拍向右移动 (X+)
向上举起    ───────▶  球拍向上移动 (Y+)
向下压低    ───────▶  球拍向下移动 (Y-)
```

### 2.3 旋转同步系统

#### 2.3.1 四元数映射

Android传感器四元数到Godot坐标系的转换：

```gdscript
func convert_quaternion_to_godot(q: Quaternion) -> Quaternion:
    """将Android坐标系的四元数转换为Godot坐标系

    Android坐标系:
    - X: 手机右侧为正
    - Y: 手机顶部为正
    - Z: 屏幕朝向用户为正

    Godot坐标系:
    - X: 右
    - Y: 上
    - Z: 后（屏幕向里）
    """
    return Quaternion(q.x, q.y, q.z, q.w).normalized()
```

#### 2.3.2 球拍姿态映射

```
手机握持方式          虚拟球拍姿态
─────────────        ─────────────
屏幕朝上平放  ───────▶  球拍面水平（准备姿势）
屏幕朝前竖握  ───────▶  球拍面竖直（击球姿势）
向左倾斜    ───────▶  球拍面向左倾斜（切球）
向右倾斜    ───────▶  球拍面向右倾斜（切球）
向前翻转    ───────▶  球拍面前倾（扣杀）
向后翻转    ───────▶  球拍面后仰（挑球）
```

#### 2.3.3 校准偏移

```gdscript
# 校准：将当前姿态设为零点
calibration_offset = convert_quaternion_to_godot(current_rotation).inverse()

# 应用校准后的旋转
var raw_rotation = convert_quaternion_to_godot(current_rotation)
var final_rotation = calibration_offset * raw_rotation
paddle.quaternion = final_rotation
```

### 2.4 击球判定系统

#### 2.4.1 击球检测逻辑

```gdscript
# 击球判定参数
const HIT_COOLDOWN := 0.3  # 击球冷却时间(秒)
const MIN_HIT_SPEED := 2.0  # 最小击球速度(m/s)
const HIT_DISTANCE := 0.5   # 有效击球距离(m)

var last_hit_time := 0.0
var ball: RigidBody3D

func check_hit(delta: float) -> bool:
    var current_time = Time.get_time_dict_from_system()["second"]

    # 冷却检查
    if current_time - last_hit_time < HIT_COOLDOWN:
        return false

    # 距离检查
    var distance = paddle_position.distance_to(ball.position)
    if distance > HIT_DISTANCE:
        return false

    # 速度检查 - 检测挥拍动作
    var paddle_speed = velocity.length()
    if paddle_speed < MIN_HIT_SPEED:
        return false

    # 方向检查 - 确保球拍朝向球
    var to_ball = (ball.position - paddle_position).normalized()
    var paddle_forward = -paddle.transform.basis.z
    var dot = paddle_forward.dot(to_ball)

    if dot < 0.5:  # 角度大于60度
        return false

    # 击球成功
    last_hit_time = current_time
    return true
```

#### 2.4.2 击球力量计算

```gdscript
func calculate_hit_power() -> Dictionary:
    var accel_mag = user_accel_data.length()
    var velocity_mag = velocity.length()

    # 基础力量 = 加速度贡献 + 速度贡献
    var base_power = accel_mag * 0.3 + velocity_mag * 0.7

    # 归一化到0-1范围
    var normalized_power = clamp(base_power / 15.0, 0.0, 1.0)

    # 力量分级
    var power_level: String
    match normalized_power:
        var p when p < 0.3: power_level = "light"
        var p when p < 0.6: power_level = "medium"
        var p when p < 0.85: power_level = "heavy"
        _: power_level = "smash"

    return {
        "power": normalized_power,
        "level": power_level,
        "speed": 5.0 + normalized_power * 15.0  // 5-20 m/s
    }
```

#### 2.4.3 击球方向计算

```gdscript
func calculate_hit_direction() -> Vector3:
    # 基础方向：球拍法线方向
    var base_direction = -paddle.transform.basis.z

    # 根据挥拍速度添加偏移（控制落点）
    var velocity_influence = velocity.normalized() * 0.3

    # 根据球拍倾斜角度添加旋转
    var tilt = paddle.rotation_degrees
    var spin_effect = Vector3(
        -tilt.z * 0.01,  # 左右倾斜影响左右旋
        tilt.x * 0.01,   # 前后倾斜影响上下旋
        0
    )

    var final_direction = (base_direction + velocity_influence + spin_effect).normalized()
    return final_direction
```

### 2.5 校准方案

#### 2.5.1 姿态校准流程

```
步骤1: 标准平放
   - 手机平放在桌面，屏幕朝上
   - 底部朝向玩家
   - 记录基准四元数

步骤2: 向右旋转
   - 保持平放，向右旋转90度
   - 记录右侧姿态

步骤3: 向左旋转
   - 保持平放，向左旋转90度
   - 记录左侧姿态

步骤4: 竖直握持
   - 竖直握持手机，屏幕朝向玩家
   - 记录击球姿态

步骤5: 计算转换矩阵
   - 基于采样数据计算校准矩阵
   - 保存校准数据
```

#### 2.5.2 位置校准

```gdscript
func calibrate_position():
    # 让玩家将球拍放在"准备位置"
    # 通常是在身体前方，腰部高度

    origin_position = paddle_position

    # 显示提示：请保持球拍在准备位置，点击确认
    # 记录此时位置为原点
```

#### 2.5.3 实时微调

游戏中提供实时校准快捷键：
- **R键**: 重置位置和视角
- **K键**: 重新校准姿态
- **按住空格**: 临时冻结球拍位置（用于调整握持）

---

## 3. AI对手设计

### 3.1 AI架构

```
AI控制器
├── 感知模块 (Perception)
│   ├── 球位置追踪
│   ├── 球速度预测
│   └── 玩家行为分析
├── 决策模块 (Decision)
│   ├── 移动决策
│   ├── 击球时机
│   └── 回球策略
└── 执行模块 (Execution)
    ├── 移动控制
    ├── 击球动作
    └── 动画触发
```

### 3.2 行为模式

#### 3.2.1 站位系统

| 站位 | 位置 | 适用情况 |
|------|------|---------|
| **中心站位** | (0, 0, -4.5) | 默认站位，准备接任何球 |
| **偏左站位** | (-1, 0, -4.5) | 预测玩家打正手 |
| **偏右站位** | (1, 0, -4.5) | 预测玩家打反手 |
| **近台站位** | (0, 0, -3.5) | 准备接短球/扣杀 |
| **远台站位** | (0, 0, -5.5) | 准备接高球/防守 |

#### 3.2.2 移动策略

```gdscript
func update_ai_movement(delta: float):
    # 预测球落点
    var predicted_landing = predict_ball_landing()

    # 计算目标位置
    var target_position = calculate_optimal_position(predicted_landing)

    # 平滑移动
    var direction = (target_position - ai_position).normalized()
    var distance = ai_position.distance_to(target_position)

    # 根据难度调整移动速度
    var move_speed = difficulty.move_speed * (1.0 + distance * 0.1)

    ai_position += direction * min(move_speed * delta, distance)
```

### 3.3 难度参数详解

#### 简单难度
```gdscript
var easy_difficulty = {
    "reaction_time": 0.4,      # 反应延迟
    "move_speed": 1.5,         # 移动速度 (m/s)
    "accuracy": 0.6,           # 回球精度 (0-1)
    "spin_capability": false,  # 是否使用旋转
    "error_rate": 0.15,        # 失误率
    "aggressiveness": 0.2      # 进攻倾向
}
```

#### 普通难度
```gdscript
var normal_difficulty = {
    "reaction_time": 0.25,
    "move_speed": 2.5,
    "accuracy": 0.75,
    "spin_capability": true,
    "spin_strength": 0.3,
    "error_rate": 0.08,
    "aggressiveness": 0.4
}
```

#### 困难难度
```gdscript
var hard_difficulty = {
    "reaction_time": 0.15,
    "move_speed": 4.0,
    "accuracy": 0.9,
    "spin_capability": true,
    "spin_strength": 0.7,
    "error_rate": 0.03,
    "aggressiveness": 0.7,
    "prediction": true  # 预测玩家击球方向
}
```

### 3.4 击球决策逻辑

#### 3.4.1 击球类型选择

```gdscript
enum HitType {
    FLAT,       # 平击
    TOPSPIN,    # 上旋
    BACKSPIN,   # 下旋
    SIDESPIN,   # 侧旋
    SMASH,      # 扣杀
    PUSH        # 推挡
}

func select_hit_type(ball_state: Dictionary) -> HitType:
    var ball_height = ball_state["position"].y
    var ball_speed = ball_state["velocity"].length()
    var distance_to_net = ball_state["position"].z + 2.75

    # 高球扣杀机会
    if ball_height > 1.5 and ball_speed < 10:
        return HitType.SMASH

    # 近网短球
    if distance_to_net < 1.0 and ball_height < 0.3:
        return HitType.PUSH

    # 根据难度随机选择旋转
    if difficulty.spin_capability and randf() < 0.5:
        var spin_types = [HitType.TOPSPIN, HitType.BACKSPIN, HitType.SIDESPIN]
        return spin_types[randi() % spin_types.size()]

    return HitType.FLAT
```

#### 3.4.2 回球落点选择

```gdscript
func select_target_landing() -> Vector3:
    var targets = [
        Vector3(-1.2, 0, 2.75),   # 左角
        Vector3(1.2, 0, 2.75),    # 右角
        Vector3(0, 0, 1.5),       # 近网
        Vector3(0, 0, 2.75),      # 深球
        Vector3(-0.8, 0, 2.0),    # 左中
        Vector3(0.8, 0, 2.0)      # 右中
    ]

    # 根据难度选择精度
    var target = targets[randi() % targets.size()]

    # 添加随机偏移
    var accuracy = difficulty.accuracy
    var offset = Vector3(
        (randf() - 0.5) * 2.0 * (1.0 - accuracy),
        0,
        (randf() - 0.5) * 2.0 * (1.0 - accuracy)
    )

    return target + offset
```

---

## 4. 物理系统设计

### 4.1 球的物理属性

| 属性 | 值 | 说明 |
|------|-----|------|
| 质量 | 2.7g | 标准乒乓球质量 |
| 直径 | 40mm | 标准乒乓球直径 |
| 重力加速度 | 9.8 m/s² | 标准重力 |
| 空气阻力系数 | 0.47 | 球体阻力系数 |
| 弹性系数 | 0.85 | 球与球台/球拍碰撞 |

### 4.2 球速范围

| 击球类型 | 速度范围 | 典型速度 |
|---------|---------|---------|
| 轻推 | 3-6 m/s | 4 m/s |
| 普通回球 | 6-10 m/s | 8 m/s |
| 发力击球 | 10-15 m/s | 12 m/s |
| 扣杀 | 15-20 m/s | 18 m/s |
| 极限扣杀 | 20-25 m/s | 22 m/s |

### 4.3 旋转效果

#### 旋转类型与物理影响

| 旋转类型 | 角速度 | 物理效果 |
|---------|--------|---------|
| 无旋转 | 0 | 标准抛物线轨迹 |
| 轻微上旋 | 10-30 rad/s | 球落地后向前加速 |
| 强烈上旋 | 30-60 rad/s | 明显前冲，弧线低平 |
| 轻微下旋 | 10-30 rad/s | 球落地后向后减速 |
| 强烈下旋 | 30-60 rad/s | 明显回跳，弧线较高 |
| 侧旋 | 20-50 rad/s | 横向偏移轨迹 |

#### 马格努斯效应计算

```gdscript
func apply_magnus_effect(ball: RigidBody3D, angular_velocity: Vector3):
    var velocity = ball.linear_velocity
    var magnus_force = angular_velocity.cross(velocity) * MAGNUS_COEFFICIENT
    ball.apply_central_force(magnus_force)
```

### 4.4 球拍击球物理

#### 击球公式

```gdscript
func apply_hit(ball: RigidBody3D, hit_info: Dictionary):
    var direction = hit_info["direction"]
    var speed = hit_info["speed"]
    var spin = hit_info["spin"]

    # 设置线速度
    ball.linear_velocity = direction * speed

    # 设置角速度（旋转）
    ball.angular_velocity = spin

    # 播放击球音效和特效
    play_hit_effect(hit_info["power_level"])
```

#### 击球力量与球速关系

| 挥拍加速度 | 挥拍速度 | 输出球速 | 球拍反弹系数 |
|-----------|---------|---------|-------------|
| < 5 m/s² | < 2 m/s | 5-8 m/s | 0.6 |
| 5-10 m/s² | 2-4 m/s | 8-12 m/s | 0.7 |
| 10-20 m/s² | 4-7 m/s | 12-18 m/s | 0.8 |
| > 20 m/s² | > 7 m/s | 18-25 m/s | 0.9 |

### 4.5 球台反弹物理

#### 反弹参数

```gdscript
const TABLE_RESTITUTION = 0.85  # 弹性系数
const TABLE_FRICTION = 0.3      # 摩擦系数

func on_ball_hit_table(ball: RigidBody3D, collision_normal: Vector3):
    var velocity = ball.linear_velocity

    # 分解速度
    var normal_component = collision_normal * velocity.dot(collision_normal)
    var tangent_component = velocity - normal_component

    # 应用弹性系数
    var new_normal = -normal_component * TABLE_RESTITUTION

    # 应用摩擦（影响切向速度）
    var new_tangent = tangent_component * (1.0 - TABLE_FRICTION)

    ball.linear_velocity = new_normal + new_tangent
```

#### 球台区域划分

```
        球台俯视图 (2.74m x 1.525m)

        ┌─────────────────────────────┐  ← 端线 (Z = 2.75)
        │  左区   │   中区   │  右区  │
        │ (-X)   │   (0)   │  (+X)  │
        │        │         │        │
        ├────────┼─────────┼────────┤  ← 中线
        │        │         │        │
        │        │  球网   │        │  ← 球网位置 (Z = 0)
        │        │         │        │
        ├────────┼─────────┼────────┤
        │        │         │        │
        │  左区   │   中区   │  右区  │
        │ (-X)   │   (0)   │  (+X)  │
        └─────────────────────────────┘  ← 端线 (Z = -2.75)

        玩家位置: Z ≈ 4.0
        AI位置: Z ≈ -4.0
```

---

## 5. UI/UX设计

### 5.1 主菜单布局

```
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│                    [游戏LOGO]                               │
│              混合现实乒乓球                                  │
│                                                             │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│                    [开始游戏]  ← 默认选中                    │
│                                                             │
│                    [难度选择]                                │
│                     ○ 简单  ● 普通  ○ 困难                   │
│                                                             │
│                    [教程]                                    │
│                                                             │
│                    [设置]                                    │
│                                                             │
│                    [退出]                                    │
│                                                             │
├─────────────────────────────────────────────────────────────┤
│  状态: 等待手机连接...  [连接状态指示灯]                      │
└─────────────────────────────────────────────────────────────┘
```

### 5.2 HUD元素（游戏界面）

```
┌─────────────────────────────────────────────────────────────┐
│  [玩家得分] 11                    09 [AI得分]              │
│                                                             │
│  [回合数] 第3回合                     [难度:普通]           │
│                                                             │
│                                                             │
│                                                             │
│                                                             │
│                                                             │
│                    [3D游戏场景]                              │
│                                                             │
│                                                             │
│                                                             │
│                                                             │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  击球力量: [████████░░] 80%                         │   │
│  │  球拍速度: 5.2 m/s                                  │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
│  [R:重置] [K:校准] [ESC:暂停]                              │
└─────────────────────────────────────────────────────────────┘
```

### 5.3 校准流程UI

```
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│                    姿态校准                                  │
│                                                             │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  步骤 1/4: 标准平放                                          │
│                                                             │
│  ┌─────────────────────────┐                                │
│  │                         │                                │
│  │    [手机示意图]          │  ← 动画演示正确姿势            │
│  │                         │                                │
│  └─────────────────────────┘                                │
│                                                             │
│  请将手机平放在桌面上，屏幕向上，                            │
│  底部朝向你自己，然后点击确定                                │
│                                                             │
│                    [确定]  [跳过校准]                        │
│                                                             │
│  进度: [█░░░░░░░░░░░░░] 25%                                 │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### 5.4 状态提示系统

| 提示类型 | 显示位置 | 示例 |
|---------|---------|------|
| 得分提示 | 屏幕中央 | "得分!" / "失分!" |
| 回合开始 | 屏幕中央 | "发球!" |
| 击球反馈 | 球拍附近 | "好球!" / "完美!" |
| 连接状态 | 左下角 | "手机已连接" |
| 错误提示 | 屏幕中央 | "手机断开连接" |

---

## 6. 美术需求清单

### 6.1 场景美术

#### 6.1.1 球台

| 元素 | 规格 | 说明 |
|------|------|------|
| 球台模型 | 2.74m x 1.525m x 0.76m | 标准乒乓球台尺寸 |
| 台面材质 | 深蓝色哑光 | 标准乒乓球台颜色 |
| 球网模型 | 1.83m宽 x 0.1525m高 | 白色网布+支架 |
| 边线 | 2cm宽白色线条 | UV贴图或材质区分 |
| 桌腿 | 金属质感 | 简约现代风格 |

#### 6.1.2 场馆环境

| 元素 | 规格 | 说明 |
|------|------|------|
| 地板 | 木地板材质 | 标准体育馆地板 |
| 背景墙 | 深色渐变 | 突出游戏主体 |
| 观众席 | 简约轮廓 | 可选，增加氛围 |
| 灯光系统 | 顶部聚光灯 | 模拟体育馆照明 |

### 6.2 道具美术

#### 6.2.1 虚拟球拍（玩家）

| 元素 | 规格 | 说明 |
|------|------|------|
| 球拍模型 | 标准乒乓球拍比例 | 红色胶皮面 |
| 球拍柄 | 黑色握把 | 便于识别朝向 |
| 发光效果 | 边缘发光 | 增强可视性 |
| 轨迹拖尾 | 半透明残影 | 显示挥拍轨迹 |

#### 6.2.2 乒乓球

| 元素 | 规格 | 说明 |
|------|------|------|
| 球体模型 | 40mm直径 | 标准尺寸 |
| 材质 | 白色哑光塑料 | 标准乒乓球外观 |
| 发光效果 | 自发光 | 增强轨迹可见性 |
| 运动模糊 | 速度线效果 | 高速时显示 |

### 6.3 角色美术（AI对手）

#### 方案A：抽象球拍

| 元素 | 规格 | 说明 |
|------|------|------|
| AI球拍 | 蓝色胶皮面 | 与玩家区分 |
| 机械臂 | 简约机械结构 | 连接球拍到场地 |
| 发光效果 | 蓝色能量光效 | 科技感 |

#### 方案B：人形角色

| 元素 | 规格 | 说明 |
|------|------|------|
| 角色模型 | 运动员形象 | 简约风格 |
| 服装 | 运动服 | 可区分难度颜色 |
| 动画 | 击球/移动/庆祝 | 基础动作集 |
| 球拍 | 手持球拍 | 与玩家球拍类似 |

### 6.4 特效需求

#### 6.4.1 击球特效

| 特效 | 触发条件 | 效果描述 |
|------|---------|---------|
| 击球火花 | 每次击球 | 球拍与球接触点产生 |
| 冲击波 | 大力击球 | 扩散的环形波纹 |
| 粒子爆发 | 扣杀 | 向击球方向喷射 |

#### 6.4.2 轨迹特效

| 特效 | 触发条件 | 效果描述 |
|------|---------|---------|
| 球轨迹 | 球运动时 | 半透明拖尾线 |
| 旋转指示 | 旋转球 | 螺旋状轨迹 |
| 预测线 | 发球时 | 虚线显示预计轨迹 |

#### 6.4.3 得分特效

| 特效 | 触发条件 | 效果描述 |
|------|---------|---------|
| 得分文字 | 得分时 | "得分!" 弹跳动画 |
| 分数变化 | 分数更新 | 数字缩放+发光 |
| 胜利特效 | 赢得比赛 | 彩带+粒子庆祝 |

### 6.5 UI美术

| 元素 | 规格 | 说明 |
|------|------|------|
| 主菜单背景 | 动态模糊球台 | 突出主题 |
| 按钮样式 | 圆角矩形 | 现代简约风格 |
| 字体 | 无衬线体 | 清晰易读 |
| 分数板 | 数字显示屏风格 | 类似体育记分牌 |
| 血条/力量条 | 渐变色条 | 直观显示数值 |

---

## 7. 技术规格

### 7.1 网络协议

```
数据包格式 (二进制, 28字节):
┌─────────────┬─────────────┬─────────────┬─────────────┐
│  UserAccel  │  UserAccel  │  UserAccel  │  Quaternion │
│     X       │     Y       │     Z       │     X       │
│  (4 bytes)  │  (4 bytes)  │  (4 bytes)  │  (4 bytes)  │
├─────────────┼─────────────┼─────────────┼─────────────┤
│  Quaternion │  Quaternion │  Quaternion │             │
│     Y       │     Z       │     W       │             │
│  (4 bytes)  │  (4 bytes)  │  (4 bytes)  │             │
└─────────────┴─────────────┴─────────────┴─────────────┘

传输协议: UDP
端口: 49555 (PC接收)
帧率: 60fps
延迟目标: < 50ms
```

### 7.2 性能目标

| 指标 | 目标值 | 最低要求 |
|------|--------|---------|
| 渲染帧率 | 60 FPS | 30 FPS |
| 物理更新 | 120 Hz | 60 Hz |
| 输入延迟 | < 50ms | < 100ms |
| 网络延迟 | < 20ms | < 50ms |

### 7.3 文件结构

```
project/
├── scenes/
│   ├── main_menu.tscn      # 主菜单场景
│   ├── game.tscn           # 游戏主场景
│   ├── calibration.tscn    # 校准场景
│   └── result.tscn         # 结算场景
├── scripts/
│   ├── game_manager.gd     # 游戏管理器
│   ├── paddle_controller.gd # 球拍控制
│   ├── ai_controller.gd    # AI控制
│   ├── ball_physics.gd     # 球的物理
│   ├── sensor_receiver.gd  # 传感器接收
│   └── ui/
│       ├── hud.gd          # HUD控制
│       ├── main_menu.gd    # 主菜单
│       └── calibration_ui.gd # 校准UI
├── assets/
│   ├── models/             # 3D模型
│   ├── materials/          # 材质
│   ├── textures/           # 贴图
│   ├── sounds/             # 音效
│   └── fonts/              # 字体
└── docs/
    └── GDD.md              # 本文件
```

---

## 8. 与协作团队的接口

### 8.1 与美术团队的协作接口

#### UI布局需求

| UI元素 | 尺寸参考 | 位置 | 特殊要求 |
|--------|---------|------|---------|
| 主菜单按钮 | 300x80px | 垂直居中排列 | 支持键盘/手柄导航 |
| 分数显示 | 150x100px | 顶部两侧 | 大字体，远距离可读 |
| 力量条 | 400x30px | 左下角 | 渐变色，实时更新 |
| 状态提示 | 全屏居中 | 屏幕中央 | 大字体，动画效果 |
| 校准指引 | 600x400px | 屏幕中央 | 包含示意图区域 |

#### 场景元素清单

```yaml
球台:
  - 模型: 标准乒乓球台 (2.74m x 1.525m x 0.76m)
  - 材质: 深蓝色哑光台面，白色边线
  - 球网: 1.83m宽，白色
  - 碰撞体: 精确匹配模型

场馆:
  - 地板: 木质体育馆地板
  - 背景: 深色渐变，不分散注意力
  - 灯光: 顶部聚光灯，产生适当阴影

道具:
  - 玩家球拍: 红色胶皮，发光边缘
  - AI球拍: 蓝色胶皮，科技感设计
  - 乒乓球: 40mm直径，白色，自发光
```

#### 特效需求

```yaml
击球特效:
  - 火花粒子: 接触点爆发
  - 冲击波: 环形扩散
  - 屏幕震动: 大力击球时轻微震动

轨迹特效:
  - 球拖尾: 半透明轨迹线
  - 旋转指示: 螺旋效果
  - 预测线: 虚线轨迹

得分特效:
  - 文字动画: 弹跳+缩放
  - 粒子庆祝: 彩带/星星
  - 音效配合: 视觉与音频同步
```

### 8.2 与架构师的协作接口

#### 球拍控制数据需求

```yaml
输入数据:
  user_accel: Vector3  # 线性加速度 (m/s²)
  quaternion: Quaternion  # 旋转四元数 (x, y, z, w)
  timestamp: float  # 时间戳

输出数据:
  paddle_position: Vector3  # 球拍位置 (世界坐标)
  paddle_rotation: Quaternion  # 球拍旋转
  paddle_velocity: Vector3  # 球拍速度 (用于力量计算)
  is_hitting: bool  # 是否正在击球
  hit_power: float  # 击球力量 (0-1)

配置参数:
  friction: float = 5.0  # 速度衰减
  return_speed: float = 2.0  # 回中速度
  max_displacement: float = 5.0  # 最大位移
  hit_cooldown: float = 0.3  # 击球冷却
  min_hit_speed: float = 2.0  # 最小击球速度
```

#### 物理参数规格

```yaml
球的物理:
  mass: 0.0027  # kg
  diameter: 0.04  # m
  gravity: 9.8  # m/s²
  air_drag: 0.47  # 阻力系数
  restitution_table: 0.85  # 球台反弹系数
  restitution_paddle: 0.8  # 球拍反弹系数
  friction_table: 0.3  # 球台摩擦

速度范围:
  min_speed: 3.0  # m/s
  max_speed: 25.0  # m/s
  serve_speed: 5.0  # m/s

旋转参数:
  max_topspin: 60.0  # rad/s
  max_backspin: 60.0  # rad/s
  max_sidespin: 50.0  # rad/s
  magnus_coefficient: 0.001  # 马格努斯效应系数
```

#### AI行为逻辑接口

```yaml
AI输入:
  ball_position: Vector3  # 球位置
  ball_velocity: Vector3  # 球速度
  ball_angular_velocity: Vector3  # 球旋转
  player_position: Vector3  # 玩家位置 (可选)
  current_score: Dictionary  # 比分

AI输出:
  target_position: Vector3  # 目标移动位置
  hit_type: enum  # 击球类型
  hit_direction: Vector3  # 击球方向
  hit_power: float  # 击球力量
  hit_spin: Vector3  # 击球旋转

难度参数:
  reaction_time: float  # 反应时间 (秒)
  move_speed: float  # 移动速度 (m/s)
  accuracy: float  # 精度 (0-1)
  error_rate: float  # 失误率 (0-1)
  spin_capability: bool  # 是否使用旋转
  aggressiveness: float  # 进攻倾向 (0-1)
```

---

## 9. 附录

### 9.1 术语表

| 术语 | 解释 |
|------|------|
| IMU | 惯性测量单元，包含加速度计和陀螺仪 |
| 四元数 | 用于表示3D旋转的数学结构，避免万向节锁 |
| 弹性回中 | 位置计算算法，使物体始终向中心点回归 |
| 马格努斯效应 | 旋转物体在流体中受到的横向力 |
| DDA | 动态难度调整 (Dynamic Difficulty Adjustment) |

### 9.2 参考标准

- 国际乒联(ITTF)球台规格
- 标准乒乓球物理参数
- Godot 4.6 物理引擎文档
- Android传感器API文档

### 9.3 修订历史

| 版本 | 日期 | 修改内容 | 作者 |
|------|------|---------|------|
| 1.0 | 2026-02-21 | 初始版本 | 项目总监 |

---

**文档结束**
