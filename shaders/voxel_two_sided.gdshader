shader_type spatial;
render_mode cull_disabled, diffuse_lambert, specular_disabled;

// Opaque two-sided voxel material. Some special block models intentionally
// contain mixed winding, so back faces remain visible while their normals are
// corrected for stable lighting.
//
// Lighting follows the classic voxel recipe: each face direction carries a
// fixed brightness (top brightest, bottom darkest) and the baked vertex colour
// holds Minecraft-style ambient occlusion. The result reads as "smooth
// lighting" without a screen-space pass.
uniform sampler2D albedo_texture : source_color, filter_nearest;

// Classic face-brightness curve (top / x-sides / z-sides / bottom).
const float FACE_TOP = 1.00;
const float FACE_X = 0.60;
const float FACE_Z = 0.80;
const float FACE_BOTTOM = 0.50;

float face_brightness(vec3 n) {
	vec3 a = abs(n);
	// Dominant axis decides the shading band.
	if (a.y >= a.x && a.y >= a.z) {
		return n.y > 0.0 ? FACE_TOP : FACE_BOTTOM;
	}
	if (a.x > a.z) {
		return FACE_X;
	}
	return FACE_Z;
}

void fragment() {
	vec4 tex = texture(albedo_texture, UV);
	// COLOR holds baked ambient occlusion as a grey scale (white = none). Meshes
	// without a colour array get white from the engine, so special models that
	// do not compute AO stay fully lit.
	ALBEDO = tex.rgb * face_brightness(NORMAL) * COLOR.rgb;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
}
