extends RefCounted
# Le noyau de génération de géométrie, isolé derrière une interface propre —
# `Vault/Technique/Moteur et architecture.md:18`.
#
# Cette interface N'EST PAS une hiérarchie de classes : c'est le contrat JSON.
# Toute la géométrie a été calculée en Python par 07_exporter_godot.py. Ici on
# ne fait qu'EMPAQUETER des tableaux — aucune décision géométrique, aucune
# boucle lourde (l.16), aucun accès aux nœuds.
#
# Le jour où ça goulotte, ce fichier se porte en C# par copier-coller.

const PRIM := Mesh.PRIMITIVE_TRIANGLES
# L'arbre est le seul objet du fichier qui porte ses matériaux DANS son
# maillage — deux surfaces, deux matériaux — parce qu'un `material_override`
# peindrait le tronc de la couleur du feuillage. D'où cet import, qui n'est
# pas circulaire : `materiaux.gd` ne connaît pas ce fichier.
const Materiaux := preload("res://scripts/materiaux.gd")


## Un maillage plat {v, n, c, uv, i} → ArrayMesh. Un seul appel à
## add_surface_from_arrays : c'est ce qui évite les ~95 000 appels de fonction
## qu'un SurfaceTool coûterait sur le terrain.
static func maillage(d: Dictionary) -> ArrayMesh:
	var vs: Array = d["v"]
	var ns: Array = d["n"]
	var cs: Array = d["c"]
	var uvs: Array = d.get("uv", [])
	# 🪟 UV2 ne descend que sur les maillages qui portent un mur percé — 07
	# ne l'écrit pas ailleurs. Absent, Godot laisse UV2 à zéro, ce qui est
	# exactement « pas une façade » pour le shader.
	var uv2s: Array = d.get("uv2", [])
	var idx: Array = d["i"]

	var n: int = vs.size()
	var v := PackedVector3Array()
	var nm := PackedVector3Array()
	var co := PackedColorArray()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	v.resize(n)
	nm.resize(n)
	co.resize(n)
	uv.resize(n)
	uv2.resize(n)
	for k in n:
		var a: Array = vs[k]
		var b: Array = ns[k]
		var c: Array = cs[k]
		v[k] = Vector3(a[0], a[1], a[2])
		nm[k] = Vector3(b[0], b[1], b[2])
		co[k] = _couleur(c)
		uv[k] = Vector2.ZERO if uvs.is_empty() else Vector2(uvs[k][0], uvs[k][1])
		uv2[k] = Vector2.ZERO if uv2s.is_empty() \
			else Vector2(uv2s[k][0], uv2s[k][1])

	var i := PackedInt32Array()
	i.resize(idx.size())
	for k in idx.size():
		i[k] = int(idx[k])

	return _surface(v, nm, co, i, uv, uv2)


## Une TRANCHE du même maillage : les `nb` indices à partir de `debut`, avec
## les sommets qu'ils citent et rien d'autre.
##
## C'est ce qui donne un nœud par îlot et par tronçon, donc un objet qu'on peut
## cliquer, surligner et teinter. Les plages viennent de `groupes` (clé `g`),
## posées par 07 au fil de l'émission — Godot ne redécoupe rien, il lit.
static func maillage_groupe(d: Dictionary, debut: int, nb: int) -> ArrayMesh:
	var vs: Array = d["v"]
	var ns: Array = d["n"]
	var cs: Array = d["c"]
	var uvs: Array = d.get("uv", [])
	var uv2s: Array = d.get("uv2", [])
	var idx: Array = d["i"]

	# Les indices citent des sommets répartis dans TOUT le tableau : il faut
	# les renuméroter, sinon la tranche traîne les 40 000 sommets des autres.
	var renumerote := {}
	var v := PackedVector3Array()
	var nm := PackedVector3Array()
	var co := PackedColorArray()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	var i := PackedInt32Array()
	i.resize(nb)
	for k in nb:
		var src: int = int(idx[debut + k])
		if not renumerote.has(src):
			renumerote[src] = v.size()
			var a: Array = vs[src]
			var b: Array = ns[src]
			v.append(Vector3(a[0], a[1], a[2]))
			nm.append(Vector3(b[0], b[1], b[2]))
			co.append(_couleur(cs[src]))
			uv.append(Vector2.ZERO if uvs.is_empty() else Vector2(uvs[src][0], uvs[src][1]))
			uv2.append(Vector2.ZERO if uv2s.is_empty() \
				else Vector2(uv2s[src][0], uv2s[src][1]))
		i[k] = renumerote[src]

	return _surface(v, nm, co, i, uv, uv2)


