shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, fog_disabled;
uniform float horloge = -1.0;
varying vec2 carte;
varying float graine;
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float bruit(vec2 p) {
	vec2 i=floor(p),f=fract(p); f=f*f*(3.0-2.0*f);
	return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1)),f.x),f.y);
}
void vertex() {
	carte = VERTEX.xy*2.0;
	graine = INSTANCE_CUSTOM.z;
	vec3 centre = MODEL_MATRIX[3].xyz;
	vec3 p = centre + INV_VIEW_MATRIX[0].xyz * VERTEX.x * INSTANCE_CUSTOM.x
		+ INV_VIEW_MATRIX[1].xyz * VERTEX.y * INSTANCE_CUSTOM.y;
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(p,1.0);
}
void fragment() {
	float t = (horloge < 0.0 ? TIME : horloge)*0.007;
	vec2 p=carte*vec2(3.5,2.5)+vec2(graine*71.0+t,0);
	float n=bruit(p)*0.6+bruit(p*2.1)*0.27+bruit(p*4.3)*0.13;
	float enveloppe=1.0-smoothstep(0.30,1.0,length(carte*vec2(1.0,1.2)));
	ALPHA = enveloppe*smoothstep(0.23,0.68,n)*0.80;
	ALBEDO=mix(vec3(0.70,0.77,0.78),vec3(0.96,0.97,0.94),smoothstep(-0.7,0.7,carte.y+n*0.4));
}
