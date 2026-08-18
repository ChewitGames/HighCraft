shader_type spatial;
render_mode blend_mix, cull_disabled, diffuse_lambert, specular_schlick_ggx;

// HighCraft realistic water: simple animated wave displacement + soft
// fresnel-style edge brightening. Cheap (vertex-only wave, no extra passes)
// so it is safe to run on every water face in view.

uniform sampler2D albedo_texture : source_color, filter_nearest;
uniform float wave_speed : hint_range(0.0, 5.0) = 1.0;
uniform float wave_height : hint_range(0.0, 0.3) = 0.06;
uniform vec4 tint : source_color = vec4(0.55, 0.75, 0.95, 0.75);

varying float wave_offset;

void vertex() {
	float t = TIME * wave_speed;
	// World-space-ish coords (VERTEX is local to the chunk mesh, which is
	// good enough here — waves just need to look organic, not be exact).
	wave_offset = sin(VERTEX.x * 1.3 + t) * 0.5 + cos(VERTEX.z * 1.7 + t * 0.8) * 0.5;
	VERTEX.y += wave_offset * wave_height;
}

void fragment() {
	vec4 tex = texture(albedo_texture, UV);
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	ALBEDO = mix(tex.rgb * tint.rgb, vec3(1.0), fresnel * 0.4);
	ALPHA = clamp(tex.a * tint.a + fresnel * 0.2, 0.0, 1.0);
	ROUGHNESS = 0.05;
	SPECULAR = 0.9;
}
