shader_type canvas_item;

uniform vec4 cutout_rect = vec4(0.0,0.0,0.0,0.0);
varying vec2 local_pos;
uniform sampler2D source_texture: filter_nearest, repeat_disable;

void vertex() {
	local_pos = VERTEX;
}

void fragment() {
    // Check if the current pixel falls inside the cutout rectangle
    if (local_pos.x >= cutout_rect.x && local_pos.x <= (cutout_rect.x + cutout_rect.z) &&
        local_pos.y >= cutout_rect.y && local_pos.y <= (cutout_rect.y + cutout_rect.w)) {
        // Erase pixel (make completely transparent)
        COLOR = vec4(0.0);
    }
}
