shader_type spatial;
render_mode cull_back, specular_disabled;
#include "res://shaders/brume.gdshaderinc"
#include "res://shaders/saison.gdshaderinc"
// Arbres de ville et de forêt, couronne et tronc. CUSTOM0 = centre du lobe et
// son rôle (`Constructeur.arbre`) : 0 fixe, 1 couronne, ≥ 2 satellite ; < 0 une
// branche qui suit le lobe −rôle, xyz = son ancrage au tronc, COLOR.a = où le long.
uniform bool tronc = false;
uniform int essence = 0;          // `Constructeur.FEUILLU`…
// Nu, ce que la couronne garde en brume de rameaux : 0 aucune, l'arbre ne montre que ses branches.
uniform float brume_ramure = 0.0;
uniform vec3 ecorce : source_color = vec3(0.54, 0.48, 0.40);
// Zéro en ville : pas de brume. La forêt reçoit la demi-emprise du décor.
uniform vec2 demi_emprise = vec2(0.0);

varying vec3 local;
varying vec3 monde;
varying vec4 cycle;               // feuilles, roux, tendre, fleur : 0 à 1
varying vec4 cycle2;              // voile du débourrement, bougies, variété, teinte
varying float tirage;

float alea(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float alea3(vec3 p) { return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453); }
float bruit3(vec3 p) {
	vec3 i = floor(p), f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(alea3(i), alea3(i + vec3(1, 0, 0)), f.x),
			mix(alea3(i + vec3(0, 1, 0)), alea3(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(alea3(i + vec3(0, 0, 1)), alea3(i + vec3(1, 0, 1)), f.x),
			mix(alea3(i + vec3(0, 1, 1)), alea3(i + vec3(1)), f.x), f.y), f.z);
}

// 🍂 Débourrement et automne en mois du calendrier, par essence ; chaque arbre
// à ±2 semaines, tiré de sa position : en avril, la rue n'est pas d'un seul
// ton (2026-10-19). `variete` = `Constructeur.ROSE`…
vec4 phenologie(vec3 origine, int variete, out vec2 extra) {
	extra = vec2(0.0);
	if (essence == 1) return vec4(1.0, 0.0, 0.0, 0.0);   // le conifère ne bouge pas
	float j = (alea(floor(origine.xz * 4.0) * 0.517 + 5.3) - 0.5) * 0.9;
	float mp = saison_mois - saison_decalage.x - j;
	float ma = saison_mois - saison_decalage.y - j * 0.6;
	float s = 3.30;                                       // feuillu : début avril
	float a = 9.25;                                       // et début octobre
	if (essence == 2) { s = 4.20; a = 8.80; }             // roseau
	else if (essence == 3) { s = 3.20; a = 9.30; }        // buisson
	else if (essence == 4) { s = 3.10; a = 9.00; }        // bouleau
	else if (essence == 5) { s = 3.30; a = 9.10; }        // peuplier
	else if (essence == 6) { s = 3.55; a = 9.40; }        // fruitier, après ses fleurs
	else if (essence == 7) { s = 2.95; a = 9.70; }        // saule : le premier vert, le dernier jaune
	else if (essence == 8) { s = 3.45; a = 9.15; }        // tilleul
	if (variete == 2) s -= 0.20;                          // le marronnier, en avance
	else if (variete == 1 && essence != 6) s += 0.25;     // le cerisier fleurit d'abord
	float pousse = smoothstep(s, s + 0.8, mp);
	float roux = smoothstep(a, a + 0.6, ma);
	float tendre = 1.0 - smoothstep(s + 0.5, s + 1.6, mp);
	// Deux semaines avant la feuille, les bourgeons verdissent la ramure.
	extra.x = smoothstep(s - 0.55, s + 0.05, mp);
	// Le roseau ne tombe pas : il sèche sur pied et reverdit en mai.
	if (essence == 2) return vec4(1.0, max(roux, 1.0 - pousse), 0.0, 0.0);
	float feuilles = pousse * (1.0 - smoothstep(a + 0.45, a + 1.25, ma));
	float fleur = 0.0;
	if (essence == 6)
		fleur = smoothstep(s - 0.45, s - 0.2, mp) * (1.0 - smoothstep(s + 0.05, s + 0.4, mp));
	else if (variete == 1)
		fleur = smoothstep(s - 0.55, s - 0.3, mp) * (1.0 - smoothstep(s + 0.05, s + 0.35, mp));
	// Les bougies du marronnier, sur la feuille déjà faite : le mois de mai.
	if (variete == 2)
		extra.y = smoothstep(s + 0.85, s + 1.05, mp) * (1.0 - smoothstep(s + 1.45, s + 1.7, mp));
	return vec4(feuilles, roux, tendre, fleur);
}

