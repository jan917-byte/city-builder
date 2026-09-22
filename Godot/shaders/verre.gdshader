shader_type canvas_item;
// 🔷 LE VERRE DES PANNEAUX : la ville floutée sous une teinte bleue.
// Le flou vient des mipmaps de l'écran — la seule façon d'en avoir un en 2D
// sans passe de rendu en plus. `taille` est réglée par `interface._vitrer` à
// chaque changement de rectangle : un ColorRect n'a pas de UV en pixels.
uniform sampler2D ecran : hint_screen_texture, filter_linear_mipmap;
uniform vec2 taille = vec2(320.0, 240.0);
uniform float rayon = 13.0;
uniform float flou = 4.0;
uniform vec4 teinte : source_color = vec4(0.90, 0.94, 1.00, 0.78);

void fragment() {
	vec2 demi = taille * 0.5;
	vec2 d = abs(UV * taille - demi) - demi + vec2(rayon);
	float bord = length(max(d, vec2(0.0))) + min(max(d.x, d.y), 0.0) - rayon;
	vec3 fond = textureLod(ecran, SCREEN_UV, flou).rgb;
	vec3 verre = mix(fond, teinte.rgb, teinte.a);
	// La lumière glisse du haut : sans ce dégradé le panneau est un aplat.
	verre += 0.045 * (1.0 - UV.y);
	COLOR = vec4(verre, 1.0 - smoothstep(-1.0, 0.5, bord));
}
