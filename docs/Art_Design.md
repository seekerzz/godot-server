# 混合现实乒乓球游戏 - 美术设计文档

**版本**: 1.0
**日期**: 2026-02-21
**引擎**: Godot 4.6
**渲染器**: Forward Plus
**目标平台**: Windows PC

---

## 1. 视觉风格定位

### 1.1 整体美术风格

**风格定义**: 现代极简科技风 (Modern Minimalist Tech)

- **核心特征**: 简洁的几何形态、高对比度色彩、动态光影反馈
- **设计哲学**: 强调"数字孪生"概念——虚拟球拍与真实手机1:1映射，创造虚实融合的沉浸感
- **视觉参考**:
  - 《TRON》系列的霓虹光效美学
  - 《Rocket League》的简洁运动风格
  - Apple Design 的极简界面语言

### 1.2 色彩方案

#### 主色调 (Primary Colors)
| 颜色名称 | 色值 (Hex) | Godot Color | 用途 |
|---------|-----------|-------------|------|
| 深空黑 | `#0A0A0F` | `Color(0.04, 0.04, 0.06)` | 背景、场馆暗部 |
| 电光蓝 | `#00D4FF` | `Color(0, 0.83, 1)` | 主强调色、玩家球拍 |
| 纯白 | `#FFFFFF` | `Color(1, 1, 1)` | 高光、文字 |

#### 辅色调 (Secondary Colors)
| 颜色名称 | 色值 (Hex) | Godot Color | 用途 |
|---------|-----------|-------------|------|
| 霓虹紫 | `#B829DD` | `Color(0.72, 0.16, 0.87)` | AI对手、敌方球拍 |
| 荧光绿 | `#39FF14` | `Color(0.22, 1, 0.08)` | 得分特效、正向反馈 |
| 警示橙 | `#FF6B35` | `Color(1, 0.42, 0.21)` | 警告、失误提示 |

#### 中性色 (Neutral Colors)
| 颜色名称 | 色值 (Hex) | Godot Color | 用途 |
|---------|-----------|-------------|------|
| 炭灰 | `#2A2A35` | `Color(0.16, 0.16, 0.21)` | 球台边框、UI面板 |
| 银灰 | `#8A8A9A` | `Color(0.54, 0.54, 0.6)` | 次要文字、网格线 |
| 半透明黑 | `#00000080` | `Color(0, 0, 0, 0.5)` | UI背景遮罩 |

### 1.3 光影风格

**主光源设置**:
- 类型: DirectionalLight3D
- 颜色: 冷白色 `#E8F4FF` (Color(0.91, 0.96, 1))
- 强度: 1.2
- 方向: 从球台左上方45度角照射
- 阴影: 启用软阴影 (shadow_enabled = true)

**补光设置**:
- 类型: OmniLight3D (点光源)
- 颜色: 电光蓝 `#00D4FF` (Color(0, 0.83, 1))
- 强度: 0.6
- 位置: 球台中心上方2米处
- 作用: 营造科技感氛围

**氛围光**:
- 环境光 (Ambient Light): 深蓝色调 `#1A1A2E`
- 反射光 (Reflection): 球台表面微反射
- 自发光 (Emission): 球拍和球体带有微弱自发光

### 1.4 参考图集/情绪板描述

**关键词**: 未来感、运动、数字、霓虹、极简

**视觉元素**:
1. 深色背景上的霓虹光带
2. 网格地面延伸至地平线
3. 发光的几何形状
4. 流畅的运动轨迹拖尾
5. 高对比度的黑白配色点缀亮色

---

## 2. 场景设计

### 2.1 乒乓球桌设计

#### 尺寸规格 (标准比赛规格)
| 参数 | 数值 | 单位 |
|-----|------|-----|
| 长度 | 2.74 | 米 |
| 宽度 | 1.525 | 米 |
| 高度 | 0.76 | 米 |
| 网高 | 0.1525 | 米 |

**Godot单位换算**: 1 Godot单位 = 1米

#### 材质与颜色

