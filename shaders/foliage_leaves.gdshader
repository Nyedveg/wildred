shader_type spatial;
render_mode blend_mix, depth_prepass_alpha, depth_draw_opaque, cull_disabled;

uniform vec3 color : source_color;
uniform vec3 color2 : source_color;
uniform sampler2D noise;
uniform float noiseScale = 20.0;

// === LEAF TEXTURE SUPPORT ===
uniform sampler2D leaf_texture;

// === WIND PARAMETERS ===
uniform float swayStrength = 0.12;
uniform float swaySpeed = 1.0;

// === PLAYER INTERACTION ===
global uniform vec3 player_position;
global uniform vec3 player_velocity;
uniform float interact_radius = 1.5;
uniform float velocity_threshold = 0.2;
uniform float spring_strength = 0.05;
uniform float blend_ease_power = 0.5; // 0.3–0.7 = slower in/out, 1.0 = linear

varying vec3 worldPos;

void vertex() {
	worldPos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;

	// === WIND SWAY ===
	vec2 noiseUV = (worldPos.xz + vec2(TIME * swaySpeed, TIME * 0.7 * swaySpeed)) / noiseScale;
	float noiseValue = texture(noise, noiseUV).r;
	float swayBase = (noiseValue - 0.5) * 2.0 * swayStrength * (1.0 - UV.y);
	vec2 wind_sway = vec2(swayBase, swayBase * 0.5);

	// === PLAYER INTERACTION ===
	float dist = distance(worldPos.xz, player_position.xz);
	float distance_falloff = smoothstep(interact_radius, 0.0, dist);

	float speed = length(player_velocity.xz);
	vec2 vel_dir = speed > velocity_threshold ? normalize(player_velocity.xz) : vec2(0.0);

	float spring = sin(TIME * 15.0 + worldPos.x * 0.3 + worldPos.z * 0.3);

	vec2 player_push = -vel_dir * swayStrength * 2.0 * (1.0 - UV.y) * distance_falloff;
	player_push += -vel_dir * spring * spring_strength * (1.0 - UV.y) * distance_falloff;

	float speed_blend = clamp(speed / 1.0, 0.0, 1.0);
	speed_blend = pow(speed_blend, blend_ease_power);
	float blend_strength = speed_blend * distance_falloff;

	vec2 final_displacement = mix(wind_sway, player_push, blend_strength);

	VERTEX.x += final_displacement.x;
	VERTEX.z += final_displacement.y;
}

void fragment() {
	// Sample the leaf texture using UV
	vec4 tex_color = texture(leaf_texture, UV);

	// Optional noise blend for organic color variation
	vec3 noiseFactor = texture(noise, worldPos.xz / noiseScale).rgb;
	vec3 blended_color = mix(color, color2, noiseFactor.r);

	// Final color is modulated by texture and optional blend
	ALBEDO = tex_color.rgb * blended_color;
	ALPHA = tex_color.a;

	// Fix normals for double-sided leaves
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
}