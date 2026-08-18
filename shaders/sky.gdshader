shader_type sky;

uniform float time_of_day : hint_range(0.0, 1.0) = 0.3;
uniform float rain_amount : hint_range(0.0, 1.0) = 0.0;
uniform float thunder_flash : hint_range(0.0, 1.0) = 0.0;   // ← NEU für Gewitter

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

void sky() {
    // === ZEIT ===
    float angle = time_of_day * TAU;
    float elevation = sin(angle - PI * 0.5);
    float day = smoothstep(-0.12, 0.18, elevation);
    float night = 1.0 - smoothstep(-0.05, 0.22, elevation);

    // === HIMMEL FARBEN ===
    vec3 day_top = vec3(0.22, 0.52, 0.92);
    vec3 day_horizon = vec3(0.72, 0.82, 0.98);
    vec3 night_top = vec3(0.003, 0.008, 0.035);
    vec3 night_horizon = vec3(0.025, 0.04, 0.10);

    float horizon = clamp(abs(EYEDIR.y), 0.0, 1.0);
    vec3 day_color = mix(day_horizon, day_top, horizon);
    vec3 night_color = mix(night_horizon, night_top, horizon);
    vec3 color = mix(night_color, day_color, day);

    // === SONNE ===
    vec3 sun_dir = normalize(vec3(0.0, sin(angle - PI * 0.5), cos(angle - PI * 0.5)));
    float sun_dot = max(dot(EYEDIR, sun_dir), 0.0);
    float sun_glow = pow(sun_dot, 25.0);
    float sun_disk = pow(sun_dot, 250.0);
    color += vec3(1.0, 0.75, 0.45) * sun_glow * day;
    color += vec3(1.0, 0.95, 0.75) * sun_disk * day;

    // === MOND ===
    vec3 moon_dir = -sun_dir;
    float moon_dot = max(dot(EYEDIR, moon_dir), 0.0);
    float moon_glow = pow(moon_dot, 25.0);
    float moon_disk = pow(moon_dot, 180.0);
    color += vec3(0.4, 0.55, 1.0) * moon_glow * night;
    color += vec3(0.85, 0.9, 1.0) * moon_disk * night;

    // =========================
    // WOLKEN - Stark verbessert
    // =========================
    vec3 dir = normalize(EYEDIR);

    // Bessere Projektion → keine langen/streckten Wolken mehr + natürlichere Verteilung
    float cloud_height = 0.13;
    vec2 cloud_uv = dir.xz / max(dir.y + cloud_height, 0.025);
    cloud_uv *= 2.9;

    // Bewegung
    cloud_uv.x += TIME * 0.011;
    cloud_uv.y += TIME * 0.0025;

    // Mehr Oktaven = schönere, fluffigere Wolken (nicht mehr abgeschnitten)
    float clouds = 0.0;
    float amp = 0.55;
    float freq = 1.0;
    for (int i = 0; i < 5; i++) {
        clouds += noise(cloud_uv * freq) * amp;
        freq *= 1.95;
        amp *= 0.48;
    }

    // === GEWITTER / REGEN COVERAGE ===
    float coverage = mix(0.47, 0.18, rain_amount);           // bei Regen viel mehr Wolken
    float softness = mix(0.23, 0.10, rain_amount);
    clouds = smoothstep(coverage, coverage + softness, clouds);

    // Wolkenfarbe
    vec3 cloud_color = mix(vec3(0.20, 0.23, 0.30), vec3(0.92, 0.95, 1.0), day * 0.65);
    cloud_color = mix(cloud_color, vec3(0.12, 0.14, 0.18), rain_amount * 0.9); // dunkler bei Regen

    float cloud_alpha = clouds * mix(0.5, 0.95, rain_amount); // bei Regen fast undurchsichtig

    color = mix(color, cloud_color, cloud_alpha);

    // === STERNE ===
    vec2 star_pos = floor(EYEDIR.xz * 600.0);
    float stars = step(0.9985, hash(star_pos));
    float twinkle = 0.7 + 0.3 * sin(TIME * 4.0 + hash(star_pos) * 20.0);
    color += vec3(1.0) * stars * twinkle * night;

    // === REGEN abdunkeln ===
    color = mix(color, color * 0.55, rain_amount);

    // === GEWITTER-BLITZ (kurzes Aufhellen) ===
    color += vec3(0.65, 0.72, 0.95) * thunder_flash * 1.1;

    COLOR = color;
}