**桌面**:
- 基础颜色: 深炭灰 `#2A2A35`
- 材质类型: StandardMaterial3D
- 粗糙度 (Roughness): 0.3 (半哑光)
- 金属度 (Metallic): 0.1 (轻微金属感)
- 自发光: 边缘微弱蓝光 `#00D4FF` (emission_energy = 0.2)

**中线/边线**:
- 颜色: 电光蓝 `#00D4FF`
- 宽度: 0.02米
- 自发光: 启用 (emission_energy = 0.5)

**球网**:
- 网格材质: 半透明网格
- 支柱: 金属质感
- 颜色: 银灰色

**边框**:
- 材质: 金属
- 颜色: 深灰色 `#4A4A5A`
- 金属度: 0.8
- 粗糙度: 0.2

#### 3D模型规格
- **面数预算**: < 2000三角面
- **碰撞体**: 使用BoxShape3D简化碰撞

### 2.2 场馆环境

#### 地板
- 类型: 无限延伸的网格地面
- 颜色: 深空黑 `#0A0A0F`
- 网格线: 电光蓝 `#00D4FF`，透明度 0.3
- 网格间距: 1米
- 延伸范围: 20x20米 (视觉范围)

**Godot实现**:
```gdscript
# 程序化生成网格地面
func create_ground_grid():
    for i in range(-10, 11):
        create_grid_line(Vector3(i, 0, -10), Vector3(i, 0, 10), Color(0, 0.83, 1, 0.3))
        create_grid_line(Vector3(-10, 0, i), Vector3(10, 0, i), Color(0, 0.83, 1, 0.3))
```

#### 墙壁/天花板
- **设计**: 极简暗色空间，无实体墙壁
- **背景**: 渐变雾效 (Fog)，从 `#0A0A0F` 渐变到 `#1A1A2E`
- **远景**: 微弱的发光网格延伸至黑暗

#### 环境氛围
- **雾效**: 启用深度雾 (Depth Fog)
- **雾密度**: 0.02
- **雾颜色**: `#0A0A0F`
- **效果**: 营造无限延伸的虚拟空间感

### 2.3 灯光方案

#### 主光源 (Key Light)
```gdscript
[node name="DirectionalLight3D" type="DirectionalLight3D" parent="."]
transform = Transform3D(0.707107, -0.5, 0.5, 0, 0.707107, 0.707107, -0.707107, -0.5, 0.5, 5, 10, 5)
light_color = Color(0.91, 0.96, 1)
light_energy = 1.2
shadow_enabled = true
shadow_bias = 0.05
```

#### 补光 (Fill Light)
```gdscript
[node name="FillLight" type="OmniLight3D" parent="."]
position = Vector3(0, 2, 0)
light_color = Color(0, 0.83, 1)
light_energy = 0.6
omni_range = 5.0
```

#### 氛围光 (Rim Light)
```gdscript
[node name="RimLight" type="SpotLight3D" parent="."]
position = Vector3(0, 5, -5)
rotation = Vector3(deg_to_rad(-45), 0, 0)
light_color = Color(0.72, 0.16, 0.87)
light_energy = 0.8
spot_range = 10.0
```

### 2.4 摄像机角度和视野

#### 主游戏视角
- **位置**: 球台一侧，高度1.5米，距离球台2.5米
- **朝向**: 对准球台中心
- **FOV**: 60度
- **投影**: 透视投影

```gdscript
[node name="Camera3D" type="Camera3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 0.707107, 0.707107, 0, -0.707107, 0.707107, 0, 2.5, 2.5)
fov = 60.0
```

#### 备选视角
- **俯视角**: 用于调试和回放
- **侧视角**: 用于展示击球瞬间
- **自由视角**: 开发调试使用

---

## 3. 道具设计

### 3.1 虚拟球拍设计

#### 设计概念
虚拟球拍需要与真实手机1:1对应，玩家通过手机握持姿态控制虚拟球拍。

#### 尺寸规格
| 参数 | 数值 | 说明 |
|-----|------|-----|
| 长度 | 0.16米 | 对应手机长度 |
| 宽度 | 0.075米 | 对应手机宽度 |
| 厚度 | 0.008米 | 对应手机厚度 |
| 拍面延伸 | 0.08米 | 虚拟拍面从手机底部延伸 |

