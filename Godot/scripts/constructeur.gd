extends RefCounted
# Le noyau de génération de géométrie, isolé derrière une interface propre
# (`Vault/Technique/Moteur et architecture.md:18`) — et cette interface est le
# contrat JSON, pas une hiérarchie de classes.
#
# 07_exporter_godot.py a tout calculé ; ici on EMPAQUETTE des tableaux. Aucune
# décision géométrique, aucune boucle lourde (l.16), aucun accès aux nœuds :
# le jour où ça goulotte, ce fichier se porte en C# par copier-coller.

const PRIM := Mesh.PRIMITIVE_TRIANGLES
# L'arbre porte ses matériaux DANS son maillage (deux surfaces) : un
# `material_override` peindrait le tronc de la couleur du feuillage. L'import
# n'est pas circulaire, `materiaux.gd` ne connaît pas ce fichier.
const Materiaux := preload("res://scripts/materiaux.gd")


## {v, n, c, uv, i} → ArrayMesh, en UN seul add_surface_from_arrays : un
## SurfaceTool coûterait ~95 000 appels de fonction sur le terrain.
## Les tableaux arrivent déjà typés de `donnees.gd` : rien à convertir.
## Couleur : RGB = teinte déjà occluse, ALPHA = l'occlusion seule, dont le
## shader se sert pour repeindre en calque sans perdre l'AO.
static func maillage(d: Dictionary) -> ArrayMesh:
	var v: PackedVector3Array = d["v"]
	# 🪟 UV2 ne descend que sur les maillages à mur percé. Absents, UV et UV2
	# sont des zéros, « pas une façade » pour le shader, mais toujours déclarés.
	var uv: PackedVector2Array = d.get("uv", PackedVector2Array())
	var uv2: PackedVector2Array = d.get("uv2", PackedVector2Array())
	if uv.is_empty():
		uv.resize(v.size())
	if uv2.is_empty():
		uv2.resize(v.size())
	return _surface(v, d["n"], d["c"], d["i"], uv, uv2)


## Une TRANCHE du maillage : `nb` indices depuis `debut`, et les seuls sommets
## qu'ils citent. C'est ce qui donne un nœud par îlot et par tronçon, donc un
## objet cliquable. Les plages viennent de la clé `g`, posée par 07.
static func maillage_groupe(d: Dictionary, debut: int, nb: int) -> ArrayMesh:
	var vs: PackedVector3Array = d["v"]
	var ns: PackedVector3Array = d["n"]
	var cs: PackedColorArray = d["c"]
	var uvs: PackedVector2Array = d.get("uv", PackedVector2Array())
	var uv2s: PackedVector2Array = d.get("uv2", PackedVector2Array())
	# 🏢 (rang de montée, ce sommet suit-il le toit, égout d'origine, pied du
	# bâtiment), quatre flottants à plat par sommet. Seuls les maillages de
	# bâtiments le portent ; absent, CUSTOM0 reste à zéro et rien ne se lève.
	var denses: PackedFloat32Array = d.get("dense", PackedFloat32Array())
	var idx: PackedInt32Array = d["i"]

	# Les indices citent des sommets répartis dans TOUT le tableau : sans
	# renumérotation la tranche traîne les 40 000 sommets des autres.
	var renumerote := {}
	var v := PackedVector3Array()
	var nm := PackedVector3Array()
	var co := PackedColorArray()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	var dn := PackedFloat32Array()
	var i := PackedInt32Array()
	i.resize(nb)
	for k in nb:
		var src: int = idx[debut + k]
		if not renumerote.has(src):
			renumerote[src] = v.size()
			v.append(vs[src])
			nm.append(ns[src])
			co.append(cs[src])
			uv.append(Vector2.ZERO if uvs.is_empty() else uvs[src])
			uv2.append(Vector2.ZERO if uv2s.is_empty() else uv2s[src])
			if not denses.is_empty():
				dn.append_array(denses.slice(src * 4, src * 4 + 4))
		i[k] = renumerote[src]

	return _surface(v, nm, co, i, uv, uv2, dn)


## 🔄 `terrain()` dépliait ici un champ d'altitude en grille. La carte est plate
## depuis le 2026-08-12 : le sol passe par `maillage()` comme tout le reste, et
## Godot n'a plus qu'UNE façon de lire de la géométrie.


static func _surface(v: PackedVector3Array, n: PackedVector3Array,
		c: PackedColorArray, i: PackedInt32Array,
		uv: PackedVector2Array = PackedVector2Array(),
		uv2: PackedVector2Array = PackedVector2Array(),
		dense: PackedFloat32Array = PackedFloat32Array()) -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)          # obligatoire AVANT d'indexer
	arrays[Mesh.ARRAY_VERTEX] = v
	arrays[Mesh.ARRAY_NORMAL] = n
	arrays[Mesh.ARRAY_COLOR] = c
	if not uv.is_empty():
		arrays[Mesh.ARRAY_TEX_UV] = uv
	if not uv2.is_empty():
		arrays[Mesh.ARRAY_TEX_UV2] = uv2
	# 🏢 CUSTOM0, quatre flottants par sommet. ⚠️ Le FORMAT se déclare en
	# drapeau, sinon Godot refuse le tableau : c'est un PackedFloat32Array à
	# plat, quatre valeurs par sommet, jamais un tableau de Vector4.
	var flags := 0
	if not dense.is_empty():
		arrays[Mesh.ARRAY_CUSTOM0] = dense
		flags = Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT
	arrays[Mesh.ARRAY_INDEX] = i
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(PRIM, arrays, [], {}, flags)
	return m


## 🔲 L'EMPRISE D'UN ÎLOT — plaque plate jamais affichée, qui COMPLÈTE la
## silhouette de l'îlot choisi dans le masque.
##
## Un îlot bâti ne dessine pas son sol : sous une barre il n'y a que la plaque
## de terrain, qui n'appartient à personne, donc le trait collait aux bâtiments
## et laissait le gris dehors. La plaque bouche ce trou.
##
## Anneau ouvert et simple (04b : 69/69), d'où la triangulation sans précaution.
## Le sens de parcours est indifférent : le masque n'élimine aucune face.
static func emprise(anneau: Array) -> ArrayMesh:
	if anneau.size() < 3:
		return null
	var plan := PackedVector2Array()
	var v := PackedVector3Array()
	for p in anneau:
		var pt: Array = p
		# Le point porte SON altitude : sinon le trait flotte au-dessus d'un
		# champ en pente.
		v.append(Vector3(float(pt[0]), float(pt[1]), float(pt[2])))
		plan.append(Vector2(float(pt[0]), float(pt[2])))
	var idx := Geometry2D.triangulate_polygon(plan)
	if idx.is_empty():
		# Pas une raison de perdre le trait : il reste la silhouette rendue.
		push_warning("emprise : anneau non triangulable (%d sommets)" % v.size())
		return null
	var nm := PackedVector3Array()
	nm.resize(v.size())
	nm.fill(Vector3.UP)
	var co := PackedColorArray()
	co.resize(v.size())
	co.fill(Color.WHITE)
	return _surface(v, nm, co, idx)


## 🔲 LE RUBAN D'UNE BERGE — deux rails donnés par 07, station par station, et
## un quad entre deux stations. Un couloir de largeur constante mordait sur le
## cœur ancien là où la rive se resserre.
## ⚠️ Des quads qui se recouvrent dans un angle rentrant sont SANS EFFET : le
## masque de sélection est une union de pixels, pas un polygone à trianguler.
static func ruban(rails: Array) -> ArrayMesh:
	if rails.size() < 2:
		return null
	var v := PackedVector3Array()
	var idx := PackedInt32Array()
	for k in rails.size() - 1:
		var a: Array = rails[k]
		var b: Array = rails[k + 1]
		var base := v.size()
		v.append(Vector3(float(a[0]), 0.0, float(a[1])))
		v.append(Vector3(float(a[2]), 0.0, float(a[3])))
		v.append(Vector3(float(b[2]), 0.0, float(b[3])))
		v.append(Vector3(float(b[0]), 0.0, float(b[1])))
		idx.append_array(PackedInt32Array([base, base + 1, base + 2,
			base, base + 2, base + 3]))
	var nm := PackedVector3Array()
	nm.resize(v.size())
	nm.fill(Vector3.UP)
	var co := PackedColorArray()
	co.resize(v.size())
	co.fill(Color.WHITE)
	return _surface(v, nm, co, idx)


