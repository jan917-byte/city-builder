// Le contour, la teinte et les bandes viennent de la parcelle SVG exportée.
float grain_champ(vec2 p) {
	float net = 1.0 / (1.0 + length(fwidth(p)));
	return 1.0 + sin(p.x * 1.7 + p.y * 0.6) * 0.018 * net;
}

// 🌾 CE QUE PORTE LE CHAMP (auteur, 2026-09-29). `code` vient de
// `ville.parcelle_code` : partie entière = 1 + culture (+10 pendant le
// chantier ; 6 = terre battue d'un campement), partie fractionnaire = 0,9 ×
// maturité du verger, lue par les arbres. Encodé dans `parcelle_agricole` : le matériau a ses 16 uniformes d'instance.
// Couleurs LINÉAIRES ; sRGB en commentaire. Aucune texture (règle 52).
float champ_alea(vec2 c) {
	return fract(sin(dot(c, vec2(12.9898, 78.233))) * 43758.545);
}

float champ_bruit(vec2 p) {
	vec2 c = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(champ_alea(c), champ_alea(c + vec2(1.0, 0.0)), f.x),
		mix(champ_alea(c + vec2(0.0, 1.0)), champ_alea(c + vec2(1.0, 1.0)), f.x), f.y);
}

vec3 culture_champ(vec3 base, vec2 p, float code, float ao) {
	float genre = mod(floor(code), 10.0);
	bool travaux = code >= 10.5;
	// Mètres par pixel : au-delà, le motif rend la main à sa teinte moyenne.
	float px = length(fwidth(p));
	float tache = champ_bruit(p * 0.08);
	if (travaux) {
		// Labour : terre brune #7A5A3C, sillon #5A412C tous les 0,8 m.
		float s = abs(fract(p.x / 0.8) - 0.5) * 2.0;
		float net = 1.0 - smoothstep(0.08, 0.4, px);
		vec3 terre = vec3(0.195, 0.102, 0.045) * mix(0.9, 1.08, tache);
		return mix(terre, vec3(0.102, 0.053, 0.025), smoothstep(0.7, 0.95, s) * net * 0.7) * ao;
	}
	if (genre > 5.5) {
		// 🏕️ Terre battue du campement (auteur, 2026-10-08) : #8B7A5E, plaques
		// tassées #6E5E46, gravier #A79A82 qui s'éteint de loin.
		vec3 sol = mix(vec3(0.263, 0.198, 0.112), vec3(0.157, 0.112, 0.059),
			smoothstep(0.3, 0.8, champ_bruit(p * 0.15)) * 0.4);
		sol *= mix(0.92, 1.06, champ_bruit(p * 1.3));
		float gravier = step(0.9, champ_alea(floor(p * 3.0))) * (1.0 - smoothstep(0.02, 0.08, px));
		return mix(sol, vec3(0.394, 0.330, 0.227), gravier * 0.6) * ao;
	}
	if (genre < 1.5) {
		return base;   // céréales : la teinte du SVG, telle quelle
	}
	if (genre < 2.5) {
		// Maraîchage : des bandes de six planches (9,6 m), une culture par bande
		// et par tronçon de 30 m — le patchwork qui se lit de loin. De près,
		// planches de 1,1 m et allées de terre #8C6D4B.
		// Salade #4F7F3A, chou #2F5A34, pousse #86A64C, betterave #7A3B4A,
		// #A3B85E, et une bande juste retournée #7A5A3C.
		const vec3 PLANCHES[6] = { vec3(0.078, 0.212, 0.042), vec3(0.028, 0.102, 0.034),
			vec3(0.238, 0.381, 0.072), vec3(0.195, 0.044, 0.068), vec3(0.366, 0.479, 0.112),
			vec3(0.195, 0.102, 0.045) };
		float bande = floor(p.x / 9.6);
		vec3 plante = PLANCHES[int(champ_alea(vec2(bande, floor(p.y / 30.0))) * 6.0)];
		plante *= mix(0.88, 1.10, champ_bruit(p * 1.5));
		float rang = p.x / 1.6;
		float allee = smoothstep(0.30, 0.34, abs(fract(rang) - 0.5)) * (1.0 - smoothstep(0.15, 0.6, px));
		// Le fil entre deux bandes reste visible de loin : c'est lui qui dit « planches ».
		float fil = smoothstep(0.46, 0.5, abs(fract(p.x / 9.6) - 0.5)) * 0.5;
		vec3 c = mix(plante, vec3(0.262, 0.153, 0.070), max(allee, fil));
		return c * ao;
	}
	if (genre < 3.5) {
		// Verger : herbe fauchée #7E9A52 ; les arbres sont de vrais arbres
		// (`maquette._verger_semis`), qui grandissent avec l'âge.
		vec3 herbe = vec3(0.209, 0.323, 0.084) * mix(0.88, 1.1, tache);
		return herbe * mix(0.94, 1.04, champ_bruit(p * 0.6)) * ao;
	}
	// Prairie : #98AC5C mêlé de #7D9848, semée de fleurs blanches, jaunes
	// et mauves qui s'éteignent de loin.
	// Mélange LINÉAIRE : un smoothstep sur ce bruit en faisait ressortir la grille.
	vec3 pre = mix(vec3(0.314, 0.413, 0.107), vec3(0.205, 0.314, 0.065),
		champ_bruit(p * 0.12) * 0.8);
	pre *= mix(0.95, 1.04, champ_bruit(p * 0.7));
	vec2 cf = floor(p * 1.4);
	float h = champ_alea(cf);
	float fleur = step(0.86, h) * (1.0 - smoothstep(0.03, 0.12, px));
	const vec3 FLEURS[3] = { vec3(0.847, 0.807, 0.687), vec3(0.768, 0.571, 0.068),
		vec3(0.323, 0.195, 0.434) };
	float dans_f = 1.0 - smoothstep(0.18, 0.32, length(fract(p * 1.4) - 0.5));
	return mix(pre, FLEURS[int(fract(h * 7.3) * 3.0)], fleur * dans_f) * ao;
}
