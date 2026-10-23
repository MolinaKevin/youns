shader_type spatial;
render_mode blend_mix, depth_prepass_alpha, cull_disabled, diffuse_lambert;

uniform vec4 deep_color : source_color = vec4(0.025, 0.20, 0.32, 1.0);
uniform vec4 shallow_color : source_color = vec4(0.08, 0.48, 0.58, 1.0);
uniform float wave_height = 0.09;
uniform float wave_scale = 0.32;
uniform float wave_speed = 1.35;

void vertex() {
	float wave_a = sin((VERTEX.x + VERTEX.z * 0.65) * wave_scale + TIME * wave_speed);
	float wave_b = sin((VERTEX.z - VERTEX.x * 0.4) * wave_scale * 1.7 + TIME * wave_speed * 0.72);
	VERTEX.y += (wave_a + wave_b) * wave_height * 0.5;
}

void fragment() {
	float ripple = sin((UV.x * 12.8 + UV.y * 19.2) + TIME * 1.8) * 0.5 + 0.5;
	ALBEDO = mix(deep_color.rgb, shallow_color.rgb, ripple * 0.38 + 0.18);
	METALLIC = 0.12;
	ROUGHNESS = 0.22;
	EMISSION = shallow_color.rgb * 0.10;
	ALPHA = 0.78;
}
