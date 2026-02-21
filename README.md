# PC端传感器数据接收与3D可视化

基于 Godot 4.3 开发的PC端程序，通过UDP接收Android手机传感器数据，并以3D形式可视化手机运动轨迹。

---

## 开发团队职责

### 代码提交前必须执行

1. **运行验证**
   - 每次增加新功能或修改代码后，必须用 Godot 直接运行对应场景
   - 验证场景能正常加载，没有报错
   - 验证核心功能正常工作

2. **测试场景**
   - `main.tscn` - 手机可视化场景（原版）
   - `scenes/main_game.tscn` - 乒乓球拍场景（新设计）
   - `scenes/phone_visualizer.tscn` - 手机可视化场景（副本）

---

## 功能特性

- **实时接收传感器数据**: 通过UDP网络接收手机加速度计、陀螺仪、重力传感器、磁力计数据
- **3D手机模型**: 实时显示手机姿态和运动
- **轨迹可视化**: 显示手机在3D空间中的运动轨迹
- **坐标系转换**: 自动处理手机坐标系到Godot坐标系的转换

---

## 项目结构

```
godot_server/
├── src/                  # 源代码目录
│   ├── core/             # 核心管理器
│   ├── entities/         # 游戏实体（球拍等）
│   ├── physics/          # 物理系统
│   └── sensor/           # 传感器相关
├── scenes/               # 场景文件
├── tests/                # 测试文件
├── assets/               # 资源文件
├── icon.svg              # 应用图标
├── main.tscn             # 主3D场景（手机可视化）
├── sensor_server.gd      # 传感器接收与可视化脚本
├── phone_visualizer.gd   # 手机模型可视化脚本
├── export_presets.cfg    # Windows导出配置
├── project.godot         # 项目配置
└── README.md             # 本文件
```

---

## 使用说明

### 1. 运行场景验证（开发时必须执行）

每次修改代码后，必须用 Godot 运行对应场景验证：

```bash
# 运行手机可视化场景
godot main.tscn

# 运行乒乓球拍场景
godot scenes/main_game.tscn
```

确保场景加载无报错，功能正常。

### 2. 配置PC端

编辑 `sensor_sender.gd` 中的服务器IP地址（根据你的PC实际IP）：

```gdscript
const SERVER_IP := "192.168.50.11"  # 修改为你的PC IP地址
```

### 2. 启动PC端程序

```bash
# 从Godot编辑器运行
# 或导出Windows可执行文件后运行
godot --path . --scene main.tscn
```

### 3. 启动手机端

确保手机和PC在同一WiFi网络下，然后启动手机应用。

### 4. 操作说明

| 按键 | 功能 |
|------|------|
| R | 重置视角和位置 |
| C | 清除轨迹 |
| ESC | 退出程序 |

---

## 构建Windows可执行文件

```bash
# 导出Windows可执行文件
godot --headless --export-release "Windows Desktop" ./sensor_server.exe
```

---

## 网络协议

数据通过UDP以JSON格式发送：

```json
{
  "accel": {"x": 0.0, "y": 0.0, "z": 9.8},
  "gyro": {"x": 0.0, "y": 0.0, "z": 0.0},
  "gravity": {"x": 0.0, "y": 0.0, "z": 9.8},
  "magneto": {"x": 20.0, "y": 0.0, "z": -40.0},
  "timestamp": 1234567890.123
}
```

---

## 坐标系说明

### 手机坐标系
- X: 手机右侧为正
- Y: 手机顶部为正
- Z: 屏幕朝向用户为正

### Godot坐标系
- X: 右
- Y: 上
- Z: 后（屏幕向里）

程序自动进行坐标系转换。

---

## 系统要求

| 组件 | 要求 |
|------|------|
| Godot | 4.3 stable |
| 网络 | 手机和PC在同一WiFi网络 |
| 端口 | 39433 (UDP) |

---

## 校准流程

### 手机场景 (`main.tscn`)
- **自动校准**: 收到第一帧重力数据时自动校准
- **手动重置**: 按 **R** 键重置视角并重新校准

### 乒乓球拍场景 (`scenes/main_game.tscn`)
- 按 **K** 键开始校准
- 像握球拍一样竖直握持手机，屏幕面向自己
- 按 **Enter** 键确认校准

## 轨迹计算原理

1. **姿态计算**: 通过陀螺仪积分计算手机旋转角度
2. **位置计算**: 加速度减去重力后双重积分得到位移
3. **漂移抑制**: 使用阻尼衰减减少累积误差

---

## 常见问题

### 无法接收数据
- 检查防火墙设置，允许UDP端口39433
- 确认手机和PC在同一网络
- 检查IP地址配置是否正确

### 轨迹漂移严重
- 这是惯性导航的固有问题，需要定期重置(R键)
- 保持手机静止时速度会自然衰减

---

## 参考链接

- [Godot 3D教程](https://docs.godotengine.org/en/stable/tutorials/3d/index.html)
- [Godot网络教程](https://docs.godotengine.org/en/stable/tutorials/networking/index.html)
