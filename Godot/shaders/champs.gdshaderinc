// Une même trame agricole traverse la limite de la carte jouable.
float champ_hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
vec3 couleur_champ(vec2 p) {
	vec2 parcelle=mat2(vec2(0.94,0.342),vec2(-0.342,0.94))*p;
	vec2 grille=parcelle/vec2(145,95);
	grille.x+=floor(grille.y)*0.37;
	float tirage=champ_hash(floor(grille));
	vec3 champ=mix(vec3(0.30,0.39,0.17),vec3(0.52,0.47,0.25),tirage);
	vec2 bord=min(fract(grille),1.0-fract(grille));
	float haie=1.0-smoothstep(0.006,0.024,min(bord.x,bord.y));
	champ=mix(champ,vec3(0.24,0.31,0.12),haie*0.50);
	float lignes=sin(parcelle.y*1.7)*0.018/(1.0+length(fwidth(parcelle)));
	return champ+vec3(lignes);
}