## RGB = la teinte déjà occluse, ALPHA = l'occlusion seule. C'est le shader de
## `materiaux.gd` qui s'en sert pour repeindre un objet en calque thématique
## sans perdre l'AO. Les exports d'avant n'ont que trois canaux : on retombe
## sur 1,0, ce qui donne exactement l'ancien rendu.
static func _couleur(c: Array) -> Color:
	return Color(c[0], c[1], c[2], 1.0 if c.size() < 4 else float(c[3]))


## 🔄 IL Y AVAIT ICI `terrain()` : le champ d'altitude déplié en grille, avec
## ses normales analytiques. La carte est plate depuis le 2026-08-12, le sol
## est un maillage troué par le chenal, et il passe par `maillage()` comme tout
## le reste. Godot n'a plus qu'UNE façon de lire de la géométrie.


static func _surface(v: PackedVector3Array, n: PackedVector3Array,
		c: PackedColorArray, i: PackedInt32Array,
		uv: PackedVector2Array = PackedVector2Array(),
		uv2: PackedVector2Array = PackedVector2Array()) -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)          # obligatoire AVANT d'indexer
	arrays[Mesh.ARRAY_VERTEX] = v
	arrays[Mesh.ARRAY_NORMAL] = n
	arrays[Mesh.ARRAY_COLOR] = c
	if not uv.is_empty():
		arrays[Mesh.ARRAY_TEX_UV] = uv
	if not uv2.is_empty():
		arrays[Mesh.ARRAY_TEX_UV2] = uv2
	arrays[Mesh.ARRAY_INDEX] = i
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(PRIM, arrays)
	return m


## 🔲 L'EMPRISE D'UN ÎLOT — une plaque plate, jamais affichée, qui ne sert
## qu'à COMPLÉTER la silhouette de l'îlot choisi dans le masque.
##
## Un îlot bâti ne dessine pas son sol : sous une barre de 1970 il n'y a que la
## plaque de terrain, qui n'appartient à personne. Détourer la seule silhouette
## rendue collait donc le trait aux bâtiments et laissait dehors tout le gris
## qui les entoure. La plaque bouche ce trou ; le trait suit ensuite l'union
## des deux, donc l'emprise ET ce qui la dépasse en hauteur.
##
## L'anneau est OUVERT et simple (contrôlé par 04b : 69/69), d'où le découpage
## en oreilles de Godot sans précaution particulière. Le sens de parcours n'a
## aucune importance : le matériau du masque n'élimine aucune face.
static func emprise(anneau: Array) -> ArrayMesh:
	if anneau.size() < 3:
		return null
	var plan := PackedVector2Array()
	var v := PackedVector3Array()
	for p in anneau:
		var pt: Array = p
		# Le point porte SON altitude — un champ en pente a une emprise qui
		# suit son talus, sinon le trait flotte au-dessus du bord.
		v.append(Vector3(float(pt[0]), float(pt[1]), float(pt[2])))
		plan.append(Vector2(float(pt[0]), float(pt[2])))
	var idx := Geometry2D.triangulate_polygon(plan)
	if idx.is_empty():
		# Un anneau que la triangulation refuse n'est pas une raison de perdre
		# le trait : il reste la silhouette rendue.
		push_warning("emprise : anneau non triangulable (%d sommets)" % v.size())
		return null
	var nm := PackedVector3Array()
	nm.resize(v.size())
	nm.fill(Vector3.UP)
	var co := PackedColorArray()
	co.resize(v.size())
	co.fill(Color.WHITE)
	return _surface(v, nm, co, idx)


