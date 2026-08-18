shader_type spatial;
render_mode blend_mix, cull_disabled, diffuse_lambert, alpha_to_coverage;

// HighCraft wind sway for plant-cross meshes (flowers, tall grass).
// Only the top vertices move (UV.y == 0 at the top, == 1 at the base, per
// ChunkMesher's UVS winding), so plants sway like they're rooted in the
// ground instead of just translating sideways.

uniform sampler2D albedo_texture : source_color, filter_nearest;
uniform float wind_strength : hint_range(0.0, 0.5) = 0.09;
uniform float wind_speed : hint_range(0.0, 5.0) = 1.4;

void vertex() {
	float top_factor = 1.0 - UV.y; // 1.0 at top of the cross, 0.0 at base
	float t = TIME * wind_speed;
	float sway = sin(t + VERTEX.x * 0.6 + VERTEX.z * 0.6) * wind_strength;
	float sway2 = cos(t * 0.85 + VERTEX.x * 0.35) * wind_strength * 0.6;
	VERTEX.x += sway * top_factor;
	VERTEX.z += sway2 * top_factor;
}

void fragment() {
	vec4 tex = texture(albedo_texture, UV);
	ALBEDO = tex.rgb;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	ALPHA = tex.a;
}
