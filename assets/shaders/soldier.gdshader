shader_type spatial;
render_mode diffuse_lambert, specular_disabled, vertex_lighting;
uniform sampler2D cloth_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform float walk_amount = 0.0;
uniform float phase = 0.0;
void vertex() {
	float lower = clamp((0.86 - VERTEX.y) / 0.72, 0.0, 1.0);
	float step = sin(TIME * 9.0 + sign(VERTEX.x) * 1.5708 + phase);
	VERTEX.z += step * 0.24 * lower * walk_amount;
	VERTEX.y += max(step, 0.0) * 0.08 * lower * walk_amount;
}
void fragment() {
	float tile = floor(COLOR.a * 7.0 + 0.5) - 1.0;
	vec2 cell = vec2(mod(max(tile, 0.0), 3.0), floor(max(tile, 0.0) / 3.0));
	// Inset by one pixel to keep neighboring atlas tiles out of bilinear filtering.
	vec2 tile_uv = (fract(UV) * 510.0 + 1.0) / 512.0;
	vec3 cloth = tile >= 0.0 ? texture(cloth_texture, (cell + tile_uv) / vec2(3.0, 2.0)).rgb : vec3(1.0);
	ALBEDO = COLOR.rgb * mix(cloth, vec3(1.0), 0.20);
	ROUGHNESS = 1.0;
}
