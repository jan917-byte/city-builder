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
## `etage_m` vient de `meta.etage_m`, donc de ETAGE_M dans 07. C'est le seul
## nombre que ce shader partage avec la GÉOMÉTRIE, et c'est pour ça qu'il
## est passé au lieu d'être recopié : les murs montent à un multiple exact
## de la hauteur d'étage, et c'est ce qui fait qu'aucune fenêtre n'est
## coupée par l'égout. Que les deux divergent, et toute la ville sort avec
## des rangées de fenêtres à cheval sur la gouttière.
static func objet(etage_m: float = 2.7) -> ShaderMaterial:
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
		+ "// 🧱 LE RANG DE TUILES — 32 cm, la valeur réelle d'une tuile\n" \
		+ "// mécanique. C'est le détail le moins cher de tout le projet :\n" \
		+ "// une ligne de motif, aucune texture, aucun sommet ajouté. Il ne\n" \
		+ "// se voit qu'au zoom rapproché et s'efface AVANT de grésiller.\n" \
		+ "const float RANG_M = 0.32;\n" \
		+ "const float JOINT = 0.13;\n" \
		+ "// ⚠ En espace LINÉAIRE, comme les couleurs de sommet (voir en-tête).\n" \
		+ "// BLEU = #1F61C7 en sRGB. BLANC n'est pas blanc : 92 % de sRGB, sinon\n" \
		+ "// le liseré brûle et mange le bleu dès qu'on dézoome.\n" \
		+ "const vec3 BLEU = vec3(0.013, 0.119, 0.570);\n" \
		+ "const vec3 BLANC = vec3(0.83);\n" \
		+ "// 🪟 LA FENÊTRE. Ces cotes sont celles d'un logement ordinaire :\n" \
		+ "// allège à hauteur d'appui, linteau sous le plafond, 1,15 m de\n" \
		+ "// large. Elles ne se règlent pas à l'œil : c'est parce qu'elles\n" \
		+ "// sont justes qu'un étage se lit comme un étage, et qu'un volume\n" \
		+ "// annonce enfin sa taille sans qu'on ait rien à côté pour\n" \
		+ "// comparer.\n" \
		+ ("const float ETAGE = %.4f;\n" % etage_m) \
		+ "const float ALLEGE = 0.95;\n" \
		+ "const float LINTEAU = 2.25;\n" \
		+ "const float FEN_LARGE = 1.15;\n" \
		+ "const float ENTRAXE_MIN = 2.75;\n" \
		+ "const float ENTRAXE_MAX = 3.70;\n" \
		+ "// ⚠ En espace LINÉAIRE, comme tout le reste ici. #3A424B en sRGB :\n" \
		+ "// du verre qui reflète un ciel couvert, pas un trou. Une vitre\n" \
		+ "// vraiment noire crible les façades de points sombres et donne à\n" \
		+ "// la ville l'air d'avoir été bombardée.\n" \
		+ "const vec3 VITRE = vec3(0.042, 0.055, 0.070);\n" \
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
		+ "\tvec3 normale_monde = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);\n" \
		+ "\tfloat vers_le_ciel = normale_monde.y;\n" \
		+ "\tfloat rugosite = 0.95;\n" \
		+ "\t// 🧱 LES RANGS DE TUILES, posés AVANT les panneaux : un toit\n" \
		+ "\t// équipé est couvert, il n'est plus une couverture. La borne\n" \
		+ "\t// haute (0,995) écarte tout ce qui est PLAT — le sol, la\n" \
		+ "\t// chaussée, les cours, et les toits-terrasses de 1974, qui ne\n" \
		+ "\t// sont pas en tuile.\n" \
		+ "\tif (vers_le_ciel > 0.5 && vers_le_ciel < 0.995 && pos_monde.y > 1.0) {\n" \
		+ "\t\t// L'écart des rangs se mesure LE LONG DE LA PENTE, pas en\n" \
		+ "\t\t// hauteur : sinon un toit à 14° sort avec des rangs de 1,4 m\n" \
		+ "\t\t// et un toit à 45° avec des rangs de 48 cm, pour la même\n" \
		+ "\t\t// tuile. `vers_le_ciel` étant le cosinus de la pente, son\n" \
		+ "\t\t// sinus tombe tout seul.\n" \
		+ "\t\tfloat sin_pente = sqrt(max(1.0 - vers_le_ciel * vers_le_ciel, 0.02));\n" \
		+ "\t\tfloat rang = pos_monde.y / (RANG_M * sin_pente);\n" \
		+ "\t\tfloat ar = max(fwidth(rang), 0.0005);\n" \
		+ "\t\tfloat dr = abs(fract(rang + 0.5) - 0.5);\n" \
		+ "\t\tfloat joint = smoothstep(JOINT - ar, JOINT + ar, dr);\n" \
		+ "\t\t// `visible` rend la main à l'aplat dès qu'un rang passe sous\n" \
		+ "\t\t// ~1,5 px : à la vue par défaut (1 200 m de large) les rangs\n" \
		+ "\t\t// sont bien plus fins que le pixel, et sans ce fondu tout le\n" \
		+ "\t\t// quartier scintillerait au moindre mouvement de caméra.\n" \
		+ "\t\tfloat visible = clamp(1.3 - 4.0 * ar, 0.0, 1.0);\n" \
		+ "\t\tbase *= mix(1.0, mix(0.80, 1.0, joint), visible);\n" \
		+ "\t}\n" \
		+ "\tif (equipe > 0.0 && vers_le_ciel > 0.55 && pos_monde.y > 1.0 && length(UV) > 0.5) {\n" \
		+ "\t\t// 🔄 RETOUR EN ARRIÈRE SIGNALÉ (§3 ter). Le panneau était rendu\n" \
		+ "\t\t// par un ASSOMBRISSEMENT du toit (*= 0.13, 0.15, 0.20), donc\n" \
		+ "\t\t// indiscernable d'une ombre sur les toits déjà sombres, et\n" \
		+ "\t\t// invisible au-delà du zoom moyen. L'auteur a demandé le\n" \
		+ "\t\t// 2026-08-17 : bleu franc + liseré blanc. Ce n'est plus une\n" \
		+ "\t\t// teinte, c'est un MOTIF — donc une grille, sinon aucun\n" \
		+ "\t\t// « contour » n'a de sens.\n" \
		+ "\t\t// UV porte l'axe propre de CE bâtiment. Sur un toit pentu,\n" \
		+ "\t\t// l'autre axe est reconstruit dans le plan du versant : la\n" \
		+ "\t\t// grille suit donc le faîtage et remonte réellement la pente.\n" \
		+ "\t\tvec3 axe = normalize(vec3(UV.x, 0.0, UV.y));\n" \
		+ "\t\tvec3 pente_axe = normalize(cross(axe, normale_monde));\n" \
		+ "\t\tvec2 g = vec2(dot(pos_monde, axe), dot(pos_monde, pente_axe)) / PANNEAU_M;\n" \
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
		+ "\t\t// La pose avance PAN PAR PAN. Sur un toit à deux pentes,\n" \
		+ "\t\t// le versant le mieux exposé au sud est rempli avant l'autre ;\n" \
		+ "\t\t// si le faîtage est nord-sud, l'est départage les deux. Un\n" \
		+ "\t\t// toit plat est un seul pan et conserve directement `equipe`.\n" \
		+ "\t\tfloat pan = equipe;\n" \
		+ "\t\tif (vers_le_ciel < 0.995) {\n" \
		+ "\t\t\tbool premier = normale_monde.z > 0.01 || (abs(normale_monde.z) <= 0.01 && normale_monde.x > 0.0);\n" \
		+ "\t\t\tpan = clamp(equipe * 2.0 - (premier ? 0.0 : 1.0), 0.0, 1.0);\n" \
		+ "\t\t}\n" \
		+ "\t\tfloat posee = mix(pan, step(h, pan), net);\n" \
		+ "\t\t// COLOR.a (l'AO seule) garde le volume sous le motif, comme le\n" \
		+ "\t\t// fait le repeint thématique juste au-dessus.\n" \
		+ "\t\tbase = mix(base, mix(BLEU, BLANC, bord) * COLOR.a, posee);\n" \
		+ "\t\trugosite = mix(0.95, 0.35, posee);\n" \
		+ "\t}\n" \
		+ "\t// 🪟 LES FENÊTRES, et c'est la même famille que les rangs de\n" \
		+ "\t// tuile : une recette de surface, pas un triangle de plus. Ce\n" \
		+ "\t// qui arrive ici, et rien d'autre :\n" \
		+ "\t//   UV  = (u, L)         mètres le long de la façade, et\n" \
		+ "\t//                        longueur de CETTE façade\n" \
		+ "\t//   UV2 = (genre, alea)  la recette de percement, et le tirage\n" \
		+ "\t//                        du bâtiment — le même sur ses 4 murs\n" \
		+ "\t// 🔴 LE SHADER NE DÉCIDE RIEN. Ce qu'est une rue, un mur\n" \
		+ "\t// mitoyen, un front commerçant : c'est `_facades` dans 07 qui\n" \
		+ "\t// le sait, parce que lui seul a la carte sous les yeux.\n" \
		+ "\t// Les deux tests qui accompagnent UV2 sont une ceinture : un\n" \
		+ "\t// toit porte un vecteur UNITAIRE dans UV, donc jamais 1,05.\n" \
		+ "\tif (UV2.x > 0.5 && abs(normale_monde.y) < 0.30 && UV.y > 1.05) {\n" \
		+ "\t\tfloat u = UV.x;\n" \
		+ "\t\tfloat L = UV.y;\n" \
		+ "\t\tfloat h = pos_monde.y;\n" \
		+ "\t\tint genre = int(UV2.x + 0.5);\n" \
		+ "\t\tfloat alea = UV2.y;\n" \
		+ "\t\t// aa = un pixel, mesuré EN MÈTRES DE FAÇADE. Tout le fondu\n" \
		+ "\t\t// en dépend, et c'est ce qui rend le réglage indépendant du\n" \
		+ "\t\t// zoom : on ne compare jamais des mètres à une distance.\n" \
		+ "\t\tfloat aa = max(fwidth(u), 0.0005);\n" \
		+ "\t\t// L'ÉTAGE. Les murs montent à un multiple EXACT de ETAGE (07\n" \
		+ "\t\t// pose y_haut = niveaux × ETAGE_M), donc aucune fenêtre n'est\n" \
		+ "\t\t// coupée par l'égout et le shader n'a pas besoin de connaître\n" \
		+ "\t\t// la hauteur du bâtiment. C'est tout le prix de l'argument\n" \
		+ "\t\t// `etage_m` en tête de cette fonction.\n" \
		+ "\t\tfloat etage = floor(max(h, 0.0) / ETAGE);\n" \
		+ "\t\tfloat hy = h - etage * ETAGE;\n" \
		+ "\t\t// LES TRAVÉES SONT CENTRÉES SUR LA FAÇADE, et c'est pour ça\n" \
		+ "\t\t// que 07 envoie `L`. On réserve `marge` de mur plein à chaque\n" \
		+ "\t\t// bout, puis on retient le nombre de travées qui approche le\n" \
		+ "\t\t// mieux l'entraxe visé. Une trame de pas fixe laisserait une\n" \
		+ "\t\t// demi-fenêtre dans l'angle de tous les murs dont la longueur\n" \
		+ "\t\t// n'est pas un multiple — c'est-à-dire de tous.\n" \
		+ "\t\tfloat vise = mix(ENTRAXE_MIN, ENTRAXE_MAX, alea);\n" \
		+ "\t\tfloat marge = 0.32;\n" \
		+ "\t\tif (genre == 4) { vise = mix(2.40, 3.00, alea); marge = 0.90; }\n" \
		+ "\t\tfloat utile = max(L - 2.0 * marge, 0.60);\n" \
		+ "\t\tfloat n = max(1.0, floor(utile / vise + 0.5));\n" \
		+ "\t\tfloat pas = utile / n;\n" \
		+ "\t\tfloat x = u - marge;\n" \
		+ "\t\tfloat travee = floor(x / pas);\n" \
		+ "\t\tfloat du = abs(x - (travee + 0.5) * pas);\n" \
		+ "\t\tfloat demi = 0.5 * min(FEN_LARGE, pas * 0.45);\n" \
		+ "\t\tfloat bas = ALLEGE;\n" \
		+ "\t\tfloat haut = LINTEAU;\n" \
		+ "\t\tif (genre == 4) {\n" \
		+ "\t\t\t// LA BANDE FILANTE — la barre de 1974 et les halles. Une\n" \
		+ "\t\t\t// seule ouverture par étage, coupée de meneaux fins. Les\n" \
		+ "\t\t\t// 90 cm de mur plein aux deux bouts sont ce qui la\n" \
		+ "\t\t\t// distingue d'un ruban de verre posé sur des poteaux.\n" \
		+ "\t\t\t// \u26a0 Mesuré le 2026-08-18 : à 1,75 m d'entraxe la\n" \
		+ "\t\t\t// barre sortait criblée de petits carrés — une carte\n" \
		+ "\t\t\t// perforée, pas un bandeau. Ce qui fait la BANDE, c'est\n" \
		+ "\t\t\t// que l'ouverture soit deux fois plus large que haute.\n" \
		+ "\t\t\tdemi = 0.5 * (pas - 0.30);\n" \
		+ "\t\t\tbas = 1.00;\n" \
		+ "\t\t\thaut = 2.20;\n" \
		+ "\t\t} else if (etage < 0.5 && genre == 3) {\n" \
		+ "\t\t\t// LA VITRINE : un rez presque tout vitré entre deux\n" \
		+ "\t\t\t// trumeaux. C'est elle qui fait qu'une rue commerçante se\n" \
		+ "\t\t\t// lit comme telle sans qu'on ait à colorier le tissu.\n" \
		+ "\t\t\tdemi = 0.5 * (pas - 0.80);\n" \
		+ "\t\t\tbas = 0.45;\n" \
		+ "\t\t\thaut = 2.45;\n" \
		+ "\t\t} else if (etage < 0.5 && genre == 2 && travee == floor(alea * n)) {\n" \
		+ "\t\t\t// LA PORTE. Une seule par bâtiment : 07 ne marque le genre\n" \
		+ "\t\t\t// 2 que sur sa plus longue façade sur rue.\n" \
		+ "\t\t\tdemi = 0.5 * min(1.10, pas * 0.42);\n" \
		+ "\t\t\tbas = 0.02;\n" \
		+ "\t\t\thaut = 2.15;\n" \
		+ "\t\t}\n" \
		+ "\t\tfloat bord = min(u, L - u);\n" \
		+ "\t\tfloat dedans = smoothstep(demi + aa, demi - aa, du)\n" \
		+ "\t\t\t* smoothstep(bas - aa, bas + aa, hy)\n" \
		+ "\t\t\t* smoothstep(haut + aa, haut - aa, hy)\n" \
		+ "\t\t\t* smoothstep(marge - aa, marge + aa, bord);\n" \
		+ "\t\t// L'EMBRASURE. Une fenêtre sans épaisseur est un autocollant :\n" \
		+ "\t\t// le haut du tableau rend une ombre, le dormant un liseré\n" \
		+ "\t\t// clair, et l'appui déborde de 13 cm sous l'allège. Trois\n" \
		+ "\t\t// bandes de quelques centimètres, et aucun sommet.\n" \
		+ "\t\tfloat ombre = smoothstep(haut - 0.22, haut - 0.03, hy);\n" \
		+ "\t\tfloat cerne = smoothstep(demi + 0.08 + aa, demi + 0.08 - aa, du)\n" \
		+ "\t\t\t* smoothstep(bas - 0.13 - aa, bas - 0.13 + aa, hy)\n" \
		+ "\t\t\t* smoothstep(haut + 0.08 + aa, haut + 0.08 - aa, hy)\n" \
		+ "\t\t\t* smoothstep(marge - 0.10 - aa, marge - 0.10 + aa, bord);\n" \
		+ "\t\t// Le meneau : deux vantaux, donc un montant au milieu — mais\n" \
		+ "\t\t// seulement sur les ouvertures assez larges pour en avoir un.\n" \
		+ "\t\tfloat meneau = (demi > 0.45) ? smoothstep(0.030, 0.055, du) : 1.0;\n" \
		+ "\t\tfloat ouverture = clamp(dedans * meneau, 0.0, 1.0);\n" \
		+ "\t\tfloat dormant = clamp(cerne - ouverture, 0.0, 1.0);\n" \
		+ "\t\t// 🔴 LOIN, ON NE DESSINE PLUS — ON ASSOMBRIT. Une fenêtre de\n" \
		+ "\t\t// 1,15 m tient sur deux pixels à la vue par défaut, et la\n" \
		+ "\t\t// dessiner n'y fait plus que du bruit qui grouille dès que la\n" \
		+ "\t\t// caméra bouge. On rend alors la main à la PART VITRÉE du\n" \
		+ "\t\t// mur, qui est exactement ce que l'œil voit à cette distance :\n" \
		+ "\t\t// un enduit un peu plus sombre, sans un seul scintillement.\n" \
		+ "\t\tfloat net = clamp(1.15 - 1.8 * aa, 0.0, 1.0);\n" \
		+ "\t\tfloat part = clamp(2.0 * demi * (haut - bas)\n" \
		+ "\t\t\t/ max(pas * ETAGE, 0.1), 0.0, 1.0);\n" \
		+ "\t\tfloat vitre = mix(part, ouverture, net);\n" \
		+ "\t\t// COLOR.a (l'AO seule) garde le volume sous le percement,\n" \
		+ "\t\t// comme le font le calque thématique et les panneaux.\n" \
		+ "\t\tbase = mix(base, min(base * 1.28 + 0.012, vec3(1.0)), dormant * net);\n" \
		+ "\t\tbase = mix(base, VITRE * mix(1.0, 0.45, ombre) * COLOR.a, vitre);\n" \
		+ "\t\trugosite = mix(rugosite, 0.18, vitre * net);\n" \
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
	# Le MultiMesh porte ses couleurs par instance, et le maillage porte son
	# dégradé vertical en couleur de sommet : Godot MULTIPLIE les deux, donc
	# la sous-face reste sombre quelle que soit la teinte tirée.
	m.vertex_color_use_as_albedo = true
	m.cull_mode = BaseMaterial3D.CULL_BACK
	return m


