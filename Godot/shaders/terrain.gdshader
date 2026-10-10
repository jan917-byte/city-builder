shader_type spatial;
render_mode cull_back, specular_disabled;
#include "res://shaders/boue.gdshaderinc"
#include "res://shaders/crue.gdshaderinc"
#include "res://shaders/saison.gdshaderinc"

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
	ALBEDO = diagnostic ? COLOR.rgb * 0.394 : herbe_saison(COLOR.rgb, vert) * (1.0 + grain);
	// La carte des dangers ne s'arrête pas au dernier îlot : le champ, si.
	float h_eau = crue_vue > 0 ? crue_hauteur(monde.xz, 1.0) : 0.0;
	float fw_eau = fwidth(h_eau);
	if (diagnostic && crue_vue > 0) {
		// Un fond de carte, pas un relief : les collines ne s'ombrent plus.
		ALBEDO = CRUE_PAPIER;
		NORMAL = (VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz;
	}
	if (diagnostic && crue_vue > 0 && monde.y < 1.5) {
		vec4 eau = crue_sol(h_eau, fw_eau);
		ALBEDO = mix(ALBEDO, eau.rgb * COLOR.a, eau.a);
	}
	if (!diagnostic) {
		vec4 depot = depot_boue(monde);
		ALBEDO = mix(ALBEDO, depot.rgb * COLOR.a, depot.a);
		// ❄️ Le quai et la paroi du chenal sont verticaux : seul le dessus blanchit.
		float haut = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz).y;
		ALBEDO = mix(ALBEDO, S_NEIGE * COLOR.a, neige_manteau(monde) * smoothstep(0.42, 0.78, haut));
	}
	ROUGHNESS = 1.0;
}
