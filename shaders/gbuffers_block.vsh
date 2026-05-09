#version 330 compatibility

in vec2 mc_Entity;

out vec2 lmcoord;
out vec2 texcoord;
out vec4 glcolor;

uniform float frameTimeCounter;

float foliageprofile(float blockid) {
	if (abs(blockid - 1001.0) < 0.5) return 0.92; // Leaves
	if (abs(blockid - 1002.0) < 0.5) return 0.82; // Grass-like
	if (abs(blockid - 1003.0) < 0.5) return 0.62; // Crops
	if (abs(blockid - 1004.0) < 0.5) return 0.72; // Saplings
	if (abs(blockid - 1005.0) < 0.5) return 0.64; // Flowers
	return 0.0;
}

float bendmask(float blockid, vec2 uv) {
	if (abs(blockid - 1001.0) < 0.5) return 1.0;
	return mix(0.55, 1.0, smoothstep(0.08, 0.95, uv.y));
}

vec3 foliagewave(vec3 position, float blockid, vec2 uv) {
	float profile = foliageprofile(blockid);
	if (profile <= 0.0) return position;

	float time = frameTimeCounter;
	float bend = bendmask(blockid, uv) * profile;
	float gust = 0.78 + 0.22 * sin(time * 0.12 + position.x * 0.05 - position.z * 0.06);

	float bigwind = sin(time * 0.52 + position.x * 0.24 + position.z * 0.20);
	bigwind += 0.38 * sin(time * 0.84 + position.x * 0.41 - position.z * 0.33);
	float sidewind = cos(time * 0.44 + position.z * 0.29 + uv.x * 1.6);
	float detail = sin(time * 1.18 + uv.x * 3.0 + uv.y * 2.2 + position.z * 0.17);
	float viewDist = length((gl_ModelViewMatrix * vec4(position, 1.0)).xyz);
	float distBoost = mix(1.0, 2.1, smoothstep(8.0, 56.0, viewDist));

	vec2 sway = vec2(
		(bigwind * 0.11 + detail * 0.04) * gust,
		(sidewind * 0.09 + detail * 0.03) * gust
	) * bend * distBoost;
	position.x += sway.x;
	position.z += sway.y;
	position.y += (bigwind * 0.010 + detail * 0.006) * bend * gust * distBoost;
	return position;
}

void main() {
	texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
	lmcoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
	glcolor = gl_Color;

	vec3 wavedposition = foliagewave(gl_Vertex.xyz, mc_Entity.x, texcoord);
	gl_Position = gl_ModelViewProjectionMatrix * vec4(wavedposition, 1.0);
}