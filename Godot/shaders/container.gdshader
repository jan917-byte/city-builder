shader_type spatial;
render_mode cull_back;

uniform vec3 dimensions = vec3(5.6, 2.6, 2.9);
varying vec3 local;
varying vec3 face;
varying vec3 nervure_vue;

void vertex() {
	local = VERTEX;
	face = NORMAL;
	nervure_vue = (MODELVIEW_MATRIX * vec4(abs(NORMAL.z) > 0.5 ?
		vec3(1.0, 0.0, 0.0) : vec3(0.0, 0.0, 1.0), 0.0)).xyz;
}

float rectangle(vec2 p, vec2 centre, vec2 demi) {
	vec2 d = abs(p - centre) - demi;
	float bord = max(d.x, d.y);
	return 1.0 - smoothstep(-fwidth(bord), fwidth(bord) + 0.001, bord);
}

void fragment() {
	vec3 base = COLOR.rgb;
	float vitrage = 0.0;
	float panneau = step(0.9, COLOR.a);
	float vertical = 1.0 - step(0.5, abs(face.y));
	float u = abs(face.z) > 0.5 ? local.x : local.z;
	float phase = u * 6.283185 / 0.22;
	float finesse = 1.0 - smoothstep(0.3, 1.6, fwidth(phase));
	float nervure = cos(phase) * finesse;
	base *= 1.0 - panneau * vertical * (0.035 + 0.045 * nervure);
	float pied = 1.0 - smoothstep(0.18, 0.55, local.y);
	base *= 1.0 - 0.12 * pied;
	if (panneau > 0.5 && abs(face.z) > 0.5) {
		vec2 p = local.xy;
		float porte = face.z > 0.0 ? rectangle(p,
			vec2(-dimensions.x * 0.29, 1.23), vec2(0.48, 1.01)) : 0.0;
		float vantail = face.z > 0.0 ? rectangle(p,
			vec2(-dimensions.x * 0.29, 1.23), vec2(0.41, 0.94)) : 0.0;
		base = mix(base, vec3(0.13, 0.19, 0.21), porte);
		base = mix(base, COLOR.rgb * 0.72, vantail);
		float poignee = face.z > 0.0 ? rectangle(p,
			vec2(-dimensions.x * 0.29 + 0.29, 1.16), vec2(0.07, 0.022)) : 0.0;
		base = mix(base, vec3(0.10), poignee);
		for (int i = 0; i < 2; i++) {
			float x = face.z > 0.0 ? 0.02 + float(i) * 1.70 : -1.45 + float(i) * 2.90;
			float cadre = rectangle(p, vec2(x, 1.61), vec2(0.60, 0.48));
			float verre = rectangle(p, vec2(x, 1.61), vec2(0.52, 0.40));
			float montant = rectangle(p, vec2(x, 1.61), vec2(0.023, 0.40));
			base = mix(base, vec3(0.72, 0.75, 0.73), cadre);
			vec3 reflet = mix(vec3(0.08, 0.17, 0.20), vec3(0.27, 0.43, 0.48),
				smoothstep(1.22, 2.0, local.y));
			base = mix(base, reflet, verre * (1.0 - montant));
			vitrage = max(vitrage, verre * (1.0 - montant));
		}
	}
	// La toiture porte de légers joints pliés, filtrés en vue lointaine.
	if (COLOR.a > 0.3 && COLOR.a < 0.7 && face.y > 0.5) {
		base *= 0.96 + 0.04 * cos(local.z * 25.0) *
			(1.0 - smoothstep(0.4, 1.5, fwidth(local.z * 25.0)));
	}
	ALBEDO = base;
	NORMAL = normalize(NORMAL - normalize(nervure_vue) * sin(phase) * 0.16 *
		finesse * panneau * vertical * (1.0 - vitrage));
	ROUGHNESS = mix(0.72, 0.22, vitrage);
	METALLIC = mix(0.15, 0.35, vitrage);
	SPECULAR = 0.35;
}
