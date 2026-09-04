shader_type spatial;
render_mode cull_disabled, diffuse_lambert, specular_disabled;

// Opaque two-sided voxel material. Some special block models intentionally
// contain mixed winding, so back faces remain visible while their normals are
// corrected for stable lighting.
uniform sampler2D albedo_texture : source_color, filter_nearest;

void fragment() {
	vec4 tex = texture(albedo_texture, UV);
	ALBEDO = tex.rgb;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
}