## 🔲 LE COULOIR D'UN TRONÇON — ruban plat jamais affiché, qui donne une
## SILHOUETTE D'UN SEUL TENANT à la rue choisie.
##
## Une rue rendue est faite de morceaux disjoints (chaussée, mètres libres, un
## bout de trottoir par riverain) : la détourer donne des bandes parallèles.
## Ce ruban va de façade à façade.
##
## Il est aussi la PLAQUE au sol de la miniature de la fiche, seul endroit où il
## est vraiment dessiné : d'où son sens de parcours, qui n'est plus indifférent.
##
## Les deux bords sont continus et raccordés à onglet : des rectangles qui se
## chevauchent laissaient une dent à chaque sommet dans le trait de sélection.
static func couloir(axes: Array, largeur: float, y: float) -> ArrayMesh:
	var h := largeur / 2.0
	var v := PackedVector3Array()
	var idx := PackedInt32Array()
	for a in axes:
		var plat: Array = a
		var pts := PackedVector2Array()
		for k in range(0, plat.size(), 2):
			var p := Vector2(float(plat[k]), float(plat[k + 1]))
			if pts.is_empty() or pts[-1].distance_squared_to(p) > 1e-6:
				pts.append(p)
		if pts.size() < 2:
			continue
		var gauche := PackedVector2Array()
		var droite := PackedVector2Array()
		for k in pts.size():
			var t1 := Vector2.ZERO
			var t2 := Vector2.ZERO
			if k > 0:
				var u1 := (pts[k] - pts[k - 1]).normalized()
				t1 = Vector2(u1.y, -u1.x)
			if k < pts.size() - 1:
				var u2 := (pts[k + 1] - pts[k]).normalized()
				t2 = Vector2(u2.y, -u2.x)
			var t := (t1 + t2).normalized() if k > 0 and k < pts.size() - 1 \
				else (t2 if k == 0 else t1)
			var d := h / maxf(t.dot(t1 if k > 0 else t2), 0.35)
			gauche.append(pts[k] + t * d)
			droite.append(pts[k] - t * d)
		for k in gauche.size() - 1:
			var b := v.size()
			v.append(Vector3(gauche[k].x, y, gauche[k].y))
			v.append(Vector3(droite[k].x, y, droite[k].y))
			v.append(Vector3(droite[k + 1].x, y, droite[k + 1].y))
			v.append(Vector3(gauche[k + 1].x, y, gauche[k + 1].y))
			# 🔴 EN SENS HORAIRE, comme tout le reste (piège 1 du README) : le
			# ruban n'était qu'un masque, où le sens est indifférent, et il
			# regardait vers le BAS — la plaque de la miniature était invisible.
			idx.append(b)
			idx.append(b + 2)
			idx.append(b + 1)
			idx.append(b)
			idx.append(b + 3)
			idx.append(b + 2)
	if v.size() == 0:
		return null
	# Inutiles au masque (non éclairé, sans élimination) mais `_surface` les
	# attend.
	var nm := PackedVector3Array()
	nm.resize(v.size())
	nm.fill(Vector3.UP)
	var co := PackedColorArray()
	co.resize(v.size())
	co.fill(Color.WHITE)
	return _surface(v, nm, co, idx)


## 🧱 LE SOCLE DE LA MINIATURE — la plaque de la fiche, mais ÉPAISSE. Sans jupe,
## l'objet de la fiche est une découpe posée sur du papier ; avec, c'est un
## morceau de ville qu'on a soulevé.
##
## 🔴 PAS LE MAILLAGE DU MASQUE, et les deux ne se remplacent pas : le couloir
## du masque chevauche ses quadrilatères aux coudes — ça sèmerait des murs À
## L'INTÉRIEUR de la dalle — et une jupe déborderait le trait de sélection.
## Celui-ci est donc à ONGLET, et il est dessiné : son sens de parcours compte.
## La tranche est un peu plus sombre que le dessus : c'est ce qui la fait lire
## comme une épaisseur. 🔴 Pas plus bas : elle tombe presque toujours du côté à
## l'ombre, où la lumière la fonce déjà — à 0,72 elle sortait noire.
const TRANCHE := 0.88


static func socle_ruban(axes: Array, largeur: float, epaisseur: float) -> ArrayMesh:
	var h := largeur / 2.0
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var c := PackedColorArray()
	var idx := PackedInt32Array()
	for a in axes:
		var plat: Array = a
		var pts := PackedVector2Array()
		for k in range(0, plat.size(), 2):
			var p := Vector2(float(plat[k]), float(plat[k + 1]))
			if pts.is_empty() or pts[-1].distance_squared_to(p) > 1e-6:
				pts.append(p)
		if pts.size() < 2:
			continue
		var gauche := PackedVector2Array()
		var droite := PackedVector2Array()
		for k in pts.size():
			var t1 := Vector2.ZERO
			var t2 := Vector2.ZERO
			if k > 0:
				var u1 := (pts[k] - pts[k - 1]).normalized()
				t1 = Vector2(u1.y, -u1.x)
			if k < pts.size() - 1:
				var u2 := (pts[k + 1] - pts[k]).normalized()
				t2 = Vector2(u2.y, -u2.x)
			var t := (t1 + t2).normalized() if k > 0 and k < pts.size() - 1 \
				else (t2 if k == 0 else t1)
			# 🔴 L'ONGLET : au coude le décalage vaut h / cos(demi-angle), et le
			# cosinus est PLAFONNÉ — sans ça un angle aigu envoie la dalle à
			# quarante mètres de la rue.
			var d := h / maxf(t.dot(t1 if k > 0 else t2), 0.35)
			gauche.append(pts[k] + t * d)
			droite.append(pts[k] - t * d)
		_jupe(v, n, c, idx, gauche, droite, epaisseur)
	if v.is_empty():
		return null
	return _surface(v, n, c, idx)


## Le même socle sous un îlot : son emprise, plus la jupe le long de l'anneau.
static func socle_anneau(anneau: Array, epaisseur: float) -> ArrayMesh:
	var dessus := emprise(anneau)
	if dessus == null:
		return null
	var arr: Array = dessus.surface_get_arrays(0)
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var n: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var c: PackedColorArray = arr[Mesh.ARRAY_COLOR]
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	var plan := PackedVector2Array()
	for p in anneau:
		var pt: Array = p
		plan.append(Vector2(float(pt[0]), float(pt[2])))
	# 🔴 L'ANNEAU EST REMIS DANS LE SENS TRIGONOMÉTRIQUE : 04b ne le garantit
	# pas, et la jupe d'un anneau retourné éclaire ses murs par l'intérieur.
	var aire := 0.0
	for k in plan.size():
		var q := plan[(k + 1) % plan.size()]
		aire += plan[k].x * q.y - q.x * plan[k].y
	if aire < 0.0:
		plan.reverse()
	var teinte := Color(TRANCHE, TRANCHE, TRANCHE)
	for k in plan.size():
		var a := plan[k]
		var b := plan[(k + 1) % plan.size()]
		if a.distance_squared_to(b) < 1e-6:
			continue
		var u := (b - a).normalized()
		_face(v, n, c, idx, [_p(a, 0.0), _p(b, 0.0), _p(b, -epaisseur),
			_p(a, -epaisseur)], Vector3(u.y, 0.0, -u.x), teinte)
	return _surface(v, n, c, idx)


## Le dessus d'un ruban, puis les murs qui descendent de ses deux bords et de
## ses deux bouts.
##
## 🔴 Sens HORAIRE partout (piège 1 du README) : chaque face est émise
## `0, 2, 1` puis `0, 3, 2`, donc elle regarde à l'OPPOSÉ de la normale de la
## main droite de ses trois premiers points.
static func _jupe(v: PackedVector3Array, n: PackedVector3Array,
		c: PackedColorArray, idx: PackedInt32Array, gauche: PackedVector2Array,
		droite: PackedVector2Array, epaisseur: float) -> void:
	var teinte := Color(TRANCHE, TRANCHE, TRANCHE)
	var y1 := -epaisseur
	for k in gauche.size() - 1:
		_face(v, n, c, idx, [_p(gauche[k], 0.0), _p(droite[k], 0.0),
			_p(droite[k + 1], 0.0), _p(gauche[k + 1], 0.0)], Vector3.UP,
			Color.WHITE)
		var u := (gauche[k + 1] - gauche[k]).normalized()
		_face(v, n, c, idx, [_p(gauche[k], 0.0), _p(gauche[k + 1], 0.0),
			_p(gauche[k + 1], y1), _p(gauche[k], y1)],
			Vector3(u.y, 0.0, -u.x), teinte)
		var w := (droite[k + 1] - droite[k]).normalized()
		_face(v, n, c, idx, [_p(droite[k], 0.0), _p(droite[k], y1),
			_p(droite[k + 1], y1), _p(droite[k + 1], 0.0)],
			Vector3(-w.y, 0.0, w.x), teinte)
	var d := (gauche[1] - gauche[0]).normalized()
	_face(v, n, c, idx, [_p(gauche[0], 0.0), _p(gauche[0], y1),
		_p(droite[0], y1), _p(droite[0], 0.0)], Vector3(-d.x, 0.0, -d.y), teinte)
	var f := (gauche[-1] - gauche[-2]).normalized()
	_face(v, n, c, idx, [_p(gauche[-1], 0.0), _p(droite[-1], 0.0),
		_p(droite[-1], y1), _p(gauche[-1], y1)], Vector3(f.x, 0.0, f.y), teinte)


static func _p(a: Vector2, y: float) -> Vector3:
	return Vector3(a.x, y, a.y)


static func _face(v: PackedVector3Array, n: PackedVector3Array,
		c: PackedColorArray, idx: PackedInt32Array, quatre: Array,
		normale: Vector3, teinte: Color) -> void:
	var b := v.size()
	for p in quatre:
		v.append(p)
		n.append(normale)
		c.append(teinte)
	idx.append(b)
	idx.append(b + 2)
	idx.append(b + 1)
	idx.append(b)
	idx.append(b + 3)
	idx.append(b + 2)


