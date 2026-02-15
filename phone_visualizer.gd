extends Node3D

# 手机3D模型可视化脚本

@onready var phone_body: MeshInstance3D = $PhoneBody
@onready var screen: MeshInstance3D = $Screen

func _ready():
	# 添加一些视觉细节
	add_screen_glow()

func add_screen_glow():
	# 屏幕发光效果
	var light = OmniLight3D.new()
	light.position = Vector3(0, 0, 0.5)
	light.light_color = Color(0.2, 0.6, 1, 1)
	light.light_energy = 0.5
	light.omni_range = 2.0
	add_child(light)

func set_screen_color(color: Color):
	var material = screen.get_active_material(0)
	if material:
		material.emission = color

func pulse_screen():
	# 屏幕脉冲效果
	var tween = create_tween()
	var material = screen.get_active_material(0)
	if material:
		tween.tween_property(material, "emission_energy", 1.0, 0.1)
		tween.tween_property(material, "emission_energy", 0.5, 0.3)
