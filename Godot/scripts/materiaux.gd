extends RefCounted
# Matières procédurales, sans texture importée (Direction artistique l.19).
# La couleur voyage dans ARRAY_COLOR, donc UN matériau suffit pour les 69 îlots.


# 🏢 LA SURÉLÉVATION, ET DEUX MATÉRIAUX LA PARTAGENT : la ville et le masque de
# sélection. Posée dans un seul des deux, le trait de sélection reste sur
# l'ancien volume — vu à l'écran par l'auteur le 2026-09-03.
# `densification` = (avancement, pas d'un bâtiment, mètres gagnés) : un vec4 et
# non trois flottants, les uniformes d'instance sont comptés.
# CUSTOM0 = (rang du bâtiment, ce sommet suit-il le toit, égout d'origine), posé
# par 07. Un bâtiment monte ENTIER, chacun son tour, du plus bas au plus haut —
# même mécanique que le toit vert, sur les sommets cette fois. Le mur s'étire,
# donc la recette de fenêtres, qui compte les étages en Y monde, en perce de
# neuves. ⚠ La collision ne monte pas : cliquer vise l'îlot, pas une façade.
const DENSE_DECL := "instance uniform vec4 densification = vec4(0.0, 1.0, 0.0, 0.0);\n" \
	+ "varying float montee;\n" \
	+ "varying float plafond;\n"

# `montee` et `plafond` sont constants sur tout le bâtiment, donc
# l'interpolation ne les déforme pas — au contraire du déplacement du sommet,
# nul en pied de mur et plein en tête.
const DENSE_VERTEX := "\tmontee = densification.z * clamp(\n" \
	+ "\t\t(densification.x - CUSTOM0.x) / max(densification.y, 0.001),\n" \
	+ "\t\t0.0, 1.0);\n" \
	+ "\tplafond = CUSTOM0.z;\n" \
	+ "\tif (montee > 0.0 && CUSTOM0.y > 0.5) {\n" \
	+ "\t\tVERTEX.y += montee;\n" \
	+ "\t}\n"


static func surface(rugosite: float = 0.95) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.albedo_color = Color.WHITE
	m.roughness = rugosite
	m.metallic = 0.0
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	# 07 vérifie les normales (376/376 murs dehors, 270/270 toits en haut) et
	# émet en sens horaire, la convention de face avant de Godot.
	m.cull_mode = BaseMaterial3D.CULL_BACK
	return m


