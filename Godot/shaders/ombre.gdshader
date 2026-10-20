shader_type canvas_item;
// 🔷 L'OMBRE DES PANNEAUX, dessinée autour du verre : sombre au bord, éteinte en quelques
// pixels (auteur, 2026-10-20). Le `shadow_size` d'un StyleBoxFlat faisait une bande grise
// plate. Rien sous le panneau : sous le verre translucide, elle grisait le fond.
// `taille` (le panneau) et `marge` sont réglées par `interface._vitrer`.
uniform vec2 taille = vec2(320.0, 240.0);
uniform float marge = 24.0;
uniform float rayon = 0.0;
uniform float chute = 2.5;
uniform vec2 decalage = vec2(0.0, 1.0);
uniform vec4 couleur : source_color = vec4(0.10, 0.10, 0.08, 0.35);

float boite(vec2 p, vec2 demi, float r) {
	vec2 q = abs(p) - demi + vec2(r);
	return length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - r;
}

void fragment() {
	vec2 demi = taille * 0.5;
	vec2 p = UV * (taille + 2.0 * marge) - marge - demi;
	float hors = clamp(boite(p, demi, rayon) + 0.5, 0.0, 1.0);
	float d = max(boite(p - decalage, demi, rayon), 0.0);
	// Un contact serré, et un voile à peine plus large pour que la fin ne se voie pas.
	float a = 0.8 * exp(-d / chute) + 0.2 * exp(-d / (chute * 3.0));
	COLOR = vec4(couleur.rgb, couleur.a * a * hors);
}
