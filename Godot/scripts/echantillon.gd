extends RefCounted
# 🧩 LE MORCEAU DROIT DE LA FICHE (2026-08-31, demandé : « la bonne largeur et
# le bon type, sur un petit bout droit »). Une rue et une berge ne se montrent
# plus par un bout de la ville — un ruban qui tourne, sans eau ni sol autour —
# mais par un ÉCHANTILLON fabriqué ici : une coupe droite, montée en bloc.
#
# 🔴 SEULE GÉOMÉTRIE FABRIQUÉE DANS GODOT, et c'est un APERÇU, pas la ville :
# un îlot reste montré par son maillage réel. Toute largeur vient d'un nombre
# mesuré (`largeur_m`, `debord_m2 / longueur_m`, `mur_m`) ou d'une constante de
# 07 recopiée plus bas — aucune n'est réglée à l'œil.
#
# La coupe se déclare en BANDES parallèles à l'axe, du bord le plus à gauche au
# plus à droite ; `_emettre` en fait un bloc à quatre parois. Le morceau court
# le long de X, centré sur l'origine : c'est ce qui rend le cadrage trivial.

## L'émetteur de faces vient de `constructeur.gd` : même sens de parcours, même
## convention de normale. Un deuxième en aurait pris l'autre, une fois sur deux.
const Constructeur := preload("res://scripts/constructeur.gd")

# --- les cotes de la rue, toutes reprises de 07 et de 04 -------------------
## `04_deriver_attributs.EMPRISE_CIRCULATION` : la chaussée d'une hiérarchie.
const EMPRISE_CIRCULATION := {
	"autoroute": 25.0, "boulevard": 10.5, "rue": 8.5,
	"ruelle": 4.0, "rive": 6.5, "voie ferree": 8.0,
}
const LARGEUR_TROTTOIR := 2.0
const TROTTOIR_MIN := 0.8        # en dessous, pas de trottoir du tout
const JEU_CHAUSSEE := 0.10       # le trottoir ne touche jamais l'asphalte
const HAUTEUR_BORDURE := 0.14
const Y_SOL := 0.05
const Y_CHAUSSEE := -0.02
const Y_TROTTOIR := Y_CHAUSSEE + HAUTEUR_BORDURE
const Y_MARQUAGE := Y_CHAUSSEE + 0.01
const LARGEUR_LIGNE := 0.15
const AXE_MIN_CHAUSSEE := 5.5    # en dessous, une seule voie : pas d'axe
const AXE_TRAIT := 3.0
const AXE_VIDE := 6.0
const RIVE_RETRAIT := 0.35
const HIER_LIGNE_RIVE := ["boulevard", "rive"]

# --- les cotes de la berge ------------------------------------------------
const NAPPE := -2.0              # le plan d'eau, 2 m sous la ville
const FOND := -2.6               # le lit
const TALUS_BAS := -2.15
const TALUS_LARGEUR := 10.0      # la course horizontale de la pente → 22 %
const Y_QUAI := Y_SOL - 0.01
const PARAPET_H := 1.00
const PARAPET_EP := 0.40
const BERGE_BANDE_M := 3.5       # la largeur de rive que la transformation rend
## Ce que la vignette montre du fleuve — un cadre, pas la largeur de l'Ilse.
const EAU_VUE_M := 9.0
## De combien le lit ressort de l'eau au bord du bloc : le fleuve continue
## au-delà du morceau, et cette ligne mouillée le dit sans dessiner l'autre rive.
const BORD_MOUILLE := 0.05
## Ce qui reste de ville derrière le quai, et de champ derrière le talus.
## 🔴 COURT : au-delà, le gris du fond pèse plus que la rive, qui est l'objet.
const FOND_DE_COUPE_M := 3.0

# --- le bloc --------------------------------------------------------------
## La tranche du bloc, un peu plus sombre que le dessus : c'est elle qui le
## fait lire comme un morceau soulevé. Le nombre est celui de `constructeur`.
const TRANCHE := 0.88
const EPAISSEUR := 1.6           # sous le point le plus bas de la coupe
## Le morceau est plus long que large — sinon ce n'est plus un bout de rue.
const ELANCEMENT := 2.6
const LONGUEUR_MIN := 18.0
const LONGUEUR_MAX := 44.0

