#version 330 compatibility

in vec2 mc_Entity;

out vec2 lmcoord;
out vec2 texcoord;
out vec4 glcolor;

uniform float frameTimeCounter;

float foliageprofile(float blockid) {
	if (abs(blockid - 1001.0) < 0.5) return 0.48;
	if (abs(blockid - 1002.0) < 0.5) return 0.74;
	if (abs(blockid - 1003.0) < 0.5) return 0.54;
	if (abs(blockid - 1004.0) < 0.5) return 0.58;
	if (abs(blockid - 1005.0) < 0.5) return 0.50;
	return 0.0;
}

float bendmask(float blockid, vec2 uv) {
	if (abs(blockid - 1001.0) < 0.5) return 0.86;
	return mix(0.46, 1.0, smoothstep(0.10, 0.92, uv.y));
}

vec3 foliagewave(vec3 position, float blockid, vec2 uv) {
	float profile = foliageprofile(blockid);
	if (profile <= 0.0) return position;

	float time = frameTimeCounter;
	float bend = bendmask(blockid, uv) * profile;
	float bigwind = sin(time * 0.72 + position.x * 0.24 + position.z * 0.20);
	bigwind += 0.45 * sin(time * 1.08 + position.x * 0.43 - position.z * 0.31);
	float smallwind = sin(time * 1.85 + uv.x * 3.8 + uv.y * 2.6 + position.z * 0.18);
	float sidewind = cos(time * 0.64 + position.z * 0.28 + uv.x * 1.6);

	vec2 sway = vec2(bigwind * 0.042 + smallwind * 0.010, sidewind * 0.028 + smallwind * 0.006) * bend;
	position.x += sway.x;
	position.z += sway.y;
	position.y += (bigwind * 0.003 + smallwind * 0.002) * bend;
	return position;
}

void main() {
	texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
	lmcoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
	glcolor = gl_Color;

	vec3 wavedposition = foliagewave(gl_Vertex.xyz, mc_Entity.x, texcoord);
	gl_Position = gl_ModelViewProjectionMatrix * vec4(wavedposition, 1.0);
}
