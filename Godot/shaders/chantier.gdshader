shader_type spatial;
render_mode cull_disabled;

uniform float temps = 0.0;
uniform bool grue = false;
instance uniform float phase = 0.0;
varying vec2 balise;

void vertex() {
	balise = INSTANCE_CUSTOM.rg;
	if (grue && COLOR.a > 0.5) {
		float angle = sin(temps * 0.22 + phase) * 0.48;
		mat2 rotation = mat2(vec2(cos(angle), -sin(angle)), vec2(sin(angle), cos(angle)));
		VERTEX.xz = rotation * VERTEX.xz;
		NORMAL.xz = rotation * NORMAL.xz;
	}
}

void fragment() {
	vec3 orange = vec3(0.92, 0.28, 0.035);
	if (grue) {
		ALBEDO = COLOR.rgb;
	} else if (balise.x < 0.5) {
		float diagonale = UV.x * 5.0 + UV.y * 1.5;
		float largeur = max(fwidth(diagonale), 0.015);
		float rayure = smoothstep(-largeur, largeur, sin(diagonale * 6.283185));
		ALBEDO = mix(vec3(0.91, 0.85, 0.67), orange, rayure);
	} else if (balise.x < 1.5) {
		ALBEDO = vec3(0.12, 0.16, 0.17);
	} else {
		float eclat = pow(0.5 + 0.5 * sin(temps * 2.4 - balise.y), 4.0);
		ALBEDO = mix(orange, vec3(1.0, 0.75, 0.25), eclat);
		EMISSION = vec3(1.0, 0.40, 0.04) * (0.2 + eclat * 1.8);
	}
	ROUGHNESS = 0.85;
}