## Les objets cliquables — îlots et tronçons. `instance uniform` permet de
## surligner un îlot ou d'en repeindre 69 sans dupliquer le matériau 247 fois.
##
## ⚠ Tout est en espace LINÉAIRE : une teinte de palette passe par
## `.srgb_to_linear()` avant d'arriver ici. Les deux uniformes sont des
## facteurs, pas des couleurs d'interface — d'où l'absence de `source_color`.
##
## ⚠ `etage_m` vient de ETAGE_M dans 07 : seul nombre partagé avec la GÉOMÉTRIE,
## passé plutôt que recopié. Les murs montent à un multiple exact de l'étage ;
## s'ils divergent, la ville sort avec des fenêtres à cheval sur la gouttière.
static func objet(etage_m: float = 2.7) -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = "shader_type spatial;\n" \
		+ "render_mode cull_back, specular_disabled;\n" \
		+ "instance uniform vec4 teinte = vec4(1.0, 1.0, 1.0, 1.0);\n" \
		+ "instance uniform vec4 calque = vec4(1.0, 1.0, 1.0, 0.0);\n" \
		+ "instance uniform float maquette_blanche = 0.0;\n" \
		+ "instance uniform float diagnostic_sol = 0.0;\n" \
		+ "instance uniform float diagnostic_bati = 0.0;\n" \
		+ "instance uniform float chantier_etat = 0.0;\n" \
		+ "instance uniform float equipe = 0.0;\n" \
		+ "instance uniform float verdi = 0.0;\n" \
		+ "instance uniform float part_plate = 0.0;\n" \
		+ "instance uniform float etat_berge = 0.0;\n" \
		+ DENSE_DECL \
		+ "varying vec3 pos_monde;\n" \
		+ "// Choix de LISIBILITÉ, pas des mesures de toiture. ⚠ Mesuré le\n" \
		+ "// 2026-08-17 : à 0,10 de liseré le toit se lit BLANC semé de bleu.\n" \
		+ "const float PANNEAU_M = 3.0;\n" \
		+ "const float LISERE = 0.05;\n" \
		+ "// 🏢 LE BÂTI AJOUTÉ — bardage bois clair et zinc. Une\n" \
		+ "// surélévation ne se rejointoie pas en enduit : c'est la SEULE\n" \
		+ "// famille de matière du projet qui ne soit pas de l'époque du\n" \
		+ "// bâtiment, et c'est ce qui la fait lire comme neuve.\n" \
		+ "// ⚠ LINÉAIRE. #C6A277, #B08E63, #4E545C en sRGB.\n" \
		+ "const vec3 BARDAGE = vec3(0.565, 0.361, 0.184);\n" \
		+ "const vec3 BARDAGE_SEC = vec3(0.434, 0.270, 0.125);\n" \
		+ "const vec3 ZINC = vec3(0.076, 0.089, 0.107);\n" \
		+ "// La lame de bardage et le joint debout du zinc, en mètres.\n" \
		+ "const float LAME_M = 0.22;\n" \
		+ "const float JOINT_ZINC_M = 0.52;\n" \
		+ "// 🧱 LE RANG DE TUILES — 32 cm, la valeur réelle d'une tuile\n" \
		+ "// mécanique. Une ligne de motif, aucune texture, aucun sommet.\n" \
		+ "const float RANG_M = 0.32;\n" \
		+ "const float JOINT = 0.13;\n" \
		+ "// ⚠ LINÉAIRE. BLEU = #1F61C7 en sRGB ; BLANC n'est pas blanc mais\n" \
		+ "// 92 % de sRGB, sinon le liseré brûle et mange le bleu au dézoom.\n" \
		+ "const vec3 BLEU = vec3(0.013, 0.119, 0.570);\n" \
		+ "const vec3 BLANC = vec3(0.83);\n" \
		+ "// 🌿 LINÉAIRE. #4C6B3C et #7A8A4E en sRGB : un sédum en juin et le\n" \
		+ "// même en août. ⚠ Mesuré le 2026-08-31 : deux tons clairs (#6F8455)\n" \
		+ "// sortaient KHAKI sur un enduit crème — il faut descendre sous la\n" \
		+ "// valeur du mur pour qu'un toit se lise planté.\n" \
		+ "const vec3 SEDUM = vec3(0.072, 0.147, 0.045);\n" \
		+ "const vec3 SEDUM_SEC = vec3(0.194, 0.254, 0.076);\n" \
		+ "// 🪟 LA FENÊTRE — cotes d'un logement ordinaire. Ne se règlent pas\n" \
		+ "// à l'œil : c'est leur justesse qui fait qu'un volume annonce sa\n" \
		+ "// taille sans rien à côté pour comparer.\n" \
		+ ("const float ETAGE = %.4f;\n" % etage_m) \
		+ "const float ALLEGE = 0.95;\n" \
		+ "const float LINTEAU = 2.25;\n" \
		+ "const float FEN_LARGE = 1.15;\n" \
		+ "const float ENTRAXE_MIN = 2.75;\n" \
		+ "const float ENTRAXE_MAX = 3.70;\n" \
		+ "// ⚠ LINÉAIRE. #3A424B en sRGB : du verre qui reflète un ciel\n" \
		+ "// couvert. Une vitre noire donne à la ville l'air bombardée.\n" \
		+ "const vec3 VITRE = vec3(0.042, 0.055, 0.070);\n" \
		+ "// ⚠ LINÉAIRE. #D2CFC9 en sRGB : le carton d'une maquette\n" \
		+ "// d'architecte. Assez clair pour que les quatre signaux\n" \
		+ "// saturés ressortent, assez gris pour ne pas brûler au soleil.\n" \
		+ "const vec3 PAPIER = vec3(0.624, 0.605, 0.560);\n" \
		+ "// 🌿 LE GRAIN D'UNE RIVE RENDUE — deux teintes de vert en linéaire.\n" \
		+ "// ⚠ Le premier est celui d'avant le semis : la valeur moyenne de la\n" \
		+ "// bande ne bouge pas, c'est son UNIFORMITÉ qui disparaît.\n" \
		+ "const vec3 RIVE_VERTE = vec3(0.128, 0.318, 0.096);\n" \
		+ "const vec3 RIVE_SABLE = vec3(0.620, 0.548, 0.398);\n" \
		+ "float alea_pt(vec2 p) {\n" \
		+ "\treturn fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.545);\n" \
		+ "}\n" \
		+ "// Bruit de valeur bilinéaire, en MÈTRES : deux octaves suffisent à\n" \
		+ "// casser un aplat, et rien ici n'a besoin d'un vrai Perlin.\n" \
		+ "float bruit(vec2 p) {\n" \
		+ "\tvec2 c = floor(p);\n" \
		+ "\tvec2 f = fract(p);\n" \
		+ "\tf = f * f * (3.0 - 2.0 * f);\n" \
		+ "\treturn mix(mix(alea_pt(c), alea_pt(c + vec2(1.0, 0.0)), f.x),\n" \
		+ "\t\tmix(alea_pt(c + vec2(0.0, 1.0)), alea_pt(c + vec2(1.0, 1.0)), f.x), f.y);\n" \
		+ "}\n" \
		+ "void vertex() {\n" \
		+ DENSE_VERTEX \
		+ "\tpos_monde = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;\n" \
		+ "}\n" \
		+ "void fragment() {\n" \
		+ "\t// COLOR.rgb = teinte × AO ; COLOR.a = l'AO seule, qui pose le\n" \
		+ "\t// volume et doit survivre au repeint thématique.\n" \
		+ "\tvec3 base = COLOR.rgb;\n" \
		+ "\t// Une recette, pas un asset (règle 52). NORMAL est en espace VUE,\n" \
		+ "\t// ramené au monde ; la hauteur écarte cours et jardins, qui sont\n" \
		+ "\t// dans le même maillage que le bâti.\n" \
		+ "\tvec3 normale_monde = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);\n" \
		+ "\tfloat vers_le_ciel = normale_monde.y;\n" \
		+ "\tfloat rugosite = 0.95;\n" \
		+ "\t// Patine large : reste stable à tous les zooms, avant les équipements.\n" \
		+ "\tfloat patine = bruit(pos_monde.xz * 0.32 + vec2(pos_monde.y * 0.17));\n" \
		+ "\tbase *= mix(0.94, 1.04, patine);\n" \
		+ "\tif (abs(normale_monde.y) < 0.30 && UV.y > 1.05) {\n" \
		+ "\t\tfloat corniche = 1.0 - smoothstep(0.0, 0.20, abs(pos_monde.y - plafond + 0.18));\n" \
		+ "\t\tbase *= 1.0 - corniche * 0.16;\n" \
		+ "\t}\n" \
		+ "\t// 🏢 CE QUI EST NEUF, ET ÇA SE JOUE À LA HAUTEUR. Le mur\n" \
		+ "\t// s'ÉTIRE au lieu de s'allonger, mais toutes les recettes de\n" \
		+ "\t// surface se comptent en Y MONDE : au-dessus de l'ancien égout,\n" \
		+ "\t// ce qu'on voit est ce que la densification a posé.\n" \
		+ "\tbool neuf = montee > 0.05 && plafond > 0.5 && pos_monde.y > plafond;\n" \
		+ "\t// 🧱 Les rangs AVANT les panneaux : un toit équipé est couvert.\n" \
		+ "\t// La borne 0,995 écarte tout ce qui est PLAT — sol, chaussée,\n" \
		+ "\t// cours, et les toits-terrasses de 1974, qui ne sont pas en tuile.\n" \
		+ "\tif (!neuf && vers_le_ciel > 0.5 && vers_le_ciel < 0.995 && pos_monde.y > 1.0) {\n" \
		+ "\t\t// L'écart se mesure LE LONG DE LA PENTE : sinon un toit à 14°\n" \
		+ "\t\t// sort avec des rangs de 1,4 m pour la même tuile.\n" \
		+ "\t\tfloat sin_pente = sqrt(max(1.0 - vers_le_ciel * vers_le_ciel, 0.02));\n" \
		+ "\t\tfloat rang = pos_monde.y / (RANG_M * sin_pente);\n" \
		+ "\t\tfloat ar = max(fwidth(rang), 0.0005);\n" \
		+ "\t\tfloat dr = abs(fract(rang + 0.5) - 0.5);\n" \
		+ "\t\tfloat joint = smoothstep(JOINT - ar, JOINT + ar, dr);\n" \
		+ "\t\t// `visible` rend la main à l'aplat sous ~1,5 px : à la vue par\n" \
		+ "\t\t// défaut les rangs sont plus fins qu'un pixel et scintillent.\n" \
		+ "\t\tfloat visible = clamp(1.3 - 4.0 * ar, 0.0, 1.0);\n" \
		+ "\t\tbase *= mix(1.0, mix(0.80, 1.0, joint), visible);\n" \
		+ "\t}\n" \
		+ "\t// 🏢 LE TOIT REFAIT. Une surélévation emporte la toiture :\n" \
		+ "\t// zinc à joint debout, jamais la tuile de dessous. Les joints\n" \
		+ "\t// suivent la pente — UV porte l'axe du bâtiment, donc les\n" \
		+ "\t// espacer le long de cet axe les couche dans le bon sens.\n" \
		+ "\tif (neuf && vers_le_ciel > 0.5 && pos_monde.y > 1.0) {\n" \
		+ "\t\tbase = ZINC * COLOR.a;\n" \
		+ "\t\trugosite = 0.55;\n" \
		+ "\t\tif (length(UV) > 0.5) {\n" \
		+ "\t\t\tfloat j = dot(pos_monde.xz, normalize(UV)) / JOINT_ZINC_M;\n" \
		+ "\t\t\tfloat aj = max(fwidth(j), 0.0005);\n" \
		+ "\t\t\tfloat dj = abs(fract(j + 0.5) - 0.5);\n" \
		+ "\t\t\t// Le joint est un pli DEBOUT : il accroche la lumière.\n" \
		+ "\t\t\tfloat vj = clamp(1.3 - 4.0 * aj, 0.0, 1.0);\n" \
		+ "\t\t\tbase *= mix(1.0, mix(1.45, 1.0,\n" \
		+ "\t\t\t\tsmoothstep(0.05 - aj, 0.05 + aj, dj)), vj);\n" \
		+ "\t\t}\n" \
		+ "\t}\n" \
		+ "\tif ((equipe > 0.0 || verdi > 0.0) && vers_le_ciel > 0.55 && pos_monde.y > 1.0 && length(UV) > 0.5) {\n" \
		+ "\t\t// 🔄 RETOUR EN ARRIÈRE SIGNALÉ (§3 ter) : le panneau était un\n" \
		+ "\t\t// ASSOMBRISSEMENT du toit, indiscernable d'une ombre. Bleu franc\n" \
		+ "\t\t// + liseré blanc depuis le 2026-08-17 — un MOTIF, donc une grille.\n" \
		+ "\t\t// UV porte l'axe propre du bâtiment ; l'autre axe est reconstruit\n" \
		+ "\t\t// dans le plan du versant, donc la grille remonte la pente.\n" \
		+ "\t\tvec3 axe = normalize(vec3(UV.x, 0.0, UV.y));\n" \
		+ "\t\tvec3 pente_axe = normalize(cross(axe, normale_monde));\n" \
		+ "\t\tvec2 g = vec2(dot(pos_monde, axe), dot(pos_monde, pente_axe)) / PANNEAU_M;\n" \
		+ "\t\t// aa = largeur d'une case en pixels⁻¹ ; à la vue par défaut une\n" \
		+ "\t\t// case fait ~3 px et scintille. ⚠ fwidth sur `g`, PAS sur son\n" \
		+ "\t\t// fract(), dont la dérivée explose au bord de chaque case.\n" \
		+ "\t\tfloat aa = max(max(fwidth(g.x), fwidth(g.y)), 0.0005);\n" \
		+ "\t\tvec2 f = abs(fract(g) - 0.5);\n" \
		+ "\t\tfloat d = max(f.x, f.y);\n" \
		+ "\t\tfloat bord = smoothstep(0.5 - LISERE - aa, 0.5 - LISERE + aa, d);\n" \
		+ "\t\t// Pose DISCRÈTE : à 30 %, trente panneaux francs, pas un toit\n" \
		+ "\t\t// lavé de bleu à 30 %.\n" \
		+ "\t\tfloat h = fract(sin(dot(floor(g), vec2(12.9898, 78.233))) * 43758.545);\n" \
		+ "\t\t// De loin le tirage devient du bruit : `net` rend la main au\n" \
		+ "\t\t// fondu continu sous ~7 px de case.\n" \
		+ "\t\tfloat net = clamp(1.15 - 5.0 * aa, 0.0, 1.0);\n" \
		+ "\t\t// 🌿 LE PARTAGE DU TOIT, ET IL SE JOUE ICI. `equipe` et `verdi`\n" \
		+ "\t\t// sont des parts du toit ENTIER de l'îlot ; ce pan-ci n'en est\n" \
		+ "\t\t// qu'un morceau. Le substrat ne tient que sur le plat, donc les\n" \
		+ "\t\t// panneaux prennent les VERSANTS D'ABORD et ne redescendent sur\n" \
		+ "\t\t// le plat qu'une fois les versants pleins. `part_plate` vient de\n" \
		+ "\t\t// 07, mesurée volume par volume — la somme retombe juste.\n" \
		+ "\t\tfloat p = clamp(part_plate, 0.0, 1.0);\n" \
		+ "\t\tfloat pan = 0.0;\n" \
		+ "\t\tfloat pan_vert = 0.0;\n" \
		+ "\t\tif (vers_le_ciel < 0.995) {\n" \
		+ "\t\t\t// PAN PAR PAN : le versant le mieux exposé au sud se remplit\n" \
		+ "\t\t\t// en premier (l'est départage un faîtage nord-sud).\n" \
		+ "\t\t\tfloat sur_pente = clamp(equipe / max(1.0 - p, 0.001), 0.0, 1.0);\n" \
		+ "\t\t\tbool premier = normale_monde.z > 0.01 || (abs(normale_monde.z) <= 0.01 && normale_monde.x > 0.0);\n" \
		+ "\t\t\tpan = clamp(sur_pente * 2.0 - (premier ? 0.0 : 1.0), 0.0, 1.0);\n" \
		+ "\t\t} else {\n" \
		+ "\t\t\t// 🌿 UN TOIT EST SOLAIRE OU VERT, JAMAIS LES DEUX, et le grain\n" \
		+ "\t\t\t// de cette règle est le BÂTIMENT. UV2.y porte la place de CE\n" \
		+ "\t\t\t// toit-ci dans l'aire plate de l'îlot, posée par 07 : il\n" \
		+ "\t\t\t// verdit en entier dès qu'elle passe sous le curseur.\n" \
		+ "\t\t\tfloat plat = max(p, 0.001);\n" \
		+ "\t\t\tfloat part_v = clamp(verdi / plat, 0.0, 1.0);\n" \
		+ "\t\t\tpan_vert = (part_v > 0.0 && UV2.y < part_v) ? 1.0 : 0.0;\n" \
		+ "\t\t\t// Les panneaux se reportent sur les toits restés nus, à la\n" \
		+ "\t\t\t// densité qu'il faut pour que leur aire retombe sur `equipe`.\n" \
		+ "\t\t\tfloat sur_plat = clamp((equipe - (1.0 - p)) / plat, 0.0, 1.0);\n" \
		+ "\t\t\tpan = (1.0 - pan_vert)\n" \
		+ "\t\t\t\t* clamp(sur_plat / max(1.0 - part_v, 0.001), 0.0, 1.0);\n" \
		+ "\t\t}\n" \
		+ "\t\t// 🔄 RETOUR EN ARRIÈRE SIGNALÉ (2026-08-31) : le sédum se posait\n" \
		+ "\t\t// par NAPPES de 3 cases, donc un même toit sortait moitié bleu,\n" \
		+ "\t\t// moitié vert. Le partage est monté d'un cran — au BÂTIMENT :\n" \
		+ "\t\t// un toit verdi l'est de bout en bout, et le semis de panneaux\n" \
		+ "\t\t// ne tombe que sur les autres. Sans vert, rien ne change du\n" \
		+ "\t\t// semis de 2026-08-17.\n" \
		+ "\t\tfloat posee = mix(pan, step(h, pan), net) * (1.0 - pan_vert);\n" \
		+ "\t\tfloat posee_v = pan_vert;\n" \
		+ "\t\t// Sans liseré : deux cases voisines doivent se souder. La\n" \
		+ "\t\t// variation est un tirage de la case, pas de la nappe.\n" \
		+ "\t\tfloat hv = fract(sin(dot(floor(g), vec2(11.917, 57.301))) * 15731.113);\n" \
		+ "\t\tvec3 c_pan = mix(BLEU, BLANC, bord) * COLOR.a;\n" \
		+ "\t\tvec3 c_vert = mix(SEDUM, SEDUM_SEC, hv) * COLOR.a;\n" \
		+ "\t\t// COLOR.a garde le volume sous les deux motifs. Somme et non\n" \
		+ "\t\t// deux `mix` enchaînés : au loin le second rendrait du carton\n" \
		+ "\t\t// visible sous un toit pourtant couvert de bout en bout.\n" \
		+ "\t\tbase = base * max(1.0 - posee - posee_v, 0.0)\n" \
		+ "\t\t\t+ c_pan * posee + c_vert * posee_v;\n" \
		+ "\t\trugosite = mix(0.95, 0.35, posee);\n" \
		+ "\t}\n" \
		+ "\t// 🏢 LE MUR AJOUTÉ — bardage de lames verticales. La\n" \
		+ "\t// tangente sort de la NORMALE et non d'UV : un mur mitoyen\n" \
		+ "\t// aveugle n'a aucune coordonnée de façade, et il se barde\n" \
		+ "\t// comme les autres.\n" \
		+ "\tif (neuf && abs(normale_monde.y) < 0.30) {\n" \
		+ "\t\tvec2 tang = normalize(vec2(-normale_monde.z, normale_monde.x));\n" \
		+ "\t\tfloat lame = dot(pos_monde.xz, tang) / LAME_M;\n" \
		+ "\t\tfloat hl = fract(sin(floor(lame) * 91.317) * 43758.545);\n" \
		+ "\t\tbase = mix(BARDAGE, BARDAGE_SEC, hl) * COLOR.a;\n" \
		+ "\t\tfloat al = max(fwidth(lame), 0.0005);\n" \
		+ "\t\tfloat dl = abs(fract(lame + 0.5) - 0.5);\n" \
		+ "\t\tfloat vl = clamp(1.3 - 4.0 * al, 0.0, 1.0);\n" \
		+ "\t\tbase *= mix(1.0, mix(0.70, 1.0,\n" \
		+ "\t\t\tsmoothstep(0.07 - al, 0.07 + al, dl)), vl);\n" \
		+ "\t\t// LA COUTURE, à l'ancien égout : sans elle le bardage se lit\n" \
		+ "\t\t// comme un bâtiment repeint, pas comme un étage posé dessus.\n" \
		+ "\t\tbase *= mix(1.0, 0.45,\n" \
		+ "\t\t\tsmoothstep(0.11, 0.02, abs(pos_monde.y - plafond)));\n" \
		+ "\t}\n" \
		+ "\t// 🪟 LES FENÊTRES — une recette de surface, pas un triangle de\n" \
		+ "\t// plus. Tout ce qui arrive ici :\n" \
		+ "\t//   UV  = (u, L)         mètres le long de la façade, longueur\n" \
		+ "\t//   UV2 = (genre, alea)  recette de percement, tirage du bâtiment\n" \
		+ "\t// 🔴 LE SHADER NE DÉCIDE RIEN : rue, mitoyen, front commerçant,\n" \
		+ "\t// c'est `_facades` dans 07 qui le sait, carte sous les yeux.\n" \
		+ "\t// Ceinture : un toit porte un vecteur UNITAIRE dans UV, jamais 1,05.\n" \
		+ "\tif (UV2.x > 0.5 && abs(normale_monde.y) < 0.30 && UV.y > 1.05) {\n" \
		+ "\t\tfloat u = UV.x;\n" \
		+ "\t\tfloat L = UV.y;\n" \
		+ "\t\tfloat h = pos_monde.y;\n" \
		+ "\t\tint genre = int(UV2.x + 0.5);\n" \
		+ "\t\tfloat alea = UV2.y;\n" \
		+ "\t\t// aa = un pixel, EN MÈTRES DE FAÇADE : c'est ce qui rend le\n" \
		+ "\t\t// fondu indépendant du zoom.\n" \
		+ "\t\tfloat aa = max(fwidth(u), 0.0005);\n" \
		+ "\t\t// 07 pose y_haut = niveaux × ETAGE_M, un multiple EXACT : aucune\n" \
		+ "\t\t// fenêtre coupée par l'égout, et pas besoin de la hauteur ici.\n" \
		+ "\t\tfloat etage = floor(max(h, 0.0) / ETAGE);\n" \
		+ "\t\tfloat hy = h - etage * ETAGE;\n" \
		+ "\t\t// TRAVÉES CENTRÉES sur la façade — d'où le `L` envoyé par 07.\n" \
		+ "\t\t// Une trame de pas fixe laisserait une demi-fenêtre dans l'angle\n" \
		+ "\t\t// de tout mur dont la longueur n'est pas un multiple, donc de tous.\n" \
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
		+ "\t\t\t// LA BANDE FILANTE — barre de 1974 et halles. Les 90 cm de\n" \
		+ "\t\t\t// mur plein aux bouts la distinguent d'un ruban sur poteaux.\n" \
		+ "\t\t\t// \u26a0 Mesuré le 2026-08-18 : à 1,75 m d'entraxe la barre\n" \
		+ "\t\t\t// sortait en carte perforée. La bande veut une ouverture\n" \
		+ "\t\t\t// deux fois plus large que haute.\n" \
		+ "\t\t\tdemi = 0.5 * (pas - 0.30);\n" \
		+ "\t\t\tbas = 1.00;\n" \
		+ "\t\t\thaut = 2.20;\n" \
		+ "\t\t} else if (etage < 0.5 && genre == 3) {\n" \
		+ "\t\t\t// LA VITRINE : un rez vitré entre deux trumeaux — de quoi\n" \
		+ "\t\t\t// lire une rue commerçante sans colorier le tissu.\n" \
		+ "\t\t\tdemi = 0.5 * (pas - 0.80);\n" \
		+ "\t\t\tbas = 0.45;\n" \
		+ "\t\t\thaut = 2.45;\n" \
		+ "\t\t} else if (etage < 0.5 && genre == 2 && travee == floor(alea * n)) {\n" \
		+ "\t\t\t// Une porte par bâtiment : 07 ne marque le genre 2 que sur\n" \
		+ "\t\t\t// sa plus longue façade sur rue.\n" \
		+ "\t\t\tdemi = 0.5 * min(1.10, pas * 0.42);\n" \
		+ "\t\t\tbas = 0.02;\n" \
		+ "\t\t\thaut = 2.15;\n" \
		+ "\t\t}\n" \
		+ "\t\t// 🏢 L'ÉTAGE AJOUTÉ PERCE PLUS GRAND : même trame que\n" \
		+ "\t\t// dessous — sinon l'immeuble se disloque —, mais une\n" \
		+ "\t\t// ouverture d'aujourd'hui. C'est ce qui reste lisible de\n" \
		+ "\t\t// loin, quand la lame de bardage a fondu en teinte.\n" \
		+ "\t\t// \U0001f3e2 DEUX ÉTAGES AJOUTÉS = DEUX RANGÉES, JAMAIS UNE\n" \
		+ "\t\t// TROISIÈME TRANCHÉE PAR LE TOIT (auteur, 2026-09-03). Les\n" \
		+ "\t\t// étages ajoutés ont leur PROPRE trame, accrochée à l'ancien\n" \
		+ "\t\t// égout : celle du monde est décalée de \u00b11 m par la\n" \
		+ "\t\t// hauteur des deux rives, et couperait une rangée en deux.\n" \
		+ "\t\tfloat tient = 1.0;\n" \
		+ "\t\tif (neuf) {\n" \
		+ "\t\t\tdemi = 0.5 * min(1.90, pas * 0.66);\n" \
		+ "\t\t\tbas = 0.50;\n" \
		+ "\t\t\thaut = 2.48;\n" \
		+ "\t\t\tfloat hn = h - plafond;\n" \
		+ "\t\t\tfloat k = floor(hn / ETAGE);\n" \
		+ "\t\t\thy = hn - k * ETAGE;\n" \
		+ "\t\t\t// Une rangée n'apparaît qu'une fois son étage LIVRÉ.\n" \
		+ "\t\t\ttient = (k * ETAGE + haut > montee) ? 0.0 : 1.0;\n" \
		+ "\t\t} else if (montee > 0.05 && plafond > 0.5\n" \
		+ "\t\t\t\t&& etage * ETAGE + haut > plafond) {\n" \
		+ "\t\t\t// La dernière rangée d'origine traverserait la couture :\n" \
		+ "\t\t\t// elle laisse un bandeau plein sous l'étage ajouté.\n" \
		+ "\t\t\ttient = 0.0;\n" \
		+ "\t\t}\n" \
		+ "\t\tfloat bord = min(u, L - u);\n" \
		+ "\t\tfloat dedans = smoothstep(demi + aa, demi - aa, du)\n" \
		+ "\t\t\t* smoothstep(bas - aa, bas + aa, hy)\n" \
		+ "\t\t\t* smoothstep(haut + aa, haut - aa, hy)\n" \
		+ "\t\t\t* smoothstep(marge - aa, marge + aa, bord);\n" \
		+ "\t\t// L'EMBRASURE : sans épaisseur, une fenêtre est un autocollant.\n" \
		+ "\t\t// Ombre au tableau, liseré au dormant, appui débordant de 13 cm.\n" \
		+ "\t\tfloat ombre = smoothstep(haut - 0.22, haut - 0.03, hy);\n" \
		+ "\t\tfloat cerne = smoothstep(demi + 0.08 + aa, demi + 0.08 - aa, du)\n" \
		+ "\t\t\t* smoothstep(bas - 0.13 - aa, bas - 0.13 + aa, hy)\n" \
		+ "\t\t\t* smoothstep(haut + 0.08 + aa, haut + 0.08 - aa, hy)\n" \
		+ "\t\t\t* smoothstep(marge - 0.10 - aa, marge - 0.10 + aa, bord);\n" \
		+ "\t\t// Le meneau, sur les ouvertures assez larges pour en avoir un.\n" \
		+ "\t\tfloat meneau = (demi > 0.45) ? smoothstep(0.030, 0.055, du) : 1.0;\n" \
		+ "\t\tfloat ouverture = clamp(dedans * meneau, 0.0, 1.0) * tient;\n" \
		+ "\t\tfloat dormant = clamp(cerne * tient - ouverture, 0.0, 1.0);\n" \
		+ "\t\t// 🔴 LOIN, ON N'ÉCRIT PLUS — ON ASSOMBRIT. Une fenêtre tient sur\n" \
		+ "\t\t// deux pixels à la vue par défaut : on rend la main à la PART\n" \
		+ "\t\t// VITRÉE du mur, un enduit plus sombre, sans scintillement.\n" \
		+ "\t\tfloat net = clamp(1.15 - 1.8 * aa, 0.0, 1.0);\n" \
		+ "\t\tfloat part = clamp(2.0 * demi * (haut - bas)\n" \
		+ "\t\t\t/ max(pas * ETAGE, 0.1), 0.0, 1.0);\n" \
		+ "\t\tfloat vitre = mix(part * tient, ouverture, net);\n" \
		+ "\t\t// COLOR.a garde le volume sous le percement.\n" \
		+ "\t\tbase = mix(base, min(base * 1.28 + 0.012, vec3(1.0)), dormant * net);\n" \
		+ "\t\tfloat interieur = alea_pt(vec2(floor(u / pas), etage) + vec2(alea * 53.0));\n" \
		+ "\t\tvec3 reflet = mix(VITRE, vec3(0.12, 0.18, 0.20), 0.25 + 0.45 * (hy / ETAGE));\n" \
		+ "\t\treflet = mix(reflet, vec3(0.32, 0.25, 0.16), step(0.86, interieur) * 0.55);\n" \
		+ "\t\tbase = mix(base, reflet * mix(1.0, 0.60, ombre) * COLOR.a, vitre);\n" \
		+ "\t\trugosite = mix(rugosite, 0.18, vitre * net);\n" \
		+ "\t}\n" \
		+ "\t// 🌊 L'ÉTAT D'UNE BERGE, DANS LA VILLE VIVANTE. `calque` ne\n" \
		+ "\t// peint que la maquette blanche ; une rive rendue au fleuve doit se\n" \
		+ "\t// voir SANS ouvrir le diagnostic, sinon la décision n'a pas d'effet.\n" \
		+ "\tif (etat_berge > 0.5) {\n" \
		+ "\t\t// 🔴 UNE VARIATION DE VALEUR, PAS UNE DEUXIÈME TEINTE (DA l.67) :\n" \
		+ "\t\t// deux octaves de 2,2 m et 0,5 m, l'herbe rase et l'herbe grasse.\n" \
		+ "\t\tfloat grain = 0.64 * bruit(pos_monde.xz * 0.45)\n" \
		+ "\t\t\t+ 0.36 * bruit(pos_monde.xz * 2.10);\n" \
		+ "\t\tvec3 rive = (etat_berge > 1.5 ? RIVE_VERTE : RIVE_SABLE)\n" \
		+ "\t\t\t* mix(0.62, 1.48, grain);\n" \
		+ "\t\t// 🔴 LE MUR NE SE REPEINT PAS, IL VERDIT. À plat (la bande) la\n" \
		+ "\t\t// rive prend tout ; sur la paroi du quai, la pierre reste\n" \
		+ "\t\t// dessous — sinon renaturer badigeonne un mur de vert.\n" \
		+ "\t\tfloat couche = mix(0.34, etat_berge > 1.5 ? 0.92 : 0.70,\n" \
		+ "\t\t\tclamp(vers_le_ciel, 0.0, 1.0));\n" \
		+ "\t\tbase = mix(base, rive * COLOR.a, couche);\n" \
		+ "\t\trugosite = 1.0;\n" \
		+ "\t}\n" \
		+ "\t// 🩶 LA MAQUETTE BLANCHE — la vue diagnostic. La ville perd sa\n" \
		+ "\t// matière et ne garde que son VOLUME (COLOR.a = l'AO bakée) :\n" \
		+ "\t// seul le thème est en couleur, donc tout thème est lisible.\n" \
		+ "\t// Les quatre signaux s'excluent — un thème remplit un seul.\n" \
		+ "\tif (maquette_blanche > 0.5) {\n" \
		+ "\t\tbase = PAPIER * COLOR.a;\n" \
		+ "\t\trugosite = 1.0;\n" \
		+ "\t\t// Le calque continu : énergie, trafic, tissu. Opacité pleine,\n" \
		+ "\t\t// il n'y a plus de matière sous lui à ménager.\n" \
		+ "\t\tif (calque.a > 0.0) {\n" \
		+ "\t\t\tbase = mix(base, calque.rgb * COLOR.a, calque.a);\n" \
		+ "\t\t}\n" \
		+ "\t\t// Dangers : le sol raconte le passage de l'eau, le volume les\n" \
		+ "\t\t// bâtiments touchés, les routes coupées ont leur rouge.\n" \
		+ "\t\tif (diagnostic_sol > 0.5) {\n" \
		+ "\t\t\tvec3 signal_sol = diagnostic_sol > 1.5 ? vec3(0.72, 0.035, 0.025) : vec3(0.020, 0.310, 0.550);\n" \
		+ "\t\t\tbase = mix(base, signal_sol * COLOR.a, 0.88);\n" \
		+ "\t\t}\n" \
		+ "\t\tif (diagnostic_bati > 0.5 && pos_monde.y > 0.35) {\n" \
		+ "\t\t\tbase = mix(base, vec3(0.81, 0.210, 0.030) * COLOR.a, 0.92);\n" \
		+ "\t\t}\n" \
		+ "\t\t// Chantiers : l'objet ENTIER prend la couleur de son état, sol\n" \
		+ "\t\t// et volume ensemble — c'est l'avancement qu'on lit, pas l'eau.\n" \
		+ "\t\t// ⚠ Les trois teintes sont aussi dans `interface.gd`, en sRGB.\n" \
		+ "\t\tif (chantier_etat > 0.5) {\n" \
		+ "\t\t\tvec3 signal = chantier_etat > 2.5 ? vec3(0.105, 0.423, 0.178)\n" \
		+ "\t\t\t\t: (chantier_etat > 1.5 ? vec3(0.807, 0.402, 0.030)\n" \
		+ "\t\t\t\t: vec3(0.716, 0.042, 0.030));\n" \
		+ "\t\t\tbase = mix(base, signal * COLOR.a, 0.88);\n" \
		+ "\t\t}\n" \
		+ "\t}\n" \
		+ "\tALBEDO = base * teinte.rgb;\n" \
		+ "\tROUGHNESS = rugosite;\n" \
		+ "\tMETALLIC = 0.0;\n" \
		+ "}\n"
	var m := ShaderMaterial.new()
	m.shader = sh
	return m


