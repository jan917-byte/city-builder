// Bord du monde : la brume prend la teinte du ciel (CIEL de palette.py, en
// linéaire) sur un rectangle aux coins très arrondis, frangé de bruit — un bord
// droit se lisait comme la fin de la carte.
const vec3 BRUME_CIEL = vec3(0.578, 0.624, 0.658);
const float BRUME_RAYON = 850.0;
float _brume_alea(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float _brume_bruit(vec2 p) {
	vec2 i = floor(p), f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(_brume_alea(i), _brume_alea(i + vec2(1, 0)), f.x),
		mix(_brume_alea(i + vec2(0, 1)), _brume_alea(i + vec2(1)), f.x), f.y);
}
float brume_bord(vec2 xz, vec2 demi) {
	vec2 q = abs(xz) - (demi - vec2(BRUME_RAYON));
	float d = length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - BRUME_RAYON;
	d += (_brume_bruit(xz * 0.0012) - 0.5) * 560.0;
	return smoothstep(420.0, 2250.0, d);
}
