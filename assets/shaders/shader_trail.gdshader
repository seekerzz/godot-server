shader_type spatial;

uniform vec4 start_color : source_color = vec4(0.0, 0.83, 1.0, 1.0);
uniform vec4 end_color : source_color = vec4(0.0, 0.83, 1.0, 0.0);
uniform float trail_fade : hint_range(0.0, 1.0) = 0.5;
uniform float emission_strength : hint_range(0.0, 2.0) = 0.5;
uniform float uv_scale : hint_range(0.1, 10.0) = 1.0;

void fragment() {
    // UV.x 从0(头部)到1(尾部)
    vec4 gradient_color = mix(start_color, end_color, UV.x);

    // 透明度渐变
    float alpha = gradient_color.a * (1.0 - UV.x * trail_fade);

    // 添加一些噪点纹理效果
    float noise = fract(sin(UV.x * 100.0 + UV.y * 50.0) * 43758.5453);
    alpha *= (0.9 + noise * 0.1);

    ALBEDO = gradient_color.rgb;
    ALPHA = alpha;
    EMISSION = gradient_color.rgb * emission_strength;
}
