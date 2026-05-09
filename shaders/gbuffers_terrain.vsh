#version 330 compatibility

in vec2 mc_Entity;

out vec2 lmcoord;
out vec2 texcoord;
out vec4 glcolor;

uniform float frameTimeCounter;

float foliageprofile(float blockid) {
	if (abs(blockid - 1001.0) < 0.5) return 0.86;
	if (abs(blockid - 1002.0) < 0.5) return 0.74;
	if (abs(blockid - 1003.0) < 0.5) return 0.54;
	if (abs(blockid - 1004.0) < 0.5) return 0.58;
	if (abs(blockid - 1005.0) < 0.5) return 0.50;
	return 0.0;
}

float bendmask(float blockid, vec2 uv) {
	if (abs(blockid - 1001.0) < 0.5) return 1.0;
	return mix(0.46, 1.0, smoothstep(0.10, 0.92, uv.y));
}

vec3 foliagewave(vec3 position, float blockid, vec2 uv) {
	float profile = foliageprofile(blockid);
	if (profile <= 0.0) return position;

	float time = frameTimeCounter;
	float bend = bendmask(blockid, uv) * profile;
	float gust = 0.75 + 0.25 * sin(time * 0.14 + position.x * 0.05 - position.z * 0.06);

	float bigwind = sin(time * 0.56 + position.x * 0.22 + position.z * 0.19);
	bigwind += 0.40 * sin(time * 0.90 + position.x * 0.40 - position.z * 0.29);
	float smallwind = sin(time * 1.30 + uv.x * 4.0 + uv.y * 2.8 + position.z * 0.16);
	float sidewind = cos(time * 0.46 + position.z * 0.26 + uv.x * 1.8);
	float micro = sin(time * 2.00 + (position.x + position.z) * 0.18 + uv.y * 6.0);
	float viewDist = length((gl_ModelViewMatrix * vec4(position, 1.0)).xyz);
	float distBoost = mix(1.0, 2.0, smoothstep(8.0, 56.0, viewDist));

	vec2 sway = vec2(
		(bigwind * 0.095 + smallwind * 0.030 + micro * 0.012) * gust,
		(sidewind * 0.075 + smallwind * 0.022 + micro * 0.010) * gust
	) * bend * distBoost;
	position.x += sway.x;
	position.z += sway.y;
	position.y += (bigwind * 0.0090 + smallwind * 0.0060) * bend * gust * distBoost;
	return position;
}

void main() {
	texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
	lmcoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
	glcolor = gl_Color;

	vec3 wavedposition = foliagewave(gl_Vertex.xyz, mc_Entity.x, texcoord);
	gl_Position = gl_ModelViewProjectionMatrix * vec4(wavedposition, 1.0);
}
