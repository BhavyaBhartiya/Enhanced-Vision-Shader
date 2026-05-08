#version 330 compatibility

uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D depthtex0;
uniform int worldTime;
uniform float frameTimeCounter;
uniform float viewWidth;
uniform float viewHeight;
uniform float rainStrength;
uniform mat4 gbufferProjection;
uniform vec3 sunPosition;

in vec2 texcoord;

/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 color;

vec3 blur(vec2 uv, float r) {
	vec2 p = r / vec2(viewWidth, viewHeight);
	vec3 c = texture(colortex0, uv).rgb;
	c += texture(colortex0, uv + vec2( p.x, 0.0)).rgb;
	c += texture(colortex0, uv + vec2(-p.x, 0.0)).rgb;
	c += texture(colortex0, uv + vec2(0.0,  p.y)).rgb;
	c += texture(colortex0, uv + vec2(0.0, -p.y)).rgb;
	return c * 0.2;
}

float edge(vec2 uv) {
	vec2 p = 1.0 / vec2(viewWidth, viewHeight);
	float d = texture(depthtex0, uv).r;
	float e = 0.0;
	e += abs(d - texture(depthtex0, uv + vec2( p.x, 0.0)).r);
	e += abs(d - texture(depthtex0, uv + vec2(-p.x, 0.0)).r);
	e += abs(d - texture(depthtex0, uv + vec2(0.0,  p.y)).r);
	e += abs(d - texture(depthtex0, uv + vec2(0.0, -p.y)).r);
	return smoothstep(0.001, 0.01, e);
}

float heatsourcemask(vec3 color) {
	float red = smoothstep(0.55, 0.95, color.r);
	float green = smoothstep(0.15, 0.55, color.g);
	float blue = 1.0 - smoothstep(0.20, 0.45, color.b);
	return red * green * blue;
}

float screenfade(vec2 uv) {
	vec2 a = smoothstep(vec2(0.02), vec2(0.12), uv);
	vec2 b = 1.0 - smoothstep(vec2(0.88), vec2(0.98), uv);
	return a.x * a.y * b.x * b.y;
}

float nightamount() {
	float t = float(worldTime);
	return smoothstep(12600.0, 13400.0, t) * (1.0 - smoothstep(22400.0, 23400.0, t));
}

vec2 projectsun(out float w) {
	vec4 clip = gbufferProjection * vec4(sunPosition, 1.0);
	w = clip.w;
	return clip.xy / max(abs(clip.w), 1e-4) * 0.5 + 0.5;
}

float skymask(vec2 uv) {
	return smoothstep(0.996, 0.99998, texture(depthtex0, clamp(uv, vec2(0.0), vec2(1.0))).r);
}

float sunshaft(vec2 rel, vec2 dir, float width) {
	float side = abs(dot(rel, vec2(-dir.y, dir.x)));
	float along = abs(dot(rel, dir));
	float line = 1.0 - smoothstep(width, width * 2.4, side);
	float fade = smoothstep(0.035, 0.09, along) * (1.0 - smoothstep(0.10, 0.45, along));
	return line * fade;
}

vec3 godrays(vec2 uv, vec3 scene) {
	float day = 1.0 - nightamount();
	if (day <= 0.01) return scene;

	float w = 0.0;
	vec2 sunuv = projectsun(w);
	if (w <= 0.0) return scene;

	float frame = step(-0.04, sunuv.x) * step(-0.04, sunuv.y) * step(sunuv.x, 1.04) * step(sunuv.y, 1.04);
	float mask = frame * skymask(sunuv) * skymask(uv) * (1.0 - rainStrength * 0.80);
	if (mask <= 0.001) return scene;

	vec2 rel = uv - sunuv;
	float dist = length(rel);
	float halo = pow(max(1.0 - smoothstep(0.012, 0.16, dist), 0.0), 2.0);
	float shafts = 0.0;
	shafts += sunshaft(rel, normalize(vec2(1.0, 0.36)), 0.010);
	shafts += sunshaft(rel, normalize(vec2(1.0, -0.26)), 0.011);
	shafts += sunshaft(rel, normalize(vec2(0.42, 1.0)), 0.009) * 0.65;

	float amount = mask * day * screenfade(uv);
	vec3 rays = vec3(1.00, 0.91, 0.72) * (shafts * 0.10 + halo * 0.08) * amount;
	return scene + rays;
}