#### 视觉呈现

**玩家球拍 (电光蓝主题)**:
- **主体**: 半透明蓝色立方体，代表手机
- **拍面**: 从手机底部延伸的扇形/椭圆形拍面
- **颜色**: 电光蓝 `#00D4FF`
- **材质**:
  - 主体: StandardMaterial3D，金属度0.3，粗糙度0.2
  - 拍面: 半透明发光材质，emission_enabled = true

**Godot材质配置**:
```gdscript
var paddle_material = StandardMaterial3D.new()
paddle_material.albedo_color = Color(0, 0.83, 1, 0.8)
paddle_material.emission_enabled = true
paddle_material.emission = Color(0, 0.83, 1)
paddle_material.emission_energy_multiplier = 0.5
paddle_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
```

#### 3D模型规格
- **面数预算**: < 500三角面
- **结构**:
  - 手机主体: BoxMesh (6面)
  - 拍面: CylinderMesh 或自定义扇形Mesh
  - 连接处: 平滑过渡

### 3.2 乒乓球设计

#### 尺寸规格
- **直径**: 0.04米 (标准乒乓球大小)
- **Godot缩放**: 0.02 (SphereMesh默认半径为1)

#### 视觉设计
- **基础颜色**: 纯白 `#FFFFFF`
- **自发光**: 微弱白光 (emission_energy = 0.3)
- **材质**:
  - 粗糙度: 0.1 (光滑)
  - 金属度: 0.0
  - 次表面散射: 轻微 (模拟塑料质感)

#### 3D模型规格
- **面数预算**: < 100三角面
- **Mesh类型**: SphereMesh
- **细分级别**: 中等 (32段)

```gdscript
var ball_mesh = SphereMesh.new()
ball_mesh.radius = 0.02
ball_mesh.height = 0.04
ball_mesh.radial_segments = 16
ball_mesh.rings = 8
```

### 3.3 轨迹可视化方案

#### 设计概念
球体运动轨迹以发光拖尾形式呈现，增强速度感和视觉反馈。

#### 视觉规格
- **轨迹类型**: 连续线段
- **颜色**: 从电光蓝渐变到白色
- **宽度**: 0.005米
- **持续时间**: 0.5秒后渐隐
- **最大点数**: 50个点

#### Godot实现
```gdscript
func create_trajectory_line(start_pos: Vector3, end_pos: Vector3):
    var mesh_instance = MeshInstance3D.new()
    var mesh = ImmediateMesh.new()
    mesh_instance.mesh = mesh

    mesh.surface_begin(Mesh.PRIMITIVE_LINES)
    mesh.surface_set_color(Color(0, 0.83, 1, 0.8))
    mesh.surface_add_vertex(start_pos)
    mesh.surface_add_vertex(end_pos)
    mesh.surface_end()

    var material = StandardMaterial3D.new()
    material.albedo_color = Color(0, 0.8, 1, 0.6)
    material.emission_enabled = true
    material.emission = Color(0, 0.5, 0.8, 1)
    material.emission_energy = 0.3
    mesh_instance.material_override = material
```

---

## 4. AI对手形象

### 4.1 AI球拍设计

#### 视觉区分
AI球拍需要与玩家球拍有明显区分，同时保持风格统一。

| 特征 | 玩家球拍 | AI球拍 |
|-----|---------|-------|
| 主色 | 电光蓝 `#00D4FF` | 霓虹紫 `#B829DD` |
| 形状 | 矩形手机+扇形拍面 | 六边形核心+菱形拍面 |
| 发光强度 | 0.5 | 0.7 (更强) |
| 动态效果 | 静态发光 | 脉动发光 |

#### AI球拍材质
```gdscript
var ai_paddle_material = StandardMaterial3D.new()
ai_paddle_material.albedo_color = Color(0.72, 0.16, 0.87, 0.8)
ai_paddle_material.emission_enabled = true
ai_paddle_material.emission = Color(0.72, 0.16, 0.87)
ai_paddle_material.emission_energy_multiplier = 0.7
```

### 4.2 AI角色形象 (可选)

