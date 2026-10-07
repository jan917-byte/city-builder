shader_type spatial;
render_mode cull_back, specular_disabled;
#include "res://shaders/brume.gdshaderinc"
// Arbres de ville et de forêt, couronne et tronc. CUSTOM0 = centre du lobe et
// son rôle (`Constructeur.arbre`) : 0 fixe, 1 couronne, ≥ 2 satellite.
uniform bool tronc = false;
uniform vec3 ecorce : source_color = vec3(0.54, 0.48, 0.40);
// Zéro en ville : pas de brume. La forêt reçoit la demi-emprise du décor.
uniform vec2 demi_emprise = vec2(0.0);

varying vec3 local;
varying vec3 monde;

float alea(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

void vertex() {
	vec3 origine = MODEL_MATRIX[3].xyz;
	// 🌳 Chaque arbre joue la recette à sa façon, tiré de SA position : même
	// ville, mêmes arbres, et les ombres suivent (même calcul dans leur passe).
	float role = CUSTOM0.w;
	if (role > 0.5) {
		vec2 graine = floor(origine.xz * 4.0) * 0.731 + vec2(role * 3.7, role * 9.1);
		float a = alea(graine);
		float b = alea(graine + 17.0);
		float c = alea(graine + 41.0);
		vec3 centre = CUSTOM0.xyz;
		float s = role < 1.5 ? mix(0.90, 1.10, a) : mix(0.62, 1.18, a);
		vec3 decale = role < 1.5 ? vec3(0.0)
			: vec3(b - 0.5, (c - 0.5) * 0.5, c - b) * 0.9;
		// Un satellite sur cinq manque : la couronne s'ouvre d'un côté.
		if (role > 1.5 && alea(graine + 73.0) < 0.2) s = 0.0;
		VERTEX = centre + decale + (VERTEX - centre) * s;
	}
	local = VERTEX;
	float prise = smoothstep(0.3, 5.5, VERTEX.y);
	VERTEX.x += sin(TIME * 1.15 + origine.x * 0.13 + origine.z * 0.17) * 0.055 * prise;
	VERTEX.z += cos(TIME * 0.85 + origine.z * 0.19) * 0.035 * prise;
	monde = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 couleur = ecorce;
	if (!tronc) {
		float grain = sin(local.x * 4.0 + local.y * 2.1) * sin(local.z * 3.5 - local.y);
		float net = 1.0 - smoothstep(0.2, 1.0, length(fwidth(local)));
		couleur = COLOR.rgb * vec3(0.86, 1.0, 0.92) * (1.0 + grain * 0.085 * net);
	}
	float brume = demi_emprise.x > 0.0 ? brume_bord(monde.xz, demi_emprise) : 0.0;
	ALBEDO = couleur * (1.0 - brume);
	EMISSION = BRUME_CIEL * brume;
	ROUGHNESS = 0.95;
}
