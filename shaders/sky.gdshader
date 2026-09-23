shader_type sky;

// HighCraft sky — styled after the classic 1.6.4 skybox:
//   * one uniform day blue that bleeds into the fog colour right at the
//     horizon (the original fades the sky to transparency ~7° above the
//     horizon and lets the fog take over the atmosphere),
//   * an almost pure-black night sky,
//   * hard SQUARE sun & moon discs that clouds/fog never wash out,
//   * flat, blocky cloud fields drifting slowly westward,
//   * a warm sunrise/sunset band and a star field that rotates with the sky.
uniform float time_of_day : hint_range(0.0, 1.0) = 0.3;
uniform float rain_amount : hint_range(0.0, 1.0) = 0.0;
uniform float thunder_flash : hint_range(0.0, 1.0) = 0.0;

// --- 1.6.4 palette -------------------------------------------------------
const vec3 SKY_BLUE  = vec3(0.455, 0.655, 1.00);  // plains/forest zenith (#78A7FF)
const vec3 FOG_BLUE  = vec3(0.620, 0.722, 0.965); // classic horizon fog blue
const vec3 DEEP_BLUE = vec3(0.150, 0.260, 0.540); // sky below the horizon
const vec3 NIGHT     = vec3(0.004, 0.006, 0.014); // night is essentially black

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    float a = hash(i);
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

// Angular size using a Chebyshev (square) metric instead of a dot product,
// so the sun/moon render as hard squares. `facing` = dot(dir, body_dir).
float square_angular_size(vec3 dir, vec3 body_dir, out float facing) {
    facing = dot(dir, body_dir);
    if (facing <= 0.001) {
        return 1e9;
    }
    vec3 up = abs(body_dir.y) < 0.95 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0);
    vec3 right = normalize(cross(up, body_dir));
    vec3 up2 = normalize(cross(body_dir, right));
    float u = dot(dir, right) / facing;
    float v = dot(dir, up2) / facing;
    return max(abs(u), abs(v));
}

void sky() {
    vec3 dir = normalize(EYEDIR);

    float angle = time_of_day * TAU;
    float elevation = sin(angle - PI * 0.5);
    float day = smoothstep(-0.12, 0.18, elevation);
    float night = 1.0 - smoothstep(-0.05, 0.22, elevation);
    // Warm band centred on the horizon for sunrise/sunset.
    float dusk = exp(-pow(elevation / 0.22, 2.0));

    // === SKY GRADIENT =====================================================
    // Below horizon → deep blue; a band right at the horizon → fog colour;
    // everything above → the uniform Minecraft day blue.
    float below = smoothstep(-0.06, 0.10, dir.y);
    float horizon = smoothstep(0.0, 0.14, dir.y); // ~8°, like the original fade
    vec3 sky_day = mix(DEEP_BLUE, SKY_BLUE, below);
    sky_day = mix(FOG_BLUE, sky_day, horizon);
    vec3 color = mix(NIGHT, sky_day, day);

    // Sunrise/sunset warmth, strongest low in the sky.
    float warmth = dusk * (1.0 - smoothstep(0.0, 0.45, dir.y));
    color = mix(color, vec3(1.0, 0.52, 0.22), warmth * 0.45);

    // === STARS (rotate with the night sky) ================================
    float cs = cos(angle);
    float sn = sin(angle);
    vec2 sky_uv = vec2(dir.x * cs - dir.z * sn, dir.x * sn + dir.z * cs);
    vec2 star_pos = floor(sky_uv * 620.0);
    float stars = step(0.997, hash(star_pos));
    float twinkle = 0.6 + 0.4 * sin(TIME * 3.5 + hash(star_pos) * 25.0);
    color += vec3(0.92, 0.93, 1.0) * stars * twinkle * night * (1.0 - rain_amount);

    // === CLOUDS (flat blocky fields drifting west) ========================
    float cloud_mask = 0.0;
    if (dir.y > 0.01) {
        // Project onto a high cloud plane and drift slowly.
        vec2 cuv = dir.xz / dir.y * 1.7;
        cuv.x += TIME * 0.007;
        cuv.y += TIME * 0.0015;
        // Coarse clusters + per-block holes = rectangular puffs with gaps.
        vec2 coarse = floor(cuv / 3.0);
        vec2 fine = floor(cuv);
        float shape = hash(coarse) * 0.6 + hash(coarse + vec2(7.1, 3.9)) * 0.4;
        float hole = hash(fine);
        float threshold = mix(0.44, 0.26, rain_amount);
        cloud_mask = step(threshold, shape) * step(0.28, hole);
        cloud_mask *= smoothstep(0.01, 0.30, dir.y); // fade near the horizon
    }
    vec3 cloud_color = mix(vec3(0.82, 0.84, 0.90), vec3(1.0, 1.0, 1.0), day);
    cloud_color = mix(cloud_color, vec3(0.22, 0.23, 0.28), night * 0.85);
    cloud_color = mix(cloud_color, vec3(0.30, 0.32, 0.37), rain_amount * 0.85);
    float cloud_alpha = cloud_mask * mix(0.85, 1.0, rain_amount);
    color = mix(color, cloud_color, cloud_alpha);

    // === SUN (square) =====================================================
    vec3 sun_dir = normalize(vec3(0.0, sin(angle - PI * 0.5), cos(angle - PI * 0.5)));
    float sun_face;
    float sun_sq = square_angular_size(dir, sun_dir, sun_face);
    float celestial_vis = 1.0 - rain_amount * 0.85;
    float sun_glow = pow(clamp(sun_face, 0.0, 1.0), 16.0);
    float sun_disk = step(sun_sq, 0.055);
    vec3 sun_color = mix(vec3(1.0, 0.98, 0.92), vec3(1.0, 0.58, 0.20), dusk * 0.8);
    color += sun_color * sun_glow * 0.55 * day * celestial_vis;
    color += sun_color * sun_disk * day * celestial_vis;

    // === MOON (square, opposite side) =====================================
    vec3 moon_dir = -sun_dir;
    float moon_face;
    float moon_sq = square_angular_size(dir, moon_dir, moon_face);
    float moon_glow = pow(clamp(moon_face, 0.0, 1.0), 22.0);
    float moon_disk = step(moon_sq, 0.042);
    color += vec3(0.82, 0.88, 1.0) * moon_glow * 0.35 * night * celestial_vis;
    color += vec3(0.92, 0.94, 1.0) * moon_disk * night * celestial_vis;

    // === WEATHER ==========================================================
    color = mix(color, color * 0.55, rain_amount);
    color += vec3(0.65, 0.72, 0.95) * thunder_flash * 1.1;

    COLOR = color;
}