#### 概念设计
如需要具象化AI对手，采用"全息投影"风格:
- **形态**: 抽象人形轮廓
- **材质**: 半透明全息效果
- **颜色**: 霓虹紫主调
- **细节**: 数字干扰效果 (glitch effect)

#### 动画状态需求

**1. 待机状态 (Idle)**
- 轻微上下浮动
- 拍面缓慢旋转
- 呼吸灯效果

**2. 移动状态 (Move)**
- 平滑左右移动
- 身体倾斜跟随移动方向
- 拍面朝向球体

**3. 击球状态 (Hit)**
- 快速挥拍动作
- 击球瞬间发光增强
- 回位动画

**4. 得分状态 (Score)**
- 庆祝动画
- 粒子特效爆发
- 颜色闪烁

**5. 失分状态 (Miss)**
- 短暂停滞
- 颜色变暗
- 恢复动画

---

## 5. UI系统设计

### 5.1 主菜单视觉风格

#### 布局
- **背景**: 深色渐变 + 动态网格
- **标题**: 大号发光字体，电光蓝
- **按钮**: 圆角矩形，悬停发光效果
- **整体风格**: 极简科技风

#### 视觉元素
```gdscript
# 主菜单背景
var menu_background = ColorRect.new()
menu_background.color = Color(0.04, 0.04, 0.06, 0.95)

# 标题样式
var title_label = Label.new()
title_label.add_theme_font_size_override("font_size", 72)
title_label.add_theme_color_override("font_color", Color(0, 0.83, 1))
```

### 5.2 HUD布局

#### 屏幕分区 (1280x720)

```
+--------------------------------------------------+
|  [玩家得分]  11  :  9  [AI得分]      [设置按钮]   |
|                                                  |
|                                                  |
|                                                  |
|              [游戏主视图 - 3D场景]                |
|                                                  |
|                                                  |
|                                                  |
|  [速度指示器]                        [状态提示]   |
|  [连接状态]                          [操作提示]   |
+--------------------------------------------------+
```

#### HUD元素规格

**比分显示**:
- 位置: 屏幕顶部中央
- 字体大小: 48px
- 玩家分数颜色: 电光蓝 `#00D4FF`
- AI分数颜色: 霓虹紫 `#B829DD`
- 分隔符: 白色 ":"

**状态提示**:
- 位置: 屏幕底部右侧
- 字体大小: 18px
- 颜色: 银灰 `#8A8A9A`
- 内容: 等待连接/游戏中/暂停

**操作提示**:
- 位置: 屏幕底部左侧
- 字体大小: 14px
- 颜色: 半透明银灰
- 内容: 按键说明

### 5.3 字体规范

#### 字体选择
| 用途 | 字体类型 | 推荐字体 | 备选 |
|-----|---------|---------|-----|
| 标题 | 无衬线粗体 | Orbitron | Arial Bold |
| 正文 | 无衬线常规 | Exo 2 | Arial |
| 数字 | 等宽数字 | Roboto Mono | Consolas |

#### 字号规范
| 元素 | 字号 | 字重 |
|-----|------|-----|
| 游戏标题 | 72px | Bold |
| 菜单按钮 | 32px | Medium |
| HUD分数 | 48px | Bold |
| HUD标签 | 18px | Regular |
| 提示文字 | 14px | Regular |

#### Godot字体配置
```gdscript
# 加载自定义字体
var font_title = load("res://fonts/Orbitron-Bold.ttf")
var font_body = load("res://fonts/Exo2-Regular.ttf")
var font_mono = load("res://fonts/RobotoMono-Regular.ttf")

# 应用字体
label.add_theme_font_override("font", font_title)
label.add_theme_font_size_override("font_size", 48)
```

### 5.4 图标风格

#### 设计规范
- **风格**: 线性图标 (Outline Style)
- **线条粗细**: 2px
- **圆角**: 2px
- **颜色**: 默认银灰，悬停电光蓝

