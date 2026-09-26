shader_type spatial;
render_mode cull_back;
#include "res://shaders/brume.gdshaderinc"

uniform vec4 teinte : source_color;
uniform bool diagnostic = false;
uniform vec2 brume_exterieure = vec2(0.0);
varying vec3 monde;
// UV.x = distance à la rive + 1 (0 = inconnue), UV2 = sens de l'aval : posés par 07.
varying float rive;
varying vec2 aval;

float alea(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float bruit(vec2 p) {
	vec2 i = floor(p), f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(alea(i), alea(i + vec2(1, 0)), f.x),
		mix(alea(i + vec2(0, 1)), alea(i + vec2(1)), f.x), f.y);
}
float houle(vec2 p) { return bruit(p * 0.45) * 0.6 + bruit(p * 1.15 + 7.3) * 0.4; }

void vertex() {
	monde = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	rive = UV.x - 1.0;
	aval = UV2;
}

void fragment() {
	vec2 p = monde.xz;
	float net = 1.0 - smoothstep(0.35, 1.6, length(fwidth(p)));
	// Le courant : deux phases décalées d'un demi-cycle, fondues l'une dans
	// l'autre — la ride avance vers l'aval sans jamais sauter.
	vec2 f = length(aval) > 0.1 ? normalize(aval) : vec2(0.0, 1.0);
	float cycle = TIME * 0.16;
	float ph0 = fract(cycle), ph1 = fract(cycle + 0.5);
	float w0 = 1.0 - abs(1.0 - 2.0 * ph0);
	vec2 o0 = f * ph0 * 3.4, o1 = f * ph1 * 3.4 + vec2(13.7, 5.1);
	vec2 e = vec2(0.3, 0.0);
	float h = mix(houle(p - o1), houle(p - o0), w0);
	float hx = mix(houle(p + e - o1), houle(p + e - o0), w0);
	float hz = mix(houle(p + e.yx - o1), houle(p + e.yx - o0), w0);
	vec3 pente = normalize(vec3((h - hx) * 0.55 * net, 1.0, (h - hz) * 0.55 * net));

	// Clair et vert au bord, profond au milieu : l'Ilse fait ~30 m.
	float d = rive < 0.0 ? 7.0 : rive;
	float prof = smoothstep(0.5, 11.0, d);
	vec3 clair = teinte.rgb * vec3(0.76, 0.99, 0.90);
	vec3 profond = teinte.rgb * vec3(0.40, 0.65, 0.74);
	vec3 couleur = mix(clair, profond, prof) * (1.0 + (h - 0.5) * 0.10 * net);
	// L'écume ne tient qu'à la rive, et elle se déchire au fil de l'eau.
	float dechire = mix(houle(p * 2.3 - o1), houle(p * 2.3 - o0), w0);
	float ecume = rive < 0.0 ? 0.0 :
		(1.0 - smoothstep(0.15, 1.1, d + (dechire - 0.5) * 0.9))
		* smoothstep(0.38, 0.62, dechire);
	couleur = mix(couleur, teinte.rgb * vec3(1.02, 1.08, 1.06) + 0.10, ecume * 0.75);

	ALBEDO = diagnostic ? vec3(0.073, 0.089, 0.107) : couleur;
	float brume = brume_exterieure.x > 0.0 ? brume_bord(p, brume_exterieure) : 0.0;
	ALBEDO *= 1.0 - brume;
	EMISSION = BRUME_CIEL * brume;
	NORMAL = diagnostic ? NORMAL : normalize((VIEW_MATRIX * vec4(pente, 0.0)).xyz);
	ROUGHNESS = diagnostic ? 1.0 : mix(0.20, 0.75, ecume);
	SPECULAR = diagnostic ? 0.0 : 0.5;
}