## UNE instance multiple par ESSENCE, pas un nœud par objet — « le geste se
## prend au début, pas après » (`Génération procédurale.md:74`). Les 69 îlots
## n'en ont pas : un MultiMesh répète UN MÊME mesh, il en faudrait 69 d'une
## instance, donc 69 draw calls au lieu de 1.
##
## 🔄 RETOUR EN ARRIÈRE SIGNALÉ : c'était UNE sphère à six segments, d'où les
## billes vertes d'avant le 2026-08-18. Il manquait un tronc, une couronne qui
## ne soit pas un cercle, une sous-face sombre — trois recettes, aucun asset.
const FEUILLU := 0
const CONIFERE := 1
## 🌿 Les deux plantes d'une rive rendue au fleuve. Mêmes tableaux, même
## MultiMesh, même semis que les arbres : une berge renaturée ne demande pas un
## deuxième système, elle demande deux recettes de plus.
const ROSEAU := 2
const BUISSON := 3
## 🌳 Quatre silhouettes de plus (2026-09-26), choisies par 07 selon le lieu :
## le bouleau des parcs, le peuplier et le saule de l'eau, le fruitier des
## jardins. Toujours la même teinte de feuillage, en valeur (DA l.67).
const BOULEAU := 4
const PEUPLIER := 5
const FRUITIER := 6
const SAULE := 7
## 🌳 L'arbre d'alignement allemand (2026-10-19) : ovale, dense, plus haut que large.
const TILLEUL := 8
const VILLE := [FEUILLU, CONIFERE, BOULEAU, PEUPLIER, FRUITIER, SAULE, TILLEUL]
## 🌸 La VARIÉTÉ d'un arbre, 7e nombre de sa liste ou tirée de sa position, lue
## par `feuillage.gdshader` (INSTANCE_CUSTOM.r) : même recette, autre année.
## Sur un fruitier, ROSE = fleurs roses au lieu de blanches.
## ⚠️ Flaggable (90) : couleurs de floraison choisies par Claude.
const ORDINAIRE := 0
const ROSE := 1         # cerisier à fleurs : rose avant les feuilles, début avril
const MARRONNIER := 2   # bougies blanches en mai
const POURPRE := 3      # hêtre pourpre : rouge vin tout l'été

## La teinte d'instance MULTIPLIE celle du sommet : au-dessus de 1, la tête
## reste plus claire que le vêtement, quel que soit le vêtement tiré.
const TETE := Color(1.18, 1.06, 0.98)


## Une recette unique pour voitures roulantes et garées. La teinte vient de
## l'instance ; 4 000 véhicules restent donc deux MultiMesh et deux appels.
## `circuit` = la voiture de la VILLE : elle ne reboucle pas sur son segment,
## elle s'arrête au bout et c'est `trafic.gd` qui l'engage sur le suivant. La
## fiche, elle, montre un morceau droit sans suite : elle reboucle.
static func voitures(nombre: int, anime := false, circuit := false) -> MultiMesh:
	var mesh := _voiture()
	# La fiche reboucle ses voitures sur 40 m : elles s'effacent au bout.
	mesh.surface_set_material(0, _glisse(anime, 0.0, 0.0, circuit, true,
		0.0 if circuit else 3.0))
	return _instances(mesh, nombre, anime)


## 📏 L'ALLONGEMENT d'une voiture voyage dans l'ALPHA de sa teinte d'instance :
## 1 → 3,33 m, et chaque 0,25 en dessous ajoute 1 m, partagé entre l'avant et
## l'arrière. Les roues sont entières d'un côté de z = 0 : elles glissent sans
## s'étirer. 🔴 Recopié dans `trafic.gdshader` : les deux changent ensemble.
const ALLONGE := "  VERTEX.z += sign(VERTEX.z) * (1.0 - COLOR.a) * 2.0;\n"


## 🌗 CE QUI PORTE L'OMBRE D'UNE VOITURE : caisse et habitacle, 24 triangles au
## lieu de 778. Mesuré sur `voiture.json` : 1,78 × 3,33 m, toit à 1,65 m,
## habitacle de z −1,32 à +0,06 avec le pare-brise penché jusqu'à +0,75.
## Mêmes instances que la voiture, donc même matériau (les roulantes y lisent
## leur trajet).
static func voitures_ombre(nombre: int, anime := false) -> MultiMesh:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var c := PackedColorArray()
	var i := PackedInt32Array()
	_boite(v, n, c, i, Vector3(1.76, 0.85, 3.3), Vector3(0.0, 0.575, 0.0), Color.WHITE)
	_boite(v, n, c, i, Vector3(1.38, 0.65, 1.8), Vector3(0.0, 1.325, -0.55), Color.WHITE)
	var mesh := _surface(v, n, c, i)
	mesh.surface_set_material(0, _glisse(anime, 0.0, 0.0, false, true))
	return _instances(mesh, nombre, anime)


## 🚗 LA VOITURE VUE DE LOIN : 48 triangles au lieu de 778, mêmes cotes que l'ombre
## ci-dessus — dessous sombre, caisse, vitrage, toit. Au-delà de
## `Trafic.TAILLE_VOITURE_SIMPLE` elle fait une vingtaine de pixels : les 2 000
## instances y coûtaient 2 à 3 ms de GPU (GTX 1650, 2026-10-30). Le matériau
## est celui de la voiture qu'elle remplace : l'appelant le pose.
static func voiture_simple() -> ArrayMesh:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var c := PackedColorArray()
	var i := PackedInt32Array()
	var sombre := Color(0.10, 0.10, 0.11)
	_boite(v, n, c, i, Vector3(1.62, 0.30, 3.0), Vector3(0.0, 0.15, 0.0), sombre)
	_boite(v, n, c, i, Vector3(1.76, 0.62, 3.3), Vector3(0.0, 0.58, 0.0), Color.WHITE)
	_boite(v, n, c, i, Vector3(1.40, 0.48, 1.80), Vector3(0.0, 1.13, -0.50),
		Color(0.16, 0.18, 0.21))
	_boite(v, n, c, i, Vector3(1.36, 0.10, 1.56), Vector3(0.0, 1.42, -0.58), Color.WHITE)
	return _surface(v, n, c, i)


## 🚗 La voiture allégée par `outils/voiture_blender.py` (778 triangles, 3,33 m,
## avant vers +z) : carrosserie blanche, la teinte d'instance la peint. Lue une
## fois, puis copiée : chaque appelant pose son propre matériau sur la surface 0.
const VOITURE := "res://data/voiture.json"
static var _voiture_lue: Dictionary


static func _voiture() -> ArrayMesh:
	if _voiture_lue.is_empty():
		_voiture_lue = JSON.parse_string(FileAccess.get_file_as_string(VOITURE))
	var d := _voiture_lue
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var c := PackedColorArray()
	for k in d["v"].size():
		v.append(Vector3(d["v"][k][0], d["v"][k][1], d["v"][k][2]))
		n.append(Vector3(d["n"][k][0], d["n"][k][1], d["n"][k][2]))
		c.append(Color(d["c"][k][0], d["c"][k][1], d["c"][k][2]))
	return _surface(v, n, c, PackedInt32Array(d["i"]))


## 🚶 UN PIÉTON — trois boîtes : jambes, buste, tête. 🔴 DEUX NE
## SUFFISAIENT PAS : une seule boîte du sol aux épaules se lisait comme une
## borne de trottoir. C'est l'étranglement des jambes qui fait la silhouette.
## Il avance le long de son segment ; le balancement de la marche est dans le
## shader, donc le CPU n'en sait rien.
static func pietons(nombre: int) -> MultiMesh:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var c := PackedColorArray()
	var i := PackedInt32Array()
	_boite(v, n, c, i, Vector3(0.26, 0.84, 0.24), Vector3(0.0, 0.42, 0.0),
		Color(0.46, 0.46, 0.50))
	_boite(v, n, c, i, Vector3(0.42, 0.62, 0.28), Vector3(0.0, 1.13, 0.0),
		Color.WHITE)
	_boite(v, n, c, i, Vector3(0.22, 0.24, 0.22), Vector3(0.0, 1.57, 0.0),
		TETE)
	var mesh := _surface(v, n, c, i)
	# 3,5 cm de balancement à 1,9 pas par seconde : à 45 m c'est le seul indice
	# qui distingue un marcheur d'un plot posé sur le trottoir.
	mesh.surface_set_material(0, _glisse(true, 0.035, 1.9, false, false, 1.5))
	return _instances(mesh, nombre, true)


## 🚲 UN CYCLISTE — trois boîtes : le vélo, le buste penché, la tête.
## Il roule dans la chaussée, à sa vitesse propre : la congestion des voitures
## ne le ralentit pas, et c'est le sujet.
static func cyclistes(nombre: int) -> MultiMesh:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var c := PackedColorArray()
	var i := PackedInt32Array()
	_boite(v, n, c, i, Vector3(0.16, 0.66, 1.68), Vector3(0.0, 0.33, 0.0),
		Color(0.16, 0.17, 0.19))
	_boite(v, n, c, i, Vector3(0.42, 0.74, 0.32), Vector3(0.0, 1.00, -0.06),
		Color.WHITE)
	_boite(v, n, c, i, Vector3(0.22, 0.23, 0.22), Vector3(0.0, 1.49, -0.10),
		TETE)
	var mesh := _surface(v, n, c, i)
	# Le pédalage : deux fois plus rapide que le pas, deux fois moins ample.
	mesh.surface_set_material(0, _glisse(true, 0.018, 3.6, false, false, 2.5))
	return _instances(mesh, nombre, true)