#### 必需图标列表
| 图标 | 用途 | 尺寸 |
|-----|------|-----|
| 设置/齿轮 | 设置菜单 | 32x32 |
| 暂停/播放 | 游戏控制 | 32x32 |
| 音量 | 音量控制 | 32x32 |
| 全屏 | 窗口模式 | 32x32 |
| 返回 | 返回上级 | 32x32 |
| 连接状态 | 网络状态指示 | 16x16 |

### 5.5 动效规范

#### 转场动画
| 转场类型 | 时长 | 缓动函数 | 效果 |
|---------|------|---------|-----|
| 场景切换 | 0.5s | EASE_IN_OUT | 淡入淡出 + 轻微缩放 |
| 菜单弹出 | 0.3s | EASE_OUT_BACK | 弹性缩放 |
| 按钮悬停 | 0.15s | EASE_OUT | 发光增强 |

#### 反馈动效
| 反馈类型 | 时长 | 效果 |
|---------|------|-----|
| 得分 | 1.0s | 数字跳动 + 粒子爆发 |
| 击球 | 0.2s | 球拍发光脉冲 |
| 失误 | 0.5s | 屏幕边缘红色闪烁 |
| 连接成功 | 0.5s | 状态指示器变绿 + 对勾动画 |

#### Godot Tween示例
```gdscript
# 按钮悬停效果
func _on_button_mouse_entered():
    var tween = create_tween()
    tween.tween_property(button, "modulate", Color(0, 0.83, 1), 0.15)
    tween.tween_property(button, "scale", Vector2(1.05, 1.05), 0.15)

# 得分动画
func play_score_animation():
    var tween = create_tween()
    tween.tween_property(score_label, "scale", Vector2(1.5, 1.5), 0.2)
    tween.tween_property(score_label, "scale", Vector2(1.0, 1.0), 0.3).set_ease(Tween.EASE_OUT)
```

---

## 6. 特效设计

### 6.1 击球特效

#### 火花特效 (Hit Spark)
- **触发**: 球拍与球碰撞瞬间
- **效果**: 球拍接触点爆发蓝色粒子
- **粒子数量**: 20-30个
- **颜色**: 电光蓝 `#00D4FF` 到白色
- **持续时间**: 0.3秒
- **扩散范围**: 0.1米半径

#### 光晕特效 (Hit Glow)
- **触发**: 击球瞬间
- **效果**: 球拍整体发光增强
- **强度变化**: 0.5 -> 2.0 -> 0.5
- **持续时间**: 0.2秒

#### Godot粒子配置
```gdscript
var hit_particles = GPUParticles3D.new()
hit_particles.emitting = false
hit_particles.one_shot = true
hit_particles.explosiveness = 1.0
hit_particles.amount = 25

var particle_material = ParticleProcessMaterial.new()
particle_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
particle_material.emission_sphere_radius = 0.05
particle_material.direction = Vector3(0, 1, 0)
particle_material.spread = 45.0
particle_material.gravity = Vector3(0, -2, 0)
particle_material.initial_velocity_min = 1.0
particle_material.initial_velocity_max = 3.0
particle_material.scale_min = 0.01
particle_material.scale_max = 0.03
particle_material.color = Color(0, 0.83, 1)

hit_particles.process_material = particle_material
```

### 6.2 球轨迹拖尾

#### 设计规格
- **类型**: 连续拖尾渲染
- **颜色渐变**: 电光蓝 (头部) -> 透明 (尾部)
- **宽度**: 0.01米，逐渐变细
- **长度**: 保留最近0.5秒轨迹
- **发光**: 整体微弱发光

#### Godot实现方案
使用 ImmediateMesh 或 Trail Renderer:
```gdscript
# 轨迹点管理
var trail_points: Array[Vector3] = []
const MAX_TRAIL_POINTS = 30

func update_trail(ball_position: Vector3):
    trail_points.append(ball_position)
    if trail_points.size() > MAX_TRAIL_POINTS:
        trail_points.pop_front()

    # 重新生成轨迹Mesh
    generate_trail_mesh()
```

### 6.3 得分特效

#### 玩家得分
- **主效果**: 屏幕中央显示"+1"，向上飘动消失
- **粒子**: 绿色粒子从球台向上喷射
- **颜色**: 荧光绿 `#39FF14`
- **音效配合**: 清脆得分音