## 🔲 LE COULOIR D'UN TRONÇON — un ruban plat, jamais affiché, qui ne sert
## qu'à donner une SILHOUETTE D'UN SEUL TENANT à une rue choisie.
##
## Une rue rendue est faite de morceaux disjoints : la chaussée, les mètres
## libres (qui ne sont rien du tout — du sol nu), et un bout de trottoir par
## îlot riverain. Détourer ce maillage-là donne trois bandes parallèles, pas
## une rue. Ce ruban-ci va de façade à façade, d'une seule pièce.
##
## Les quadrilatères SE CHEVAUCHENT aux coudes, et c'est voulu : chaque
## segment est rallongé d'une demi-largeur à ses jointures INTERNES, ce qui
## remplit l'angle sans calculer d'onglet. Un masque ne se soucie pas des
## recouvrements — seule sa couverture compte. Les deux BOUTS ne sont pas
## rallongés : sinon la rue choisie déborderait de neuf mètres dans le
## carrefour voisin.
static func couloir(axes: Array, largeur: float, y: float) -> ArrayMesh:
	var h := largeur / 2.0
	var v := PackedVector3Array()
	var idx := PackedInt32Array()
	for a in axes:
		var plat: Array = a
		@warning_ignore("integer_division")
		var n: int = plat.size() / 2
		for k in n - 1:
			var p := Vector2(float(plat[k * 2]), float(plat[k * 2 + 1]))
			var q := Vector2(float(plat[k * 2 + 2]), float(plat[k * 2 + 3]))
			var u := (q - p)
			if u.length_squared() < 1e-8:
				continue
			u = u.normalized()
			if k > 0:
				p -= u * h
			if k < n - 2:
				q += u * h
			var t := Vector2(u.y, -u.x) * h
			var b := v.size()
			v.append(Vector3(p.x + t.x, y, p.y + t.y))
			v.append(Vector3(p.x - t.x, y, p.y - t.y))
			v.append(Vector3(q.x - t.x, y, q.y - t.y))
			v.append(Vector3(q.x + t.x, y, q.y + t.y))
			idx.append(b)
			idx.append(b + 1)
			idx.append(b + 2)
			idx.append(b)
			idx.append(b + 2)
			idx.append(b + 3)
	if v.size() == 0:
		return null
	# Le matériau du masque est non éclairé et sans élimination de faces :
	# normales et couleurs ne servent à rien, mais `_surface` les attend.
	var nm := PackedVector3Array()
	nm.resize(v.size())
	nm.fill(Vector3.UP)
	var co := PackedColorArray()
	co.resize(v.size())
	co.fill(Color.WHITE)
	return _surface(v, nm, co, idx)


## Les arbres : UNE instance multiple par ESSENCE, pas un nœud par objet — « le
## geste se prend au début, pas après » (`Génération procédurale.md:74`).
##
## Les 69 îlots, eux, n'en ont pas : un MultiMesh répète UN MÊME mesh, or ce
## sont 69 formes distinctes. Il faudrait 69 MultiMesh d'une instance chacun,
## soit 69 draw calls au lieu de 1. La fusion en un ArrayMesh sert la même
## intention, et mieux.
##
## 🔄 RETOUR EN ARRIÈRE SIGNALÉ. C'ÉTAIT UNE SPHÈRE, une seule, à six segments
## — d'où les billes vertes des captures d'avant le 2026-08-18. Ce qu'une bille
## ne peut pas donner, et que l'auteur voulait voir sur sa photo de référence :
## un tronc, une couronne qui n'est pas un cercle parfait, et une sous-face
## sombre. Les trois sont ici, et aucun n'est un asset : la couronne est un tas
## de trois lobes, le dégradé est bakké en couleur de sommet, et l'essence est
## une deuxième recette et non un deuxième fichier.
const FEUILLU := 0
const CONIFERE := 1


static func arbres(liste: Array, essence: int, feuillage: Color,
		tronc: Color) -> MultiMesh:
	var pris: Array = []
	for a in liste:
		# Les exports d'avant le 2026-08-18 n'ont que cinq nombres : tout y
		# est feuillu, ce qui donne exactement l'ancienne forêt.
		var e: int = int(a[5]) if (a as Array).size() > 5 else FEUILLU
		if e == essence:
			pris.append(a)

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = _arbre(essence, tronc)
	mm.instance_count = pris.size()

	for k in pris.size():
		var a: Array = pris[k]
		var ech: float = float(a[3])
		var t := Transform3D(Basis(), Vector3.ZERO)
		t = t.rotated(Vector3.UP, float(a[4]))
		t = t.scaled(Vector3(ech, ech, ech))
		# 🔄 Le mesh a maintenant son PIED À L'ORIGINE : plus de demi-blob à
		# remonter. L'ancienne ligne compensait le fait qu'une sphère est
		# centrée sur elle-même.
		t.origin = Vector3(float(a[0]), float(a[1]), float(a[2]))
		mm.set_instance_transform(k, t)
		# Une variation de valeur, pas de teinte : « les teintes sont fixes »
		# (Direction artistique l.67).
		var f: float = 0.86 + 0.28 * fmod(abs(float(a[4])) * 7.3, 1.0)
		mm.set_instance_color(k, Color(feuillage.r * f, feuillage.g * f,
			feuillage.b * f))
	return mm


