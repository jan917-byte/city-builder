shader_type spatial;
render_mode cull_back, specular_disabled;

uniform bool diagnostic = false;
varying vec3 monde;
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
float bruit(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0)), f.x), f.y);
}
void vertex() {
	monde = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	float vert = smoothstep(0.01, 0.10, COLOR.g - COLOR.b);
	float large = bruit(monde.xz * 0.085);
	float net = 1.0 - smoothstep(0.3, 1.2, length(fwidth(monde.xz)));
	float fin = bruit(monde.xz * 1.6);
	float grain = (large - 0.5) * mix(0.05, 0.20, vert) + (fin - 0.5) * 0.055 * net;
	ALBEDO = COLOR.rgb * (diagnostic ? vec3(0.394) : vec3(1.0 + grain));
	ROUGHNESS = 1.0;
}
