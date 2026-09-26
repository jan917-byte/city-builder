shader_type spatial;
render_mode cull_back, specular_disabled;
#include "res://shaders/brume.gdshaderinc"
// Un cumulus de maquette : facettes éclairées, dessous gris bleuté.
uniform float horloge = -1.0;
uniform vec2 demi_emprise;
varying vec3 monde;
varying float bas;

void vertex() {
	// Dérive lente vers l'est, bouclée sur 700 m ; le banc fond en bout de course.
	float t = (horloge < 0.0 ? TIME : horloge) * 0.9 + INSTANCE_CUSTOM.x * 700.0;
	float course = mod(t, 700.0);
	float fond = smoothstep(0.0, 90.0, course) * smoothstep(700.0, 610.0, course);
	vec3 derive = inverse(mat3(MODEL_MATRIX)) * vec3(course - 350.0, 0.0, 0.0);
	bas = VERTEX.y;
	VERTEX = VERTEX * fond + derive;
	monde = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 blanc = vec3(0.93, 0.94, 0.93);
	vec3 dessous = vec3(0.62, 0.67, 0.72);
	ALBEDO = mix(dessous, blanc, smoothstep(-0.12, 0.10, bas));
	float brume = brume_bord(monde.xz, demi_emprise);
	ALBEDO *= 1.0 - brume;
	EMISSION = ALBEDO * 0.28 + BRUME_CIEL * brume;
	ROUGHNESS = 1.0;
}