## L'horloge que le CPU et le GPU partagent. Sans elle, `trafic.gd` ne saurait
## pas OÙ le shader a posé la voiture, donc pas quand l'engager sur le segment
## suivant : `TIME` n'est lisible que du GPU.
const HORLOGE := "temps_trafic"


## Le matériau de TOUT CE QUI GLISSE. `INSTANCE_CUSTOM` porte (phase, vitesse
## en m/s, longueur du segment) : le vertex avance seul, à la fréquence de
## l'écran, et le CPU ne déplace personne. Sans balancement, le code émis est
## exactement celui des usagers doux — ne pas y ajouter de terme mort.
## `circuit` change UNE chose : la course s'arrête au bout du segment au lieu
## d'y reboucler, et un retard d'une image se voit comme un arrêt, pas comme un
## saut en arrière.
## `fondu` : les mètres où il naît et s'efface aux deux bouts du segment, en trame —
## sans lui le bouclage se voyait comme un saut de 65 m en arrière (2026-10-30).
static func _glisse(anime: bool, balance := 0.0, cadence := 0.0,
		circuit := false, allonge := false, fondu := 0.0) -> Material:
	var etire := ALLONGE if allonge else ""
	if not anime and allonge:
		var fixe := Shader.new()
		fixe.code = "shader_type spatial;\nvarying vec4 teinte;\nvoid vertex() {\n" \
			+ etire + "  teinte = COLOR;\n}\n" \
			+ "void fragment() { ALBEDO = teinte.rgb; ROUGHNESS = 0.72; }\n"
		var garee := ShaderMaterial.new()
		garee.shader = fixe
		return garee
	if not anime:
		var std := StandardMaterial3D.new()
		std.vertex_color_use_as_albedo = true
		std.roughness = 0.72
		return std
	# Tout ce qui glisse suit l'horloge partagée, jamais `TIME` : elle s'arrête
	# quand le temps est en pause (auteur, 2026-09-28), `TIME` jamais. Déclarée
	# dans `project.godot`, parce que l'eau la lit avant la première voiture.
	var pas := ""
	if balance > 0.0:
		pas = "  VERTEX.y += %f * sin(%s * %f + INSTANCE_CUSTOM.x);\n" \
			% [balance, HORLOGE, cadence * TAU]
	var course := "mod(INSTANCE_CUSTOM.x + %s * INSTANCE_CUSTOM.y, longueur)"
	if circuit:
		course = "clamp(INSTANCE_CUSTOM.x + %s * INSTANCE_CUSTOM.y, 0.0, longueur)"
	var entete := "global uniform float %s;\n" % HORLOGE
	var horloge := HORLOGE
	var avance := "  VERTEX.z += " + (course % horloge) + ";\n"
	var jeter := ""
	if fondu > 0.0:
		entete += "varying float fondu;\n"
		avance = "  float course = " + (course % horloge) + ";\n" \
			+ "  fondu = clamp(min(course, longueur - course) / min(%f, 0.3 * longueur), 0.0, 1.0);\n" % fondu \
			+ "  VERTEX *= step(0.001, fondu);\n" \
			+ "  VERTEX.z += course;\n"
		# Bruit de gradient entrelacé : opaque, sans tri, il s'éteint grain à grain.
		jeter = "  if (fondu < fract(52.9829 * fract(dot(FRAGCOORD.xy, vec2(0.06711, 0.00584))))) { discard; }\n"
	var shader := Shader.new()
	shader.code = "shader_type spatial;\n" \
		+ entete \
		+ "varying vec4 teinte;\n" \
		+ "void vertex() {\n" \
		+ etire \
		+ "  float longueur = max(INSTANCE_CUSTOM.z, 0.01);\n" \
		+ avance \
		+ pas \
		+ "  teinte = COLOR;\n" \
		+ "}\n" \
		+ "void fragment() {\n" + jeter + "  ALBEDO = teinte.rgb; ROUGHNESS = 0.72;\n}\n"
	var mat := ShaderMaterial.new()
	mat.shader = shader
	return mat


static func _instances(mesh: Mesh, nombre: int, anime: bool) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = anime
	mm.mesh = mesh
	mm.instance_count = nombre
	return mm


static func _boite(v: PackedVector3Array, n: PackedVector3Array,
		c: PackedColorArray, i: PackedInt32Array, taille: Vector3,
		centre: Vector3, couleur: Color) -> void:
	var h := taille * 0.5
	var faces := [
		[Vector3.RIGHT, [Vector3(h.x,-h.y,-h.z), Vector3(h.x,-h.y,h.z), Vector3(h.x,h.y,h.z), Vector3(h.x,h.y,-h.z)]],
		[Vector3.LEFT, [Vector3(-h.x,-h.y,h.z), Vector3(-h.x,-h.y,-h.z), Vector3(-h.x,h.y,-h.z), Vector3(-h.x,h.y,h.z)]],
		[Vector3.UP, [Vector3(-h.x,h.y,-h.z), Vector3(h.x,h.y,-h.z), Vector3(h.x,h.y,h.z), Vector3(-h.x,h.y,h.z)]],
		[Vector3.DOWN, [Vector3(-h.x,-h.y,h.z), Vector3(h.x,-h.y,h.z), Vector3(h.x,-h.y,-h.z), Vector3(-h.x,-h.y,-h.z)]],
		# 🔧 CORRIGÉ le 2026-09-18 : les deux faces en Z portaient la normale de
		# l'AUTRE — Godot nomme BACK le +Z. Les longs côtés d'un abri, d'une
		# voiture ou d'un piéton étaient éclairés à l'envers.
		[Vector3.BACK, [Vector3(h.x,-h.y,h.z), Vector3(-h.x,-h.y,h.z), Vector3(-h.x,h.y,h.z), Vector3(h.x,h.y,h.z)]],
		[Vector3.FORWARD, [Vector3(-h.x,-h.y,-h.z), Vector3(h.x,-h.y,-h.z), Vector3(h.x,h.y,-h.z), Vector3(-h.x,h.y,-h.z)]],
	]
	for f in faces:
		var b := v.size()
		for p in f[1]:
			v.append(p + centre)
			n.append(f[0])
			c.append(couleur)
		i.append_array(PackedInt32Array([b, b + 1, b + 2, b, b + 2, b + 3]))


## 🌿 La noue du parc inondable, recopiée du shader (`noue`, materiaux.gd) :
## au-dessus de 0,42 commencent les joncs, puis l'eau.
static func noue(x: float, z: float) -> float:
	return sin(x * 0.11 + 1.3) * sin(z * 0.13 + 0.7) + 0.6 * sin((x - z) * 0.07 + 2.1)


## 🌿 LES ARBRES D'UN PARC INONDABLE (95) : semés sur la dalle des ruines, que
## 07 marque d'un égout à −1 — là où étaient les maisons. Saules près de l'eau,
## feuillus ailleurs, aucun dans la noue. Tirage fixe : deux captures égales.
const PARC_M2_PAR_ARBRE := 110.0

static func semis_parc(mesh: Mesh) -> Array:
	var liste := []
	if mesh == null or mesh.get_surface_count() == 0:
		return liste
	var a: Array = mesh.surface_get_arrays(0)
	var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var nm: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
	var cu = a[Mesh.ARRAY_CUSTOM0]
	var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX]
	if cu == null or (cu as PackedFloat32Array).is_empty():
		return liste
	var c0: PackedFloat32Array = cu
	var j := 0
	for t in range(0, idx.size(), 3):
		var i0 := idx[t]
		# La dalle seule : ni débris (−2), ni crête de mur cassé, qui regarde aussi le ciel.
		var marque := c0[i0 * 4 + 2]
		if marque > -0.5 or marque < -1.5 or nm[i0].y < 0.9 \
				or v[i0].y > c0[i0 * 4 + 3] + 0.2:
			continue
		var p0 := v[i0]
		var p1 := v[idx[t + 1]]
		var p2 := v[idx[t + 2]]
		var aire := 0.5 * (p1 - p0).cross(p2 - p0).length()
		var n := int(aire / PARC_M2_PAR_ARBRE + fmod(float(t) * 0.618034, 1.0))
		for k in n:
			j += 1
			var r1 := fmod(float(j) * 0.618034 + 0.31, 1.0)
			var r2 := fmod(float(j) * 0.381966 + 0.72, 1.0)
			if r1 + r2 > 1.0:
				r1 = 1.0 - r1
				r2 = 1.0 - r2
			var p := p0 + (p1 - p0) * r1 + (p2 - p0) * r2
			var w := noue(p.x, p.z)
			if w > 0.40:
				continue
			liste.append([p.x, p.y, p.z, 0.80 + 0.40 * fmod(float(j) * 0.7548, 1.0),
				float(j) * 1.7, SAULE if w > 0.05 else FEUILLU])
	return liste


static func arbres(liste: Array, essence: int, feuillage: Color,
		tronc: Color) -> MultiMesh:
	var pris: Array = []
	for a in liste:
		# Les exports d'avant le 2026-08-18 n'ont que cinq nombres : tout y est
		# feuillu, donc l'ancienne forêt.
		var e: int = int(a[5]) if (a as Array).size() > 5 else FEUILLU
		if e == essence:
			pris.append(a)

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = arbre(essence, tronc)
	mm.instance_count = pris.size()

	for k in pris.size():
		var a: Array = pris[k]
		mm.set_instance_transform(k, pose(a, essence))
		mm.set_instance_custom_data(k, Color(float(variete(a, essence)), 0.0, 0.0, 0.0))
		# Variation de valeur, pas de teinte (Direction artistique l.67).
		var f: float = 0.86 + 0.28 * fmod(abs(float(a[4])) * 7.3, 1.0)
		mm.set_instance_color(k, Color(feuillage.r * f, feuillage.g * f,
			feuillage.b * f))
	return mm


