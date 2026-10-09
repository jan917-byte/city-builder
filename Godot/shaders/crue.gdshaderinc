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
uniform float crue_baisse_ville = 0.0;
uniform vec4 crue_biefs[12];
uniform vec2 crue_fil = vec2(0.0, 1.0);

float crue_baisse(float z) {
	float fil = clamp((crue_fil.x - z) / (crue_fil.x - crue_fil.y), 0.0, 1.0);
	float b = crue_baisse_ville;
	for (int k = 0; k < 12; k++) {
		if (fil >= crue_biefs[k].x - 0.001 && fil <= crue_biefs[k].y + 0.001) b += crue_biefs[k].z;
	}
	return b;
}

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
	float d2 = textureLod(crue_annonce, clamp(uv2, 0.0, 1.0), 0.0).r * crue_annonce_niveau
		- crue_baisse(xz.y);
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
