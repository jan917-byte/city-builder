shader_type spatial;
render_mode cull_back, specular_disabled;
#include "res://shaders/brume.gdshaderinc"
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
	// La couleur exportée prolonge le bois ou le versant dessiné au bord.
	vec3 couleur = COLOR.rgb;
	if (!arbres) couleur *= 0.94 + bruit(monde.xz * 0.085) * 0.12;
	float brume = brume_bord(monde.xz, demi_emprise);
	ALBEDO = couleur*(1.0-brume);
	EMISSION = BRUME_CIEL*brume;
	ROUGHNESS = 1.0;
}