static func terrain() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/terrain.gdshader")
	return m


static func eau(teinte: Color) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/eau.gdshader")
	m.set_shader_parameter("teinte", teinte)
	return m


static func feuillage() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/feuillage.gdshader")
	return m


## Le tronc, en seconde surface pour que sa teinte soit FIXE : sinon un tronc
## sous un feuillage vert ressortirait vert.
static func bois(teinte: Color) -> StandardMaterial3D:
	var m := surface(0.95)
	m.vertex_color_use_as_albedo = false
	m.albedo_color = teinte
	return m


## 🔲 LE MASQUE DE SÉLECTION : l'objet choisi, redessiné seul en blanc plat
## dans une vue à part, d'où le contour est tiré. Non éclairé (on ne lit que la
## couverture) et faces non éliminées (un dos manquant troue le trait).
static func masque() -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = "shader_type spatial;\n" \
		+ "render_mode unshaded, cull_disabled;\n" \
		+ DENSE_DECL \
		+ "void vertex() {\n" \
		+ DENSE_VERTEX \
		+ "}\n" \
		+ "void fragment() {\n" \
		+ "\tALBEDO = vec3(1.0);\n" \
		+ "}\n"
	var m := ShaderMaterial.new()
	m.shader = sh
	return m


## ✏️ LE TRAIT AUTOUR DE L'OBJET CHOISI, dessiné À L'ÉCRAN (2026-08-18).
##
## 🔄 RETOUR EN ARRIÈRE SIGNALÉ, le même jour : c'était un ruban posé au sol,
## qui n'entourait que l'emprise — les bâtiments dépassaient, et dans le cœur
## ancien ils le cachaient. Il faut la silhouette, donc la vue.
##
## 🔄 REPRIS EN TROIS COUCHES (2026-09-02, « la sélection est moche ») : le
## trait était un aplat d'une seule épaisseur, qui se perdait sur un toit clair
## et se lisait comme un défaut d'affichage sur une berge d'un pixel de large.
## Ce qui le pose maintenant, c'est ce qu'il y a AUTOUR de lui :
##   ① un halo sombre dehors, qui le décolle de n'importe quel fond ;
##   ② le trait clair, net, à `rayon` pixels du bord ;
##   ③ une lueur DEDANS, qui dit quelle surface est choisie — indispensable
##      pour un objet linéaire, dont les deux traits se touchent presque.
##
## Le shader ne mesure plus « y a-t-il du masque par ici » mais la DISTANCE au
## bord, en pixels : c'est elle qui permet trois épaisseurs pour un seul
## sondage. Tout est en pixels, donc constant au zoom.
##
## 16 directions × 6 distances : une berge faisant deux pixels de large, un
## sondage plus grossier la manquerait et troue le trait.
static func contour(masque_tex: Texture2D, couleur: Color,
		ombre: Color) -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = "shader_type canvas_item;\n" \
		+ "render_mode unshaded;\n" \
		+ "uniform sampler2D masque : filter_linear, repeat_disable;\n" \
		+ "uniform vec2 pas = vec2(0.001);\n" \
		+ "uniform float rayon = 3.0;\n" \
		+ "uniform vec4 couleur : source_color = vec4(1.0);\n" \
		+ "uniform vec4 ombre : source_color = vec4(0.0, 0.0, 0.0, 0.5);\n" \
		+ "const int DIRS = 16;\n" \
		+ "const int PALIERS = 6;\n" \
		+ "// Jusqu'où le halo et la lueur portent, en multiples du trait.\n" \
		+ "const float PORTEE = 2.6;\n" \
		+ "void fragment() {\n" \
		+ "  float dedans = step(0.5, texture(masque, UV).a);\n" \
		+ "  float portee = rayon * PORTEE;\n" \
		+ "  // La distance au bord : le premier sondage qui change de côté.\n" \
		+ "  float d = portee;\n" \
		+ "  for (int k = 0; k < DIRS; k++) {\n" \
		+ "    float a = float(k) * 6.2831853 / float(DIRS);\n" \
		+ "    vec2 u = vec2(cos(a), sin(a)) * pas;\n" \
		+ "    for (int j = 1; j <= PALIERS; j++) {\n" \
		+ "      float t = portee * float(j) / float(PALIERS);\n" \
		+ "      if (step(0.5, texture(masque, UV + u * t).a) != dedans) {\n" \
		+ "        d = min(d, t);\n" \
		+ "        break;\n" \
		+ "      }\n" \
		+ "    }\n" \
		+ "  }\n" \
		+ "  vec3 rgb;\n" \
		+ "  float a;\n" \
		+ "  if (dedans > 0.5) {\n" \
		+ "    // ③ la lueur intérieure : elle s'éteint vers le cœur de l'objet,\n" \
		+ "    // sinon un îlot entier changerait de couleur au clic.\n" \
		+ "    rgb = couleur.rgb;\n" \
		+ "    a = (1.0 - smoothstep(0.0, rayon * 1.8, d)) * couleur.a * 0.15;\n" \
		+ "  } else {\n" \
		+ "    float trait = 1.0 - smoothstep(rayon - 0.9, rayon + 0.9, d);\n" \
		+ "    // ① le halo décroît de la fin du trait jusqu'à la portée.\n" \
		+ "    float halo = (1.0 - smoothstep(rayon, portee, d)) * ombre.a;\n" \
		+ "    rgb = mix(ombre.rgb, couleur.rgb, trait);\n" \
		+ "    a = max(halo, trait * couleur.a);\n" \
		+ "  }\n" \
		+ "  COLOR = vec4(rgb, clamp(a, 0.0, 1.0));\n" \
		+ "}\n"
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("masque", masque_tex)
	m.set_shader_parameter("couleur", couleur)
	m.set_shader_parameter("ombre", ombre)
	return m


