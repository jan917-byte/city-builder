shader_type spatial;
render_mode cull_back;

uniform vec4 teinte : source_color;
uniform bool diagnostic = false;
varying vec3 monde;

void vertex() {
	monde = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// Deux trains d'ondes en mètres ; leur contraste disparaît sous le pixel.
	vec2 p = monde.xz;
	float a = dot(p, vec2(0.8, 0.6)) * 2.2 + sin(p.y * 0.31) * 1.4 + TIME * 0.65;
	float b = dot(p, vec2(0.65, 0.76)) * 3.7 + sin(p.x * 0.24) - TIME * 0.42;
	float net = 1.0 - smoothstep(0.5, 2.0, max(fwidth(a), fwidth(b)));
	float onde = (sin(a) * 0.6 + sin(b) * 0.4) * net;
	vec3 couleur = teinte.rgb * vec3(0.60, 0.87, 0.85) * (1.0 + onde * 0.065);
	ALBEDO = diagnostic ? vec3(0.073, 0.089, 0.107) : couleur;
	vec3 pente = vec3(cos(a) * 0.025 * net, 1.0, cos(b) * 0.018 * net);
	NORMAL = diagnostic ? NORMAL : normalize((VIEW_MATRIX * vec4(normalize(pente), 0.0)).xyz);
	ROUGHNESS = diagnostic ? 1.0 : 0.30;
	SPECULAR = diagnostic ? 0.0 : 0.45;
}
