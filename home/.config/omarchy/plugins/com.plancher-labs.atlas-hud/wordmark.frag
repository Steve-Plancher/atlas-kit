// A.T.L.A.S wordmark animator.
//
// Draws a pixel-exact copy of the wallpaper's title box (830x125 at 420,368 in
// 00-atlas.png) back over its own pixels, so the painted letters can be dimmed,
// displaced and recoloured, not just brightened. Everything is masked to the
// glyphs and faded out at the crop border, so no effect can reveal a rectangle
// against the wallpaper behind it.
//
// uMode: 0 off, 1 power-on, 2 sweep, 3 glitch, 4 reactive, 5 hologram.

#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
  mat4 qt_Matrix;
  float qt_Opacity;
  float uTime;    // seconds
  float uMode;
  float uEnergy;  // 0..1 input pressure (reactive)
  float uPulse;   // 0..1 last keystroke, decaying (reactive)
  float uBoot;    // 0..1 HUD boot progress
  vec4 uIce;      // protocol palette (atlas-protocol); Standby = the blues
  vec4 uCyan;
};

layout(binding = 1) uniform sampler2D src;

#define ICE  uIce.rgb
#define CYAN uCyan.rgb

float hash11(float n) { return fract(sin(n * 127.1) * 43758.5453); }
float hash21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float lum(vec3 c) { return dot(c, vec3(0.2126, 0.7152, 0.0722)); }

// Soft border so no effect touches the edge of the crop.
float edgeFade(vec2 uv) {
  vec2 f = smoothstep(vec2(0.0), vec2(0.035, 0.12), uv)
         * smoothstep(vec2(1.0), vec2(0.965, 0.88), uv);
  return f.x * f.y;
}

