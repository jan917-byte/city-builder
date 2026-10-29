// 🌊 LA CARTE DES DANGERS, au mètre et non à l'îlot : la même eau que `04e`
// lit au centre de chaque bâtiment. Dégâts = le canal R de `boue_carte` (la
// crue d'ouverture) ; prochaine crue = `crue_annonce`, moins ce que la ville a
// racheté. ⚠ À inclure APRÈS boue.gdshaderinc (`boue_bruit`, `boue_carte`).
uniform sampler2D crue_annonce : filter_linear, repeat_disable;
uniform vec4 crue_annonce_repere = vec4(0.0, 0.0, 1.0, 1.0);
uniform float crue_annonce_niveau = 6.0;
// 0 éteinte, 1 dégâts, 2 prochaine crue.
uniform int crue_vue = 0;
uniform float crue_max = 1.0;
uniform vec3 crue_clair = vec3(0.55, 0.76, 0.87);
uniform vec3 crue_fonce = vec3(0.008, 0.089, 0.305);
// La baisse de `ville.baisse_crue_m` : la part de toute la ville, puis une par
// berge sur son bief (fil amont, fil aval, mètres). `crue_fil` = Z au sud, au nord.
// `_avant` et `.w` : la même baisse avant le dernier clic sur la carte.
uniform float crue_baisse_ville = 0.0;
uniform float crue_baisse_ville_avant = 0.0;
uniform vec4 crue_biefs[12];
uniform vec2 crue_fil = vec2(0.0, 1.0);
// Le fond de la carte des dangers, blanc (auteur, 2026-10-09). ⚠ LINÉAIRE ;
// le ciel assorti est `maquette.FOND_DANGERS`.
const vec3 CRUE_PAPIER = vec3(0.880, 0.870, 0.840);

float crue_baisse(float z) {
	float fil = clamp((crue_fil.x - z) / (crue_fil.x - crue_fil.y), 0.0, 1.0);
	float b = crue_baisse_ville;
	for (int k = 0; k < 12; k++) {
		if (fil >= crue_biefs[k].x - 0.001 && fil <= crue_biefs[k].y + 0.001) b += crue_biefs[k].z;
	}
	return b;
}

// Ce que le dernier clic a rendu, en mètres : 0 hors de la prochaine crue.
float crue_gain(float z) {
	if (crue_vue != 2) return 0.0;
	float fil = clamp((crue_fil.x - z) / (crue_fil.x - crue_fil.y), 0.0, 1.0);
	float b = crue_baisse_ville - crue_baisse_ville_avant;
	for (int k = 0; k < 12; k++) {
		if (fil >= crue_biefs[k].x - 0.001 && fil <= crue_biefs[k].y + 0.001)
			b += crue_biefs[k].z - crue_biefs[k].w;
	}
	return b;
}

// B-spline cubique en 4 lectures bilinéaires : le bilinéaire seul casse le
// contour à chaque case de 12 m.
vec4 crue_cubique(float v) {
	vec4 n = vec4(1.0, 2.0, 3.0, 4.0) - v;
	vec4 s = n * n * n;
	float x = s.x;
	float y = s.y - 4.0 * s.x;
	float z = s.z - 4.0 * s.y + 6.0 * s.x;
	return vec4(x, y, z, 6.0 - x - y - z) / 6.0;
}

// Mètres d'eau annoncés, lissés, avec les lobes mais sans la dérive fine.
float crue_annonce_lisse(vec2 xz) {
	vec2 lobes = vec2(boue_bruit(xz * 0.017 + 7.0), boue_bruit(xz.yx * 0.019 + 19.0)) - 0.5;
	vec2 ts = vec2(textureSize(crue_annonce, 0));
	vec2 uv = ((xz + lobes * 26.0) - crue_annonce_repere.xy) / crue_annonce_repere.zw * ts - 0.5;
	vec2 f = fract(uv);
	uv -= f;
	vec4 xc = crue_cubique(f.x);
	vec4 yc = crue_cubique(f.y);
	vec4 c = uv.xxyy + vec2(-0.5, 1.5).xyxy;
	vec4 s = vec4(xc.xz + xc.yw, yc.xz + yc.yw);
	vec4 o = (c + vec4(xc.yw, yc.yw) / s) / ts.xxyy;
	float a = textureLod(crue_annonce, o.xz, 0.0).r;
	float b = textureLod(crue_annonce, o.yz, 0.0).r;
	float d = textureLod(crue_annonce, o.xw, 0.0).r;
	float e = textureLod(crue_annonce, o.yw, 0.0).r;
	float sx = s.x / (s.x + s.y);
	float sy = s.z / (s.z + s.w);
	return mix(mix(e, d, sx), mix(b, a, sx), sy) * crue_annonce_niveau;
}