const DECOR := 0
const OBJET := 1                 # la part que la fiche teinte (`etat_berge`)

## Les trois états de `ville.gd`, recopiés pour ne pas l'importer.
const ASPHALTE := 0
const APAISEE := 1
const RENATUREE := 2


## La chaussée d'un tronçon : la règle de 07, et le seul endroit qui l'écrit
## côté Godot. Sert aussi à mesurer la voie de berge d'une rive.
static func chaussee(route: Dictionary) -> float:
	var largeur := maxf(float(route.get("largeur_m", 0.0)), 4.0)
	return minf(float(EMPRISE_CIRCULATION.get(
		str(route.get("hierarchie", "rue")), 8.5)), largeur)


## 🛣️ UN MORCEAU DE RUE. Rend `{decor, objet, longueur, chaussee, largeur}` :
## la miniature pose les deux maillages, les voitures suivent la chaussée.
static func rue(d: Dictionary, pal: Dictionary) -> Dictionary:
	var largeur := maxf(float(d.get("largeur_m", 0.0)), 4.0)
	var ch := chaussee(d)
	var tr := minf(LARGEUR_TROTTOIR, largeur * 0.5 - ch * 0.5 - JEU_CHAUSSEE)
	if tr < TROTTOIR_MIN:
		tr = 0.0
	var sol := _c(pal, "_mineral_clair")
	var bitume := _c(pal, "_mineral")
	var dalle := _c(pal, "_trottoir")
	# La bordure est le trottoir assombri, pas une couleur de plus : l'œil n'y
	# lit qu'une ombre d'arête (07).
	var bord := _sombre(dalle, 0.22)
	var bandes := []
	# Les bords de la coupe, du dehors vers la chaussée. Le sol nu prend ce qui
	# RESTE : la moitié d'emprise moins la chaussée, le jeu et le trottoir.
	var demi := largeur * 0.5
	var bitume_bord := ch * 0.5
	var dalle_bord := bitume_bord + JEU_CHAUSSEE
	var dehors := minf(dalle_bord + tr, demi)
	if tr > 0.0:
		bandes.append([-demi, -dehors, Y_SOL, Y_SOL, sol, sol, DECOR])
		bandes.append([-dehors, -dalle_bord, Y_TROTTOIR, Y_TROTTOIR, dalle, bord,
			OBJET])
		bandes.append([-dalle_bord, -bitume_bord, Y_SOL, Y_SOL, sol, bord, DECOR])
	else:
		bandes.append([-demi, -bitume_bord, Y_SOL, Y_SOL, sol, sol, DECOR])
	bandes.append([-bitume_bord, bitume_bord, Y_CHAUSSEE, Y_CHAUSSEE, bitume,
		bitume, OBJET])
	if tr > 0.0:
		bandes.append([bitume_bord, dalle_bord, Y_SOL, Y_SOL, sol, sol, DECOR])
		bandes.append([dalle_bord, dehors, Y_TROTTOIR, Y_TROTTOIR, dalle, bord,
			OBJET])
		bandes.append([dehors, demi, Y_SOL, Y_SOL, sol, bord, DECOR])
	else:
		bandes.append([bitume_bord, demi, Y_SOL, Y_SOL, sol, sol, DECOR])

	var longueur := clampf(ELANCEMENT * largeur, LONGUEUR_MIN, LONGUEUR_MAX)
	var g := _emettre(bandes, longueur)
	_marquage(g[OBJET], longueur, ch, str(d.get("hierarchie", "rue")),
		_c(pal, "_marquage"))
	return {"decor": _mailler(g[DECOR]), "objet": _mailler(g[OBJET]),
		"eau": null, "longueur": longueur, "chaussee": ch, "largeur": largeur}


