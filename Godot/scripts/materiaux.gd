extends RefCounted
# Matières procédurales, sans texture importée (Direction artistique l.19).
# La couleur voyage dans ARRAY_COLOR, donc UN matériau suffit pour les 69 îlots.


# 🏢 LA SURÉLÉVATION, ET DEUX MATÉRIAUX LA PARTAGENT : la ville et le masque de
# sélection. Posée dans un seul des deux, le trait de sélection reste sur
# l'ancien volume — vu à l'écran par l'auteur le 2026-09-03.
# `densification` = (avancement, pas d'un bâtiment, mètres gagnés) : un vec4 et
# non trois flottants, les uniformes d'instance sont comptés.
# CUSTOM0 = (rang du bâtiment, ce sommet suit-il le toit, égout d'origine, pied
# du bâtiment), posé par 07. Un bâtiment monte ENTIER, chacun son tour, du plus
# bas au plus haut — même mécanique que le toit vert, sur les sommets cette
# fois. Le mur s'étire, donc la recette de fenêtres, qui compte les étages
# depuis le pied, en perce de neuves. ⚠ La collision ne monte pas : cliquer vise l'îlot, pas une façade.
const DENSE_DECL := "instance uniform vec4 densification = vec4(0.0, 1.0, 0.0, 0.0);\n" \
	+ "varying float montee;\n" \
	+ "varying float plafond;\n" \
	+ "varying float sol;\n" \
	+ "varying float rebati;\n" \
	+ "varying float ruine;\n"

# 🏗️ REBÂTIR UN ÎLOT (95) : `densification.w` = 1 moderne, 2 pilotis, 3 parc,
# `.z` la hauteur en jeu (l'attique, la levée). 07 marque le bâti neuf d'un
# rang 1e6, qui ne se densifie donc jamais, et la ruine d'un égout à −1.
# Moderne : le toit se rabat à plat un étage au-dessus de l'égout, et cet
# étage se lit comme une `montee` — bardage et grandes baies.
# Pilotis (auteur, 2026-10-02) : le même moderne, rez évidé sur poteaux ; son
# attique rend l'étage pris par le vide, d'où autant de logements qu'avant.
const REBATI_VERTEX := "\truine = CUSTOM0.z < -0.5 ? 1.0 : 0.0;\n" \
	+ "\trebati = CUSTOM0.x > 1.0e5 ? densification.w : 0.0;\n" \
	+ "\tif (rebati > 0.5 && rebati < 2.5) {\n" \
	+ "\t\tmontee = densification.z;\n" \
	+ "\t\tif (CUSTOM0.y > 0.5) {\n" \
	+ "\t\t\tVERTEX.y = CUSTOM0.z + densification.z;\n" \
	+ "\t\t\tif (NORMAL.y > 0.3) NORMAL = vec3(0.0, 1.0, 0.0);\n" \
	+ "\t\t}\n" \
	+ "\t\tif (rebati > 1.5) sol += densification.z;\n" \
	+ "\t}\n"