void vertex() {
	vec3 origine = MODEL_MATRIX[3].xyz;
	int variete = int(INSTANCE_CUSTOM.r + 0.5);   // 0 en forêt : pas de données
	vec2 extra;
	cycle = phenologie(origine, variete, extra);
	tirage = alea(floor(origine.xz * 4.0) * 0.291 + 2.7);
	cycle2 = vec4(extra, float(variete), alea(floor(origine.xz * 4.0) * 0.613 + 8.1));
	// Le voile des bourgeons épaissit la ramure avant la feuille.
	float presence = max(max(cycle.x, cycle.w), cycle2.x * 0.35);
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
		// 🍂 Nu, la couronne disparaît (on voit les branches) ou se réduit à une brume de rameaux.
		s *= brume_ramure > 0.0 ? mix(0.8, 1.0, presence)
			: (presence < 0.03 ? 0.0 : mix(0.6, 1.0, presence));
		VERTEX = centre + decale + (VERTEX - centre) * s;
	} else if (role < -0.5) {
		// 🌳 Une branche suit son satellite, et part avec lui. En pleine feuille
		// elle est repliée sur le tronc : un satellite rétréci la laisserait dépasser.
		float r = -role;
		bool garde = presence < 0.97;
		if (r > 1.5) {
			vec2 graine = floor(origine.xz * 4.0) * 0.731 + vec2(r * 3.7, r * 9.1);
			if (alea(graine + 73.0) < 0.2) garde = false;
			float b = alea(graine + 17.0);
			float c = alea(graine + 41.0);
			VERTEX += vec3(b - 0.5, (c - 0.5) * 0.5, c - b) * 0.9 * COLOR.a;
		}
		if (!garde) VERTEX = CUSTOM0.xyz;
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
		int variete = int(cycle2.z + 0.5);
		float voile = cycle2.x * (1.0 - cycle.x);
		float presence = max(max(cycle.x, cycle.w), voile * 0.35);
		// La couronne se troue quand elle se déshabille, dans l'espace de
		// l'arbre : les trous ne scintillent pas quand la caméra bouge.
		if (presence < 0.999) {
			float dense = brume_ramure > 0.0 ? mix(brume_ramure, 1.0, presence) : presence;
			if (bruit3(local * 1.9 + tirage * 31.0) > dense * 1.08) discard;
		}
		float grain = sin(local.x * 4.0 + local.y * 2.1) * sin(local.z * 3.5 - local.y);
		float net = 1.0 - smoothstep(0.2, 1.0, length(fwidth(local)));
		// La valeur de l'arbre (dégradé, essence, tirage) relative au FEUILLAGE de
		// palette : les couleurs de saison la gardent.
		float ombre = dot(COLOR.rgb, vec3(1.0)) / 0.8097;
		vec3 automne = S_ORANGE;
		if (essence == 0 || essence == 8) automne = tirage < 0.4 ? S_JAUNE : (tirage < 0.75 ? S_ORANGE : S_ROUX);
		else if (essence == 2) automne = S_PAILLE;
		else if (essence == 3) automne = S_ROUX;
		else if (essence == 4 || essence == 5) automne = S_JAUNE;
		else if (essence == 6) automne = mix(S_ORANGE, S_ROUX, tirage);
		else if (essence == 7) automne = S_SAULE;
		if (variete == 3) automne = S_ROUX;
		// 🌳 Chaque arbre son vert, du jaune au bleuté (2026-10-19) : la même
		// valeur, une teinte qui glisse. Le conifère reste dans le sien.
		vec3 c = COLOR.rgb * vec3(0.86, 1.0, 0.92);
		if (essence != 1 && essence != 2) {
			c *= mix(vec3(1.10, 1.02, 0.82), vec3(0.90, 0.98, 1.18), cycle2.w);
		}
		if (variete == 3) c = S_POURPRE * ombre;
		// Le vert tendre d'avril, plus ou moins jaune selon l'arbre. 🔄 Le bronze
		// essayé le 2026-10-19 se lisait en arbre mort : retiré.
		vec3 tendre = mix(S_DEBOURRE, S_CITRON, step(0.7, tirage));
		if (variete == 3) tendre = S_POURPRE_TENDRE;
		c = mix(c, tendre * ombre, cycle.z * 0.75);
		if (essence != 1) c = mix(c, S_PAILLE * ombre, saison_secheresse * 0.18);
		c = mix(c, automne * ombre, cycle.y);
		// 🌸 La fleur en taches sur le vert tendre, pas une boule blanche.
		vec3 petale = variete == 1 ? (essence == 6 ? S_FLEUR_ROSE : S_ROSE) : S_FLEUR;
		float fleurie = step(bruit3(local * 3.1 + tirage * 17.0), cycle.w * 0.95);
		c = mix(c, petale * min(ombre, 1.05), fleurie);
		// Les bougies du marronnier : de petits points blancs dressés.
		if (cycle2.y > 0.0 && bruit3(local * vec3(5.0, 2.6, 5.0) + 3.0) > 1.0 - cycle2.y * 0.32)
			c = S_FLEUR * min(ombre, 1.05);
		// Ce qui n'est plus feuille est bois ; au débourrement, un voile vert.
		if (brume_ramure > 0.0 && cycle.w < 0.05 && bruit3(local * 2.0 + 11.0) > max(presence, cycle.x)) {
			c = S_RAMURE * mix(1.0, ombre, 0.35) * mix(0.88, 1.12, tirage);
			c = mix(c, tendre * ombre * 0.92, smoothstep(0.0, 1.0, voile) * 0.8);
		}
		couleur = c * (1.0 + grain * 0.085 * net);
		// ❄️ La neige se pose sur ce qui regarde le ciel : les sapins surtout.
		float haut = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz).y;
		couleur = mix(couleur, S_NEIGE, neige_manteau(monde) * smoothstep(0.15, 0.6, haut) * 0.85);
	}
	float brume = demi_emprise.x > 0.0 ? brume_bord(monde.xz, demi_emprise) : 0.0;
	ALBEDO = couleur * (1.0 - brume);
	EMISSION = BRUME_CIEL * brume;
	ROUGHNESS = 0.95;
}