## Un arbre en deux surfaces : la couronne (couleur de sommet, donc teintée par
## l'instance) et le tronc (couleur fixe, donc INDIFFÉRENT à la teinte de
## l'instance). C'est ce découpage qui permet d'avoir un tronc brun sous un
## feuillage vert avec un seul MultiMesh — et c'est pour ça que les arbres ne
## portent plus de `material_override`, qui écraserait les deux d'un coup.
static func _arbre(essence: int, tronc: Color) -> ArrayMesh:
	var m := ArrayMesh.new()

	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var c := PackedColorArray()
	var i := PackedInt32Array()

	if essence == CONIFERE:
		# Trois cônes empilés qui se resserrent : la silhouette d'un épicéa se
		# lit à la SILHOUETTE, pas au détail — c'est la règle du budget
		# polygonal (le détail va dans le matériau, jamais dans le maillage).
		_cone(v, n, c, i, 1.90, 1.10, 3.20, 6, 0.62, 0.86)
		_cone(v, n, c, i, 1.45, 3.00, 2.80, 6, 0.78, 1.00)
		_cone(v, n, c, i, 0.95, 4.90, 2.60, 6, 0.92, 1.12)
	else:
		# Trois lobes DÉCENTRÉS. Le décentrage est tout le sujet : trois
		# sphères concentriques redonneraient la bille d'avant.
		_lobe(v, n, c, i, Vector3(0.0, 4.7, 0.0), 2.70, 0.66, 1.10)
		_lobe(v, n, c, i, Vector3(1.35, 3.85, -0.65), 2.00, 0.60, 0.96)
		_lobe(v, n, c, i, Vector3(-1.10, 4.15, 0.90), 1.80, 0.60, 0.98)

	m.add_surface_from_arrays(PRIM, _emballer(v, n, c, i))
	m.surface_set_material(0, Materiaux.feuillage())

	var tv := PackedVector3Array()
	var tn := PackedVector3Array()
	var tc := PackedColorArray()
	var ti := PackedInt32Array()
	var haut: float = 1.6 if essence == CONIFERE else 3.4
	_cone(tv, tn, tc, ti, 0.30, 0.0, haut, 5, 1.0, 1.0, 0.72)
	m.add_surface_from_arrays(PRIM, _emballer(tv, tn, tc, ti))
	m.surface_set_material(1, Materiaux.bois(tronc))
	return m


## Un lobe de feuillage : une sphère à six méridiens, dont les sommets portent
## un dégradé vertical bakké. Ce dégradé fait tout le travail — sans lui, une
## sphère sous une lumière fixe est un disque plat.
static func _lobe(v: PackedVector3Array, n: PackedVector3Array,
		c: PackedColorArray, i: PackedInt32Array,
		centre: Vector3, rayon: float, bas: float, haut: float) -> void:
	var s := SphereMesh.new()
	s.radius = rayon
	s.height = rayon * 1.85
	s.radial_segments = 6
	s.rings = 3
	_fondre(v, n, c, i, s, Transform3D(Basis(), centre),
		centre.y - rayon * 0.93, centre.y + rayon * 0.93, bas, haut)


## Un cône (ou un tronc de cône) posé sur `y0`. `pointe` < 1 le laisse ouvert
## en haut : c'est ce qui donne un tronc plutôt qu'une aiguille.
static func _cone(v: PackedVector3Array, n: PackedVector3Array,
		c: PackedColorArray, i: PackedInt32Array,
		rayon: float, y0: float, hauteur: float, cotes: int,
		bas: float, haut: float, pointe: float = 0.04) -> void:
	var cy := CylinderMesh.new()
	cy.bottom_radius = rayon
	cy.top_radius = rayon * pointe
	cy.height = hauteur
	cy.radial_segments = cotes
	cy.rings = 0
	cy.cap_bottom = false          # jamais vue : le pied est dans le sol
	_fondre(v, n, c, i, cy,
		Transform3D(Basis(), Vector3(0.0, y0 + hauteur * 0.5, 0.0)),
		y0, y0 + hauteur, bas, haut)


## Verse une primitive dans les tableaux en cours, transformée, avec un dégradé
## vertical entre `bas` et `haut` posé en couleur de sommet.
static func _fondre(v: PackedVector3Array, n: PackedVector3Array,
		c: PackedColorArray, i: PackedInt32Array, source: PrimitiveMesh,
		t: Transform3D, y0: float, y1: float, bas: float, haut: float) -> void:
	var a := source.surface_get_arrays(0)
	var pv: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var pn: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
	var pi: PackedInt32Array = a[Mesh.ARRAY_INDEX]
	var base := v.size()
	for k in pv.size():
		var p: Vector3 = t * pv[k]
		v.append(p)
		n.append((t.basis * pn[k]).normalized())
		var f := clampf(inverse_lerp(y0, y1, p.y), 0.0, 1.0)
		var g := lerpf(bas, haut, f)
		c.append(Color(g, g, g, 1.0))
	for k in pi.size():
		i.append(base + pi[k])


static func _emballer(v: PackedVector3Array, n: PackedVector3Array,
		c: PackedColorArray, i: PackedInt32Array) -> Array:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = v
	arrays[Mesh.ARRAY_NORMAL] = n
	arrays[Mesh.ARRAY_COLOR] = c
	arrays[Mesh.ARRAY_INDEX] = i
	return arrays
