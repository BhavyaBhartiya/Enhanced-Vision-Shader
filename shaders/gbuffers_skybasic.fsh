#version 330 compatibility

uniform int renderStage;
uniform int worldTime;
uniform float viewHeight;
uniform float viewWidth;
uniform float frameTimeCounter;
uniform float rainStrength;
uniform mat4 gbufferModelView;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform vec3 fogColor;
uniform vec3 skyColor;

in vec4 glcolor;

float fogify(float x, float w) {
	return w / (x * x + w);
}

vec3 calcskycolor(vec3 pos) {
	float updot = dot(pos, gbufferModelView[1].xyz);
	float horizon = smoothstep(-0.18, 0.70, updot);
	vec3 horizonCol = mix(fogColor, vec3(0.54, 0.69, 0.96), 0.62);
	vec3 zenithCol = mix(skyColor, vec3(0.25, 0.39, 0.94), 0.72);
	return mix(horizonCol, zenithCol, horizon);
}

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

vec3 screentoview(vec3 screenpos) {
	vec4 ndcpos = vec4(screenpos, 1.0) * 2.0 - 1.0;
	vec4 tmp = gbufferProjectionInverse * ndcpos;
	return tmp.xyz / tmp.w;
}

float nightamount() {
	float t = float(worldTime);
	float afterdusk = smoothstep(12600.0, 13400.0, t);
	float beforedawn = 1.0 - smoothstep(22400.0, 23400.0, t);
	return afterdusk * beforedawn * (1.0 - rainStrength * 0.35);
}

vec2 skyuv(vec3 dir) {
	float lon = atan(dir.z, dir.x) / 6.2831853 + 0.5;
	float lat = clamp(dir.y * 0.5 + 0.5, 0.0, 1.0);
	return vec2(lon, lat);
}

float starlayer(vec2 uv, float scale, float threshold, float size) {
	vec2 cell = floor(uv * scale);
	vec2 local = fract(uv * scale) - 0.5;
	float seed = hash12(cell);
	float star = smoothstep(threshold, 1.0, seed);
	float radius = mix(0.030, 0.009, seed) * size;
	float core = 1.0 - smoothstep(radius, radius * 2.3, length(local));
	float twinkle = 0.78 + 0.22 * sin(frameTimeCounter * (0.7 + seed * 2.1) + seed * 18.0);
	return core * star * twinkle;
}

float valuenoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = hash12(i);
	float b = hash12(i + vec2(1.0, 0.0));
	float c = hash12(i + vec2(0.0, 1.0));
	float d = hash12(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm(vec2 p) {
	float s = 0.0;
	float w = 0.5;
	for (int i = 0; i < 4; i++) {
		s += valuenoise(p) * w;
		p = p * 2.03 + vec2(17.1, 9.7);
		w *= 0.5;
	}
	return s;
}

vec3 aurora(vec3 dir, float night) {
	float aurora_on = night * (1.0 - rainStrength * 0.60);
	if (aurora_on < 0.001) return vec3(0.0);

	float low = smoothstep(0.03, 0.20, dir.y);
	float high = 1.0 - smoothstep(0.42, 0.74, dir.y);
	float height = low * high;

	float lon = atan(dir.z, dir.x);
	float t = frameTimeCounter * 0.01;
	vec2 domain = vec2(lon * 2.2, dir.y * 5.4);
	float n1 = fbm(domain + vec2(t * 0.7, -t * 0.4));
	float n2 = fbm(domain * 1.7 + vec2(-t * 0.5, t * 0.3));
	float curtain = smoothstep(0.50, 0.80, n1 * 0.70 + n2 * 0.30);
	float folds = 0.80 + 0.20 * sin(dir.y * 150.0 + n2 * 10.0 - t * 7.0);
	float veil = smoothstep(0.42, 0.86, n1) * height;

	float body = height * curtain * folds;
	float intensity = aurora_on * (0.92 + 0.08 * sin(t * 2.4 + lon * 1.8));

	vec3 col = vec3(0.06, 0.74, 0.55) * body;
	col += vec3(0.10, 0.40, 0.78) * body * smoothstep(0.58, 0.90, n2);
	col += vec3(0.08, 0.38, 0.26) * veil * 0.18;
	return col * intensity * 0.34;
}

vec3 nightsky(vec3 viewdir) {
	float night = nightamount();
	vec3 dir = normalize((gbufferModelViewInverse * vec4(viewdir, 0.0)).xyz);
	vec2 uv = skyuv(dir);

	vec3 base = mix(vec3(0.006, 0.011, 0.032), vec3(0.013, 0.026, 0.060), smoothstep(-0.15, 0.58, dir.y));
	float milky = 1.0 - smoothstep(0.045, 0.21, abs(dir.x * 0.58 + dir.z * 0.80));
	base += vec3(0.08, 0.10, 0.16) * milky * starlayer(uv + vec2(0.17, 0.0), 18.0, 0.54, 1.30) * 0.35;

	float stars = 0.0;
	stars += starlayer(uv, 98.0, 0.930, 1.10);
	stars += starlayer(uv + vec2(0.31, 0.17), 172.0, 0.970, 0.90) * 1.10;
	stars += starlayer(uv + vec2(0.67, 0.42), 58.0, 0.890, 1.45) * 1.30;

	vec3 sky = base;
	sky += vec3(0.86, 0.92, 1.00) * stars * night * 2.45;
	sky += aurora(dir, night);
	return sky;
}

/* RENDERTARGETS: 0,1 */
layout(location = 0) out vec4 color;
layout(location = 1) out vec4 water;

void main() {
	float night = nightamount();

	if (renderStage == MC_RENDER_STAGE_STARS) {
		vec3 stars = glcolor.rgb * mix(vec3(0.76, 0.84, 1.0), vec3(1.0), 0.45);
		color = vec4(stars, glcolor.a * night);
	} else {
		vec3 pos = screentoview(vec3(gl_FragCoord.xy / vec2(viewWidth, viewHeight), 1.0));
		vec3 viewdir = normalize(pos);
		vec3 finalsky = mix(calcskycolor(viewdir), nightsky(viewdir), night);
		color = vec4(finalsky, 1.0);
	}

	water = vec4(0.0);
}
