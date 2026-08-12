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


## Un maillage plat {v, n, c, i} → ArrayMesh. Un seul appel à
## add_surface_from_arrays : c'est ce qui évite les ~95 000 appels de fonction
## qu'un SurfaceTool coûterait sur le terrain.
static func maillage(d: Dictionary) -> ArrayMesh:
	var vs: Array = d["v"]
	var ns: Array = d["n"]
	var cs: Array = d["c"]
	var idx: Array = d["i"]

	var n: int = vs.size()
	var v := PackedVector3Array()
	var nm := PackedVector3Array()
	var co := PackedColorArray()
	v.resize(n)
	nm.resize(n)
	co.resize(n)
	for k in n:
		var a: Array = vs[k]
		var b: Array = ns[k]
		var c: Array = cs[k]
		v[k] = Vector3(a[0], a[1], a[2])
		nm[k] = Vector3(b[0], b[1], b[2])
		co[k] = _couleur(c)

	var i := PackedInt32Array()
	i.resize(idx.size())
	for k in idx.size():
		i[k] = int(idx[k])

	return _surface(v, nm, co, i)


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
	var idx: Array = d["i"]

	# Les indices citent des sommets répartis dans TOUT le tableau : il faut
	# les renuméroter, sinon la tranche traîne les 40 000 sommets des autres.
	var renumerote := {}
	var v := PackedVector3Array()
	var nm := PackedVector3Array()
	var co := PackedColorArray()
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
		i[k] = renumerote[src]

	return _surface(v, nm, co, i)


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
		c: PackedColorArray, i: PackedInt32Array) -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)          # obligatoire AVANT d'indexer
	arrays[Mesh.ARRAY_VERTEX] = v
	arrays[Mesh.ARRAY_NORMAL] = n
	arrays[Mesh.ARRAY_COLOR] = c
	arrays[Mesh.ARRAY_INDEX] = i
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(PRIM, arrays)
	return m


## Les arbres : UNE instance multiple pour toute la famille, pas un nœud par
## objet — « le geste se prend au début, pas après »
## (`Génération procédurale.md:74`).
##
## Les 69 îlots, eux, n'en ont pas : un MultiMesh répète UN MÊME mesh, or ce
## sont 69 formes distinctes. Il faudrait 69 MultiMesh d'une instance chacun,
## soit 69 draw calls au lieu de 1. La fusion en un ArrayMesh sert la même
## intention, et mieux.
static func arbres(liste: Array, feuillage: Color) -> MultiMesh:
	var blob := SphereMesh.new()
	blob.radius = 3.0
	blob.height = 7.0
	blob.radial_segments = 6      # une maquette, pas un jardin
	blob.rings = 3

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = blob
	mm.instance_count = liste.size()

	for k in liste.size():
		var a: Array = liste[k]
		var ech: float = float(a[3])
		var t := Transform3D(Basis(), Vector3.ZERO)
		t = t.rotated(Vector3.UP, float(a[4]))
		t = t.scaled(Vector3(ech, ech, ech))
		# Posé sur le sol : le centre de la sphère monte d'un demi-blob.
		t.origin = Vector3(float(a[0]), float(a[1]) + blob.height * 0.42 * ech,
			float(a[2]))
		mm.set_instance_transform(k, t)
		# Une variation de valeur, pas de teinte : « les teintes sont fixes »
		# (Direction artistique l.67).
		var f: float = 0.88 + 0.24 * fmod(abs(float(a[4])) * 7.3, 1.0)
		mm.set_instance_color(k, Color(feuillage.r * f, feuillage.g * f,
			feuillage.b * f))
	return mm
