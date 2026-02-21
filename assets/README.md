# 美术资源目录

本目录包含混合现实乒乓球游戏的所有美术资源。

## 目录结构

```
assets/
├── models/          # 3D模型场景文件
├── materials/       # 材质文件
├── textures/        # 贴图文件（待添加）
├── shaders/         # Shader文件
└── fonts/           # 字体文件（待添加）
```

## 模型文件

### P0 核心资源（已完成）

| 文件 | 描述 | 规格 |
|------|------|------|
| `paddle_player.tscn` | 玩家球拍 | 0.16×0.075×0.008米, 电光蓝 |
| `paddle_ai.tscn` | AI球拍 | 同尺寸, 霓虹紫 |
| `ball.tscn` | 乒乓球 | 直径0.04米, 白色发光 |
| `table.tscn` | 球台 | 标准尺寸, 深炭灰+电光蓝边线 |

### 使用方式

在Godot场景中直接实例化:

```gdscript
# 加载玩家球拍
var paddle_scene = preload("res://assets/models/paddle_player.tscn")
var paddle = paddle_scene.instantiate()
add_child(paddle)

# 加载乒乓球
var ball_scene = preload("res://assets/models/ball.tscn")
var ball = ball_scene.instantiate()
ball.position = Vector3(0, 1, 0)
add_child(ball)
```

## 材质文件

### 球拍材质

- `mat_paddle_player.tres` - 玩家球拍材质（电光蓝 #00D4FF）
- `mat_paddle_ai.tres` - AI球拍材质（霓虹紫 #B829DD）

### 球体材质

- `mat_ball.tres` - 乒乓球材质（白色发光）

### 球台材质

- `mat_table_surface.tres` - 桌面材质（深炭灰）
- `mat_table_line.tres` - 边线材质（电光蓝发光）
- `mat_table_frame.tres` - 边框材质（金属质感）
- `mat_net.tres` - 球网材质（半透明）

## Shader文件

### 可用Shader

| 文件 | 用途 | 效果 |
|------|------|------|
| `shader_hologram.gdshader` | AI全息效果 | 扫描线+数字干扰 |
| `shader_glow_edge.gdshader` | 发光边缘 | 边缘高亮+脉冲效果 |
| `shader_trail.gdshader` | 轨迹拖尾 | 渐变透明拖尾 |

### Shader使用示例

```gdscript
# 创建带发光边缘的材质
var material = ShaderMaterial.new()
material.shader = preload("res://assets/shaders/shader_glow_edge.gdshader")
material.set_shader_parameter("edge_color", Color(0, 0.83, 1))
material.set_shader_parameter("edge_width", 0.05)
material.set_shader_parameter("glow_intensity", 2.0)
```

## 导出GLB格式

如需导出为GLB格式（用于其他工具或引擎），请运行:

```gdscript
# 在Godot编辑器中运行 export_glb.gd 脚本
```

## 技术规格

### 面数预算

| 对象 | 三角面数 |
|------|---------|
| 球台 | < 2000 |
| 球拍 | < 500 |
| 球体 | < 100 |

### 颜色规范

| 名称 | Hex | Godot Color |
|------|-----|-------------|
| 电光蓝 | #00D4FF | Color(0, 0.83, 1) |
| 霓虹紫 | #B829DD | Color(0.72, 0.16, 0.87) |
| 深空黑 | #0A0A0F | Color(0.04, 0.04, 0.06) |
| 炭灰 | #2A2A35 | Color(0.16, 0.16, 0.21) |

## 注意事项

1. 所有模型使用Godot内置PrimitiveMesh（BoxMesh, SphereMesh, CylinderMesh）
2. 材质使用StandardMaterial3D，支持发光效果
3. 场景文件可直接实例化使用
4. 如需修改模型，建议直接编辑.tscn文件中的Mesh参数

---

**最后更新**: 2026-02-21