## 🌊 UN MORCEAU DE BERGE, dans l'état visé. `voie_m` est la chaussée de la
## voie de berge, mesurée sur les tronçons que la berge longe.
##
## 🔴 LA COUPE DIT LA DÉCISION. 🔄 Le quai était bâti EN AVANT de la rive, du
## débord d'asphalte mesuré ; depuis que le corridor se colle aux façades ce
## débord est nul et le quai est un TERRE-PLEIN minéral de `rive_m` (1,4 m sur
## une voie `rive`, 10,2 m sur le boulevard de la berge 6). Renaturer en verdit
## la bande du bord, qui devient une pente ; le reste du quai ne bouge pas.
## Le fond de coupe ne bouge pas d'un état à l'autre — sinon les trois
## captures de contrôle ne se compareraient plus.
static func berge(d: Dictionary, voie_m: float, pal: Dictionary,
		etat: int) -> Dictionary:
	var lg := maxf(float(d.get("longueur_m", 0.0)), 1.0)
	var debord := float(d.get("debord_m2", 0.0)) / lg
	var mur := float(d.get("mur_m", 0.0)) > 0.5 * lg
	# La rive minérale mesurée, et la part qui verdit : jamais plus large que
	# le quai lui-même, sinon la pente monterait sur la chaussée.
	var rive := maxf(float(d.get("rive_m", BERGE_BANDE_M)), 1.0)
	var bande := minf(BERGE_BANDE_M, rive)
	var lit := _sombre(_c(pal, "_mineral_clair"), 0.45)
	var quai := _sombre(_c(pal, "_mineral_clair"), 0.14)   # `coul_quai` de 07
	var dalle := _c(pal, "_trottoir")
	var bitume := _c(pal, "_mineral")
	var vert := _c(pal, "parc")
	var bandes := []
	var z_eau := 0.0
	if mur:
		# Le nu du quai : en avant de la rive tant que l'asphalte déborde.
		var b := -debord if etat <= ASPHALTE else 0.0
		var z0 := -(EAU_VUE_M + debord)
		# 🔴 LE LIT REMONTE AU PLAN D'EAU au bord du bloc : à plat, la nappe
		# passait par-dessus la tranche et flottait à côté du morceau.
		bandes.append([z0, b, NAPPE + BORD_MOUILLE, FOND, lit, lit, DECOR])
		z_eau = b
		if etat >= RENATUREE:
			# La rive rendue : la bande du bord devient la pente qui descend au
			# fleuve, et il n'y a plus de mur du tout. Le quai qui reste
			# derrière elle est toujours minéral — c'est la promenade.
			bandes.append([b, b + bande, NAPPE - 0.15, Y_SOL, vert, vert,
				OBJET])
			z_eau = _croisement(b, NAPPE - 0.15, b + bande, Y_SOL, NAPPE)
			if rive > bande:
				bandes.append([b + bande, b + rive, Y_SOL, Y_SOL, dalle, quai,
					OBJET])
		else:
			bandes.append([b, b + PARAPET_EP, Y_QUAI + PARAPET_H,
				Y_QUAI + PARAPET_H, dalle, quai, OBJET])
			bandes.append([b + PARAPET_EP, b + rive, Y_TROTTOIR,
				Y_TROTTOIR, dalle, quai, OBJET])
		# La voie de berge suit le quai. Le fond de coupe, lui, ne bouge pas —
		# il absorbe le recul.
		bandes.append([b + rive, b + rive + voie_m,
			Y_CHAUSSEE, Y_CHAUSSEE, bitume, bitume, DECOR])
		bandes.append([b + rive + voie_m,
			rive + voie_m + FOND_DE_COUPE_M, Y_SOL, Y_SOL,
			_c(pal, "_mineral_clair"), _c(pal, "_mineral_clair"), DECOR])
	else:
		# Sans mur, la rive est un talus d'herbe : c'est le type, et il se lit
		# à la pente. La bande de rive est ses 3,5 m du haut.
		var champ := _c(pal, "champ")
		bandes.append([-EAU_VUE_M, 0.0, NAPPE + BORD_MOUILLE, FOND, lit, lit,
			DECOR])
		var haut := TALUS_LARGEUR - BERGE_BANDE_M
		var y_haut := TALUS_BAS + (Y_SOL - TALUS_BAS) * haut / TALUS_LARGEUR
		bandes.append([0.0, haut, TALUS_BAS, y_haut, vert, vert, DECOR])
		bandes.append([haut, TALUS_LARGEUR, y_haut, Y_SOL, vert, vert, OBJET])
		bandes.append([TALUS_LARGEUR, TALUS_LARGEUR + FOND_DE_COUPE_M, Y_SOL,
			Y_SOL, champ, champ, DECOR])
		z_eau = _croisement(0.0, TALUS_BAS, haut, y_haut, NAPPE)

	var large: float = float(bandes[-1][1]) - float(bandes[0][0])
	var longueur := clampf(1.4 * large, LONGUEUR_MIN + 6.0, LONGUEUR_MAX)
	var g := _emettre(bandes, longueur)
	return {"decor": _mailler(g[DECOR]), "objet": _mailler(g[OBJET]),
		"eau": _eau(longueur, float(bandes[0][0]) + 1.0, z_eau),
		"longueur": longueur, "chaussee": voie_m, "largeur": large}


