shader_type spatial;
// Agua estilo PS1: luz por vértice, colores en bandas (sin degradé suave),
// olitas en los vértices y un dibujo de ruido que se desplaza con el tiempo.
// Usa coordenadas del mundo, así dos mallas de agua vecinas empalman.
render_mode vertex_lighting, specular_disabled, cull_disabled, blend_mix, depth_draw_opaque;

uniform vec4 deep_color : source_color = vec4(0.10, 0.30, 0.52, 0.86);
uniform vec4 shallow_color : source_color = vec4(0.26, 0.58, 0.74, 0.78);
uniform vec4 foam_color : source_color = vec4(0.86, 0.94, 0.96, 0.92);
// Olas (en metros y radianes/segundo).
uniform float wave_height = 0.10;
uniform float wave_length = 9.0;
uniform float wave_speed = 0.9;
// Dibujo de la superficie.
uniform float pattern_size = 7.0;
uniform vec2 flow = vec2(0.5, 0.25);
uniform float color_steps : hint_range(2.0, 8.0) = 4.0;
uniform float foam_threshold : hint_range(0.0, 1.0) = 0.76;

varying vec3 world_pos;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float k = 6.2831 / wave_length;
	float w = sin(world_pos.x * k + TIME * wave_speed) + cos(world_pos.z * k * 1.3 + TIME * wave_speed * 0.8);
	VERTEX.y += w * 0.5 * wave_height;
}

void fragment() {
	vec2 uv = world_pos.xz / pattern_size;
	float n = noise(uv + flow * TIME * 0.12) * 0.6 + noise(uv * 2.3 - flow * TIME * 0.2) * 0.4;
	n = floor(n * color_steps) / color_steps;
	vec4 c = mix(deep_color, shallow_color, n);
	if (n >= foam_threshold) {
		c = mix(c, foam_color, 0.65);
	}
	ALBEDO = c.rgb;
	ALPHA = c.a;
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
}
