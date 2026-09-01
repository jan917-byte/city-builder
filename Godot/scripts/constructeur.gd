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
static func maillage(d: Dictionary) -> ArrayMesh:
	var vs: Array = d["v"]
	var ns: Array = d["n"]
	var cs: Array = d["c"]
	var uvs: Array = d.get("uv", [])
	# 🪟 UV2 ne descend que sur les maillages à mur percé. Absent, Godot le
	# laisse à zéro, ce qui est « pas une façade » pour le shader.
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


## Une TRANCHE du maillage : `nb` indices depuis `debut`, et les seuls sommets
## qu'ils citent. C'est ce qui donne un nœud par îlot et par tronçon, donc un
## objet cliquable. Les plages viennent de la clé `g`, posée par 07.
static func maillage_groupe(d: Dictionary, debut: int, nb: int) -> ArrayMesh:
	var vs: Array = d["v"]
	var ns: Array = d["n"]
	var cs: Array = d["c"]
	var uvs: Array = d.get("uv", [])
	var uv2s: Array = d.get("uv2", [])
	var idx: Array = d["i"]

	# Les indices citent des sommets répartis dans TOUT le tableau : sans
	# renumérotation la tranche traîne les 40 000 sommets des autres.
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


## RGB = teinte déjà occluse, ALPHA = l'occlusion seule, dont le shader se sert
## pour repeindre en calque sans perdre l'AO. Les exports d'avant n'ont que
## trois canaux : on retombe sur 1,0, donc l'ancien rendu.
static func _couleur(c: Array) -> Color:
	return Color(c[0], c[1], c[2], 1.0 if c.size() < 4 else float(c[3]))


## 🔄 `terrain()` dépliait ici un champ d'altitude en grille. La carte est plate
## depuis le 2026-08-12 : le sol passe par `maillage()` comme tout le reste, et
## Godot n'a plus qu'UNE façon de lire de la géométrie.


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

## La teinte d'instance MULTIPLIE celle du sommet : au-dessus de 1, la tête
## reste plus claire que le vêtement, quel que soit le vêtement tiré.
const TETE := Color(1.18, 1.06, 0.98)


## Une recette unique pour voitures roulantes et garées. La teinte vient de
## l'instance ; 4 000 véhicules restent donc deux MultiMesh et deux appels.
## `circuit` = la voiture de la VILLE : elle ne reboucle pas sur son segment,
## elle s'arrête au bout et c'est `trafic.gd` qui l'engage sur le suivant. La
## fiche, elle, montre un morceau droit sans suite : elle reboucle.
static func voitures(nombre: int, anime := false, circuit := false) -> MultiMesh:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var c := PackedColorArray()
	var i := PackedInt32Array()
	_boite(v, n, c, i, Vector3(1.78, 0.62, 4.15), Vector3(0.0, 0.31, 0.0), Color.WHITE)
	_boite(v, n, c, i, Vector3(1.48, 0.58, 2.05), Vector3(0.0, 0.90, -0.15),
		Color(0.28, 0.33, 0.36))
	var mesh := _surface(v, n, c, i)
	mesh.surface_set_material(0, _glisse(anime, 0.0, 0.0, circuit))
	return _instances(mesh, nombre, anime)


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
	mesh.surface_set_material(0, _glisse(true, 0.035, 1.9))
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
	mesh.surface_set_material(0, _glisse(true, 0.018, 3.6))
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
static func _glisse(anime: bool, balance := 0.0, cadence := 0.0,
		circuit := false) -> Material:
	if not anime:
		var std := StandardMaterial3D.new()
		std.vertex_color_use_as_albedo = true
		std.roughness = 0.72
		return std
	var pas := ""
	if balance > 0.0:
		pas = "  VERTEX.y += %f * sin(TIME * %f + INSTANCE_CUSTOM.x);\n" \
			% [balance, cadence * TAU]
	var horloge := "TIME"
	var course := "mod(INSTANCE_CUSTOM.x + %s * INSTANCE_CUSTOM.y, longueur)"
	var entete := ""
	if circuit:
		_declarer_horloge()
		horloge = HORLOGE
		course = "clamp(INSTANCE_CUSTOM.x + %s * INSTANCE_CUSTOM.y, 0.0, longueur)"
		entete = "global uniform float %s;\n" % HORLOGE
	var shader := Shader.new()
	shader.code = "shader_type spatial;\n" \
		+ entete \
		+ "varying vec4 teinte;\n" \
		+ "void vertex() {\n" \
		+ "  float longueur = max(INSTANCE_CUSTOM.z, 0.01);\n" \
		+ "  VERTEX.z += " + (course % horloge) + ";\n" \
		+ pas \
		+ "  teinte = COLOR;\n" \
		+ "}\n" \
		+ "void fragment() { ALBEDO = teinte.rgb; ROUGHNESS = 0.72; }\n"
	var mat := ShaderMaterial.new()
	mat.shader = shader
	return mat