## Le tronc. Sa teinte est FIXE et ne suit pas la couleur d'instance : c'est
## tout l'intérêt de le mettre dans une seconde surface. Sans ça, un tronc sous
## un feuillage vert ressortirait vert.
static func bois(teinte: Color) -> StandardMaterial3D:
	var m := surface(0.95)
	m.vertex_color_use_as_albedo = false
	m.albedo_color = teinte
	return m


## 🔲 LE MASQUE DE SÉLECTION. L'îlot choisi est redessiné seul, en blanc
## plat, dans une petite vue à part : c'est de cette SILHOUETTE que le contour
## est tiré. Non éclairé parce qu'on ne lit que sa couverture, jamais sa
## couleur ; faces non éliminées parce qu'un dos manquant ferait un trou dans
## la silhouette, donc un trou dans le trait.
static func masque() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color.WHITE
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


## ✏️ LE TRAIT AUTOUR DE L'OBJET CHOISI, dessiné À L'ÉCRAN et pas dans la
## scène — 2026-08-18.
##
## 🔄 RETOUR EN ARRIÈRE SIGNALÉ, le même jour : c'était un ruban de
## triangles posé au sol le long de l'anneau de l'îlot. Il n'entourait que
## l'emprise AU SOL, alors qu'on sélectionne l'objet ENTIER — ses bâtiments
## dépassaient du trait, et dans le cœur ancien ils le cachaient. Aucune
## géométrie posée au sol ne peut résoudre ça : il faut la silhouette, donc
## il faut la vue.
##
## Le principe tient en une ligne : le trait est là où le masque est VIDE mais
## où il y a du masque à moins de `rayon` pixels. Donc il épouse la silhouette
## quel que soit l'angle, il ne recouvre jamais l'objet, et son épaisseur est
## en PIXELS — elle ne change pas au zoom, sans qu'aucun code n'ait à la
## recalculer.
##
## 🔴 `bouche` EST CE QUI FAIT QU'UN TRONÇON EST UN SEUL BLOC. Une rue
## n'est pas une surface : c'est la chaussée, plus deux trottoirs posés à
## `JEU_CHAUSSEE` (10 cm) de l'asphalte, plus un morceau de trottoir par îlot
## riverain. Sans rien faire, le trait entoure CHACUN de ces morceaux et la
## rue choisie ressort en bandes parallèles — mesuré sur le tronçon 120 le
## 2026-08-18. On dilate donc le masque de `bouche` pixels AVANT de chercher
## son bord : toute couture plus étroite que ça se referme, et il ne reste que
## le contour extérieur. Le prix est un jeu de `bouche` pixels entre l'objet
## et son trait — assez petit pour se lire comme un souffle, assez grand pour
## recoudre les trottoirs.
##
## Les sondages sont 16 directions × 5 distances, et les cinq distances ne sont
## pas du luxe : une rue fait quelques pixels de large, donc un sondage à la
## seule distance maximale la MANQUERAIT et le trait sortirait troué.
static func contour(masque_tex: Texture2D, couleur: Color) -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = "shader_type canvas_item;\n" \
		+ "render_mode unshaded;\n" \
		+ "uniform sampler2D masque : filter_linear, repeat_disable;\n" \
		+ "uniform vec2 pas = vec2(0.001);\n" \
		+ "uniform float rayon = 3.0;\n" \
		+ "uniform float bouche = 2.0;\n" \
		+ "uniform vec4 couleur : source_color = vec4(1.0);\n" \
		+ "const int DIRS = 16;\n" \
		+ "const int PALIERS = 5;\n" \
		+ "void fragment() {\n" \
		+ "  float au_centre = texture(masque, UV).a;\n" \
		+ "  float dedans = au_centre;\n" \
		+ "  float autour = au_centre;\n" \
		+ "  float loin = bouche + rayon;\n" \
		+ "  for (int k = 0; k < DIRS; k++) {\n" \
		+ "    float a = float(k) * 6.2831853 / float(DIRS);\n" \
		+ "    vec2 u = vec2(cos(a), sin(a)) * pas;\n" \
		+ "    for (int j = 1; j <= PALIERS; j++) {\n" \
		+ "      float d = loin * float(j) / float(PALIERS);\n" \
		+ "      float m = texture(masque, UV + u * d).a;\n" \
		+ "      autour = max(autour, m);\n" \
		+ "      if (d <= bouche) { dedans = max(dedans, m); }\n" \
		+ "    }\n" \
		+ "  }\n" \
		+ "  // Un pixel a\u0300 peine couvert compte comme PLEIN : sinon la couture\n" \
		+ "  // de 10 cm entre asphalte et trottoir laisse un liser\u00e9 gris qui\n" \
		+ "  // rallume le trait au milieu de la rue.\n" \
		+ "  float bord = smoothstep(0.0, 0.30, autour) - smoothstep(0.0, 0.30, dedans);\n" \
		+ "  COLOR = vec4(couleur.rgb, clamp(bord, 0.0, 1.0) * couleur.a);\n" \
		+ "}\n"
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("masque", masque_tex)
	m.set_shader_parameter("couleur", couleur)
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
	# 🔄 0,85 → 0,66 le 2026-08-18. Voir `AMBIANT` dans palette.py : à
	# 0,85 l'ambiant bleu du ciel repeignait toutes les façades à l'ombre,
	# ce qui ne se voyait pas tant que les murs étaient colorés.
	e.ambient_light_energy = 0.74

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
