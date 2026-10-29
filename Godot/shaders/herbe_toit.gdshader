shader_type spatial;
render_mode cull_disabled, specular_disabled;
#include "res://shaders/saison.gdshaderinc"
#include "res://shaders/champs.gdshaderinc"
// L'herbe d'un toit vert (`toits_verts.gd`). COLOR.rgb = vert linéaire déjà nuancé (creux,
// bord) ; COLOR.a = combien le sommet suit le vent (1 au bout d'une mèche).
// Trois échelles, chacune éteinte quand le pixel la dépasse : taches (~6 m), touffes
// (~30 cm), brins (~15 cm). Aucune texture (règle 52).

const vec3 JAUNI = vec3(1.12, 1.06, 0.70);   // × le vert : herbe sèche, tirant au paille
const vec3 BLEUI = vec3(0.86, 0.98, 1.02);   // × le vert : herbe drue, à l'ombre

varying vec3 monde;

float vent(vec2 p) {
	return sin(dot(p, vec2(0.31, 0.19)) - TIME * 1.2 + champ_bruit(p * 0.12) * 4.0);
}

// Un brin par case, orienté au hasard ; 1 sur le brin, 0 entre deux.
float brins(vec2 p, float pas, float tourne) {
	vec2 g = p / pas;
	vec2 id = floor(g);
	vec2 f = fract(g) - 0.5;
	float a = champ_alea(id) * 3.1416 + tourne;
	vec2 d = vec2(cos(a), sin(a));
	float le_long = abs(dot(f, d));
	float en_travers = abs(dot(f, vec2(-d.y, d.x)));
	return (1.0 - smoothstep(0.05, 0.13, en_travers)) * (1.0 - smoothstep(0.28, 0.46, le_long))
		* mix(0.6, 1.0, champ_alea(id + 7.0));
}

// Des touffes rondes, une par case décalée au hasard ; claire au cœur, sombre entre deux.
float touffes(vec2 p, float pas) {
	vec2 g = p / pas;
	vec2 id = floor(g);
	vec2 f = fract(g) - 0.5 - (vec2(champ_alea(id + 3.0), champ_alea(id + 5.0)) - 0.5) * 0.5;
	float r = mix(0.28, 0.48, champ_alea(id + 9.0));
	return (1.0 - smoothstep(r * 0.4, r, length(f))) * mix(0.5, 1.0, champ_alea(id));
}

void vertex() {
	monde = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	// Les mèches du bord se balancent de quelques centimètres.
	VERTEX.xz += vec2(0.04, 0.025) * vent(monde.xz) * COLOR.a;
}

void fragment() {
	vec2 p = monde.xz;
	float px = length(fwidth(p));
	vec3 c = COLOR.rgb;
	// Taches : jauni et dru par plaques, toujours visibles.
	float tache = champ_bruit(p * 0.16 + 3.0);
	c *= mix(BLEUI, JAUNI, smoothstep(0.35, 0.85, tache) * 0.55);
	c *= mix(0.94, 1.05, champ_bruit(p * 0.6));
	// Touffes : deux semis de 35 et 23 cm, c'est eux qui disent « herbe » au zoom de jeu.
	float t = max(touffes(p, 0.35), touffes(p * mat2(vec2(0.6, 0.8), vec2(-0.8, 0.6)) + 1.7, 0.23));
	c *= mix(1.0, mix(0.78, 1.12, t), 1.0 - smoothstep(0.06, 0.22, px));
	// Brins : deux grilles décalées et tournées, la pointe claire.
	float b = max(brins(p, 0.17, 0.0), brins(p * mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8)) + 0.37, 0.13, 1.3));
	c *= mix(1.0, mix(0.80, 1.16, b), 1.0 - smoothstep(0.025, 0.08, px));
	// Le vent couche l'herbe par vagues : un reflet qui passe, à peine.
	c *= 1.0 + 0.035 * vent(p);
	c = herbe_saison(c, 1.0);
	ALBEDO = mix(c, S_NEIGE, neige_manteau(monde) * 0.85);
	ROUGHNESS = 1.0;
}
