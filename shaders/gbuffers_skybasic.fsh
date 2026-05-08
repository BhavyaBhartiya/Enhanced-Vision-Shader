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
	return mix(skyColor, fogColor, fogify(max(updot, 0.0), 0.25));
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

float softband(vec2 uv, float speed, float scale) {
	float a = sin(uv.x * scale + frameTimeCounter * speed + uv.y * 6.0);
	float b = sin(uv.x * scale * 1.62 - frameTimeCounter * speed * 1.25 - uv.y * 13.0);
	float c = sin((uv.x * 0.6 + uv.y) * scale * 0.85 + frameTimeCounter * speed * 0.72);
	return a * 0.36 + b * 0.24 + c * 0.16 + 0.5;
}

vec3 aurora(vec3 dir, vec2 uv, float night) {
	float low = smoothstep(0.04, 0.18, dir.y);
	float high = 1.0 - smoothstep(0.54, 0.86, dir.y);
	float height = low * high;

	float curtain1 = smoothstep(0.38, 0.74, softband(uv * vec2(1.0, 1.8), 0.105, 17.0));
	float curtain2 = smoothstep(0.46, 0.82, softband(uv.yx + vec2(0.24, 0.06), 0.145, 25.0));
	float curtain3 = smoothstep(0.54, 0.90, softband(uv * vec2(1.6, 2.4) + vec2(0.37, 0.11), 0.075, 31.0));
	float streaks = 0.64 + 0.36 * sin(uv.y * 145.0 + uv.x * 18.0 - frameTimeCounter * 0.78);
	streaks *= 0.78 + 0.22 * sin(uv.y * 55.0 - frameTimeCounter * 0.37);

	float body = height * (curtain1 * 0.55 + curtain2 * 0.32 + curtain3 * 0.22) * streaks * night;
	float glow = height * smoothstep(0.20, 0.75, curtain1 + curtain2) * night;

	vec3 col = vec3(0.04, 0.82, 0.46) * body;
	col += vec3(0.08, 0.36, 0.95) * body * curtain2;
	col += vec3(0.68, 0.16, 0.66) * body * curtain3;
	col += vec3(0.05, 0.35, 0.22) * glow * 0.25;
	return col * 0.62;
}

vec3 nightsky(vec3 viewdir) {
	float night = nightamount();
	vec3 dir = normalize((gbufferModelViewInverse * vec4(viewdir, 0.0)).xyz);
	vec2 uv = skyuv(dir);

	vec3 base = mix(vec3(0.006, 0.011, 0.032), vec3(0.013, 0.026, 0.060), smoothstep(-0.15, 0.58, dir.y));
	float milky = 1.0 - smoothstep(0.045, 0.21, abs(dir.x * 0.58 + dir.z * 0.80));
	base += vec3(0.06, 0.085, 0.14) * milky * starlayer(uv + vec2(0.17, 0.0), 18.0, 0.58, 1.25) * 0.22;

	float stars = 0.0;
	stars += starlayer(uv, 98.0, 0.948, 1.05);
	stars += starlayer(uv + vec2(0.31, 0.17), 172.0, 0.981, 0.80) * 0.90;
	stars += starlayer(uv + vec2(0.67, 0.42), 58.0, 0.916, 1.35) * 1.10;

	vec3 sky = base;
	sky += vec3(0.82, 0.88, 1.00) * stars * night * 1.35;
	sky += aurora(dir, uv, night);
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
