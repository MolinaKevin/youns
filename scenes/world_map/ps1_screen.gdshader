shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;
uniform float pixel_size : hint_range(1.0, 8.0) = 3.0;

void fragment() {
	vec2 snapped = floor(SCREEN_UV / (pixel_size * SCREEN_PIXEL_SIZE)) * pixel_size * SCREEN_PIXEL_SIZE;
	COLOR = texture(screen_texture, snapped);
}
