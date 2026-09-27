// Aurora flame: domain-warped fbm "flame tongues" rising from the bottom edge,
// with a palette that drifts coral -> gold -> teal -> sky -> violet -> pink.
// One shader, three looks (u.a.w = mode): 0 pastel field, 1 light, 2 night.
// Drawn as a fullscreen triangle, so no vertex or index buffers are needed.

struct Uniforms {
    a: vec4<f32>,   // x, y = canvas size in px, z = time (s), w = mode
    b: vec4<f32>,   // x = seed, y = reach multiplier, zw unused
}

@group(0) @binding(0)
var<uniform> u: Uniforms;

struct VertexOutput {
    @builtin(position) position: vec4<f32>,
    @location(0) uv: vec2<f32>,
}

@vertex
fn vs_main(@builtin(vertex_index) vertexIndex: u32) -> VertexOutput {
    var pos = array<vec2<f32>, 3>(
        vec2<f32>(-1.0, -1.0),
        vec2<f32>(3.0, -1.0),
        vec2<f32>(-1.0, 3.0),
    );
    let p = pos[vertexIndex];
    var out: VertexOutput;
    out.position = vec4<f32>(p, 0.0, 1.0);
    // uv.y = 0 at the bottom edge, 1 at the top.
    out.uv = p * 0.5 + vec2<f32>(0.5, 0.5);
    return out;
}

// --- value noise + fbm ------------------------------------------------------

fn hash(p: vec2<f32>) -> f32 {
    return fract(sin(dot(p, vec2<f32>(127.1, 311.7))) * 43758.5453);
}

fn noise(p: vec2<f32>) -> f32 {
    let i = floor(p);
    let f = fract(p);
    let w = f * f * (vec2<f32>(3.0) - 2.0 * f);
    return mix(
        mix(hash(i), hash(i + vec2<f32>(1.0, 0.0)), w.x),
        mix(hash(i + vec2<f32>(0.0, 1.0)), hash(i + vec2<f32>(1.0, 1.0)), w.x),
        w.y,
    );
}

fn fbm(p0: vec2<f32>) -> f32 {
    var p = p0;
    var v = 0.0;
    var amp = 0.5;
    let r = mat2x2<f32>(0.8, -0.6, 0.6, 0.8);
    for (var i = 0; i < 4; i++) {
        v += amp * noise(p);
        p = r * p * 1.97 + vec2<f32>(11.7, 11.7);
        amp *= 0.45;
    }
    return v;
}

// --- palette: six keys sampled from the reference, blended around a loop ----

fn pal(h: f32) -> vec3<f32> {
    var keys = array<vec3<f32>, 6>(
        vec3<f32>(1.00, 0.42, 0.36),   // coral
        vec3<f32>(1.00, 0.72, 0.28),   // gold
        vec3<f32>(0.25, 0.80, 0.78),   // teal
        vec3<f32>(0.45, 0.66, 1.00),   // sky
        vec3<f32>(0.68, 0.45, 1.00),   // violet
        vec3<f32>(1.00, 0.45, 0.68),   // pink
    );
    let x = fract(h) * 6.0;
    let i = i32(floor(x)) % 6;
    let j = (i + 1) % 6;
    let f = smoothstep(0.0, 1.0, fract(x));
    return mix(keys[i], keys[j], f);
}

@fragment
fn fs_main(in: VertexOutput) -> @location(0) vec4<f32> {
    let res = u.a.xy;
    let t = u.a.z;
    let mode = i32(u.a.w + 0.5);
    let seed = u.b.x;
    let reachMul = select(1.0, u.b.y, u.b.y > 0.0);
    let uv = in.uv;
    let aspect = res.x / max(res.y, 1.0);

    // Flame space: squashed horizontally so features stretch upward, scrolling up.
    let p = vec2<f32>(uv.x * aspect * 2.2, uv.y * 1.4) + vec2<f32>(seed, seed);
    let q = vec2<f32>(
        fbm(p + vec2<f32>(0.0, -t * 0.35)),
        fbm(p + vec2<f32>(5.2, -t * 0.30) + vec2<f32>(1.3, 1.3)),
    );
    let r = vec2<f32>(
        fbm(p + 3.0 * q + vec2<f32>(1.7, 9.2) + vec2<f32>(0.15 * t, -0.4 * t)),
        fbm(p + 3.0 * q + vec2<f32>(8.3, 2.8) - vec2<f32>(0.12 * t, 0.35 * t)),
    );
    let f = fbm(p + 2.6 * r);

    // Height of the flame front: low for the framed posters, full-bleed for the field.
    var reach = 0.60;
    if (mode == 0) { reach = 0.95; } else if (mode == 1) { reach = 0.52; }
    reach *= reachMul;
    let front = reach * (0.55 + 0.75 * f) + 0.10 * sin(t * 0.7 + uv.x * 5.0);
    let y = uv.y + 0.22 * (r.y - 0.5);
    var mask = smoothstep(front, 0.0, y);
    mask = pow(mask, select(1.35, 0.8, mode == 0));

    let hue = t * 0.06 + 0.55 * r.x + 0.35 * uv.x + seed * 0.1;
    var col: vec3<f32>;
    if (mode == 2) {
        // Saturated fire/aurora on near-black; white-hot spots where the field peaks.
        let c = pal(hue);
        let core = smoothstep(0.62, 1.05, mask * (0.45 + 0.9 * f));
        col = vec3<f32>(0.086, 0.082, 0.094) + c * mask * 1.05 + vec3<f32>(1.0, 0.96, 0.9) * core * 0.95;
    } else if (mode == 1) {
        // Pale tints bleeding into white paper.
        let c = mix(pal(hue + 0.3), vec3<f32>(1.0), 0.25);
        col = mix(vec3<f32>(1.0), c, mask * 0.9);
    } else {
        // Pastel field: sky-blue ceiling, rosy warped body, white mist between.
        let c = mix(pal(hue + 0.6), vec3<f32>(1.0), 0.35);
        let sky = vec3<f32>(0.70, 0.88, 0.98);
        let mist = smoothstep(0.25, 0.75, fbm(p * 0.8 + q * 2.0 - vec2<f32>(0.0, t * 0.1)));
        col = mix(sky, vec3<f32>(1.0), smoothstep(0.95, 0.55, uv.y) * 0.8);
        col = mix(col, c, mask * 0.85);
        col = mix(col, vec3<f32>(1.0), mist * 0.45 * (1.0 - mask * 0.5));
    }

    // Fine grain so the soft gradients don't band.
    col += vec3<f32>((hash(in.position.xy + vec2<f32>(fract(t) * 91.0)) - 0.5) * 0.018);
    return vec4<f32>(clamp(col, vec3<f32>(0.0), vec3<f32>(1.0)), 1.0);
}
