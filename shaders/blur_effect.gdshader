shader_type canvas_item;

uniform sampler2D screen_texture: hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform float blur_radius : hint_range(0, 1) = 0.2;
uniform float blur_amount : hint_range(0, 5) = 1.0;
uniform float blur_inner : hint_range(0, 1) = 0.6;
uniform float blur_outer : hint_range(0, 1) = 0.66;

void fragment() {
    vec4 pixelColor = texture(screen_texture, UV);
    vec4 blurColor = textureLod(screen_texture, SCREEN_UV, blur_amount);

    float distance = length(UV - vec2(0.5, 0.5));
    float blur = smoothstep(blur_inner - blur_radius, blur_outer, distance);

    pixelColor.rgb = mix(blurColor.rgb, COLOR.rgb, -blur);

    blurColor.a = blur;
    blurColor.rgb = mix(blurColor.rgb, vec3(1.0), 0.1);

    COLOR = blurColor;
}