# `montee`, `plafond` et `sol` sont constants sur tout le bâtiment, donc
# l'interpolation ne les déforme pas — au contraire du déplacement du sommet,
# nul en pied de mur et plein en tête.
const DENSE_VERTEX := "\tmontee = densification.z * clamp(\n" \
	+ "\t\t(densification.x - CUSTOM0.x) / max(densification.y, 0.001),\n" \
	+ "\t\t0.0, 1.0);\n" \
	+ "\tplafond = CUSTOM0.z;\n" \
	+ "\tsol = CUSTOM0.w;\n" \
	+ "\tif (montee > 0.0 && CUSTOM0.y > 0.5) {\n" \
	+ "\t\tVERTEX.y += montee;\n" \
	+ "\t}\n" \
	+ REBATI_VERTEX


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
		+ "#include \"res://shaders/boue.gdshaderinc\"\n" \
		+ "#include \"res://shaders/crue.gdshaderinc\"\n" \
		+ "#include \"res://shaders/champs.gdshaderinc\"\n" \
		+ "instance uniform float parcelle_agricole = 0.0;\n" \
		+ "instance uniform float boue_propre = 0.0;\n" \
		+ "instance uniform vec4 boue_acces = vec4(0.0);\n" \
		+ "instance uniform float boue_largeur = 0.0;\n" \
		+ "instance uniform float boue_hauteur = -1.0;\n" \
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
		+ "// 🏗️ REBÂTI (95), LINÉAIRE. Enduit #E6E2D8, toit-terrasse #A9A9A2,\n" \
		+ "// béton #9C9A93, prairie #6E8B4A / #8FA35C, jonc #56683A, eau #4A6468.\n" \
		+ "// Un poteau tous les ~4 m, 60 cm de section.\n" \
		+ "const vec3 ENDUIT_NEUF = vec3(0.791, 0.761, 0.687);\n" \
		+ "const vec3 TOIT_TERRASSE = vec3(0.397, 0.397, 0.366);\n" \
		+ "const vec3 BETON = vec3(0.332, 0.323, 0.287);\n" \
		+ "const vec3 PRAIRIE = vec3(0.155, 0.258, 0.069);\n" \
		+ "const vec3 PRAIRIE_CLAIRE = vec3(0.275, 0.366, 0.107);\n" \
		+ "const vec3 JONC = vec3(0.093, 0.138, 0.042);\n" \
		+ "const vec3 EAU_NOUE = vec3(0.068, 0.128, 0.138);\n" \
		+ "const float POTEAU_PAS = 4.0;\n" \
		+ "const float POTEAU_DEMI = 0.30;\n" \
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
		+ "// 🎨 LES ACCENTS DE FAÇADE (2026-09-26), LINÉAIRES. Volets et portes :\n" \
		+ "// #5E7A5A #5A6E80 #8A4A3E #6B5440 #B3AEA2. Stores : #B5654A #7A9470\n" \
		+ "// #3E5670 #C99A45, rayés de #D8CFB8. Allèges de 1970 : #C98B4A #5F8F86\n" \
		+ "// #B0603F. Portes de quai : #4F7C78 #9C5044 #C9A640. Verre : #A9C2C8.\n" \
		+ "// Des accents, jamais une teinte de mur : l'enduit reste l'époque (35).\n" \
		+ "const vec3 VOLETS[5] = { vec3(0.111, 0.195, 0.102), vec3(0.102, 0.155, 0.216), vec3(0.254, 0.069, 0.048), vec3(0.147, 0.089, 0.051), vec3(0.451, 0.423, 0.361) };\n" \
		+ "const vec3 STORES[4] = { vec3(0.462, 0.130, 0.069), vec3(0.195, 0.296, 0.162), vec3(0.048, 0.092, 0.162), vec3(0.584, 0.323, 0.061) };\n" \
		+ "const vec3 CREME = vec3(0.687, 0.624, 0.479);\n" \
		+ "const vec3 ALLEGES[3] = { vec3(0.584, 0.258, 0.069), vec3(0.113, 0.275, 0.238), vec3(0.431, 0.117, 0.050) };\n" \
		+ "const vec3 QUAIS[3] = { vec3(0.078, 0.202, 0.188), vec3(0.332, 0.080, 0.058), vec3(0.584, 0.381, 0.051) };\n" \
		+ "const vec3 GARDE_CORPS = vec3(0.397, 0.539, 0.578);\n" \
		+ "// 🪟 LA FENÊTRE — cotes d'un logement ordinaire. Ne se règlent pas\n" \
		+ "// à l'œil : c'est leur justesse qui fait qu'un volume annonce sa\n" \
		+ "// taille sans rien à côté pour comparer.\n" \
		+ ("const float ETAGE = %.4f;\n" % etage_m) \
		+ "const float ALLEGE = 0.95;\n" \
		+ "const float LINTEAU = 2.25;\n" \
		+ "const float FEN_LARGE = 1.15;\n" \
		+ "// ⚠ `export_godot/entrees.py` recopie entraxes, marge 0,32 et travée\n" \
		+ "// de porte pour y mener l'allée : changer l'un, changer l'autre.\n" \
		+ "const float ENTRAXE_MIN = 2.75;\n" \
		+ "const float ENTRAXE_MAX = 3.70;\n" \
		+ "// 🪟 LE RELIEF SANS TRIANGLE (2026-10-08) : tableau de 22 cm, balcon\n" \
		+ "// de 1,20 m, dalle de 25 cm, garde-corps plein de 1 m, ombre sur 90 cm.\n" \
		+ "const float PROF_FEN = 0.22;\n" \
		+ "const float BALCON_P = 1.20;\n" \
		+ "const float OMBRE_BALCON = 0.90;\n" \
		+ "const float BALCON_E = 0.25;\n" \
		+ "const float BALCON_H = 1.00;\n" \
		+ "// ⚠ LINÉAIRE. #3A424B en sRGB : du verre qui reflète un ciel\n" \
		+ "// couvert. Une vitre noire donne à la ville l'air bombardée.\n" \
		+ "const vec3 VITRE = vec3(0.042, 0.055, 0.070);\n" \
		+ "// ⚠ LINÉAIRE. #D2CFC9 en sRGB : le carton d'une maquette\n" \
		+ "// d'architecte. Assez clair pour que les quatre signaux\n" \
		+ "// saturés ressortent, assez gris pour ne pas brûler au soleil.\n" \
		+ "const vec3 PAPIER = vec3(0.624, 0.605, 0.560);\n" \
		+ "// Teintes de rive en espace linéaire.\n" \
		+ "const vec3 RIVE_VERTE = vec3(0.112, 0.230, 0.105);\n" \
		+ "const vec3 RIVE_SABLE = vec3(0.620, 0.548, 0.398);\n" \
		+ "float alea_pt(vec2 p) {\n" \
		+ "\treturn fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.545);\n" \
		+ "}\n" \
		+ "// Le tirage d'une travée à un étage : balcon, porte de quai.\n" \
		+ "float tirage_travee(float travee, float etage, float alea) {\n" \
		+ "\treturn fract(sin(travee * 12.9898 + etage * 78.233 + alea * 37.719) * 43758.545);\n" \
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
		+ "// 🌿 LA NOUE DU PARC INONDABLE — des sinus et non `bruit` : la maquette\n" \
		+ "// refait ce calcul pour ne planter aucun arbre dans l'eau\n" \
		+ "// (`Constructeur.noue`), et un hachage ne se recopie pas au bit.\n" \
		+ "float noue(vec2 p) {\n" \
		+ "\treturn sin(p.x * 0.11 + 1.3) * sin(p.y * 0.13 + 0.7) + 0.6 * sin((p.x - p.y) * 0.07 + 2.1);\n" \
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
		+ "\t// 🪵 Le débris (plafond −2, 07) part avec la boue de son îlot ou de sa rue.\n" \
		+ "\tbool debris = plafond < -1.5;\n" \
		+ "\tif (debris && boue_propre > 0.5) discard;\n" \
		+ "\t// 🏗️ La ruine s'efface sous ce qui la remplace ; sa dalle reste, sombre\n" \
		+ "\t// sous les pilotis (claire, le vide ne s'y lisait pas), prairie dans le parc.\n" \
		+ "\t// Ses crêtes regardent aussi le ciel : seule la dalle, au ras du sol, reste.\n" \
		+ "\tbool parc = densification.w > 2.5;\n" \
		+ "\tbool moderne = rebati > 0.5 && rebati < 2.5;\n" \
		+ "\tif (ruine > 0.5 && densification.w > 0.5) {\n" \
		+ "\t\tif (vers_le_ciel < 0.9 || pos_monde.y > sol + 0.2) discard;\n" \
		+ "\t\tbase = BETON * 0.30 * COLOR.a;\n" \
		+ "\t}\n" \
		+ "\t// 🏗️ SOUS LE PLANCHER LEVÉ, des poteaux et du vide, et le nez de\n" \
		+ "\t// dalle sur 30 cm.\n" \
		+ "\tif (rebati > 1.5 && rebati < 2.5 && pos_monde.y < sol && abs(normale_monde.y) < 0.30) {\n" \
		+ "\t\tfloat d;\n" \
		+ "\t\tif (UV.y > 1.05) {\n" \
		+ "\t\t\tfloat pas_p = UV.y / max(1.0, floor(UV.y / POTEAU_PAS + 0.5));\n" \
		+ "\t\t\td = abs(UV.x - floor(UV.x / pas_p + 0.5) * pas_p);\n" \
		+ "\t\t} else {\n" \
		+ "\t\t\tvec2 tang_p = normalize(vec2(-normale_monde.z, normale_monde.x));\n" \
		+ "\t\t\td = abs(fract(dot(pos_monde.xz, tang_p) / POTEAU_PAS + 0.5) - 0.5) * POTEAU_PAS;\n" \
		+ "\t\t}\n" \
		+ "\t\tif (d > POTEAU_DEMI && pos_monde.y < sol - 0.30) discard;\n" \
		+ "\t\tbase = BETON * (pos_monde.y < sol - 0.30 ? 1.0 : 1.25) * COLOR.a;\n" \
		+ "\t}\n" \
		+ "\t// Patine large : reste stable à tous les zooms, avant les équipements.\n" \
		+ "\tfloat patine = bruit(pos_monde.xz * 0.32 + vec2(pos_monde.y * 0.17));\n" \
		+ "\tbase *= mix(0.94, 1.04, patine);\n" \
		+ "\t// `plafond` n'est connu que des bâtiments densifiables : ailleurs il\n" \
		+ "\t// vaut 0, et la corniche barrait la rive droite à 0,8 m du sol.\n" \
		+ "\tif (abs(normale_monde.y) < 0.30 && UV.y > 1.05 && plafond > 0.5) {\n" \
		+ "\t\tfloat corniche = 1.0 - smoothstep(0.0, 0.20, abs(pos_monde.y - plafond + 0.18));\n" \
		+ "\t\tbase *= 1.0 - corniche * 0.16;\n" \
		+ "\t}\n" \
		+ "\t// 🏢 CE QUI EST NEUF, ET ÇA SE JOUE À LA HAUTEUR. Le mur\n" \
		+ "\t// s'ÉTIRE au lieu de s'allonger, mais toutes les recettes de\n" \
		+ "\t// surface se comptent en Y MONDE : au-dessus de l'ancien égout,\n" \
		+ "\t// ce qu'on voit est ce que la densification a posé.\n" \
		+ "\tbool neuf = montee > 0.05 && plafond > 0.5 && pos_monde.y > plafond;\n" \
		+ "\t// 🏗️ Moderne : un enduit clair d'aujourd'hui, l'époque n'y est plus.\n" \
		+ "\tif (moderne && !neuf && pos_monde.y >= sol && abs(normale_monde.y) < 0.30) base = ENDUIT_NEUF * COLOR.a * mix(0.96, 1.03, patine);\n" \
		+ "\t// 🧱 Les rangs AVANT les panneaux : un toit équipé est couvert.\n" \
		+ "\t// La borne 0,995 écarte tout ce qui est PLAT — sol, chaussée,\n" \
		+ "\t// cours, et les toits-terrasses de 1974, qui ne sont pas en tuile.\n" \
		+ "\tif (!neuf && UV.y <= 1.05 && dot(UV, UV) > 0.5 && vers_le_ciel > 0.5 && vers_le_ciel < 0.995 && pos_monde.y > 1.0) {\n" \
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
		+ "\t// 🏗️ Le toit-terrasse du moderne, clair : en zinc il se lisait en trou.\n" \
		+ "\tif (moderne && vers_le_ciel > 0.5 && pos_monde.y > 1.0) {\n" \
		+ "\t\tbase = TOIT_TERRASSE * COLOR.a * mix(0.90, 1.06, bruit(pos_monde.xz * 0.9));\n" \
		+ "\t\trugosite = 0.95;\n" \
		+ "\t}\n" \
		+ "\t// 🏭 LE TOIT PLAT A UNE MATIÈRE (2026-09-26) : gravier, et les\n" \
		+ "\t// verrières de la halle en travers de son axe. UV2.x = −famille.\n" \
		+ "\tif (!neuf && vers_le_ciel >= 0.995 && length(UV) > 0.5 && pos_monde.y > 1.0 && UV2.x < -0.5) {\n" \
		+ "\t\tvec3 axe_t = normalize(vec3(UV.x, 0.0, UV.y));\n" \
		+ "\t\tvec2 gt = vec2(dot(pos_monde, axe_t), dot(pos_monde, vec3(-axe_t.z, 0.0, axe_t.x)));\n" \
		+ "\t\tfloat aat = max(max(fwidth(gt.x), fwidth(gt.y)), 0.0005);\n" \
		+ "\t\tbase *= mix(1.0, 0.93 + 0.14 * bruit(pos_monde.xz * 2.3), clamp(1.2 - 3.0 * aat, 0.0, 1.0));\n" \
		+ "\t\tif (UV2.x < -4.5 && UV2.x > -5.5) {\n" \
		+ "\t\t\tfloat t = abs(fract(gt.x / 7.5) - 0.5) * 7.5;\n" \
		+ "\t\t\tfloat verriere = smoothstep(0.60 + aat, 0.60 - aat, t);\n" \
		+ "\t\t\tfloat montant = smoothstep(0.34, 0.46, abs(fract(gt.y / 1.2) - 0.5)) * clamp(1.2 - 3.0 * aat, 0.0, 1.0);\n" \
		+ "\t\t\tvec3 vitrage = mix(vec3(0.20, 0.25, 0.29), vec3(0.42, 0.48, 0.52), smoothstep(-0.6, 0.6, (fract(gt.x / 7.5) - 0.5) * 7.5));\n" \
		+ "\t\t\tbase = mix(base, mix(vitrage, vec3(0.28, 0.29, 0.30), montant) * COLOR.a, verriere);\n" \
		+ "\t\t}\n" \
		+ "\t}\n" \
		+ "\tfloat toit_vert_ici = 0.0;\n" \
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
		+ "\t\ttoit_vert_ici = pan_vert;\n" \
		+ "\t\t// Sans liseré : deux cases voisines doivent se souder. La\n" \
		+ "\t\t// variation est un tirage de la case, pas de la nappe.\n" \
		+ "\t\tfloat hv = fract(sin(dot(floor(g), vec2(11.917, 57.301))) * 15731.113);\n" \
		+ "\t\t// ☀️ LE PANNEAU A UNE ÉPAISSEUR ET REFLÈTE LE CIEL (2026-09-26).\n" \
		+ "\t\t// Le bleu franc du 2026-08-17 reste le fond : c'est lui qui se lit\n" \
		+ "\t\t// de loin. De près : cellules, cadre éclairé en haut, ombre en bas.\n" \
		+ "\t\tvec2 fr = fract(g);\n" \
		+ "\t\tfloat monte = pente_axe.y >= 0.0 ? fr.y : 1.0 - fr.y;\n" \
		+ "\t\tfloat hp = fract(sin(dot(floor(g), vec2(3.113, 91.71))) * 2437.37);\n" \
		+ "\t\tvec3 verre = BLEU * mix(0.86, 1.06, hp);\n" \
		+ "\t\tvec2 cel = abs(fract(g * 4.0) - 0.5);\n" \
		+ "\t\tfloat ac = aa * 4.0;\n" \
		+ "\t\tfloat net_cel = clamp(1.2 - 6.0 * ac, 0.0, 1.0);\n" \
		+ "\t\tfloat trait = smoothstep(0.46 - ac, 0.46 + ac, max(cel.x, cel.y));\n" \
		+ "\t\tverre *= 1.0 - 0.30 * trait * net_cel;\n" \
		+ "\t\t// Le ciel dans la vitre : il dépend du versant, donc deux pans d'un\n" \
		+ "\t\t// même toit ne sortent jamais du même bleu.\n" \
		+ "\t\tvec3 vue = normalize((INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz);\n" \
		+ "\t\tfloat ciel = clamp(reflect(-vue, normale_monde).y, 0.0, 1.0);\n" \
		+ "\t\tfloat fresnel = pow(1.0 - clamp(dot(vue, normale_monde), 0.0, 1.0), 3.0);\n" \
		+ "\t\tverre = mix(verre, vec3(0.578, 0.624, 0.658), clamp(0.05 + 0.35 * fresnel, 0.0, 0.3) * ciel);\n" \
		+ "\t\tverre *= mix(0.93, 1.07, monte);\n" \
		+ "\t\tvec3 c_pan = verre;\n" \
		+ "\t\tbool plat = vers_le_ciel >= 0.995;\n" \
		+ "\t\tif (!plat) {\n" \
		+ "\t\t\tfloat cote = smoothstep(0.5 - LISERE - aa, 0.5 - LISERE + aa, abs(fr.x - 0.5));\n" \
		+ "\t\t\tfloat haut = smoothstep(1.0 - LISERE - aa, 1.0 - LISERE + aa, monte);\n" \
		+ "\t\t\tfloat bas = smoothstep(LISERE + aa, LISERE - aa, monte);\n" \
		+ "\t\t\tc_pan = mix(c_pan, BLANC * 0.92, cote);\n" \
		+ "\t\t\tc_pan = mix(c_pan, BLANC, haut);\n" \
		+ "\t\t\tc_pan = mix(c_pan, BLEU * 0.22, bas);\n" \
		+ "\t\t\tc_pan *= COLOR.a;\n" \
		+ "\t\t} else {\n" \
		+ "\t\t\t// 🔆 SUR LE PLAT, DES RANGÉES INCLINÉES VERS LE SUD : deux par\n" \
		+ "\t\t\t// case de 3 m, chacune suivie de son ombre sur l'étanchéité.\n" \
		+ "\t\t\tfloat s = pente_axe.z >= 0.0 ? 1.0 : -1.0;\n" \
		+ "\t\t\tfloat v = fract(g.y * 2.0);\n" \
		+ "\t\t\tfloat q = s > 0.0 ? v : 1.0 - v;\n" \
		+ "\t\t\tfloat aq = aa * 2.0;\n" \
		+ "\t\t\tfloat panneau = smoothstep(0.30 - aq, 0.30 + aq, q);\n" \
		+ "\t\t\tfloat ombre = smoothstep(0.22 + aq, 0.22 - aq, q);\n" \
		+ "\t\t\tfloat colonne = smoothstep(0.47 - aa * 3.0, 0.47 + aa * 3.0, abs(fract(g.x * 3.0) - 0.5));\n" \
		+ "\t\t\tvec3 rang = mix(verre * mix(1.08, 0.90, q), BLANC * 0.92, colonne * 0.8);\n" \
		+ "\t\t\trang = mix(rang, BLANC, smoothstep(0.30 + aq, 0.34, q) * smoothstep(0.37, 0.33, q));\n" \
		+ "\t\t\tvec3 dessous = base * mix(1.0, 0.55, ombre);\n" \
		+ "\t\t\tvec3 motif = mix(dessous, rang * COLOR.a, panneau);\n" \
		+ "\t\t\t// Sous ~2 px de rang, la moyenne, et franche : de loin, un toit\n" \
		+ "\t\t\t// équipé doit rester BLEU, pas une bâche délavée.\n" \
		+ "\t\t\tvec3 moyen = mix(BLEU * 0.80, BLANC * 0.90, bord * 0.85) * COLOR.a;\n" \
		+ "\t\t\tc_pan = mix(moyen, motif, clamp(1.2 - 4.0 * aq, 0.0, 1.0));\n" \
		+ "\t\t}\n" \
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
		+ "\t// Ce que le relief peint réoriente pour la lumière, en monde.\n" \
		+ "\tvec3 n_relief = normale_monde;\n" \
		+ "\tfloat w_relief = 0.0;\n" \
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
		+ "\t\t// Depuis le PIED du bâtiment, pas depuis le Y monde : les rives\n" \
		+ "\t\t// le décalent de ±1 m, et la dernière rangée était tranchée.\n" \
		+ "\t\tfloat h = pos_monde.y - sol;\n" \
		+ "\t\tint genre = int(UV2.x + 0.5);\n" \
		+ "\t\t// UV2.y = famille de façade + tirage du bâtiment (FAMILLE_FACADE, 07).\n" \
		+ "\t\tfloat alea = fract(UV2.y);\n" \
		+ "\t\tfloat famille = floor(UV2.y);\n" \
		+ "\t\tbool porte = false;\n" \
		+ "\t\t// aa = un pixel, EN MÈTRES DE FAÇADE : c'est ce qui rend le\n" \
		+ "\t\t// fondu indépendant du zoom.\n" \
		+ "\t\tfloat aa = max(fwidth(u), 0.0005);\n" \
		+ "\t\t// 07 pose y_haut = niveaux × ETAGE_M, niveaux ENTIERS (04c) :\n" \
		+ "\t\t// aucune fenêtre coupée par l'égout.\n" \
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
		+ "\t\t} else if (etage < 0.5 && genre == 2 && travee == floor(alea * n) && rebati < 1.5) {\n" \
		+ "\t\t\t// Une porte par bâtiment : 07 ne marque le genre 2 que sur\n" \
		+ "\t\t\t// sa plus longue façade sur rue.\n" \
		+ "\t\t\tporte = true;\n" \
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
		+ "\t\t// égout.\n" \
		+ "\t\tfloat tient = 1.0;\n" \
		+ "\t\tif (neuf) {\n" \
		+ "\t\t\tdemi = 0.5 * min(1.90, pas * 0.66);\n" \
		+ "\t\t\tbas = 0.50;\n" \
		+ "\t\t\thaut = 2.48;\n" \
		+ "\t\t\tfloat hn = pos_monde.y - plafond;\n" \
		+ "\t\t\tfloat k = floor(hn / ETAGE);\n" \
		+ "\t\t\thy = hn - k * ETAGE;\n" \
		+ "\t\t\t// Une rangée n'apparaît qu'une fois son étage LIVRÉ.\n" \
		+ "\t\t\ttient = (k * ETAGE + haut > montee) ? 0.0 : 1.0;\n" \
		+ "\t\t} else if (moderne && !porte && !(etage < 0.5 && genre == 3)) {\n" \
		+ "\t\t\tdemi = 0.5 * min(1.90, pas * 0.66);\n" \
		+ "\t\t\tbas = 0.50;\n" \
		+ "\t\t\thaut = 2.48;\n" \
		+ "\t\t} else if (montee > 0.05 && plafond > 0.5\n" \
		+ "\t\t\t\t&& etage * ETAGE + haut > plafond - sol) {\n" \
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
		+ "\t\tfloat cerne = smoothstep(demi + 0.08 + aa, demi + 0.08 - aa, du)\n" \
		+ "\t\t\t* smoothstep(bas - 0.13 - aa, bas - 0.13 + aa, hy)\n" \
		+ "\t\t\t* smoothstep(haut + 0.08 + aa, haut + 0.08 - aa, hy)\n" \
		+ "\t\t\t* smoothstep(marge - 0.10 - aa, marge - 0.10 + aa, bord);\n" \
		+ "\t\t// 🪟 LE TABLEAU, PAR PARALLAXE (2026-10-08). Le rayon de vue\n" \
		+ "\t\t// entre dans le trou : il touche la vitre au fond, ou d'abord un\n" \
		+ "\t\t// tableau, l'appui ou le linteau. pu, pv = glissement le long\n" \
		+ "\t\t// de la façade et en hauteur par mètre de profondeur.\n" \
		+ "\t\t// La tangente est orientée sur `u` par ses dérivées : 07 ne\n" \
		+ "\t\t// garantit pas le sens de parcours d'un mur.\n" \
		+ "\t\tvec3 vue_m = normalize((INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz);\n" \
		+ "\t\tfloat vn = max(dot(vue_m, normale_monde), 0.05);\n" \
		+ "\t\tvec3 tg = normalize(vec3(-normale_monde.z, 0.0, normale_monde.x));\n" \
		+ "\t\ttg *= (dFdx(u) * dot(dFdx(pos_monde), tg) + dFdy(u) * dot(dFdy(pos_monde), tg)) >= 0.0 ? 1.0 : -1.0;\n" \
		+ "\t\tfloat pu = clamp(-dot(vue_m, tg) / vn, -2.0, 2.0);\n" \
		+ "\t\tfloat pv = clamp(-vue_m.y / vn, -1.5, 1.5);\n" \
		+ "\t\t// Loin, la profondeur s'éteint avec le dessin : plus rien à creuser.\n" \
		+ "\t\tfloat prof = PROF_FEN * clamp(1.15 - 1.8 * aa, 0.0, 1.0);\n" \
		+ "\t\tif (etage < 0.5 && genre == 3) prof *= 0.55;\n" \
		+ "\t\tfloat ox = x - (travee + 0.5) * pas;\n" \
		+ "\t\tfloat kx = abs(pu) > 0.001 ? (sign(pu) * demi - ox) / pu : 1.0e3;\n" \
		+ "\t\tfloat ky = abs(pv) > 0.001 ? ((pv < 0.0 ? bas : haut) - hy) / pv : 1.0e3;\n" \
		+ "\t\tfloat kmin = min(kx, ky);\n" \
		+ "\t\tfloat ak = max(fwidth(kmin), 0.0005);\n" \
		+ "\t\tfloat revele = dedans * smoothstep(-ak, ak, prof - kmin) * tient;\n" \
		+ "\t\tfloat hyb = hy + pv * prof;\n" \
		+ "\t\tfloat dub = abs(ox + pu * prof);\n" \
		+ "\t\tfloat ombre = smoothstep(haut - 0.22, haut - 0.03, hyb);\n" \
		+ "\t\t// Le meneau, sur les ouvertures assez larges pour en avoir un.\n" \
		+ "\t\tfloat meneau = (demi > 0.45) ? smoothstep(0.030, 0.055, dub) : 1.0;\n" \
		+ "\t\tfloat ouverture = clamp(dedans * (1.0 - revele) * meneau, 0.0, 1.0) * tient;\n" \
		+ "\t\tfloat dormant = clamp(cerne * tient - ouverture, 0.0, 1.0);\n" \
		+ "\t\t// 🔴 LOIN, ON N'ÉCRIT PLUS — ON ASSOMBRIT. Une fenêtre tient sur\n" \
		+ "\t\t// deux pixels à la vue par défaut : on rend la main à la PART\n" \
		+ "\t\t// VITRÉE du mur, un enduit plus sombre, sans scintillement.\n" \
		+ "\t\tfloat net = clamp(1.15 - 1.8 * aa, 0.0, 1.0);\n" \
		+ "\t\tfloat part = clamp(2.0 * demi * (haut - bas)\n" \
		+ "\t\t\t/ max(pas * ETAGE, 0.1), 0.0, 1.0);\n" \
		+ "\t\t// 🏢 ENTRE LES DEUX, L'ÉTAGE RESTE UNE BANDE : la travée fond\n" \
		+ "\t\t// en largeur, la rangée tient en hauteur tant qu'elle fait ~2 px.\n" \
		+ "\t\t// Sans ce palier, on ne compte plus les étages dès le mi-zoom.\n" \
		+ "\t\t// La racine : à la part vitrée brute, la bande existait sans se lire.\n" \
		+ "\t\tfloat aa_h = max(fwidth(h), 0.0005);\n" \
		+ "\t\tfloat rangee = smoothstep(bas - aa_h, bas + aa_h, hy)\n" \
		+ "\t\t\t* smoothstep(haut + aa_h, haut - aa_h, hy)\n" \
		+ "\t\t\t* smoothstep(marge - aa, marge + aa, bord);\n" \
		+ "\t\tfloat bande = rangee * sqrt(clamp(2.0 * demi / pas, 0.0, 1.0)) * tient;\n" \
		+ "\t\tfloat net_h = clamp((1.10 - aa_h) / 0.55, 0.0, 1.0);\n" \
		+ "\t\tfloat vitre = mix(mix(part * tient, bande, net_h), ouverture, net);\n" \
		+ "\t\t// COLOR.a garde le volume sous le percement.\n" \
		+ "\t\tbase = mix(base, min(base * 1.28 + 0.012, vec3(1.0)), dormant * net);\n" \
		+ "\t\tvec3 mur = base;\n" \
		+ "\t\tfloat interieur = alea_pt(vec2(floor(u / pas), etage) + vec2(alea * 53.0));\n" \
		+ "\t\tvec3 reflet = mix(VITRE, vec3(0.12, 0.18, 0.20), 0.25 + 0.45 * (hyb / ETAGE));\n" \
		+ "\t\treflet = mix(reflet, vec3(0.32, 0.25, 0.16), step(0.86, interieur) * 0.55);\n" \
		+ "\t\tbase = mix(base, reflet * mix(1.0, 0.60, ombre) * COLOR.a, vitre);\n" \
		+ "\t\t// Le tableau est du mur, plus sombre au fond ; c'est sa normale\n" \
		+ "\t\t// qui fait qu'un côté prend le soleil et l'autre non.\n" \
		+ "\t\tfloat cote = smoothstep(-ak, ak, ky - kx);\n" \
		+ "\t\tvec3 n_tab = normalize(mix(vec3(0.0, pv < 0.0 ? 1.0 : -1.0, 0.0), -sign(pu) * tg, cote));\n" \
		+ "\t\tbase = mix(base, mur * mix(1.0, 0.72, clamp(kmin / max(prof, 0.001), 0.0, 1.0)), revele);\n" \
		+ "\t\tn_relief = n_tab;\n" \
		+ "\t\tw_relief = revele;\n" \
		+ "\t\trugosite = mix(rugosite, 0.18, vitre * net);\n" \
		+ "\t\t// 🎨 LA FAMILLE DE FAÇADE (2026-09-26). `net_g` rend la main plus\n" \
		+ "\t\t// tard que `net` : un volet ou un store fait un mètre, il se lit\n" \
		+ "\t\t// encore quand la fenêtre n'est plus qu'un assombrissement.\n" \
		+ "\t\tfloat net_g = clamp(1.3 - 0.8 * aa, 0.0, 1.0);\n" \
		+ "\t\tfloat hb = tirage_travee(travee, etage, alea);\n" \
		+ "\t\tif (!neuf && !moderne && (famille == 1.0 || famille == 2.0)) {\n" \
		+ "\t\t\t// Le soubassement, et le bandeau entre le rez et les étages.\n" \
		+ "\t\t\tbase *= mix(1.0, 0.80, smoothstep(0.60, 0.52, h) * net_g);\n" \
		+ "\t\t\tif (famille == 1.0) {\n" \
		+ "\t\t\t\tbase *= mix(1.0, 1.10, smoothstep(0.10, 0.03, abs(h - ETAGE + 0.05)) * net_g);\n" \
		+ "\t\t\t}\n" \
		+ "\t\t\t// Les volets, sur sept bâtiments sur dix, jamais à la porte.\n" \
		+ "\t\t\tif (!porte && alea > 0.30 && genre <= 2) {\n" \
		+ "\t\t\t\tfloat x0 = demi + 0.05;\n" \
		+ "\t\t\t\tfloat x1 = x0 + demi * 0.92;\n" \
		+ "\t\t\t\tfloat volet = smoothstep(x0 - aa, x0 + aa, du) * smoothstep(x1 + aa, x1 - aa, du)\n" \
		+ "\t\t\t\t\t* smoothstep(bas - aa, bas + aa, hy) * smoothstep(haut + aa, haut - aa, hy)\n" \
		+ "\t\t\t\t\t* smoothstep(marge - aa, marge + aa, bord) * tient;\n" \
		+ "\t\t\t\tfloat lames = mix(1.0, 0.82 + 0.18 * smoothstep(0.15, 0.35, abs(fract(hy / 0.11) - 0.5)), net);\n" \
		+ "\t\t\t\tbase = mix(base, VOLETS[int(fract(alea * 7.13) * 5.0)] * lames * COLOR.a, volet * net_g);\n" \
		+ "\t\t\t}\n" \
		+ "\t\t}\n" \
		+ "\t\tif (!neuf && !moderne && porte) {\n" \
		+ "\t\t\tbase = mix(base, VOLETS[int(fract(alea * 3.71) * 5.0)] * 0.9 * COLOR.a, vitre * net_g);\n" \
		+ "\t\t}\n" \
		+ "\t\tif (!neuf && !moderne && famille == 3.0 && genre == 3 && etage < 0.5 && alea > 0.20) {\n" \
		+ "\t\t\t// Le store au-dessus de la vitrine, et l'ombre qu'il pose dessus.\n" \
		+ "\t\t\tfloat large = smoothstep(demi + 0.14 + aa, demi + 0.14 - aa, du);\n" \
		+ "\t\t\tfloat store = large * smoothstep(2.50 - aa, 2.50 + aa, hy) * smoothstep(2.82 + aa, 2.82 - aa, hy);\n" \
		+ "\t\t\tfloat raie = smoothstep(-0.25, 0.25, sin(u * 20.94)) * net;\n" \
		+ "\t\t\tvec3 toile = mix(STORES[int(fract(alea * 5.31) * 4.0)], CREME, raie * 0.85);\n" \
		+ "\t\t\tbase *= 1.0 - 0.40 * large * smoothstep(2.05, 2.48, hy) * step(hy, 2.50) * net_g;\n" \
		+ "\t\t\tbase = mix(base, toile * COLOR.a, store * net_g);\n" \
		+ "\t\t}\n" \
		+ "\t\tif (!neuf && !moderne && famille == 4.0 && genre == 4) {\n" \
		+ "\t\t\t// Les allèges de couleur de 1970, une travée sur trois, du pied\n" \
		+ "\t\t\t// au toit (au hasard, elles sortaient en confettis), et le nez\n" \
		+ "\t\t\t// de dalle à chaque plancher.\n" \
		+ "\t\t\tfloat allege = smoothstep(demi + aa, demi - aa, du) * smoothstep(0.16 - aa, 0.16 + aa, hy)\n" \
		+ "\t\t\t\t* smoothstep(0.92 + aa, 0.92 - aa, hy) * smoothstep(marge - aa, marge + aa, bord);\n" \
		+ "\t\t\tbase = mix(base, ALLEGES[int(fract(alea * 3.77) * 3.0)] * COLOR.a, allege * step(mod(travee + floor(alea * 3.0), 3.0), 0.5) * net_g);\n" \
		+ "\t\t\tbase = mix(base, min(base * 1.22 + 0.02, vec3(1.0)), smoothstep(0.0, 0.03, hy) * smoothstep(0.16, 0.12, hy) * net_g);\n" \
		+ "\t\t}\n" \
		+ "\t\tif (!neuf && !moderne && famille == 5.0) {\n" \
		+ "\t\t\t// La halle : bardage nervuré, et une porte de quai sur une travée\n" \
		+ "\t\t\t// sur trois au rez.\n" \
		+ "\t\t\tfloat nv = u / 0.28;\n" \
		+ "\t\t\tfloat an = max(fwidth(nv), 0.0005);\n" \
		+ "\t\t\tfloat nerf = smoothstep(0.30, 0.45, abs(fract(nv) - 0.5));\n" \
		+ "\t\t\tbase *= mix(1.0, mix(1.05, 0.84, nerf), clamp(1.3 - 4.0 * an, 0.0, 1.0) * (1.0 - vitre));\n" \
		+ "\t\t\tif (etage < 0.5 && hb < 0.33) {\n" \
		+ "\t\t\t\tfloat quai = smoothstep(pas * 0.40 + aa, pas * 0.40 - aa, du) * smoothstep(3.30 + aa, 3.30 - aa, h)\n" \
		+ "\t\t\t\t\t* smoothstep(marge + 0.3 - aa, marge + 0.3 + aa, bord);\n" \
		+ "\t\t\t\tfloat plis = mix(1.0, 0.86 + 0.14 * smoothstep(0.2, 0.4, abs(fract(h / 0.22) - 0.5)), net);\n" \
		+ "\t\t\t\tbase = mix(base, QUAIS[int(fract(alea * 2.93) * 3.0)] * plis * COLOR.a, quai * net_g);\n" \
		+ "\t\t\t}\n" \
		+ "\t\t}\n" \
		+ "\t\tif (!neuf && (famille == 6.0 || moderne) && genre <= 2 && plafond > 0.5) {\n" \
		+ "\t\t\t// 🏢 LE BALCON EN SAILLIE (2026-10-08), même parallaxe à\n" \
		+ "\t\t\t// l'envers : vu d'en haut, il se projette PLUS BAS sur le mur.\n" \
		+ "\t\t\t// Ce pixel regarde le balcon de son étage (j = 0) et celui du\n" \
		+ "\t\t\t// dessus (j = 1). `plafond` dit si cet étage-là existe : sans\n" \
		+ "\t\t\t// lui, le dernier étage portait un balcon sur le vide.\n" \
		+ "\t\t\tfloat demi_b = moderne ? 0.5 * min(1.90, pas * 0.66) : 0.5 * min(FEN_LARGE, pas * 0.45);\n" \
		+ "\t\t\tfloat q = max(-pv, 0.0);\n" \
		+ "\t\t\tvec3 dalle_c = min(mur * 1.25 + 0.03, vec3(1.0));\n" \
		+ "\t\t\tvec3 parapet = min(mur * 1.35 + 0.05, vec3(0.85));\n" \
		+ "\t\t\tvec3 tranche = mur * 0.86;\n" \
		+ "\t\t\tfor (int j = 1; j >= 0; j--) {\n" \
		+ "\t\t\t\tfloat eb = etage + float(j);\n" \
		+ "\t\t\t\tif (eb < 0.5 || sol + (eb + 1.0) * ETAGE > plafond + 0.1) continue;\n" \
		+ "\t\t\t\tfloat hs = float(j) * ETAGE + 0.17;\n" \
		+ "\t\t\t\t// L'ombre de la dalle sur le mur, sous son épaisseur.\n" \
		+ "\t\t\t\tfloat tb0 = floor(x / pas);\n" \
		+ "\t\t\t\tfloat w0 = smoothstep(demi_b + 0.55 + aa, demi_b + 0.55 - aa, abs(x - (tb0 + 0.5) * pas))\n" \
		+ "\t\t\t\t\t* smoothstep(marge - aa, marge + aa, bord) * step(tirage_travee(tb0, eb, alea), 0.55);\n" \
		+ "\t\t\t\tfloat dessous = hs - BALCON_E;\n" \
		+ "\t\t\t\t// ⚠ Les fondus se mesurent sur `h` et `u`, continus : `hy` saute à\n" \
		+ "\t\t\t\t// chaque plancher, et fwidth(hy) traçait un pointillé sur la façade.\n" \
		+ "\t\t\t\tbase *= 1.0 - 0.38 * w0 * smoothstep(dessous - OMBRE_BALCON, dessous - OMBRE_BALCON + 0.25, hy) * smoothstep(dessous + 0.02, dessous - 0.02, hy) * net_g;\n" \
		+ "\t\t\t\t// Du fond vers l'avant : le sol (en plongée seulement, par-dessus le\n" \
		+ "\t\t\t\t// garde-corps), les deux joues, le chaperon, la face. Garde-corps PLEIN\n" \
		+ "\t\t\t\t// (auteur, 2026-10-08) : la tranche de la dalle, sur la face et les\n" \
		+ "\t\t\t\t// joues, est ce qui donne l'épaisseur.\n" \
		+ "\t\t\t\tfloat hp = hy + q * BALCON_P;\n" \
		+ "\t\t\t\tfloat xp = x - pu * BALCON_P;\n" \
		+ "\t\t\t\tfloat tbp = floor(xp / pas);\n" \
		+ "\t\t\t\tfloat cb = (tbp + 0.5) * pas;\n" \
		+ "\t\t\t\tfloat bp = min(xp + marge, L - xp - marge);\n" \
		+ "\t\t\t\tfloat existe = smoothstep(marge - aa, marge + aa, bp) * step(tirage_travee(tbp, eb, alea), 0.55) * net_g;\n" \
		+ "\t\t\t\tfloat ah = aa_h;\n" \
		+ "\t\t\t\tif (q > 0.02) {\n" \
		+ "\t\t\t\t\tfloat ts = (hs - hy) / q;\n" \
		+ "\t\t\t\t\tfloat at = aa_h / q;\n" \
		+ "\t\t\t\t\tfloat sol_b = smoothstep(-at, at, ts) * smoothstep(BALCON_P - 0.12 + at, BALCON_P - 0.12 - at, ts)\n" \
		+ "\t\t\t\t\t\t* smoothstep(demi_b + 0.45 + aa, demi_b + 0.45 - aa, abs(x - pu * ts - cb)) * existe;\n" \
		+ "\t\t\t\t\tbase = mix(base, dalle_c * 0.78, sol_b);\n" \
		+ "\t\t\t\t\tn_relief = normalize(mix(n_relief, vec3(0.0, 1.0, 0.0), sol_b));\n" \
		+ "\t\t\t\t\tw_relief = max(w_relief, sol_b);\n" \
		+ "\t\t\t\t}\n" \
		+ "\t\t\t\tif (abs(pu) > 0.01) {\n" \
		+ "\t\t\t\t\tfor (float s = -1.0; s < 2.0; s += 2.0) {\n" \
		+ "\t\t\t\t\t\tfloat tj = (x - cb - s * (demi_b + 0.55)) / pu;\n" \
		+ "\t\t\t\t\t\tfloat aj = aa / abs(pu);\n" \
		+ "\t\t\t\t\t\tfloat hj = hy + q * tj;\n" \
		+ "\t\t\t\t\t\tfloat joue = smoothstep(-aj, aj, tj) * smoothstep(BALCON_P + aj, BALCON_P - aj, tj)\n" \
		+ "\t\t\t\t\t\t\t* smoothstep(dessous - ah, dessous + ah, hj) * smoothstep(hs + BALCON_H + ah, hs + BALCON_H - ah, hj) * existe;\n" \
		+ "\t\t\t\t\t\tfloat tranche_j = smoothstep(hs + ah, hs - ah, hj);\n" \
		+ "\t\t\t\t\t\tbase = mix(base, mix(parapet, tranche, tranche_j), joue);\n" \
		+ "\t\t\t\t\t\t// La face d'une joue que le rayon voit regarde toujours vers lui.\n" \
		+ "\t\t\t\t\t\tn_relief = normalize(mix(n_relief, -sign(pu) * tg, joue));\n" \
		+ "\t\t\t\t\t\tw_relief = max(w_relief, joue);\n" \
		+ "\t\t\t\t\t}\n" \
		+ "\t\t\t\t}\n" \
		+ "\t\t\t\tfloat ttop = q > 0.02 ? (hs + BALCON_H - hy) / q : -1.0;\n" \
		+ "\t\t\t\tfloat att = aa_h / max(q, 0.02);\n" \
		+ "\t\t\t\tfloat chaperon = smoothstep(BALCON_P - 0.12 - att, BALCON_P - 0.12 + att, ttop) * smoothstep(BALCON_P + att, BALCON_P - att, ttop)\n" \
		+ "\t\t\t\t\t* smoothstep(demi_b + 0.55 + aa, demi_b + 0.55 - aa, abs(x - pu * ttop - cb)) * existe;\n" \
		+ "\t\t\t\tfloat face = smoothstep(demi_b + 0.55 + aa, demi_b + 0.55 - aa, abs(xp - cb)) * existe\n" \
		+ "\t\t\t\t\t* smoothstep(dessous - ah, dessous + ah, hp) * smoothstep(hs + BALCON_H + ah, hs + BALCON_H - ah, hp);\n" \
		+ "\t\t\t\tfloat tranche_f = smoothstep(hs + ah, hs - ah, hp);\n" \
		+ "\t\t\t\tbase = mix(base, min(parapet * 1.12, vec3(1.0)), chaperon);\n" \
		+ "\t\t\t\tbase = mix(base, mix(parapet, tranche, tranche_f), face);\n" \
		+ "\t\t\t\tn_relief = normalize(mix(n_relief, vec3(0.0, 1.0, 0.0), chaperon));\n" \
		+ "\t\t\t\tn_relief = normalize(mix(n_relief, normale_monde, face));\n" \
		+ "\t\t\t\tw_relief = max(w_relief, max(face, chaperon));\n" \
		+ "\t\t\t}\n" \
		+ "\t\t} else if (!neuf && (famille == 6.0 || moderne) && genre <= 2 && etage > 0.5 && hb < 0.55) {\n" \
		+ "\t\t\t// Sans `plafond`, le balcon reste peint à plat, dans son étage.\n" \
		+ "\t\t\tfloat large = smoothstep(demi + 0.55 + aa, demi + 0.55 - aa, du) * smoothstep(marge - aa, marge + aa, bord);\n" \
		+ "\t\t\tfloat dalle = large * smoothstep(0.02, 0.05, hy) * smoothstep(0.17, 0.13, hy);\n" \
		+ "\t\t\tfloat garde = large * smoothstep(0.17, 0.20, hy) * smoothstep(1.02, 0.98, hy);\n" \
		+ "\t\t\tbase = mix(base, min(base * 1.25 + 0.03, vec3(1.0)), dalle * net_g);\n" \
		+ "\t\t\tbase = mix(base, GARDE_CORPS * COLOR.a, garde * 0.55 * net_g);\n" \
		+ "\t\t}\n" \
		+ "\t}\n" \
		+ "\t// 🌊 L'ÉTAT D'UNE BERGE, DANS LA VILLE VIVANTE. `calque` ne\n" \
		+ "\t// peint que la maquette blanche ; une rive rendue au fleuve doit se\n" \
		+ "\t// voir SANS ouvrir le diagnostic, sinon la décision n'a pas d'effet.\n" \
		+ "\tif (parcelle_agricole > 0.5) base *= grain_champ(pos_monde.xz);\n" \
		+ "\tif (parcelle_agricole > 1.5 && vers_le_ciel > 0.5) base = culture_champ(base, pos_monde.xz, parcelle_agricole, COLOR.a);\n" \
		+ "\tvec4 depot = boue_hauteur >= 0.0 ? depot_boue_local(pos_monde, boue_hauteur, 0.0) : depot_boue(pos_monde);\n" \
		+ "\tfloat propre = boue_propre * boue_nettoyage_acces(pos_monde.xz, boue_acces, boue_largeur);\n" \
		+ "\t// Sous la boue pleine, un tronc ou une tuile se confondrait avec le sol.\n" \
		+ "\tif (debris) depot.a *= 0.5;\n" \
		+ "\t// 🌿 LE PARC INONDABLE : là où l'eau est passée, prairie et noues.\n" \
		+ "\tif (parc && vers_le_ciel > 0.9 && pos_monde.y < 0.6) {\n" \
		+ "\t\tfloat pre = max(ruine, smoothstep(0.02, 0.25, depot.a));\n" \
		+ "\t\tfloat g = bruit(pos_monde.xz * 0.35) + 0.4 * bruit(pos_monde.xz * 1.7);\n" \
		+ "\t\tvec3 herbe = mix(PRAIRIE, PRAIRIE_CLAIRE, clamp(g * 0.6, 0.0, 1.0));\n" \
		+ "\t\tfloat w = noue(pos_monde.xz);\n" \
		+ "\t\therbe = mix(herbe, JONC, smoothstep(0.42, 0.58, w) * 0.85);\n" \
		+ "\t\tfloat eau = smoothstep(0.66, 0.70, w);\n" \
		+ "\t\therbe = mix(herbe, EAU_NOUE, eau);\n" \
		+ "\t\tbase = mix(base, herbe * COLOR.a, pre);\n" \
		+ "\t\trugosite = mix(rugosite, 0.25, eau * pre);\n" \
		+ "\t\tdepot.a *= 1.0 - pre;\n" \
		+ "\t}\n" \
		+ "\tbase = mix(base, depot.rgb * COLOR.a, depot.a * (1.0 - propre));\n" \
		+ "\tif (etat_berge > 0.5) {\n" \
		+ "\t\tfloat net_rive = 1.0 - smoothstep(0.25, 1.0, length(fwidth(pos_monde.xz)));\n" \
		+ "\t\tfloat grain = bruit(pos_monde.xz * 0.18);\n" \
		+ "\t\tgrain += (bruit(pos_monde.xz * 1.2) - 0.5) * 0.16 * net_rive;\n" \
		+ "\t\tvec3 rive = (etat_berge > 1.5 ? RIVE_VERTE : RIVE_SABLE)\n" \
		+ "\t\t\t* mix(0.86, 1.12, grain);\n" \
		+ "\t\tfloat humide = 1.0 - smoothstep(-1.95, -1.40, pos_monde.y);\n" \
		+ "\t\tif (etat_berge > 1.5) rive = mix(rive, vec3(0.105, 0.125, 0.085), humide * 0.65);\n" \
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
		+ "\t\tif (calque.a > 0.0 && diagnostic_sol < 2.5) {\n" \
		+ "\t\t\tbase = mix(base, calque.rgb * COLOR.a, calque.a);\n" \
		+ "\t\t}\n" \
		+ "\t\t// 💧 3 = LA CARTE DES SOLS (101) : le calque prend le sol, un toit\n" \
		+ "\t\t// nu est en dur, un toit vert boit, les murs restent du papier.\n" \
		+ "\t\t// ⚠ Les deux teintes sont aussi dans `maquette.SOLS_*`, en sRGB.\n" \
		+ "\t\tif (diagnostic_sol > 2.5) {\n" \
		+ "\t\t\tbool toit = vers_le_ciel > 0.55 && pos_monde.y > 1.0 && length(UV) > 0.5;\n" \
		+ "\t\t\tif (toit) {\n" \
		+ "\t\t\t\tbase = mix(vec3(0.162, 0.162, 0.181), vec3(0.107, 0.352, 0.107), toit_vert_ici) * COLOR.a;\n" \
		+ "\t\t\t} else if (vers_le_ciel > 0.55 && calque.a > 0.0) {\n" \
		+ "\t\t\t\tbase = calque.rgb * COLOR.a;\n" \
		+ "\t\t\t}\n" \
		+ "\t\t}\n" \
		+ "\t\t// Dangers (crue.gdshaderinc) : le sol prend l'eau au mètre près, le\n" \
		+ "\t\t// bâti se lit à l'eau à son pied, les routes coupées en rouge.\n" \
		+ "\t\t// ⚠ LINÉAIRE. Touché #E87E30, détruit #8C1C28, coupé #DC3A30 (`interface.gd`).\n" \
		+ "\t\t// Hors des branches : texture et fwidth veulent un flot uniforme.\n" \
		+ "\t\tfloat h_eau = crue_vue > 0 ? crue_hauteur(pos_monde.xz, 1.0) : 0.0;\n" \
		+ "\t\tfloat h_pied = crue_vue > 0 ? crue_hauteur(pos_monde.xz, 0.0) : 0.0;\n" \
		+ "\t\tfloat fw_eau = fwidth(h_eau);\n" \
		+ "\t\tif (crue_vue > 0 && diagnostic_sol > 0.5 && diagnostic_sol < 2.5) {\n" \
		+ "\t\t\t// 2,60 = SEUIL_RUINE de `04e`, le plafond du rez.\n" \
		+ "\t\t\t// Bâti = mur ou toit (UV, cf. plus haut), pas l'altitude : la terrasse\n" \
		+ "\t\t\t// de rive gauche passe 0,35 m et se peignait en bâtiment touché.\n" \
		+ "\t\t\tif (diagnostic_bati < 0.5 || (ruine < 0.5 && dot(UV, UV) < 0.25)) {\n" \
		+ "\t\t\t\tvec4 eau = crue_sol(h_eau, fw_eau);\n" \
		+ "\t\t\t\tbase = mix(base, eau.rgb * COLOR.a, eau.a);\n" \
		+ "\t\t\t} else if (ruine > 0.5 || (crue_vue == 2 && h_pied >= 2.60)) {\n" \
		+ "\t\t\t\tbase = mix(base, vec3(0.262, 0.012, 0.021) * COLOR.a, 0.94);\n" \
		+ "\t\t\t} else if (h_pied > 0.10) {\n" \
		+ "\t\t\t\tbase = mix(base, vec3(0.807, 0.209, 0.030) * COLOR.a, 0.92);\n" \
		+ "\t\t\t}\n" \
		+ "\t\t}\n" \
		+ "\t\tif (diagnostic_sol > 1.5 && diagnostic_sol < 2.5) {\n" \
		+ "\t\t\tbase = mix(base, vec3(0.716, 0.042, 0.030) * COLOR.a, 0.88);\n" \
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
		+ "\t// La maquette blanche ne garde que le volume : pas de relief peint.\n" \
		+ "\tif (w_relief > 0.0 && maquette_blanche < 0.5) {\n" \
		+ "\t\tNORMAL = normalize(mix(NORMAL, (VIEW_MATRIX * vec4(n_relief, 0.0)).xyz, w_relief));\n" \
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