vec3 reflectblur(vec2 uv, vec2 p) {
	vec3 c = texture(colortex0, uv).rgb * 0.40;
	c += texture(colortex0, uv + vec2( p.x * 3.0, 0.0)).rgb * 0.15;
	c += texture(colortex0, uv + vec2(-p.x * 3.0, 0.0)).rgb * 0.15;
	c += texture(colortex0, uv + vec2(0.0,  p.y * 3.0)).rgb * 0.15;
	c += texture(colortex0, uv + vec2(0.0, -p.y * 3.0)).rgb * 0.15;
	return c;
}

float waterline(vec2 uv, vec2 p) {
	float line = min(uv.y + 260.0 * p.y, 0.98);
	for (int i = 1; i < 80; i++) {
		float y = uv.y + float(i) * 4.0 * p.y;
		if (y > 0.98) break;
		if (texture(colortex1, vec2(uv.x, y)).r < 0.5) {
			line = y;
			break;
		}
	}
	return line;
}

vec3 reflectwater(vec2 uv, vec3 c) {
	vec4 water = texture(colortex1, uv);
	if (water.r < 0.5) return c;

	vec2 p = 1.0 / vec2(viewWidth, viewHeight);
	float line = waterline(uv, p);
	float dist = max(line - uv.y, 0.0);
	float ripple = sin(uv.x * 120.0 + frameTimeCounter * 1.4);
	ripple += sin((uv.x - uv.y) * 80.0 - frameTimeCounter * 1.1);

	vec2 ruv = uv;
	ruv.x += ripple * (1.5 + dist * 16.0) * p.x;
	ruv.y = line + dist * 0.86;
	ruv.y += ripple * (1.0 + dist * 12.0) * p.y;
	ruv = clamp(ruv, vec2(0.0), vec2(1.0));

	vec3 reflection = reflectblur(ruv, p);
	reflection = mix(reflection, texture(colortex0, clamp(ruv + vec2(0.0, 18.0) * p, vec2(0.0), vec2(1.0))).rgb, 0.25);

	float angle = 1.0 - smoothstep(0.18, 0.62, dist);
	float deepwater = smoothstep(0.02, 0.28, dist);
	float reflectamount = (0.08 + angle * 0.26) * deepwater * screenfade(ruv);
	return mix(c, reflection, reflectamount);
}

void main() {
	const float sharpixels = 60.0;
	const float blurpixels = 300.0;
	const float bluradius = 3.0;
	const float shimmer = 3.0;

	vec2 p = 1.0 / vec2(viewWidth, viewHeight);

	float heatamount = heatsourcemask(texture(colortex0, texcoord).rgb);
	heatamount = max(heatamount, heatsourcemask(texture(colortex0, texcoord - vec2(0.0, 30.0) * p).rgb));
	heatamount = max(heatamount, heatsourcemask(texture(colortex0, texcoord - vec2(0.0, 60.0) * p).rgb));

	float wave = sin(texcoord.y * 90.0 + frameTimeCounter * 7.0) * heatamount;
	vec2 uv = texcoord + vec2(wave, wave * 0.5) * shimmer * p;
	vec4 sharp = texture(colortex0, uv);

	float dist = length((texcoord - vec2(0.5)) * vec2(viewWidth, viewHeight));
	float bluramount = clamp((dist - sharpixels) / (blurpixels - sharpixels), 0.0, 1.0);

	vec3 final = mix(sharp.rgb, blur(uv, bluradius), bluramount);
	final = reflectwater(texcoord, final);
	final = godrays(texcoord, final);

	float brightness = dot(final, vec3(0.299, 0.587, 0.114));
	float darkness = 1.0 - smoothstep(0.12, 0.35, brightness);
	float outline = edge(texcoord) * darkness;

	final = mix(final, vec3(0.85, 0.95, 1.0), outline * 0.75);
	color = vec4(final, sharp.a);
}