## Où une pente coupe le plan d'eau : le bord mouillé, donc le bout de la nappe.
static func _croisement(z0: float, y0: float, z1: float, y1: float,
		y: float) -> float:
	if absf(y1 - y0) < 0.001:
		return z1
	return clampf(z0 + (z1 - z0) * (y - y0) / (y1 - y0), z0, z1)


## La nappe, seule surface de l'échantillon à ne pas être du sol : elle a son
## matériau (`Materiaux.eau`), donc son maillage.
static func _eau(longueur: float, z0: float, z1: float) -> ArrayMesh:
	if z1 - z0 < 0.2:
		return null
	var g := _groupe()
	_nappe(g, -longueur * 0.5, longueur * 0.5, z0, NAPPE, z1, NAPPE,
		Color.WHITE)
	return _mailler(g)


## Les traits au sol. La règle est celle de 07 : un axe discontinu dès qu'il y
## a deux voies, une ligne de rive sur les seules hiérarchies qui en portent.
static func _marquage(g: Dictionary, longueur: float, ch: float, hier: String,
		coul: Color) -> void:
	var demi := LARGEUR_LIGNE * 0.5
	if ch >= AXE_MIN_CHAUSSEE:
		var pas := AXE_TRAIT + AXE_VIDE
		var x := -longueur * 0.5 + fmod(longueur, pas) * 0.5
		while x + AXE_TRAIT <= longueur * 0.5:
			_nappe(g, x, x + AXE_TRAIT, -demi, Y_MARQUAGE, demi, Y_MARQUAGE,
				coul)
			x += pas
	if hier in HIER_LIGNE_RIVE:
		for cote in [-1.0, 1.0]:
			var z: float = cote * (ch * 0.5 - RIVE_RETRAIT)
			_nappe(g, -longueur * 0.5, longueur * 0.5, z - demi, Y_MARQUAGE,
				z + demi, Y_MARQUAGE, coul)


## Le bloc : le dessus de chaque bande, la paroi qui monte à son bord, puis les
## quatre côtés de la tranche. Rend les deux groupes, décor et objet.
static func _emettre(bandes: Array, longueur: float) -> Array:
	var x0 := -longueur * 0.5
	var x1 := longueur * 0.5
	var bas := INF
	for b in bandes:
		bas = minf(bas, minf(float(b[2]), float(b[3])))
	bas -= EPAISSEUR
	var g := [_groupe(), _groupe()]
	var precedent := INF
	for b in bandes:
		var z0 := float(b[0])
		var z1 := float(b[1])
		var y0 := float(b[2])
		var y1 := float(b[3])
		var part := int(b[6])
		if z1 - z0 > 0.001:
			_nappe(g[part], x0, x1, z0, y0, z1, y1, b[4])
		# La paroi au bord : marche de bordure, mur de quai, tranche de dalle.
		if precedent < INF and absf(y0 - precedent) > 0.001:
			_paroi(g[part], x0, x1, z0, maxf(y0, precedent),
				minf(y0, precedent), -1.0 if y0 > precedent else 1.0, b[5])
		precedent = y1
		# La tranche, toujours du décor : elle ferme le bloc, elle n'appartient
		# à aucun objet cliquable.
		_bouts(g[DECOR], x0, x1, z0, y0, z1, y1, bas, _sombre(b[4], 1.0 - TRANCHE))
	var g0: float = float(bandes[0][0])
	var y_g: float = float(bandes[0][2])
	var d0: float = float(bandes[-1][1])
	var y_d: float = float(bandes[-1][3])
	_paroi(g[DECOR], x0, x1, g0, y_g, bas, -1.0,
		_sombre(bandes[0][4], 1.0 - TRANCHE))
	_paroi(g[DECOR], x0, x1, d0, y_d, bas, 1.0,
		_sombre(bandes[-1][4], 1.0 - TRANCHE))
	return g