void main() {
  vec2 uv = qt_TexCoord0;
  vec3 base = texture(src, uv).rgb;
  vec3 col = base;

  float fade = edgeFade(uv);
  // The letters: bright ice-blue on a near-black plate. Anything dimmer is the
  // painted ring system showing through the box and must be left alone.
  float glyph = smoothstep(0.16, 0.52, lum(base));
  float core = smoothstep(0.45, 0.85, lum(base));
  int mode = int(uMode + 0.5);

  if (mode == 1) {
    // ── Power-on: ignites left to right, flickers, settles into a breathe ──
    float p = fract(uTime / 9.0);
    float prog = clamp(p / 0.40, 0.0, 1.0);
    float front = prog * 1.18 - 0.09;
    float lit = smoothstep(front + 0.10, front - 0.03, uv.x);
    float edge = exp(-pow((uv.x - front) / 0.045, 2.0)) * (1.0 - step(0.999, prog));

    // Three hard flickers just after the fill completes.
    float fl = 1.0;
    if (p > 0.40 && p < 0.56) fl = mix(0.28, 1.0, step(0.45, hash11(floor(uTime * 17.0))));
    float breathe = 0.86 + 0.14 * sin(uTime * 1.6);

    float k = mix(0.18, 1.0, lit) * fl * (prog > 0.99 ? breathe : 1.0);
    vec3 lit_col = base * k + ICE * edge * 1.9 + CYAN * lit * core * 0.25;
    col = mix(base, lit_col, glyph * fade);
    col += ICE * edge * core * 0.5 * fade;

  } else if (mode == 2) {
    // ── Energy sweep: a charge band running through the glyphs ──
    float p = fract(uTime / 6.0);
    float band = p * 1.5 - 0.25;
    float d = uv.x - band;
    float head = exp(-pow(d / 0.055, 2.0));
    float tail = exp(clamp(d, -1.0, 0.0) / 0.16) * step(d, 0.0) * 0.55;
    float hot = clamp(head + tail, 0.0, 1.4);
    col = base + (ICE * head * 1.5 + CYAN * tail * 0.9) * glyph * fade
               + base * hot * glyph * 0.8 * fade;

  } else if (mode == 3) {
    // ── Glitch burst: slice offsets, channel split, dropouts ──
    float burst = floor(uTime / 4.0);
    float local = fract(uTime / 4.0) * 4.0;
    // Only some windows fire, so the gaps are irregular (10-20s typical).
    float fires = step(0.62, hash11(burst * 3.7));
    float env = fires * exp(-local * 6.0) * step(local, 0.5);

    float row = floor(uv.y * 14.0);
    float slice = (hash21(vec2(row, burst * 7.0 + floor(local * 40.0))) - 0.5) * 0.09 * env;
    float band = step(0.55, hash21(vec2(row, burst)));
    vec2 guv = vec2(clamp(uv.x + slice * band, 0.0, 1.0), uv.y);

    float split = 0.012 * env;
    vec3 g;
    g.r = texture(src, vec2(clamp(guv.x + split, 0.0, 1.0), guv.y)).r;
    g.g = texture(src, guv).g;
    g.b = texture(src, vec2(clamp(guv.x - split, 0.0, 1.0), guv.y)).b;

    // One or two letter-width columns drop out mid-burst.
    float colId = floor(uv.x * 9.0);
    float drop = step(0.88, hash21(vec2(colId, burst * 5.0 + floor(local * 12.0)))) * env;
    g *= 1.0 - drop * 0.9;
    g += ICE * env * 0.25 * step(0.7, hash21(vec2(row, burst + 11.0)));

    col = mix(base, g, fade);

  } else if (mode == 4) {
    // ── Reactive: flares with typing and clicks ──
    float e = clamp(uEnergy, 0.0, 1.0);
    float pulse = clamp(uPulse, 0.0, 1.0);
    // Ripple leaving the centre of the word on each keystroke.
    float d = abs(uv.x - 0.5);
    float ring = exp(-pow((d - (1.0 - pulse) * 0.55) / 0.07, 2.0)) * pulse;
    float breathe = 0.5 + 0.5 * sin(uTime * 2.2);
    // Gains stay modest: sustained typing holds energy near 1, and anything
    // hotter clips the letters to flat white and loses their gradient.
    vec3 hot = base * (1.0 + e * 0.7 + ring * 1.1)
             + ICE * ring * 0.8
             + CYAN * e * breathe * 0.25;
    col = mix(base, hot, glyph * fade);

  } else if (mode == 5) {
    // ── Hologram: rolling scanlines, jitter, flicker, chromatic fringe ──
    float jitter = (hash11(floor(uTime * 12.0)) - 0.5) * 0.012;
    float wob = sin(uTime * 0.9) * 0.004;
    vec2 huv = clamp(uv + vec2(wob, jitter), vec2(0.0), vec2(1.0));

    // A wide fringe reads as green, because shifting red and blue apart leaves
    // the green channel alone in the middle of every stroke. Keep it subpixel.
    vec3 h;
    // Roughly one panel pixel. Wider than that and each stroke's left edge
    // loses blue while keeping red, which reads as a green rim on the glyphs.
    float fr = 0.0008 + 0.0006 * abs(sin(uTime * 0.7));
    h.r = texture(src, clamp(huv + vec2(fr, 0.0), vec2(0.0), vec2(1.0))).r;
    h.g = texture(src, huv).g;
    h.b = texture(src, clamp(huv - vec2(fr, 0.0), vec2(0.0), vec2(1.0))).b;

    // 34 cycles over the box is ~3.7 art px per line, which survives the 1.5x
    // upscale to the panel; 90 aliased into thick zebra banding.
    float scan = 0.86 + 0.14 * sin(huv.y * 34.0 - uTime * 5.0);
    float roll = smoothstep(0.0, 0.25, abs(fract(huv.y * 0.5 - uTime * 0.18) - 0.5));
    float flick = 0.92 + 0.08 * hash11(floor(uTime * 20.0));
    h *= scan * flick * mix(0.86, 1.06, roll);
    h += ICE * 0.10 * (1.0 - scan) * core;

    col = mix(base, h, clamp(glyph + 0.35 * core, 0.0, 1.0) * fade);
  }

  fragColor = vec4(clamp(col, vec3(0.0), vec3(1.6)), 1.0) * qt_Opacity;
}