#### AI得分
- **主效果**: 屏幕中央显示红色提示
- **颜色**: 警示橙 `#FF6B35`
- **屏幕效果**: 边缘轻微红色闪烁

#### 胜利特效
- **触发**: 达到胜利分数 (如11分)
- **效果**:
  - 全屏粒子爆发
  - "VICTORY"文字动画
  - 球台灯光闪烁
- **持续时间**: 3秒

### 6.4 环境特效

#### 网格地面脉冲
- **触发**: 击球时
- **效果**: 击球点对应地面网格发光扩散
- **颜色**: 与击球方颜色对应
- **扩散速度**: 2米/秒

#### 氛围粒子
- **类型**: 浮尘/数据流粒子
- **数量**: 50个
- **运动**: 缓慢上升
- **颜色**: 微弱电光蓝
- **目的**: 增加空间层次感

---

## 7. 技术美术规范

### 7.1 Shader需求列表

#### 必需Shader

**1. 全息投影效果 (Hologram Shader)**
```glsl
// 用于AI对手或特殊UI元素
shader_type spatial;
uniform vec4 hologram_color : source_color = vec4(0.0, 0.83, 1.0, 0.5);
uniform float scan_line_speed : hint_range(0.0, 10.0) = 2.0;
uniform float glitch_intensity : hint_range(0.0, 1.0) = 0.1;

void fragment() {
    // 扫描线效果
    float scan = sin(UV.y * 50.0 + TIME * scan_line_speed);
    // 数字干扰效果
    float glitch = fract(sin(TIME * 10.0) * 43758.5453) * glitch_intensity;

    ALBEDO = hologram_color.rgb;
    ALPHA = hologram_color.a * (0.5 + scan * 0.5) - glitch;
    EMISSION = hologram_color.rgb * 0.5;
}
```

**2. 发光边缘 (Glow Edge Shader)**
```glsl
// 用于球拍和球台边缘
shader_type spatial;
uniform vec4 edge_color : source_color = vec4(0.0, 0.83, 1.0, 1.0);
uniform float edge_width : hint_range(0.0, 0.1) = 0.02;

void fragment() {
    // 基于UV的边缘检测
    float edge = min(min(UV.x, 1.0 - UV.x), min(UV.y, 1.0 - UV.y));
    float glow = smoothstep(edge_width, 0.0, edge);

    EMISSION = edge_color.rgb * glow * 2.0;
    ALBEDO = vec3(0.1);
}
```

**3. 轨迹拖尾 (Trail Shader)**
```glsl
// 用于球体运动轨迹
shader_type spatial;
uniform vec4 start_color : source_color = vec4(0.0, 0.83, 1.0, 1.0);
uniform vec4 end_color : source_color = vec4(0.0, 0.83, 1.0, 0.0);
uniform float trail_fade : hint_range(0.0, 1.0) = 0.5;

void fragment() {
    vec4 gradient_color = mix(start_color, end_color, UV.x);
    ALBEDO = gradient_color.rgb;
    ALPHA = gradient_color.a * (1.0 - UV.x * trail_fade);
    EMISSION = gradient_color.rgb * 0.5;
}
```

### 7.2 材质规范

#### 球台木质材质
```gdscript
var table_material = StandardMaterial3D.new()
table_material.albedo_color = Color(0.16, 0.16, 0.21)  # 深炭灰
table_material.roughness = 0.3
table_material.metallic = 0.1
table_material.emission_enabled = true
table_material.emission = Color(0, 0.83, 1)
table_material.emission_energy_multiplier = 0.1
```

#### 金属边框材质
```gdscript
var metal_material = StandardMaterial3D.new()
metal_material.albedo_color = Color(0.29, 0.29, 0.35)  # 银灰
metal_material.roughness = 0.2
metal_material.metallic = 0.8
metal_material.clearcoat_enabled = true
metal_material.clearcoat = 0.3
```

#### 橡胶球拍面材质
```gdscript
var rubber_material = StandardMaterial3D.new()
rubber_material.albedo_color = Color(0.9, 0.9, 0.9)  # 白色
rubber_material.roughness = 0.8
rubber_material.metallic = 0.0
rubber_material.normal_scale = 0.5
```

