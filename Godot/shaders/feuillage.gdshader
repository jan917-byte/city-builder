shader_type spatial;
render_mode cull_back, specular_disabled;

varying vec3 local;
void vertex() {
	local = VERTEX;
	vec3 origine = MODEL_MATRIX[3].xyz;
	float prise = smoothstep(0.3, 5.5, VERTEX.y);
	VERTEX.x += sin(TIME * 1.15 + origine.x * 0.13 + origine.z * 0.17) * 0.055 * prise;
	VERTEX.z += cos(TIME * 0.85 + origine.z * 0.19) * 0.035 * prise;
}

void fragment() {
	float grain = sin(local.x * 4.0 + local.y * 2.1) * sin(local.z * 3.5 - local.y);
	float net = 1.0 - smoothstep(0.2, 1.0, length(fwidth(local)));
	ALBEDO = COLOR.rgb * vec3(0.86, 1.0, 0.92) * (1.0 + grain * 0.085 * net);
	ROUGHNESS = 0.95;
}