## Un dessus : quadrilatère qui va de (z0, y0) à (z1, y1) sur toute la longueur.
## Plat quand y0 == y1, pente sinon.
static func _nappe(g: Dictionary, x0: float, x1: float, z0: float, y0: float,
		z1: float, y1: float, coul: Color) -> void:
	var n := Vector3(0.0, z1 - z0, -(y1 - y0)).normalized()
	Constructeur._face(g["v"], g["n"], g["c"], g["i"],
		[Vector3(x0, y0, z0), Vector3(x0, y1, z1), Vector3(x1, y1, z1),
		Vector3(x1, y0, z0)], n, coul)


## Une paroi verticale au bord d'une bande. `vers` dit de quel côté elle regarde.
static func _paroi(g: Dictionary, x0: float, x1: float, z: float, haut: float,
		bas: float, vers: float, coul: Color) -> void:
	var quatre := [Vector3(x0, haut, z), Vector3(x1, haut, z),
		Vector3(x1, bas, z), Vector3(x0, bas, z)] if vers < 0.0 \
		else [Vector3(x0, haut, z), Vector3(x0, bas, z), Vector3(x1, bas, z),
		Vector3(x1, haut, z)]
	Constructeur._face(g["v"], g["n"], g["c"], g["i"], quatre,
		Vector3(0.0, 0.0, vers), coul)


## Les deux bouts du bloc sous une bande.
static func _bouts(g: Dictionary, x0: float, x1: float, z0: float, y0: float,
		z1: float, y1: float, bas: float, coul: Color) -> void:
	if z1 - z0 < 0.001:
		return
	Constructeur._face(g["v"], g["n"], g["c"], g["i"],
		[Vector3(x1, y0, z0), Vector3(x1, y1, z1), Vector3(x1, bas, z1),
		Vector3(x1, bas, z0)], Vector3(1.0, 0.0, 0.0), coul)
	Constructeur._face(g["v"], g["n"], g["c"], g["i"],
		[Vector3(x0, y0, z0), Vector3(x0, bas, z0), Vector3(x0, bas, z1),
		Vector3(x0, y1, z1)], Vector3(-1.0, 0.0, 0.0), coul)


static func _groupe() -> Dictionary:
	return {"v": PackedVector3Array(), "n": PackedVector3Array(),
		"c": PackedColorArray(), "i": PackedInt32Array()}


static func _mailler(g: Dictionary) -> ArrayMesh:
	if (g["v"] as PackedVector3Array).is_empty():
		return null
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = g["v"]
	arrays[Mesh.ARRAY_NORMAL] = g["n"]
	arrays[Mesh.ARRAY_COLOR] = g["c"]
	arrays[Mesh.ARRAY_INDEX] = g["i"]
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return m


## ⚠ La palette est en sRGB, le rendu en LINÉAIRE — comme `vers_lineaire` de 07.
static func _c(pal: Dictionary, role: String) -> Color:
	if not pal.has(role):
		push_error("échantillon : rôle `%s` absent de la palette" % role)
		return Color.MAGENTA
	return Color(pal[role] as String).srgb_to_linear()


## ⚠ ASSOMBRIT EN sRGB, comme `melanger(…, "#000000", part)` de 07 : le même
## facteur appliqué en linéaire rend une teinte bien trop claire.
static func _sombre(c: Color, part: float) -> Color:
	var s := c.linear_to_srgb()
	return Color(s.r * (1.0 - part), s.g * (1.0 - part), s.b * (1.0 - part),
		c.a).srgb_to_linear()
