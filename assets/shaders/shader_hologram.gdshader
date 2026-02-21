shader_type spatial;

uniform vec4 hologram_color : source_color = vec4(0.0, 0.83, 1.0, 0.5);
uniform float scan_line_speed : hint_range(0.0, 10.0) = 2.0;
uniform float glitch_intensity : hint_range(0.0, 1.0) = 0.1;
uniform float flicker_speed : hint_range(0.0, 20.0) = 5.0;

void fragment() {
    // 扫描线效果
    float scan = sin(UV.y * 50.0 + TIME * scan_line_speed);

    // 数字干扰效果
    float glitch = fract(sin(TIME * 10.0 + UV.x * 100.0) * 43758.5453) * glitch_intensity;

    // 闪烁效果
    float flicker = sin(TIME * flicker_speed) * 0.1 + 0.9;

    ALBEDO = hologram_color.rgb;
    ALPHA = hologram_color.a * (0.5 + scan * 0.3) * flicker - glitch;
    EMISSION = hologram_color.rgb * 0.5 * flicker;
}