## ⚠️ On ne DEMANDE pas au serveur si l'horloge existe : la liste des uniformes
## globaux n'est lisible que dans l'éditeur, et hors éditeur elle imprime une
## erreur. Un drapeau de classe suffit — le matériau n'est bâti qu'une fois.
static var _horloge_posee := false


static func _declarer_horloge() -> void:
	if _horloge_posee:
		return
	_horloge_posee = true
	RenderingServer.global_shader_parameter_add(HORLOGE,
		RenderingServer.GLOBAL_VAR_TYPE_FLOAT, 0.0)


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
		[Vector3.FORWARD, [Vector3(h.x,-h.y,h.z), Vector3(-h.x,-h.y,h.z), Vector3(-h.x,h.y,h.z), Vector3(h.x,h.y,h.z)]],
		[Vector3.BACK, [Vector3(-h.x,-h.y,-h.z), Vector3(h.x,-h.y,-h.z), Vector3(h.x,h.y,-h.z), Vector3(-h.x,h.y,-h.z)]],
	]
	for f in faces:
		var b := v.size()
		for p in f[1]:
			v.append(p + centre)
			n.append(f[0])
			c.append(couleur)
		i.append_array(PackedInt32Array([b, b + 1, b + 2, b, b + 2, b + 3]))


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
	mm.mesh = _arbre(essence, tronc)
	mm.instance_count = pris.size()

	for k in pris.size():
		var a: Array = pris[k]
		var ech: float = float(a[3])
		var t := Transform3D(Basis(), Vector3.ZERO)
		t = t.rotated(Vector3.UP, float(a[4]))
		t = t.scaled(Vector3(ech, ech, ech))
		# 🔄 Le mesh a son PIED À L'ORIGINE : plus de demi-blob à remonter,
		# comme le faisait l'ancienne sphère centrée sur elle-même.
		t.origin = Vector3(float(a[0]), float(a[1]), float(a[2]))
		mm.set_instance_transform(k, t)
		# Variation de valeur, pas de teinte (Direction artistique l.67).
		var f: float = 0.86 + 0.28 * fmod(abs(float(a[4])) * 7.3, 1.0)
		mm.set_instance_color(k, Color(feuillage.r * f, feuillage.g * f,
			feuillage.b * f))
	return mm


## Deux surfaces : la couronne suit la teinte d'instance, le tronc non. C'est
## ce qui permet un tronc brun sous un feuillage vert dans un seul MultiMesh —
## et pourquoi les arbres n'ont pas de `material_override`.
static func _arbre(essence: int, tronc: Color) -> ArrayMesh:
	var m := ArrayMesh.new()

	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var c := PackedColorArray()
	var i := PackedInt32Array()

	if essence == CONIFERE:
		# Un épicéa se lit à sa SILHOUETTE, pas à son détail : budget
		# polygonal, le détail va dans le matériau.
		_cone(v, n, c, i, 1.90, 1.10, 3.20, 6, 0.62, 0.86)
		_cone(v, n, c, i, 1.45, 3.00, 2.80, 6, 0.78, 1.00)
		_cone(v, n, c, i, 0.95, 4.90, 2.60, 6, 0.92, 1.12)
	else:
		# DÉCENTRÉS : concentriques, ils redonneraient la bille d'avant.
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


## Une sphère à six méridiens, dégradé vertical bakké en couleur de sommet :
## sans lui, une sphère sous une lumière fixe est un disque plat.
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


## Posé sur `y0`. `pointe` < 1 le laisse ouvert en haut : un tronc plutôt
## qu'une aiguille.
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


## Verse une primitive transformée dans les tableaux, avec son dégradé vertical
## en couleur de sommet.
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