// 🔄 Le bord d'avant le clic, tracé jusqu'au clic suivant (auteur, 2026-10-22 :
// 13 cm ne reculent le bord que de quelques mètres ; 2026-10-23 : un trait net,
// sans cassures). Distance au contour en mètres (pente lue à ±3 m), pas par
// fwidth(h), qui saute d'une case et d'un maillage à l'autre. `px` = mètres par
// pixel, lu par l'appelant hors de toute branche. Flaggable (90) : rendu de shader.
float crue_bord_avant(vec2 xz, float px) {
	px = max(px, 0.01);
	float gain = crue_gain(xz.y);
	vec2 uv = (xz - crue_annonce_repere.xy) / crue_annonce_repere.zw;
	if (gain < 0.005 || any(lessThan(uv, vec2(0.01))) || any(greaterThan(uv, vec2(0.99)))) return 0.0;
	float seuil = 0.10 + crue_baisse(xz.y) - gain;
	float h = crue_annonce_lisse(xz) - seuil;
	if (abs(h) > 1.5) return 0.0;
	const float PAS = 3.0;
	vec2 pente = vec2(crue_annonce_lisse(xz + vec2(PAS, 0.0)) - crue_annonce_lisse(xz - vec2(PAS, 0.0)),
		crue_annonce_lisse(xz + vec2(0.0, PAS)) - crue_annonce_lisse(xz - vec2(0.0, PAS))) / (2.0 * PAS);
	float d = abs(h) / max(length(pente), 1e-3);
	// ~2 px (auteur, 2026-10-23 : à 4 px il prenait trop de place).
	float demi = max(1.0 * px, 0.25);
	// Un trait plein : les traitillés essayés le 2026-10-23 se brouillaient (auteur).
	return 1.0 - smoothstep(demi - 0.7 * px, demi + 0.7 * px, d);
}

// Rouge (auteur, 2026-10-23), celui des rues coupées (#DC3A30), ⚠ LINÉAIRE.
const vec3 CRUE_BORD_AVANT = vec3(0.716, 0.042, 0.030);

// Mètres d'eau en ce point. `onde` = 1 pour le sol : le bord ondule avec la
// même dérive que la boue, donc la carte et la vase tracent la même limite ;
// la prochaine crue, qui n'a pas de vase, y ajoute des lobes de ~60 m. Le bâti
// lit le champ sans dérive (`onde` = 0), sinon un toit se coupe en festons.
float crue_hauteur(vec2 xz, float onde) {
	vec2 derive = vec2(boue_bruit(xz * 0.12), boue_bruit(xz.yx * 0.13 + 41.0)) - 0.5;
	vec2 lobes = vec2(boue_bruit(xz * 0.017 + 7.0), boue_bruit(xz.yx * 0.019 + 19.0)) - 0.5;
	vec2 p = xz + onde * (derive * 9.0 + (crue_vue == 2 ? lobes * 26.0 : vec2(0.0)));
	// Sans branche autour des lectures : la vue est un uniforme, le cadre non.
	vec2 uv1 = (p - boue_repere.xy) / boue_repere.zw;
	vec2 uv2 = (p - crue_annonce_repere.xy) / crue_annonce_repere.zw;
	float d1 = textureLod(boue_carte, clamp(uv1, 0.0, 1.0), 0.0).r * 6.0;
	// Codée en racine (`boue._carte_annonce`) : le bord plat garde le centimètre.
	float r2 = textureLod(crue_annonce, clamp(uv2, 0.0, 1.0), 0.0).r;
	float d2 = r2 * r2 * crue_annonce_niveau - crue_baisse(xz.y);
	vec2 uv = crue_vue == 1 ? uv1 : uv2;
	float dehors = float(any(lessThan(uv, vec2(0.0))) || any(greaterThan(uv, vec2(1.0))));
	return (crue_vue == 1 ? d1 : d2) * (1.0 - dehors);
}

// Le sol : clair au bord, foncé au plus profond, un trait au rivage et un
// trait fin par mètre d'eau, comme une carte d'aléa. a = 0 au sec.
vec4 crue_sol(float h, float fw_h) {
	float fw = max(fw_h, 1e-4);
	float dedans = smoothstep(0.10 - fw, 0.10 + fw, h);
	if (dedans <= 0.0) return vec4(0.0);
	vec3 c = mix(crue_clair, crue_fonce, pow(clamp(h / crue_max, 0.0, 1.0), 0.8));
	float rivage = 1.0 - smoothstep(fw * 0.5, fw * 2.0, h - 0.10);
	float metre = 1.0 - smoothstep(fw * 0.4, fw * 1.4, abs(fract(h + 0.5) - 0.5));
	c = mix(c, crue_fonce * 0.6, max(rivage, metre * 0.35 * step(0.6, h)));
	return vec4(c, dedans);
}