### 7.3 贴图尺寸规范

| 用途 | 尺寸 | 格式 | 备注 |
|-----|------|-----|-----|
| UI图标 | 64x64 | PNG | 透明背景 |
| 字体纹理 | 1024x1024 | 引擎生成 | SDF字体 |
| 粒子纹理 | 128x128 | PNG | 圆形渐变 |
| 环境贴图 | 512x512 | HDR | 仅用于反射 |
| 球台纹理 | 1024x1024 | PNG | 网格线图案 |

**优化原则**:
- 优先使用程序生成纹理
- 复用贴图资源
- 压缩纹理格式 (VRAM压缩)

### 7.4 性能预算

#### 多边形预算
| 对象 | 三角面数 | LOD级别 |
|-----|---------|--------|
| 球台 | 2000 | LOD1: 1000, LOD2: 500 |
| 球拍 | 500 | LOD1: 250 |
| 球体 | 100 | 无 (本身简单) |
| AI角色 | 1000 | LOD1: 500 |
| 场景总计 | < 5000 | - |

#### 渲染性能目标
| 指标 | 目标值 | 最大允许值 |
|-----|-------|-----------|
| 帧率 | 60 FPS | 最低 45 FPS |
| Draw Calls | < 50 | < 100 |
| 粒子数量 | < 500 | < 1000 |
| 动态光源 | 3个 | 5个 |
| 阴影投射 | 仅主光源 | - |

#### Godot性能优化设置
```gdscript
# 项目设置优化
[rendering]
renderer/rendering_method = "forward_plus"
textures/vram_compression/import_etc2_astc = true
lights_and_shadows/directional_shadow/size = 2048
lights_and_shadows/directional_shadow/soft_shadow_filter_quality = 1  # Soft Low

# 场景优化
[layer_names]
3d_render/layer_1 = "Default"
3d_render/layer_2 = "UI"
3d_render/layer_3 = "Effects"
```

#### 内存预算
| 资源类型 | 预算 |
|---------|-----|
| 纹理内存 | < 128 MB |
| 网格内存 | < 32 MB |
| 音频内存 | < 16 MB |
| 总内存 | < 256 MB |

---

## 附录

### A. 颜色快速参考

```gdscript
# 主色调
const COLOR_PRIMARY = Color(0.0, 0.83, 1.0)        # 电光蓝
const COLOR_SECONDARY = Color(0.72, 0.16, 0.87)    # 霓虹紫
const COLOR_ACCENT = Color(0.22, 1.0, 0.08)        # 荧光绿
const COLOR_WARNING = Color(1.0, 0.42, 0.21)       # 警示橙

# 中性色
const COLOR_DARK = Color(0.04, 0.04, 0.06)         # 深空黑
const COLOR_GRAY = Color(0.16, 0.16, 0.21)         # 炭灰
const COLOR_LIGHT = Color(0.54, 0.54, 0.6)         # 银灰
const COLOR_WHITE = Color(1.0, 1.0, 1.0)           # 纯白
```

### B. 文件命名规范

```
assets/
├── models/
│   ├── table_001.fbx
│   ├── paddle_player_001.fbx
│   ├── paddle_ai_001.fbx
│   └── ball_001.fbx
├── textures/
│   ├── ui_icon_settings_64.png
│   ├── particle_glow_128.png
│   └── env_grid_512.png
├── materials/
│   ├── mat_table.tres
│   ├── mat_paddle_player.tres
│   ├── mat_paddle_ai.tres
│   └── mat_ball.tres
├── shaders/
│   ├── shader_hologram.gdshader
│   ├── shader_glow_edge.gdshader
│   └── shader_trail.gdshader
└── fonts/
    ├── Orbitron-Bold.ttf
    ├── Exo2-Regular.ttf
    └── RobotoMono-Regular.ttf
```

### C. 版本历史

| 版本 | 日期 | 修改内容 | 作者 |
|-----|------|---------|-----|
| 1.0 | 2026-02-21 | 初始版本 | 美术总监 |

---

**文档结束**