## 🌸 Donnée par la liste (un alignement : une variété par rue), sinon tirée
## du lieu. Parts à juger à l'écran.
static func variete(a: Array, essence: int) -> int:
	if a.size() > 6:
		return int(a[6])
	var t := fposmod(sin(float(a[0]) * 12.9898 + float(a[2]) * 78.233) * 43758.5453, 1.0)
	if essence == FRUITIER:
		return ROSE if t < 0.35 else ORDINAIRE
	if essence != FEUILLU:
		return ORDINAIRE
	if t < 0.08:
		return ROSE
	if t < 0.14:
		return MARRONNIER
	return POURPRE if t < 0.18 else ORDINAIRE


## 🌳 La pose d'un arbre : [x, y, z, échelle, lacet]. Élancé ou trapu, un peu
## penché — tiré du lacet, donc la même ville plante les mêmes arbres. Le
## bouleau et le saule penchent plus : c'est ce qui les fait lire.
## 🔄 Le mesh a son PIED À L'ORIGINE : il penche autour de son pied.
static func pose(a: Array, essence: int) -> Transform3D:
	var ech := float(a[3])
	var lacet := float(a[4])
	var h := fmod(absf(lacet) * 3.17 + 0.21, 1.0)
	var l := fmod(absf(lacet) * 5.31 + 0.47, 1.0)
	# Élancé ou étalé : largeur et hauteur tirées à part (2026-10-19, plus d'écart).
	var b := Basis(Vector3.UP, lacet).scaled(Vector3(
		ech * lerpf(0.84, 1.16, l), ech * lerpf(0.84, 1.18, h), ech * lerpf(0.84, 1.16, l)))
	var penche := deg_to_rad(6.0 if essence == BOULEAU or essence == SAULE else 2.5) \
		* fmod(absf(lacet) * 11.7, 1.0)
	b = Basis(Vector3(cos(lacet * 2.3), 0.0, sin(lacet * 2.3)), penche) * b
	return Transform3D(b, Vector3(float(a[0]), float(a[1]), float(a[2])))


## 🌳 LES MODÈLES DE L'AUTEUR (packs craftpix « Free Tree » et « Free Bush 3D Low
## Poly », 2026-10-22) : leur FORME seule. Teinte, saisons et écorce restent les
## nôtres (auteur) ; la texture du pack, verte en haut, brune en bas, ne sert
## qu'à trier couronne et bois. Les numéros sont ceux de la planche de l'auteur.
const MODELES := {FEUILLU: "Tree_temp_climate_007", CONIFERE: "Tree_temp_climate_018",
	BOULEAU: "Tree_temp_climate_005", PEUPLIER: "Tree_temp_climate_004",
	FRUITIER: "Tree_temp_climate_002", SAULE: "Tree_temp_climate_015",
	TILLEUL: "Tree_temp_climate_006", BUISSON: "Bush_temp_climate_007"}
## Hauteur et largeur des recettes d'avant, mesurées le 2026-10-22 : semis,
## alignements et part d'ombre des fiches y sont réglés. Le modèle s'y étire.
const HAUTEUR := {FEUILLU: 7.4, CONIFERE: 7.5, BOULEAU: 8.1, PEUPLIER: 11.8,
	FRUITIER: 3.8, SAULE: 5.8, TILLEUL: 9.0, BUISSON: 1.5}
const LARGEUR := {FEUILLU: 5.25, CONIFERE: 4.0, BOULEAU: 2.55, PEUPLIER: 3.1,
	FRUITIER: 3.5, SAULE: 5.55, TILLEUL: 4.05, BUISSON: 1.8}
static var _modeles := {}   # essence -> [[tableaux, lods] couronne, bois?, bois de ville?], pied à l'origine
## L'écart admis entre le modèle et sa version de loin, en mètres : Godot passe à
## celle-ci quand l'écart tombe sous un pixel. Sans elle, la forêt coûtait +7 ms
## en vue d'ensemble ; avec, le même temps que l'ancienne forêt (2026-10-22).
const LOD_LOIN := 0.5
## Le bois de ville perd sa ramure (`_ramure_pack`) quand cet écart, en mètres, tombe
## sous un pixel : en vue d'ensemble, ses brindilles ne se voient plus.
const RAMURE_LOIN := 0.5


## Lu une fois par essence. Vide si le modèle manque : la recette d'avant reprend.
## Chaque bloc de feuillage porte son centre en CUSTOM0 (rôle COURONNE) : nu,
## il se resserre sur lui-même au lieu de glisser vers l'axe de l'arbre.
static func _modele(essence: int) -> Array:
	if _modeles.has(essence):
		return _modeles[essence]
	_modeles[essence] = []
	if not MODELES.has(essence):
		return []
	var doc := FBXDocument.new()
	var etat := FBXState.new()
	var chemin := "res://modeles/arbres/%s.fbx" % MODELES[essence]
	if doc.append_from_file(chemin, etat) != OK:
		push_warning("arbre : %s illisible, recette d'avant" % chemin)
		return []
	var racine := doc.generate_scene(etat)
	# La soupe de triangles, dans le repère de la racine.
	var sv := PackedVector3Array()
	var sn := PackedVector3Array()
	var su := PackedFloat32Array()
	for mi: MeshInstance3D in racine.find_children("*", "MeshInstance3D", true, false):
		var t := mi.transform
		var p := mi.get_parent()
		while p != racine and p is Node3D:
			t = (p as Node3D).transform * t
			p = p.get_parent()
		for s in mi.mesh.get_surface_count():
			var a := mi.mesh.surface_get_arrays(s)
			var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
			var nm: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
			var uv: PackedVector2Array = a[Mesh.ARRAY_TEX_UV]
			var idx = a[Mesh.ARRAY_INDEX]
			if idx == null:
				idx = PackedInt32Array(range(v.size()))
			for k in idx:
				sv.append(t * v[k])
				sn.append((t.basis * nm[k]).normalized())
				su.append(uv[k].y)
	racine.free()
	if sv.is_empty():
		return []

	# Le pied : le bas du bois, sinon le milieu (un buisson n'a pas de tronc).
	var bas := INF
	var haut := -INF
	for q in sv:
		bas = minf(bas, q.y)
		haut = maxf(haut, q.y)
	var pied := Vector3.ZERO
	var nb := 0
	for k in sv.size():
		if su[k] >= 0.5 and sv[k].y < bas + 0.25:
			pied += sv[k]
			nb += 1
	if nb > 0:
		pied /= nb
	else:
		var b := AABB(sv[0], Vector3.ZERO)
		for q in sv:
			b = b.expand(q)
		pied = b.get_center()
	pied.y = bas
	var emprise := AABB(sv[0], Vector3.ZERO)
	for q in sv:
		emprise = emprise.expand(q)
	var ech := Vector3.ONE * float(HAUTEUR[essence]) / (haut - bas)
	var l := float(LARGEUR[essence]) / (0.5 * (emprise.size.x + emprise.size.z) * ech.y)
	ech.x *= l
	ech.z *= l
	for k in sv.size():
		sv[k] = (sv[k] - pied) * ech
		sn[k] = (sn[k] / ech).normalized()
	haut = (haut - bas) * ech.y

	# Les blocs de feuillage : sommets soudés au millimètre, triangles réunis.
	var cv := PackedVector3Array()
	var cn := PackedVector3Array()
	var bv := PackedVector3Array()
	var bn := PackedVector3Array()
	for t in range(0, sv.size(), 3):
		var couronne := su[t] + su[t + 1] + su[t + 2] < 1.5
		for j in 3:
			(cv if couronne else bv).append(sv[t + j])
			(cn if couronne else bn).append(sn[t + j])
	var cle := {}
	var soude := PackedInt32Array()
	for q in cv:
		var k := Vector3i((q * 1000.0).round())
		if not cle.has(k):
			cle[k] = cle.size()
		soude.append(cle[k])
	var chef := PackedInt32Array(range(cle.size()))
	for t in range(0, soude.size(), 3):
		for j in [1, 2]:
			var r1 := _chef(chef, soude[t])
			var r2 := _chef(chef, soude[t + j])
			chef[r1] = r2
	var blocs := {}   # chef -> AABB du bloc
	for k in cv.size():
		var r := _chef(chef, soude[k])
		blocs[r] = (blocs[r] as AABB).expand(cv[k]) if blocs.has(r) else AABB(cv[k], Vector3.ZERO)

	var x := PackedFloat32Array()
	var c := PackedColorArray()
	for k in cv.size():
		var b: AABB = blocs[_chef(chef, soude[k])]
		var centre := b.get_center()
		c.append(_degrade(b, cv[k].y, haut))
		x.append_array(PackedFloat32Array([centre.x, centre.y, centre.z, COURONNE]))

	# 🔭 Le même arbre de loin : un volume à six côtés par bloc (les trois plus
	# gros ; tous pour le conifère, ses étages font sa silhouette), le bois en un fût.
	var gros: Array = blocs.values()
	gros.sort_custom(func(p: AABB, q: AABB) -> bool: return p.get_volume() > q.get_volume())
	if essence != CONIFERE:
		gros = gros.slice(0, 3)
	var n0 := cv.size()
	var sous := INF
	for b: AABB in gros:
		_bloc_loin(cv, cn, b, essence == CONIFERE)
		sous = minf(sous, b.position.y)
		var centre := b.get_center()
		for k in range(c.size(), cv.size()):
			c.append(_degrade(b, cv[k].y, haut))
			x.append_array(PackedFloat32Array([centre.x, centre.y, centre.z, COURONNE]))
	var lu := [[_tableaux(cv, cn, c, x, n0), {LOD_LOIN: PackedInt32Array(range(n0, cv.size()))}]]
	if not bv.is_empty():
		var b0 := bv.size()
		var r := maxf(0.1, 0.06 * float(LARGEUR[essence]))
		var cime := 0.0
		for q in bv:
			cime = maxf(cime, q.y)
		# Jusque dans la couronne ; le saule, dont les rideaux tombent bas, jusqu'à son dôme.
		_fut(bv, bn, r, maxf(sous + 0.3, 0.75 * cime))
		var bc := PackedColorArray()
		bc.resize(bv.size())
		bc.fill(Color.WHITE)
		var bx := PackedFloat32Array()
		bx.resize(bv.size() * 4)
		bx.fill(FIXE)
		lu.append([_tableaux(bv, bn, bc, bx, b0), {LOD_LOIN: PackedInt32Array(range(b0, bv.size()))}])
		# Le bois de ville, ramure comprise : la forêt n'en a pas (22 000 arbres).
		if essence != SAULE:
			var t := _ramure_pack(bv.slice(0, b0), blocs.values(), essence)
			var fv := bv.slice(0, b0)
			var fn := bn.slice(0, b0)
			var fc := bc.slice(0, b0)
			var fx := bx.slice(0, b0 * 4)
			fv.append_array(t.v)
			fn.append_array(t.n)
			fc.append_array(t.c)
			fx.append_array(t.x)
			var a := _tableaux(fv, fn, fc, fx, b0)
			# Indexée : déroulée en triangles, la ramure coûtait 2,25 fois plus de sommets.
			var fi: PackedInt32Array = a[Mesh.ARRAY_INDEX]
			for k in t.i:
				fi.append(b0 + k)
			a[Mesh.ARRAY_INDEX] = fi
			lu.append([a, {RAMURE_LOIN: PackedInt32Array(range(b0))}])
	_modeles[essence] = lu
	return lu


