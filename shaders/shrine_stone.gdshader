shader_type spatial;

render_mode unshaded;

uniform float hue_shift_speed : hint_range(0.0, 10.0) = 1.0;
uniform float saturation : hint_range(0.0, 2.0) = 1.0;
uniform float brightness : hint_range(0.0, 2.0) = 1.0;
uniform float emission_strength : hint_range(0.0, 5.0) = 1.5;
uniform vec3 base_color : source_color = vec3(0.5, 0.7, 1.0);

vec3 rgb2hsv(vec3 c) {
    vec4 K = vec4(0.0, -1.0/3.0, 2.0/3.0, -1.0);
    vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
    vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));

    float d = q.x - min(q.w, q.y);
    float e = 1e-10;
    return vec3(abs((q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 hsv2rgb(vec3 c) {
    vec4 K = vec4(1.0, 2.0/3.0, 1.0/3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

void fragment() {
    float hue = mod(TIME * hue_shift_speed, 1.0);
    vec3 hsv = rgb2hsv(base_color);
    hsv.x = mod(hsv.x + hue, 1.0);
    hsv.y *= saturation;
    hsv.z *= brightness;

    vec3 color = hsv2rgb(hsv);

    ALBEDO = color;
    EMISSION = color * emission_strength;
}