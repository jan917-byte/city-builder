extends RefCounted
# Cinq matériaux, zéro texture.
#
# « Aucune texture — la couleur est portée par le matériau. Un `sous_type` =
# une teinte. Rien à peindre, jamais. » (Direction artistique l.19)
#
# La couleur voyage dans ARRAY_COLOR, donc UN matériau suffit pour les 69
# îlots : c'est `vertex_color_use_as_albedo` qui fait tout le travail.


static func surface(rugosite: float = 0.95) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.albedo_color = Color.WHITE
	m.roughness = rugosite
	m.metallic = 0.0
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	# Le sens des faces est prouvé des deux côtés : 07 vérifie les NORMALES
	# (376/376 murs vers l'extérieur, 270/270 toits vers le haut) et émet les
	# sommets en sens horaire, la convention de face avant de Godot.
	m.cull_mode = BaseMaterial3D.CULL_BACK
	return m


## Le matériau des objets cliquables — îlots et tronçons.
##
## Un `StandardMaterial3D` ne suffit plus : il faut pouvoir surligner UN îlot,
## ou repeindre les 69 selon un calque thématique, sans dupliquer le matériau
## 247 fois. D'où `instance uniform` : une valeur par MeshInstance3D, portée par
## l'instance et pas par le matériau, donc sans casser le partage.
##
## ⚠ Les couleurs de sommet sont en espace LINÉAIRE (07 les convertit). Les
## deux uniformes ci-dessous ne portent PAS `source_color` : ce sont des
## facteurs, pas des couleurs d'interface. Une teinte venue de la palette doit
## donc passer par `.srgb_to_linear()` avant d'arriver ici — même règle que
## partout ailleurs dans ce projet.
static func objet() -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = "shader_type spatial;\n" \
		+ "render_mode cull_back, specular_disabled;\n" \
		+ "instance uniform vec4 teinte = vec4(1.0, 1.0, 1.0, 1.0);\n" \
		+ "instance uniform vec4 calque = vec4(1.0, 1.0, 1.0, 0.0);\n" \
		+ "instance uniform float equipe = 0.0;\n" \
		+ "varying vec3 pos_monde;\n" \
		+ "// Un panneau de 3 m de côté, cerné d'un liseré de 5 % de la case\n" \
		+ "// (~0,3 m de trait entre deux panneaux voisins). Ces deux nombres\n" \
		+ "// sont des choix de LISIBILITÉ à l'écran, pas des mesures de toiture.\n" \
		+ "// ⚠ Mesuré le 2026-08-17 : à 0,10 le liseré prend le dessus et le toit\n" \
		+ "// se lit BLANC semé de losanges bleus, l'inverse de ce qu'on veut.\n" \
		+ "const float PANNEAU_M = 3.0;\n" \
		+ "const float LISERE = 0.05;\n" \
		+ "// ⚠ En espace LINÉAIRE, comme les couleurs de sommet (voir en-tête).\n" \
		+ "// BLEU = #1F61C7 en sRGB. BLANC n'est pas blanc : 92 % de sRGB, sinon\n" \
		+ "// le liseré brûle et mange le bleu dès qu'on dézoome.\n" \
		+ "const vec3 BLEU = vec3(0.013, 0.119, 0.570);\n" \
		+ "const vec3 BLANC = vec3(0.83);\n" \
		+ "void vertex() {\n" \
		+ "\tpos_monde = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;\n" \
		+ "}\n" \
		+ "void fragment() {\n" \
		+ "\t// COLOR.rgb : la teinte de l'objet, déjà multipliée par l'AO.\n" \
		+ "\t// COLOR.a   : l'AO seule. C'est elle qui pose le volume au sol,\n" \
		+ "\t//             et qui doit survivre au repeint thématique.\n" \
		+ "\tvec3 base = mix(COLOR.rgb, calque.rgb * COLOR.a, calque.a);\n" \
		+ "\t// Les toits se COUVRENT de panneaux au fil de la pose : une\n" \
		+ "\t// recette, pas un asset (règle 52). NORMAL est en espace VUE ;\n" \
		+ "\t// on le ramène au monde pour tester « tourné vers le ciel »,\n" \
		+ "\t// et la hauteur écarte cours et jardins, qui sont dans le même\n" \
		+ "\t// maillage que le bâti de l'îlot.\n" \
		+ "\tfloat vers_le_ciel = (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).y;\n" \
		+ "\tfloat rugosite = 0.95;\n" \
		+ "\tif (equipe > 0.0 && vers_le_ciel > 0.55 && pos_monde.y > 1.0) {\n" \
		+ "\t\t// 🔄 RETOUR EN ARRIÈRE SIGNALÉ (§3 ter). Le panneau était rendu\n" \
		+ "\t\t// par un ASSOMBRISSEMENT du toit (*= 0.13, 0.15, 0.20), donc\n" \
		+ "\t\t// indiscernable d'une ombre sur les toits déjà sombres, et\n" \
		+ "\t\t// invisible au-delà du zoom moyen. L'auteur a demandé le\n" \
		+ "\t\t// 2026-08-17 : bleu franc + liseré blanc. Ce n'est plus une\n" \
		+ "\t\t// teinte, c'est un MOTIF — donc une grille, sinon aucun\n" \
		+ "\t\t// « contour » n'a de sens.\n" \
		+ "\t\tvec2 g = pos_monde.xz / PANNEAU_M;\n" \
		+ "\t\t// aa = largeur d'une case en pixels⁻¹. Tout ce qui suit en\n" \
		+ "\t\t// dépend : à la vue par défaut (1 200 m de large) une case ne\n" \
		+ "\t\t// fait que ~3 px, et une grille de 3 px scintille au moindre\n" \
		+ "\t\t// mouvement de caméra. fwidth se prend sur `g` et PAS sur son\n" \
		+ "\t\t// fract(), dont la dérivée explose au bord de chaque case.\n" \
		+ "\t\tfloat aa = max(max(fwidth(g.x), fwidth(g.y)), 0.0005);\n" \
		+ "\t\tvec2 f = abs(fract(g) - 0.5);\n" \
		+ "\t\tfloat d = max(f.x, f.y);\n" \
		+ "\t\tfloat bord = smoothstep(0.5 - LISERE - aa, 0.5 - LISERE + aa, d);\n" \
		+ "\t\t// La pose est DISCRÈTE : une case est équipée ou ne l'est pas,\n" \
		+ "\t\t// tirée au sort sous le seuil `equipe`. À 30 %, on voit trente\n" \
		+ "\t\t// panneaux bleus francs et non un toit lavé de bleu à 30 %.\n" \
		+ "\t\tfloat h = fract(sin(dot(floor(g), vec2(12.9898, 78.233))) * 43758.545);\n" \
		+ "\t\t// …mais de loin le tirage devient du bruit de pixel. `net` rend\n" \
		+ "\t\t// la main au fondu continu dès que la case passe sous ~7 px.\n" \
		+ "\t\tfloat net = clamp(1.15 - 5.0 * aa, 0.0, 1.0);\n" \
		+ "\t\tfloat posee = mix(equipe, step(h, equipe), net);\n" \
		+ "\t\t// COLOR.a (l'AO seule) garde le volume sous le motif, comme le\n" \
		+ "\t\t// fait le repeint thématique juste au-dessus.\n" \
		+ "\t\tbase = mix(base, mix(BLEU, BLANC, bord) * COLOR.a, posee);\n" \
		+ "\t\trugosite = mix(0.95, 0.35, posee);\n" \
		+ "\t}\n" \
		+ "\tALBEDO = base * teinte.rgb;\n" \
		+ "\tROUGHNESS = rugosite;\n" \
		+ "\tMETALLIC = 0.0;\n" \
		+ "}\n"
	var m := ShaderMaterial.new()
	m.shader = sh
	return m