## Le dégradé des lobes d'avant (0,66 → 1,10), moitié dans le bloc, moitié dans l'arbre.
static func _degrade(b: AABB, y: float, haut: float) -> Color:
	var dans := clampf(inverse_lerp(b.position.y, b.end.y, y), 0.0, 1.0) 		if b.size.y > 0.01 else 1.0
	var g := lerpf(0.66, 1.10, 0.5 * dans + 0.5 * y / haut)
	return Color(g, g, g, 1.0)


## Le bloc vu de loin : deux anneaux décalés et deux pointes (24 triangles), ou
## un cône ouvert dessous pour un étage de conifère (6).
static func _bloc_loin(v: PackedVector3Array, n: PackedVector3Array, b: AABB, cone: bool) -> void:
	var o := b.get_center()
	var h := b.size * 0.46
	var sommet := o + Vector3(0.0, h.y, 0.0)
	if cone:
		var a := _anneau(o, h, -1.0, 1.0, 0.0)
		for i in 6:
			_tri(v, n, a[i], a[(i + 1) % 6], sommet, o)
		return
	var bas := o - Vector3(0.0, h.y, 0.0)
	var a1 := _anneau(o, h, -0.40, 0.94, 0.0)
	var a2 := _anneau(o, h, 0.38, 0.86, PI / 6.0)
	for i in 6:
		var j := (i + 1) % 6
		_tri(v, n, bas, a1[i], a1[j], o)
		_tri(v, n, a1[i], a1[j], a2[i], o)
		_tri(v, n, a2[i], a1[j], a2[j], o)
		_tri(v, n, a2[i], a2[j], sommet, o)


static func _anneau(o: Vector3, h: Vector3, t: float, f: float, decale: float) -> Array:
	var a := []
	for i in 6:
		var ang := float(i) * TAU / 6.0 + decale
		a.append(o + Vector3(cos(ang) * h.x * f, t * h.y, sin(ang) * h.z * f))
	return a


## Le fût vu de loin : quatre faces, du pied jusque dans la couronne.
static func _fut(v: PackedVector3Array, n: PackedVector3Array, r: float, haut: float) -> void:
	for i in 4:
		var a0 := float(i) * TAU / 4.0
		var a1 := a0 + TAU / 4.0
		var p0 := Vector3(cos(a0) * r, 0.0, sin(a0) * r)
		var p1 := Vector3(cos(a1) * r, 0.0, sin(a1) * r)
		var q0 := Vector3(p0.x * 0.6, haut, p0.z * 0.6)
		var q1 := Vector3(p1.x * 0.6, haut, p1.z * 0.6)
		var axe := Vector3(0.0, haut * 0.5, 0.0)
		_tri(v, n, p0, p1, q1, axe)
		_tri(v, n, p0, q1, q0, axe)


## Une face plate tournée vers le dehors de `dedans` : Godot montre la face
## dont le produit vectoriel des côtés pointe vers l'intérieur.
static func _tri(v: PackedVector3Array, n: PackedVector3Array, a: Vector3, b: Vector3,
		c: Vector3, dedans: Vector3) -> void:
	var cr := (b - a).cross(c - a)
	if cr.dot((a + b + c) / 3.0 - dedans) > 0.0:
		var t := b
		b = c
		c = t
		cr = -cr
	var nn := -cr.normalized()
	v.append_array(PackedVector3Array([a, b, c]))
	n.append_array(PackedVector3Array([nn, nn, nn]))


static func _chef(chef: PackedInt32Array, k: int) -> int:
	while chef[k] != k:
		chef[k] = chef[chef[k]]
		k = chef[k]
	return k


## `n0` premiers sommets : le modèle ; les suivants : sa version de loin (LOD).
static func _tableaux(v: PackedVector3Array, n: PackedVector3Array, c: PackedColorArray,
		x: PackedFloat32Array, n0: int) -> Array:
	var a := []
	a.resize(Mesh.ARRAY_MAX)
	a[Mesh.ARRAY_VERTEX] = v
	a[Mesh.ARRAY_NORMAL] = n
	a[Mesh.ARRAY_COLOR] = c
	a[Mesh.ARRAY_CUSTOM0] = x
	a[Mesh.ARRAY_INDEX] = PackedInt32Array(range(n0))
	return a


## 🌳 UNE RECETTE PAR ESSENCE, et chaque arbre la joue à sa façon : chaque lobe
## porte son centre et son rôle, et `feuillage.gdshader` grossit, déplace ou
## efface les lobes satellites d'après la position de l'arbre. Mille arbres,
## mille couronnes, un seul mesh et un seul appel par essence.
## Deux surfaces : la couronne suit la teinte d'instance, le tronc non — d'où
## l'absence de `material_override` sur les arbres.
## `foret` = la demi-emprise du décor : l'arbre de la forêt est la même
## recette en plus léger, et se perd dans la brume du bord.
## ❄️ Nu, la part de couronne gardée en brume de rameaux. La forêt et le buisson
## n'ont pas de branches : sans brume, ils disparaîtraient.
## 🔄 La ville n'en garde plus (0,3 jusqu'au 2026-10-22) : ses bouts flottaient
## autour des branches du pack (auteur) ; `_ramure_pack` les remplace.
const BRUME_FORET := 0.6
const BRUME_BUISSON := 0.7
const BRUME_VILLE := 0.0
const FIXE := 0.0       # ni grossi ni déplacé : brins, tronc
const COURONNE := 1.0   # le corps de l'arbre : ±10 %, jamais effacé
const SATELLITE := 2.0  # 2, 3, 4… : grossi, déplacé, parfois absent

