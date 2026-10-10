// ❄️🍂 La saison, posée par `saison.gd` : les mêmes globales pour tous les
// matériaux, aucun objet de plus.
global uniform float saison_mois;            // 0 = 1er janvier, continu
global uniform vec2 saison_decalage;         // printemps, automne, en mois (< 0 = en avance)
global uniform float saison_neige;           // la vallée plate, 0 à 1 : toits d'abord, sol ensuite
global uniform float saison_neige_altitude;  // m : au-dessus, les collines sont blanches
global uniform float saison_secheresse;      // herbe jaunie de fin d'été, 0 à 1

// 🔴 Flaggable (90) : couleurs provisoires choisies par Claude, que l'auteur
// remplacera (2026-10-10). LINÉAIRE, sRGB en commentaire.
const vec3 S_NEIGE = vec3(0.855, 0.880, 0.905);        // #EEF1F4
const vec3 S_HERBE_HIVER = vec3(0.270, 0.279, 0.162);  // #8E9070
const vec3 S_PAILLE = vec3(0.584, 0.485, 0.254);       // #C9B98A
const vec3 S_DEBOURRE = vec3(0.456, 0.604, 0.188);     // #B4CC78
const vec3 S_JAUNE = vec3(0.745, 0.515, 0.065);        // #E0BE48 bouleau, peuplier
const vec3 S_ORANGE = vec3(0.694, 0.254, 0.027);       // #D98A2E
const vec3 S_ROUX = vec3(0.468, 0.102, 0.027);         // #B65A2E
const vec3 S_SAULE = vec3(0.584, 0.539, 0.112);        // #C9C25E
const vec3 S_RAMURE = vec3(0.262, 0.205, 0.162);       // #8C7D70 les rameaux d'un arbre nu
const vec3 S_FLEUR = vec3(0.888, 0.791, 0.807);        // #F2E6E8 fruitiers en avril

float saison_alea(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float saison_bruit(vec2 p) {
	vec2 i = floor(p), f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(saison_alea(i), saison_alea(i + vec2(1, 0)), f.x),
		mix(saison_alea(i + vec2(0, 1)), saison_alea(i + vec2(1)), f.x), f.y);
}

// Le manteau ici, vallée ou altitude : en taches quand il est mince ou qu'il fond.
// La pente se règle chez l'appelant.
float neige_manteau(vec3 p) {
	float ligne = saison_neige_altitude + (saison_bruit(p.xz * 0.02) - 0.5) * 70.0;
	float n = smoothstep(ligne - 30.0, ligne + 30.0, p.y);
	// La vallée est plate : la neige y descend des toits et des couronnes au
	// sol, par pans de quelques centaines de mètres, jamais partout d'un coup.
	float v = saison_neige * 1.7 - 0.5 * (1.0 - clamp(p.y / 15.0, 0.0, 1.0))
		- 0.3 * saison_bruit(p.xz * 0.004);
	n = max(n, clamp(v, 0.0, 1.0));
	if (n <= 0.001) return 0.0;
	float b = saison_bruit(p.xz * 0.13) * 0.65 + saison_bruit(p.xz * 0.8) * 0.35;
	return clamp((n * 1.35 - b * 0.95) * 6.0, 0.0, 1.0);
}

// L'herbe suit l'année : terne l'hiver, tendre au printemps, jaunie les étés secs.
// `part` = combien ce sol est de l'herbe ; la valeur est gardée, seule la teinte change.
vec3 herbe_saison(vec3 c, float part) {
	if (part <= 0.0) return c;
	float m = saison_mois;
	float hiver = clamp(1.0 - smoothstep(2.6, 4.2, m) + smoothstep(9.8, 11.0, m), 0.0, 1.0);
	float tendre = smoothstep(3.0, 3.8, m) * (1.0 - smoothstep(4.6, 5.6, m));
	float l = dot(c, vec3(1.0));
	vec3 cible = mix(c, S_HERBE_HIVER * l / 0.7114, hiver * 0.75);
	cible = mix(cible, S_DEBOURRE * l / 1.2481, tendre * 0.3);
	cible = mix(cible, S_PAILLE * l / 1.3234, saison_secheresse * 0.55);
	return mix(c, cible, part);
}
