shader_type spatial;
render_mode cull_back, specular_disabled;
#include "res://shaders/champs.gdshaderinc"
uniform vec2 demi_emprise;
uniform bool arbres = false;
varying vec3 monde;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1,311.7))) * 43758.5453); }
float bruit(vec2 p) {
	vec2 i = floor(p), f = fract(p); f = f*f*(3.0-2.0*f);
	return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1)),f.x),f.y);
}
void vertex() { monde = (MODEL_MATRIX * vec4(VERTEX,1)).xyz; }
void fragment() {
	float d = length(max(abs(monde.xz) - demi_emprise, vec2(0)));
	float lisiere = 165.0 + 65.0*sin(monde.x/125.0+monde.z/160.0) + 40.0*cos(monde.z/74.0-monde.x/220.0);
	float bois = smoothstep(lisiere-25.0,lisiere+70.0,d);
	vec3 champ = couleur_champ(monde.xz);
	vec3 foret = vec3(0.12,0.22,0.13)*(0.88+bruit(monde.xz/65.0)*0.24);
	vec3 couleur = arbres ? COLOR.rgb : mix(champ,foret,bois);
	float brume = smoothstep(550.0,2450.0,d);
	ALBEDO = couleur*(1.0-brume);
	EMISSION = vec3(0.578,0.624,0.658)*brume;
	ROUGHNESS = 1.0;
}
