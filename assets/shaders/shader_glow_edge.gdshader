shader_type spatial;

uniform vec4 edge_color : source_color = vec4(0.0, 0.83, 1.0, 1.0);
uniform float edge_width : hint_range(0.0, 0.5) = 0.05;
uniform float glow_intensity : hint_range(0.0, 5.0) = 2.0;
uniform float pulse_speed : hint_range(0.0, 10.0) = 0.0;

void fragment() {
    // 基于UV的边缘检测
    float edge_x = min(UV.x, 1.0 - UV.x);
    float edge_y = min(UV.y, 1.0 - UV.y);
    float edge = min(edge_x, edge_y);

    // 边缘发光
    float glow = smoothstep(edge_width, 0.0, edge);

    // 脉冲效果（可选）
    float pulse = 1.0;
    if (pulse_speed > 0.0) {
        pulse = 0.7 + 0.3 * sin(TIME * pulse_speed);
    }

    EMISSION = edge_color.rgb * glow * glow_intensity * pulse;
    ALBEDO = vec3(0.05);
    ALPHA = max(glow * 0.8, 0.1);
}