static func arbre(essence: int, tronc: Color, foret := Vector2.ZERO) -> ArrayMesh:
	var m := ArrayMesh.new()
	var brume := BRUME_FORET if foret != Vector2.ZERO \
		else (BRUME_BUISSON if essence == BUISSON else BRUME_VILLE)
	var lu := _modele(essence)
	if not lu.is_empty():
		# 🔭 La version de loin pour la forêt seule : en ville elle ne gagnait rien
		# (sonde du 2026-10-22) et cachait les modèles dès 340 m de recul.
		var loin := foret != Vector2.ZERO
		m.add_surface_from_arrays(PRIM, lu[0][0], [], lu[0][1] if loin else {}, _Volume.FORMAT)
		m.surface_set_material(0, Materiaux.feuillage(foret, essence, brume))
		if lu.size() > 1:
			var ramure := lu.size() > 2 and not loin
			var bois: Array = lu[2] if ramure else lu[1]
			m.add_surface_from_arrays(PRIM, bois[0], [], bois[1] if loin or ramure else {}, _Volume.FORMAT)
			m.surface_set_material(1, Materiaux.ecorce(tronc, foret, essence))
		return m

	# 🔄 RETOUR EN ARRIÈRE SIGNALÉ (2026-10-22) : les recettes ci-dessous ne
	# servent plus qu'au roseau, et en secours si un modèle manque.
	var f := _Volume.new()
	f.cotes = 6 if foret != Vector2.ZERO else 8
	# En forêt, deux satellites suffisent : 22 000 arbres, vus de loin.
	f.satellites = 2 if foret != Vector2.ZERO else 9

	if essence == ROSEAU:
		# La touffe : cinq brins penchés en éventail. Ce qui la fait lire de
		# loin est qu'ils ne sont ni de la même hauteur ni du même côté.
		f.brin(Vector3(0.00, 0.0, 0.00), 2.05, 0.16, 0.0)
		f.brin(Vector3(0.26, 0.0, -0.15), 1.70, 0.30, 2.1)
		f.brin(Vector3(-0.20, 0.0, 0.22), 1.42, 0.26, 4.3)
		f.brin(Vector3(0.13, 0.0, 0.30), 1.15, 0.34, 5.5)
		f.brin(Vector3(-0.28, 0.0, -0.10), 0.92, 0.30, 1.0)
	elif essence == BUISSON:
		# Bas et décentré : un buisson, pas un arbre nain.
		f.lobe(Vector3(0.0, 0.72, 0.0), 0.86, 0.52, 1.02, COURONNE)
		f.lobe(Vector3(0.52, 0.50, 0.34), 0.60, 0.48, 0.94, SATELLITE)
		f.lobe(Vector3(-0.45, 0.46, -0.30), 0.52, 0.46, 0.92, SATELLITE + 1)
	elif essence == CONIFERE:
		# Un épicéa se lit à sa SILHOUETTE : quatre étages, chacun à sa largeur.
		f.cone(2.00, 1.00, 2.70, 0.60, 0.80, COURONNE)
		f.cone(1.60, 2.40, 2.60, 0.72, 0.92, COURONNE)
		f.cone(1.18, 3.80, 2.50, 0.84, 1.04, COURONNE)
		f.cone(0.74, 5.20, 2.30, 0.96, 1.14, COURONNE)
	elif essence == BOULEAU:
		# Une couronne étroite, haute et ajourée, sur un fût clair.
		f.lobe(Vector3(0.0, 5.2, 0.0), 1.45, 0.70, 1.12, COURONNE)
		f.lobe(Vector3(0.35, 6.6, -0.2), 1.00, 0.80, 1.18, SATELLITE)
		f.lobe(Vector3(-0.45, 4.3, 0.3), 1.05, 0.66, 1.00, SATELLITE + 1)
		f.lobe(Vector3(-0.15, 7.5, 0.25), 0.68, 0.86, 1.20, SATELLITE + 2)
		f.lobe(Vector3(0.55, 4.5, 0.45), 0.80, 0.66, 1.00, SATELLITE + 3)
	elif essence == PEUPLIER:
		# Le fuseau : un cône qui s'ouvre, puis un cône qui se ferme.
		f.cone(0.70, 1.6, 2.6, 0.62, 0.86, COURONNE, 2.2)
		f.cone(1.54, 4.2, 7.6, 0.86, 1.14, COURONNE, 0.08)
		f.lobe(Vector3(0.35, 6.4, 0.2), 1.05, 0.84, 1.08, SATELLITE, 1.9)
		f.lobe(Vector3(-0.30, 8.0, -0.25), 0.85, 0.92, 1.14, SATELLITE + 1, 1.9)
	elif essence == FRUITIER:
		# Plus large que haut, la couronne presque au sol : un pommier.
		f.lobe(Vector3(0.0, 2.45, 0.0), 1.75, 0.66, 1.10, COURONNE, 0.72)
		f.lobe(Vector3(0.95, 2.25, 0.50), 1.15, 0.62, 1.02, SATELLITE, 0.80)
		f.lobe(Vector3(-0.90, 2.35, -0.45), 1.10, 0.62, 1.02, SATELLITE + 1, 0.80)
		f.lobe(Vector3(0.10, 3.05, -0.85), 0.95, 0.74, 1.12, SATELLITE + 2, 0.85)
	elif essence == SAULE:
		# Le dôme, et le rideau qui retombe : six lobes étirés vers le sol.
		f.lobe(Vector3(0.0, 4.0, 0.0), 2.50, 0.72, 1.14, COURONNE, 0.78)
		for k in 6:
			var a := float(k) * TAU / 6.0 + 0.4
			f.lobe(Vector3(cos(a) * 2.05, 2.75, sin(a) * 2.05), 0.95, 0.56, 0.94,
				SATELLITE + k, 2.0)
	elif essence == TILLEUL:
		# L'ovale : un corps étiré vers le haut, des lobes serrés autour.
		f.lobe(Vector3(0.0, 5.5, 0.0), 2.10, 0.62, 1.12, COURONNE, 1.38)
		f.lobe(Vector3(0.95, 4.4, 0.55), 1.40, 0.56, 0.96, SATELLITE, 1.10)
		f.lobe(Vector3(-1.00, 4.6, -0.45), 1.35, 0.56, 0.96, SATELLITE + 1, 1.10)
		f.lobe(Vector3(0.15, 7.6, -0.25), 1.25, 0.84, 1.18, SATELLITE + 2, 1.20)
		f.lobe(Vector3(-0.45, 6.4, 0.95), 1.15, 0.72, 1.10, SATELLITE + 3, 1.10)
		f.lobe(Vector3(0.75, 6.7, -0.85), 1.05, 0.74, 1.12, SATELLITE + 4, 1.10)
	else:
		# DÉCENTRÉS : concentriques, ils redonneraient la bille d'avant.
		f.lobe(Vector3(0.0, 4.7, 0.0), 2.55, 0.66, 1.10, COURONNE)
		f.lobe(Vector3(1.35, 3.95, -0.65), 1.90, 0.60, 0.98, SATELLITE)
		f.lobe(Vector3(-1.10, 4.20, 0.90), 1.75, 0.60, 0.98, SATELLITE + 1)
		f.lobe(Vector3(0.30, 6.05, 0.35), 1.45, 0.82, 1.16, SATELLITE + 2)
		f.lobe(Vector3(-0.80, 3.75, -1.25), 1.45, 0.58, 0.94, SATELLITE + 3)

	m.add_surface_from_arrays(PRIM, f.surface(), [], {}, _Volume.FORMAT)
	m.surface_set_material(0, Materiaux.feuillage(foret, essence, brume))

	# 🔴 Ni roseau ni buisson n'a de tronc : une deuxième surface pour un fût
	# de 3 cm coûterait un matériau et ne se verrait jamais.
	if essence == ROSEAU or essence == BUISSON:
		return m

	var t := _Volume.new()
	t.cotes = 4 if foret != Vector2.ZERO else 5
	var haut: float = {CONIFERE: 1.6, BOULEAU: 4.4, PEUPLIER: 2.0,
		FRUITIER: 1.4, SAULE: 2.4, TILLEUL: 2.9}.get(essence, 3.4)
	var rayon := 0.20 if essence == BOULEAU else 0.30
	t.cone(rayon, 0.0, haut, 1.0, 1.0, FIXE, 0.72)
	if foret == Vector2.ZERO and essence != CONIFERE:
		_ramure(t, f.lobes, essence, haut, rayon)
	m.add_surface_from_arrays(PRIM, t.surface(), [], {}, _Volume.FORMAT)
	m.surface_set_material(1, Materiaux.ecorce(tronc, foret, essence))
	return m


## 🌳 LES BRANCHES DE L'ARBRE NU (auteur, 2026-10-10) : une par lobe, deux rameaux
## chacune, cachées sous la couronne l'été (`feuillage.gdshader`). La forêt n'en a
## pas : 22 000 arbres vus de loin, une brume de rameaux suffit.
## ⚠️ Flaggable (90) : géométrie dessinée par le code et vue du joueur.
static func _ramure(t: _Volume, lobes: Array, essence: int, haut: float, rayon: float) -> void:
	var pied := Vector3(0.0, haut * 0.92, 0.0)
	if essence == PEUPLIER:
		# Le fuseau nu : une flèche jusqu'en haut, des branches dressées.
		t.branche(pied, Vector3(0.0, 10.8, 0.0), rayon * 0.6, 0.04, -COURONNE, pied)
		for k in 6:
			var a := float(k) * 2.4
			var d := Vector3(cos(a) * 0.4, 1.0, sin(a) * 0.4).normalized()
			var p := Vector3(0.0, 3.0 + 1.25 * k, 0.0)
			t.branche(p, p + d * (2.6 - 0.25 * k), 0.07, 0.015, -COURONNE, pied, 3)
	for lobe in lobes:
		var centre: Vector3 = lobe[0]
		var r: float = lobe[1]
		var role: float = lobe[2]
		var axe := centre - pied
		# La couronne sur l'axe donne la flèche ; un satellite, une branche vers le dehors.
		var bout := centre + Vector3.UP * r * 0.5
		if Vector2(axe.x, axe.z).length() > 0.3:
			bout = centre + axe.normalized() * r * 0.3
		var dir := (bout - pied).normalized()
		t.branche(pied, bout, rayon * 0.55, 0.03, -role, pied)
		var cote := dir.cross(Vector3.UP)
		cote = cote.normalized() if cote.length() > 0.1 else Vector3.RIGHT
		var milieu := pied.lerp(bout, 0.6)
		for sens in [-1.0, 1.0]:
			var d: Vector3 = (dir + cote * sens * 0.75 + Vector3.UP * 0.35).normalized()
			var l := r * 0.6
			if essence == SAULE and role > COURONNE:
				# Le saule retombe.
				d = (dir * 0.5 + cote * sens * 0.4 + Vector3.DOWN).normalized()
				l = r * 1.3
			t.branche(milieu, milieu + d * l, 0.065, 0.015, -role, pied, 3, 0.6, 1.0)


