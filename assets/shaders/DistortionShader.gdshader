shader_type canvas_item;

// The 3x3 homography matrix mapping flat destination UV -> source photo UV
uniform mat3 u_homography_matrix = mat3(
	vec3(1.0, 0.0, 0.0),
	vec3(0.0, 1.0, 0.0),
	vec3(0.0, 0.0, 1.0)
);

// Opacity for pixels sampled outside the source photo's valid bounds
uniform float out_bound_opacity : hint_range(0.0, 1.0) = 0.0;

// Optional: Tint or color for the background area outside the photo
uniform vec4 out_bound_color : source_color = vec4(0.0, 0.0, 0.0, 0.2);


void fragment() {
	// 1. Destination UV on the flat target frame (0.0 to 1.0)
	vec2 dest_uv = UV;

	// 2. Project flat frame coordinate back onto the tilted source photo plane
	vec3 projected_coord = u_homography_matrix * vec3(dest_uv, 1.0);

	// 3. Perspective divide (cancel camera foreshortening via depth factor Z)
	vec2 src_uv = projected_coord.xy / projected_coord.z;

	// 4. Sample source texture if within valid bounds [0.0, 1.0]
	if (src_uv.x >= 0.0 && src_uv.x <= 1.0 && src_uv.y >= 0.0 && src_uv.y <= 1.0) {
		COLOR = texture(TEXTURE, src_uv);
	} else {
		// Outside the 4-pin boundary / photo edge: dim or transparent
		if (out_bound_opacity > 0.0) {
			vec4 sampled_tex = texture(TEXTURE, clamp(src_uv, vec2(0.0), vec2(1.0)));
			COLOR = mix(out_bound_color, sampled_tex, out_bound_opacity);
		} else {
			COLOR = vec4(0.0);
		}
	}
}