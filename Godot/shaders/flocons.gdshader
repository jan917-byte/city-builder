// ❄️ Les flocons, à l'écran et non dans le monde : même taille à tout zoom,
// aucun objet de plus. Trois couches, des plus fins aux plus proches.
// 🔴 Flaggable (90) : rendu choisi par Claude, provisoire (2026-10-10).
shader_type canvas_item;
render_mode unshaded;
uniform float intensite = 0.0;
uniform float horloge = -1.0;   // ≥ 0 : figé, pour deux captures égales

float h21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

// `cellule` en pixels : un flocon pour une cellule sur deux, qui tombe à `vitesse` px/s.
float couche(vec2 px, float cellule, float vitesse, float rayon, float t, float graine) {
	vec2 q = vec2(px.x + sin(t * 0.35 + graine) * cellule * 0.4, px.y - t * vitesse);
	vec2 id = floor(q / cellule);
	if (h21(id + graine) > 0.5) return 0.0;
	vec2 c = vec2(h21(id + graine + 1.7), h21(id + graine + 3.1)) * 0.6 + 0.2;
	c.x += sin(t * 1.4 + h21(id + graine + 5.3) * 40.0) * 0.12;
	float d = length((q / cellule - id - c) * cellule);
	return 1.0 - smoothstep(rayon * 0.35, rayon, d);
}

void fragment() {
	float t = horloge < 0.0 ? TIME : horloge;
	vec2 px = FRAGCOORD.xy;
	float a = couche(px, 56.0, 26.0, 1.7, t, 0.0) * 0.45
		+ couche(px, 92.0, 42.0, 2.4, t, 11.0) * 0.65
		+ couche(px, 150.0, 66.0, 3.4, t, 23.0) * 0.85;
	COLOR = vec4(1.0, 1.0, 1.0, a * intensite * 0.8);
}