static func eau(teinte: Color) -> StandardMaterial3D:
	var m := surface(0.25)
	m.vertex_color_use_as_albedo = false
	m.albedo_color = teinte
	m.metallic = 0.15
	m.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	return m


static func feuillage() -> StandardMaterial3D:
	var m := surface(0.98)
	# Le MultiMesh porte ses couleurs par instance.
	m.vertex_color_use_as_albedo = true
	m.cull_mode = BaseMaterial3D.CULL_BACK
	return m


## Le décor : lumière fixe et calme. « Pas de météo d'ambiance, pas de golden
## hour, pas de ciel gris » (Direction artistique l.69). Ce qui creuse les
## volumes n'est pas la lumière, c'est l'occlusion — bakée en couleur de
## sommet par 07, et complétée ici par le SSAO.
static func environnement(ciel: Color, ambiant: Color) -> Environment:
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = ciel
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = ambiant
	e.ambient_light_energy = 0.85

	e.ssao_enabled = true
	e.ssao_radius = 2.0
	e.ssao_intensity = 2.4
	e.ssao_power = 1.5
	e.ssao_detail = 0.5

	# ⚠ Le SSAO travaille en espace vue ; son rayon ne se comporte pas
	# pareil en projection orthographique. Si c'est cassé à l'écran, l'AO
	# bakée par 07 tient debout seule — c'est pour ça qu'elle est la
	# fondation et le SSAO le complément, et pas l'inverse.
	return e