## 🟤 Les couleurs de la crue et de l'eau normale ; le passage de l'une à
## l'autre est `eau_limon`, global, que `maquette.gd` pose au fil des mois.
static func eau(palette: Dictionary) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/eau.gdshader")
	for etat in ["crue", "trouble"]:
		for part in ["bord", "milieu"]:
			m.set_shader_parameter("%s_%s" % [etat, part],
				Color(palette["_eau_%s_%s" % [etat, part]] as String))
	return m


## `foret` = la demi-emprise du décor, où l'arbre se perd dans la brume ; zéro
## en ville.
static func feuillage(foret := Vector2.ZERO) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/feuillage.gdshader")
	if foret != Vector2.ZERO:
		m.set_shader_parameter("demi_emprise", foret)
	return m


## Le tronc, en seconde surface pour que sa teinte soit FIXE : sinon un tronc
## sous un feuillage vert ressortirait vert. Même shader que la couronne, pour
## qu'il plie au même vent et entre dans la même brume.
static func ecorce(teinte: Color, foret := Vector2.ZERO) -> ShaderMaterial:
	var m := feuillage(foret)
	m.set_shader_parameter("tronc", true)
	m.set_shader_parameter("ecorce", teinte)
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
		+ "\tif ((ruine > 0.5 && densification.w > 0.5) || plafond < -1.5) discard;\n" \
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
## l'objet lui-même — murs noirs dans la miniature. En perspective, `soleil.gd`
## la recalcule à chaque mouvement de caméra.
static func soleil(teinte: Color, portee_ombre := 3000.0) -> DirectionalLight3D:
	var l: DirectionalLight3D = preload("res://scripts/soleil.gd").new()
	l.name = "Soleil"
	l.rotation_degrees = Vector3(-48.0, -125.0, 0.0)
	l.light_color = teinte
	# Ombres douces : leur pénombre se règle en angle, pas en floutant l'image.
	l.light_energy = 1.25
	l.light_angular_distance = 1.6
	l.shadow_enabled = true
	l.directional_shadow_max_distance = portee_ombre
	# Sans fondu, le passage d'une tranche à la suivante se lit en couture nette.
	l.directional_shadow_blend_splits = true
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