## 🌳 LA RAMURE DES MODÈLES DU PACK (auteur, 2026-10-22 : nu, deux ou trois moignons
## et des bouts qui flottent) : du bois le plus proche, une branche monte dans chaque
## bloc de feuillage et s'y ouvre en rameaux fourchus ; repliée l'été comme `_ramure`.
## Coût : +1 ms GPU au cœur ancien en janvier, +0,3 ms en juillet (2026-10-22).
## ⚠️ Flaggable (90) : géométrie dessinée par le code et vue du joueur.
static func _ramure_pack(bois: PackedVector3Array, blocs: Array, essence: int) -> _Volume:
	var t := _Volume.new()
	var epais := 0.025 * float(LARGEUR[essence])
	for j in blocs.size():
		var b: AABB = blocs[j]
		var centre := b.get_center()
		var demi := b.size * 0.5
		var vise := centre - Vector3(0.0, demi.y * 0.4, 0.0)
		var bord := bois[0]
		for q in bois:
			if q.distance_squared_to(vise) < bord.distance_squared_to(vise):
				bord = q
		# Du cœur du moignon, à son épaisseur : sinon une brindille sort d'un bout coupé.
		var proches: Array[Vector3] = []
		for q in bois:
			if q.distance_to(bord) < 0.08 * float(LARGEUR[essence]):
				proches.append(q)
		var depart := Vector3.ZERO
		for q in proches:
			depart += q / proches.size()
		var r0 := 0.0
		for q in proches:
			r0 += q.distance_to(depart) / proches.size()
		r0 = clampf(r0, epais, epais * 2.5)
		var bout := centre + Vector3(0.0, demi.y * 0.6, 0.0)
		t.branche(depart, bout, r0, epais * 0.3, -COURONNE, depart)
		var n := clampi(roundi(b.size.y / 1.1), 3, 7)
		for i in n:
			var a := TAU * float(i) / float(n) + float(j) * 2.1
			var p0 := depart.lerp(bout, 0.25 + 0.6 * float(i) / float(n))
			var p1 := centre + Vector3(cos(a) * demi.x, 0.0, sin(a) * demi.z) * 0.85
			p1.y = minf(p0.y + demi.y * 0.5, centre.y + demi.y * 0.85)
			t.branche(p0, p1, epais * 0.5, epais * 0.15, -COURONNE, depart, 3)
			var dir := (p1 - p0).normalized()
			var cote := dir.cross(Vector3.UP)
			cote = cote.normalized() if cote.length() > 0.1 else Vector3.RIGHT
			var l := p0.distance_to(p1)
			# Un rameau au milieu, d'un côté puis de l'autre, et la fourche au bout.
			var m := p0.lerp(p1, 0.55)
			var s := 1.0 if i % 2 == 0 else -1.0
			t.branche(m, m + (dir + cote * s * 0.8 + Vector3.UP * 0.5).normalized() * l * 0.45,
				epais * 0.3, 0.008, -COURONNE, depart, 3)
			for sens in [-1.0, 1.0]:
				t.branche(p1, p1 + (dir + cote * sens * 0.6 + Vector3.UP * 0.4).normalized() * l * 0.3,
					epais * 0.15, 0.006, -COURONNE, depart, 3)
	return t


## Les tableaux d'une surface d'arbre. CUSTOM0 = centre du lobe et son rôle,
## lus par `feuillage.gdshader`.
class _Volume:
	const FORMAT := Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var c := PackedColorArray()
	var x := PackedFloat32Array()
	var i := PackedInt32Array()
	var cotes := 8
	var satellites := 9
	var lobes := []    # [centre, rayon, rôle] : d'où partent les branches

	## Huit méridiens, deux anneaux : silhouette ronde à petit budget. Le
	## dégradé bas → haut fait le volume : sans lui, une sphère sous une
	## lumière fixe est un disque plat. `etire` < 1 aplatit, > 1 fait tomber.
	func lobe(centre: Vector3, rayon: float, bas: float, haut: float,
			role: float, etire := 1.0) -> void:
		if role >= SATELLITE + float(satellites):
			return
		lobes.append([centre, rayon, role])
		var s := SphereMesh.new()
		s.radius = rayon
		s.height = rayon * 1.85
		s.radial_segments = cotes
		s.rings = 2
		var e := rayon * 0.93 * etire
		fondre(s, Transform3D(Basis.from_scale(Vector3(1.0, etire, 1.0)), centre),
			centre.y - e, centre.y + e, bas, haut, centre, role)

	## Posé sur `y0`. `pointe` < 1 le laisse ouvert en haut : un tronc plutôt
	## qu'une aiguille.
	func cone(rayon: float, y0: float, hauteur: float, bas: float, haut: float,
			role: float, pointe := 0.04) -> void:
		var cy := CylinderMesh.new()
		cy.bottom_radius = rayon
		cy.top_radius = rayon * pointe
		cy.height = hauteur
		cy.radial_segments = cotes
		cy.rings = 0
		cy.cap_bottom = false          # jamais vue : le pied est dans le sol
		var centre := Vector3(0.0, y0 + hauteur * 0.5, 0.0)
		fondre(cy, Transform3D(Basis(), centre), y0, y0 + hauteur, bas, haut,
			centre, role)

	## 🌿 UN BRIN DE ROSEAU : un cône très effilé, penché de `inclinaison`
	## radians dans la direction `cap`, posé sur son PIED.
	func brin(pied: Vector3, hauteur: float, inclinaison: float, cap: float) -> void:
		var cy := CylinderMesh.new()
		cy.bottom_radius = 0.115
		cy.top_radius = 0.012
		cy.height = hauteur
		# 🔴 TROIS CÔTÉS ET AUCUN CHAPEAU : un brin fait deux pixels, et il y en
		# a cinq par touffe pour 1 091 touffes si les huit berges sont rendues.
		cy.radial_segments = 3
		cy.rings = 0
		cy.cap_bottom = false
		cy.cap_top = false
		var b := Basis(Vector3.UP, cap) * Basis(Vector3(0.0, 0.0, 1.0), inclinaison)
		fondre(cy, Transform3D(b, pied + b * Vector3(0.0, hauteur * 0.5, 0.0)),
			pied.y, pied.y + hauteur, 0.58, 1.16, pied, FIXE)

	## 🌳 Une branche de `pied` à `bout`, sans chapeau. CUSTOM0 = (`ancre`, −rôle) :
	## repliée, elle rentre dans le tronc. COLOR.a va de `le_long.x` à `.y`, la
	## part du déplacement du satellite qu'elle suit.
	func branche(pied: Vector3, bout: Vector3, r0: float, r1: float, role: float,
			ancre: Vector3, cotes_b := 4, de := 0.0, a := 1.0) -> void:
		var axe := bout - pied
		var l := axe.length()
		var cy := CylinderMesh.new()
		cy.bottom_radius = r0
		cy.top_radius = r1
		cy.height = l
		cy.radial_segments = cotes_b
		cy.rings = 0
		cy.cap_bottom = false
		cy.cap_top = false
		var tr := Transform3D(Basis(Quaternion(Vector3.UP, axe / l)), pied + axe * 0.5)
		var arr := cy.surface_get_arrays(0)
		var pv: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var pn: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		var pi: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
		var base := v.size()
		for k in pv.size():
			var p: Vector3 = tr * pv[k]
			v.append(p)
			n.append((tr.basis * pn[k]).normalized())
			c.append(Color(1.0, 1.0, 1.0, lerpf(de, a, clampf((p - pied).dot(axe) / (l * l), 0.0, 1.0))))
			x.append(ancre.x)
			x.append(ancre.y)
			x.append(ancre.z)
			x.append(role)
		for k in pi.size():
			i.append(base + pi[k])

	## Verse une primitive transformée, avec son dégradé vertical en couleur
	## de sommet.
	func fondre(source: PrimitiveMesh, t: Transform3D, y0: float, y1: float,
			bas: float, haut: float, centre: Vector3, role: float) -> void:
		var a := source.surface_get_arrays(0)
		var pv: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var pn: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
		var pi: PackedInt32Array = a[Mesh.ARRAY_INDEX]
		var base := v.size()
		var normale := t.basis.inverse().transposed()
		for k in pv.size():
			var p: Vector3 = t * pv[k]
			v.append(p)
			n.append((normale * pn[k]).normalized())
			var g := lerpf(bas, haut, clampf(inverse_lerp(y0, y1, p.y), 0.0, 1.0))
			c.append(Color(g, g, g, 1.0))
			x.append(centre.x)
			x.append(centre.y)
			x.append(centre.z)
			x.append(role)
		for k in pi.size():
			i.append(base + pi[k])

	func surface() -> Array:
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = v
		arrays[Mesh.ARRAY_NORMAL] = n
		arrays[Mesh.ARRAY_COLOR] = c
		arrays[Mesh.ARRAY_CUSTOM0] = x
		arrays[Mesh.ARRAY_INDEX] = i
		return arrays