## ☀ LE SOLEIL DE LA VILLE, et celui de la miniature de la fiche : deux images
## éclairées autrement ne se compareraient pas.
##
## Assez haut pour qu'aucune ombre ne noie un îlot, assez bas pour que les
## volumes se détachent.
## 🔴 `portee_ombre` n'est pas un réglage de goût : la carte d'ombre couvre
## cette distance, et l'étaler sur 3 km pour un objet de 100 m fait s'ombrer
## l'objet lui-même — murs noirs dans la miniature.
static func soleil(teinte: Color, portee_ombre := 3000.0) -> DirectionalLight3D:
	var l := DirectionalLight3D.new()
	l.name = "Soleil"
	l.rotation_degrees = Vector3(-48.0, -125.0, 0.0)
	l.light_color = teinte
	# Ombres douces : leur pénombre se règle en angle, pas en floutant l'image.
	l.light_energy = 1.25
	l.light_angular_distance = 1.6
	l.shadow_enabled = true
	l.directional_shadow_max_distance = portee_ombre
	return l


## Lumière fixe et calme (Direction artistique l.69). Ce qui creuse les volumes
## est l'occlusion, bakée en couleur de sommet par 07 et complétée ici par SSAO.
static func environnement(ciel: Color, ambiant: Color) -> Environment:
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = ciel
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = ambiant
	# Retour à un ciel plus présent ; sa teinte froide est dans palette.py.
	e.ambient_light_energy = 0.85

	e.ssao_enabled = true
	e.ssao_radius = 1.4
	e.ssao_intensity = 1.15
	e.ssao_power = 1.2
	e.ssao_detail = 0.5

	# ⚠ Le SSAO travaille en espace vue : son rayon se comporte autrement en
	# ortho. S'il casse, l'AO bakée par 07 tient debout seule — d'où l'ordre.
	return e
