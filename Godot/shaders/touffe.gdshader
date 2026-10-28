shader_type spatial;
render_mode cull_disabled, specular_disabled;
#include "res://shaders/saison.gdshaderinc"
// Les touffes d'un toit vert (`toits_verts.gd`) : COLOR = teinte d'instance × pied sombre,
// pointe claire. L'herbe suit l'année comme les pelouses ; la neige prend les pointes.
// `terre` non nulle : le cadre de terre du même toit, qui ne suit que la neige.
uniform vec3 terre = vec3(0.0);

varying vec3 monde;
varying float haut;

void vertex() {
	haut = VERTEX.y;
	monde = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// Les deux faces d'un brin prennent la normale du ciel : sinon le dos sort gris.
	if (!FRONT_FACING) NORMAL = -NORMAL;
	bool sol = terre != vec3(0.0);
	vec3 c = sol ? terre : herbe_saison(COLOR.rgb, 1.0);
	c = mix(c, S_NEIGE, neige_manteau(monde) * (sol ? 1.0 : smoothstep(0.3, 0.9, haut)) * 0.85);
	ALBEDO = c;
	ROUGHNESS = 1.0;
}
