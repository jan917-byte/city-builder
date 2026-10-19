// 🔥 La fumée des souches (auteur, 2026-10-19) : un peu toute l'année, plus en
// hiver. Une bouffée = un carré face caméra qui monte, grossit, part au vent.
// 🔴 Flaggable (90) : rendu choisi par Claude, provisoire (2026-10-19).
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, skip_vertex_transform, unshaded;
#include "res://shaders/saison.gdshaderinc"

// La même montée que la ville (`materiaux.gd`, DENSE_VERTEX) : la souche suit son toit.
instance uniform vec4 densification = vec4(0.0, 1.0, 0.0, 0.0);
uniform float horloge = -1.0;   // ≥ 0 : figé, pour deux captures égales

const float VIE_S = 9.0;
const float MONTEE_M = 8.0;
const float DERIVE_M = 12.0;
const vec2 VENT = vec2(0.94, 0.34);   // d'ouest, un peu du nord

varying float opacite;
varying float graine;

// INSTANCE_CUSTOM = (rang de montée, la souche suit-elle le toit, phase, seuil de froid).
void vertex() {
	vec4 c = INSTANCE_CUSTOM;
	// Le bâti rebâti moderne (95) n'a plus de souche : rang 1e6, comme dans 07.
	float ancien = (c.x > 1.0e5 && densification.w > 0.5) ? 0.0 : 1.0;
	float leve = c.y * densification.z
		* clamp((densification.x - c.x) / max(densification.y, 0.001), 0.0, 1.0);
	float t = horloge < 0.0 ? TIME : horloge;
	float age = fract(t / VIE_S + c.z);
	float f = saison_fumee;
	// Une souche s'allume quand le froid passe son seuil : peu en été, toutes en hiver.
	float allume = smoothstep(c.w, c.w + 0.08, f) * ancien;
	float h = MONTEE_M * (1.0 - (1.0 - age) * (1.0 - age)) * mix(0.7, 1.0, f);
	vec2 d = VENT * DERIVE_M * age * age
		+ vec2(sin(age * 5.0 + c.z * 30.0), cos(age * 4.0 + c.z * 20.0)) * 0.6 * age;
	vec3 centre = MODEL_MATRIX[3].xyz + vec3(d.x, leve + 0.3 + h, d.y);
	float taille = mix(0.7, 4.2, sqrt(age)) * mix(0.75, 1.15, f);
	VERTEX = (VIEW_MATRIX * vec4(centre, 1.0)).xyz + vec3(VERTEX.xy * taille, 0.0);
	opacite = allume * smoothstep(0.0, 0.08, age) * pow(1.0 - age, 1.6) * mix(0.25, 0.75, f);
	graine = c.z * 37.0;
}

void fragment() {
	float r = length(UV - 0.5) * 2.0;
	float n = saison_bruit(UV * 3.0 + graine) * 0.6 + saison_bruit(UV * 7.0 - graine) * 0.4;
	// Sans lumière, sinon le soleil la blanchit quelle que soit sa teinte, et sur
	// la neige elle se perdait (auteur, 2026-10-19). Le jeu n'a pas de nuit.
	ALBEDO = mix(vec3(0.30, 0.30, 0.31), vec3(0.15, 0.15, 0.16), saison_neige);
	ALPHA = smoothstep(1.0, 0.25, r + (n - 0.5) * 0.7) * opacite;
}
