shader_type spatial;

global uniform float temps_trafic;
uniform sampler2D trajets : filter_nearest, repeat_disable;
// La chaussée sous la voiture, relative au départ de l'arc (ponts, rive droite).
uniform sampler2D hauteurs : filter_nearest, repeat_disable;
// Le fondu d'apparition et de disparition, en mètres d'arc : trafic.gd FONDU.
const float FONDU = 3.0;
const float TRAME[16] = float[16](0.03, 0.53, 0.16, 0.66, 0.78, 0.28, 0.91, 0.41,
	0.22, 0.72, 0.09, 0.59, 0.97, 0.47, 0.84, 0.34);
varying vec4 teinte;
varying float fondu;

void vertex() {
	// L'allongement dans l'alpha de la teinte : Constructeur.ALLONGE, à l'identique.
	VERTEX.z += sign(VERTEX.z) * (1.0 - COLOR.a) * 2.0;
	// trafic.gd `_ecrire` : x phase, y vitesse (négative : la voiture s'efface), z longueur
	// (négative : elle apparaît), w arc × 2048 + retard en décimètres.
	float vitesse = abs(INSTANCE_CUSTOM.y);
	float longueur = max(abs(INSTANCE_CUSTOM.z), 0.01);
	float code = round(INSTANCE_CUSTOM.w);
	int arc = int(floor(code / 2048.0));
	float retard = mod(code, 2048.0) * 0.1;
	// 🚦 Céder le passage : le retard se prend aux deux tiers de l'arc, vitesse d'entrée
	// et de sortie intactes. trafic.gd `_position`, à l'identique.
	float u = INSTANCE_CUSTOM.x + temps_trafic * vitesse;
	float x = clamp(u / (longueur + retard), 0.0, 1.0);
	float avance = clamp(u - retard * x * x * x * (4.0 - 3.0 * x), 0.0, longueur);
	float etendue = min(FONDU, 0.8 * longueur);
	fondu = 1.0;
	if (INSTANCE_CUSTOM.z < 0.0) {
		fondu = clamp(avance / etendue, 0.0, 1.0);
	} else if (INSTANCE_CUSTOM.y < 0.0) {
		fondu = 1.0 - clamp(avance / etendue, 0.0, 1.0);
	}
	float s = avance / longueur * float(textureSize(trajets, 0).x - 1);
	int i = int(floor(s));
	vec4 a = texelFetch(trajets, ivec2(i, arc), 0);
	vec4 b = texelFetch(trajets,
		ivec2(min(i + 1, textureSize(trajets, 0).x - 1), arc), 0);
	vec4 pose = mix(a, b, fract(s));
	vec2 direction = normalize(pose.zw);
	mat2 rotation = mat2(vec2(direction.y, -direction.x), direction);
	VERTEX.xz = pose.xy + rotation * VERTEX.xz;
	int j = min(i + 1, textureSize(trajets, 0).x - 1);
	VERTEX.y += mix(texelFetch(hauteurs, ivec2(i, arc), 0).r,
		texelFetch(hauteurs, ivec2(j, arc), 0).r, fract(s));
	NORMAL.xz = rotation * NORMAL.xz;
	// Éteinte : triangles nuls, aucun pixel à jeter.
	VERTEX *= step(0.001, fondu);
	teinte = COLOR;
}

void fragment() {
	// Le fondu en trame ordonnée : la voiture reste opaque, sans tri, et s'éteint par seizièmes.
	if (fondu < 0.999) {
		ivec2 p = ivec2(FRAGCOORD.xy) % 4;
		if (fondu <= TRAME[p.x + p.y * 4]) {
			discard;
		}
	}
	ALBEDO = teinte.rgb;
	ROUGHNESS = 0.72;
}
