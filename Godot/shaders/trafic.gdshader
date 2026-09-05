shader_type spatial;

global uniform float temps_trafic;
uniform sampler2D trajets : filter_nearest, repeat_disable;
varying vec4 teinte;

void vertex() {
	float longueur = max(INSTANCE_CUSTOM.z, 0.01);
	float s = clamp((INSTANCE_CUSTOM.x + temps_trafic * INSTANCE_CUSTOM.y)
		/ longueur, 0.0, 1.0) * float(textureSize(trajets, 0).x - 1);
	int i = int(floor(s));
	int arc = int(round(INSTANCE_CUSTOM.w));
	vec4 a = texelFetch(trajets, ivec2(i, arc), 0);
	vec4 b = texelFetch(trajets,
		ivec2(min(i + 1, textureSize(trajets, 0).x - 1), arc), 0);
	vec4 pose = mix(a, b, fract(s));
	vec2 direction = normalize(pose.zw);
	mat2 rotation = mat2(vec2(direction.y, -direction.x), direction);
	VERTEX.xz = pose.xy + rotation * VERTEX.xz;
	NORMAL.xz = rotation * NORMAL.xz;
	teinte = COLOR;
}

void fragment() {
	ALBEDO = teinte.rgb;
	ROUGHNESS = 0.72;
}
