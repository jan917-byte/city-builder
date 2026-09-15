// Le contour, la teinte et les bandes viennent de la parcelle SVG exportée.
float grain_champ(vec2 p) {
	float net = 1.0 / (1.0 + length(fwidth(p)));
	return 1.0 + sin(p.x * 1.7 + p.y * 0.6) * 0.018 * net;
}
