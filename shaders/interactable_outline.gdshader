shader_type spatial;
render_mode unshaded, cull_front;

uniform bool enable = false; //
uniform float outline_thickness = 0.05;
uniform float outline_view_bias = 0.01;
uniform vec4 outline_color : source_color = vec4(0.0);

void vertex() {
	if (enable) {
		// Offset along normal
		VERTEX += NORMAL * outline_thickness;

		// Compute world-space camera position
		vec3 camera_pos = (INV_VIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
		vec3 world_vertex = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;

		// Offset slightly toward camera to reduce cracks
		vec3 to_camera = normalize(camera_pos - world_vertex);
		VERTEX += to_camera * outline_view_bias;
	}
}

void fragment() {
	if (enable) {
		ALBEDO = outline_color.rgb;
	}
}
