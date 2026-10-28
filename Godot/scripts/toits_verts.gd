extends RefCounted
# 🌿 LE TOIT VERT EN RELIEF (auteur, 2026-10-28 : « des vrais objets 3D, pas une texture ») :
# buissons du pack et touffes d'herbe, semés une fois par îlot sur ses toits plats. Un toit
# les montre dès que son rang (UV2.y, posé par 07) passe sous la part verdie — la règle du shader.

const Constructeur := preload("res://scripts/constructeur.gd")

const M2_PAR_TOUFFE := 0.8
# Là où un massif se serre ; ailleurs, aucun. 7 → 20 : « trop de buissons » (auteur, 2026-10-28).
const M2_PAR_BUISSON := 20.0
const MARGE_ACROTERE := 0.7     # m : rien ne dépasse du bord, ni ne pousse sur le cadre
# 🟫 Le cadre de terre le long de l'acrotère (auteur, 2026-10-28). Éclairci de #94785A
# (PAL.SENTIER), jugé trop sombre par l'auteur le même jour.
const CADRE_LARGEUR := 0.45
const CADRE := Color("#C2AA86")
const TOUFFE := -1              # « essence » d'une touffe dans le semis


## {plantes : [x, y, z, échelle, lacet, essence ou TOUFFE, rang, rang de montée, suit le toit],
##  cadre : [a, b, vers l'intérieur, rang, rang de montée, suit le toit]}, triés par rang :
## les toits verdissent dans cet ordre, donc un préfixe suffit.
static func semis(mesh: Mesh, graine: int) -> Dictionary:
	var liste := []
	var cadre := []
	var vide := {"plantes": liste, "cadre": cadre}
	if mesh == null or mesh.get_surface_count() == 0:
		return vide
	var a: Array = mesh.surface_get_arrays(0)
	var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var nm: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
	var uv = a[Mesh.ARRAY_TEX_UV]
	var uv2 = a[Mesh.ARRAY_TEX_UV2]
	var cu = a[Mesh.ARRAY_CUSTOM0]
	var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX]
	if uv == null or uv2 == null:
		return vide
	var c0: PackedFloat32Array = cu if cu != null else PackedFloat32Array()
	# Les mêmes tests que le shader : plat, en hauteur, un toit (UV unitaire), un rang.
	var tris := []
	var bords := {}
	var aretes := {}
	for t in range(0, idx.size(), 3):
		var i0 := idx[t]
		if nm[i0].y < 0.995 or v[i0].y < 1.0 or (uv[i0] as Vector2).length() < 0.5:
			continue
		var rang: float = (uv2[i0] as Vector2).y
		if rang >= 1.0 or (uv2[i0] as Vector2).x > 0.0:
			continue
		tris.append(t)
		for k in 3:
			var pa := v[idx[t + k]]
			var pb := v[idx[t + (k + 1) % 3]]
			var cle := _cle(pa, pb)
			bords[cle] = int(bords.get(cle, 0)) + 1
			aretes[cle] = [pa, pb, v[idx[t + (k + 2) % 3]], t]
	# Une arête vue une seule fois est un bord de toit : l'acrotère. Rangées par
	# hauteur au décimètre, chaque toit ne teste que les siennes.
	var segments := {}
	for cle in bords:
		if bords[cle] == 1:
			var h := roundi((aretes[cle][0] as Vector3).y * 10.0)
			if not segments.has(h):
				segments[h] = []
			var ar: Array = aretes[cle]
			(segments[h] as Array).append(ar)
			var i0: int = idx[ar[3]]
			var dir := Vector3(ar[1] - ar[0]).cross(Vector3.UP).normalized()
			if dir.dot(ar[2] - ar[0]) < 0.0:
				dir = -dir
			cadre.append([ar[0], ar[1], dir, (uv2[i0] as Vector2).y,
				c0[i0 * 4] if c0.size() > i0 * 4 + 1 else 0.0,
				c0[i0 * 4 + 1] if c0.size() > i0 * 4 + 1 else 0.0])
	var rng := RandomNumberGenerator.new()
	rng.seed = graine
	for t in tris:
		var p0 := v[idx[t]]
		var p1 := v[idx[t + 1]]
		var p2 := v[idx[t + 2]]
		var i0 := idx[t]
		var rang: float = (uv2[i0] as Vector2).y
		var monte := c0[i0 * 4] if c0.size() > i0 * 4 + 1 else 0.0
		var suit := c0[i0 * 4 + 1] if c0.size() > i0 * 4 + 1 else 0.0
		var aire := 0.5 * (p1 - p0).cross(p2 - p0).length()
		var n := int(aire / M2_PAR_TOUFFE + rng.randf())
		for k in n:
			var r1 := rng.randf()
			var r2 := rng.randf()
			if r1 + r2 > 1.0:
				r1 = 1.0 - r1
				r2 = 1.0 - r2
			var p := p0 + (p1 - p0) * r1 + (p2 - p0) * r2
			if _pres_du_bord(p, segments, MARGE_ACROTERE):
				continue
			var lacet := rng.randf() * TAU
			# En massifs, pas en pois : une nappe de ~15 m décide où les buissons se serrent.
			var massif := _nappe(p.x * 0.07, p.z * 0.07)
			var buisson := rng.randf() < M2_PAR_TOUFFE / M2_PAR_BUISSON \
				* smoothstep(0.35, 0.75, massif) * 2.0
			if buisson and not _pres_du_bord(p, segments, MARGE_ACROTERE + 0.5):
				liste.append([p.x, p.y, p.z, rng.randf_range(0.45, 0.75), lacet,
					Constructeur.BUISSON, rang, monte, suit])
			else:
				liste.append([p.x, p.y, p.z, rng.randf_range(0.7, 1.3), lacet,
					TOUFFE, rang, monte, suit])
	liste.sort_custom(func(x, y): return float(x[6]) < float(y[6]))
	cadre.sort_custom(func(x, y): return float(x[3]) < float(y[3]))
	return vide


## Combien d'entrées montrer pour cette part de toit plat verdie ; `col` = où est le rang.
static func compte(liste: Array, part_v: float, col := 6) -> int:
	return liste.bsearch_custom(part_v, func(e, p): return float(e[col]) < float(p))


## Le cadre : une bande de terre posée à plat contre chaque bord, 3 cm au-dessus du toit.
static func cadre(liste: Array, dn: Vector3) -> ArrayMesh:
	var v := PackedVector3Array()
	for e in liste:
		var lever := Vector3.UP * (0.03 + montee([0, 0, 0, 0, 0, 0, 0, e[4], e[5]], dn))
		var a: Vector3 = e[0] + lever
		var b: Vector3 = e[1] + lever
		var d: Vector3 = e[2] * CADRE_LARGEUR
		v.append_array([a, b, b + d, a, b + d, a + d])
	var n := PackedVector3Array()
	n.resize(v.size())
	n.fill(Vector3.UP)
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_NORMAL] = n
	var m := ArrayMesh.new()
	if not v.is_empty():
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m


## La touffe : neuf brins pointus en couronne, pied sombre, pointe claire. 1 m de haut,
## l'instance l'échelle. Normales vers le ciel : elle s'éclaire comme la pelouse.
static func touffe() -> ArrayMesh:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var c := PackedColorArray()
	for b in 9:
		var az := TAU * float(b) / 9.0 + 0.4 * sin(float(b) * 2.3)
		var dehors := Vector3(cos(az), 0.0, sin(az))
		var cote := Vector3(-dehors.z, 0.0, dehors.x) * 0.11
		var penche := 0.25 + 0.25 * fposmod(float(b) * 0.618, 1.0)
		var haut := 0.75 + 0.25 * fposmod(float(b) * 0.381, 1.0)
		var pied := dehors * 0.06
		v.append_array([pied - cote, pied + cote, dehors * (0.06 + penche * haut) + Vector3.UP * haut])
		c.append_array([Color(0.78, 0.78, 0.78), Color(0.78, 0.78, 0.78), Color(1.30, 1.25, 1.05)])
		for k in 3:
			n.append(Vector3.UP)
	var a := []
	a.resize(Mesh.ARRAY_MAX)
	a[Mesh.ARRAY_VERTEX] = v
	a[Mesh.ARRAY_NORMAL] = n
	a[Mesh.ARRAY_COLOR] = c
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)
	return m


## `liste` déjà coupée au compte ; `dn` = `Ville.rendu_dense`, pour suivre un toit qui monte.
static func touffes(liste: Array, dn: Vector3, herbe: Color) -> MultiMesh:
	var pris := liste.filter(func(e): return int(e[5]) == TOUFFE)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = touffe()
	mm.instance_count = pris.size()
	for k in pris.size():
		var e: Array = pris[k]
		var ech := float(e[3]) * 0.5
		var b := Basis(Vector3.UP, float(e[4])).scaled(Vector3(ech, ech, ech))
		mm.set_instance_transform(k, Transform3D(b, Vector3(float(e[0]),
			float(e[1]) + montee(e, dn), float(e[2]))))
		var f := 0.86 + 0.26 * fposmod(float(e[4]) * 7.3, 1.0)
		mm.set_instance_color(k, Color(herbe.r * f, herbe.g * f, herbe.b * f))
	return mm


## Les buissons au format de `Constructeur.arbres`, le toit levé compris.
static func buissons(liste: Array, dn: Vector3) -> Array:
	var r := []
	for e in liste:
		if int(e[5]) == Constructeur.BUISSON:
			r.append([float(e[0]), float(e[1]) + montee(e, dn), float(e[2]), e[3], e[4], e[5]])
	return r


## 🎨 Les buissons dans le vert du toit (auteur, 2026-10-28), un cran plus sombres pour se
## détacher. Chacun tire sa nuance, olive ou franche, et sa valeur : linéaire.
const BUISSON_OLIVE := Color(1.10, 1.00, 0.70)
const BUISSON_FRANC := Color(0.85, 1.02, 0.95)

static func teinter(mm: MultiMesh, pelouse: Color) -> void:
	for k in mm.instance_count:
		var o := mm.get_instance_transform(k).origin
		var h := fposmod(sin(o.x * 12.9898 + o.z * 78.233) * 43758.545, 1.0)
		var f := lerpf(0.62, 0.86, fposmod(h * 7.31, 1.0))
		var nuance := BUISSON_OLIVE.lerp(BUISSON_FRANC, h)
		mm.set_instance_color(k, Color(pelouse.r * nuance.r * f,
			pelouse.g * nuance.g * f, pelouse.b * nuance.b * f))


## Ce que DENSE_VERTEX (`materiaux.gd`) ajoute au toit : à recopier si l'un change.
static func montee(e: Array, dn: Vector3) -> float:
	if float(e[8]) < 0.5:
		return 0.0
	return dn.z * clampf((dn.x - float(e[7])) / maxf(dn.y, 0.001), 0.0, 1.0)


## Au centimètre et sans ordre : deux triangles voisins citent la même arête.
static func _cle(a: Vector3, b: Vector3) -> String:
	var sa := "%d,%d,%d" % [roundi(a.x * 100.0), roundi(a.y * 100.0), roundi(a.z * 100.0)]
	var sb := "%d,%d,%d" % [roundi(b.x * 100.0), roundi(b.y * 100.0), roundi(b.z * 100.0)]
	return sa + "|" + sb if sa < sb else sb + "|" + sa


static func _pres_du_bord(p: Vector3, segments: Dictionary, d: float) -> bool:
	for s in segments.get(roundi(p.y * 10.0), []):
		var a: Vector3 = s[0]
		var b: Vector3 = s[1]
		var ab := Vector2(b.x - a.x, b.z - a.z)
		var ap := Vector2(p.x - a.x, p.z - a.z)
		var t := clampf(ap.dot(ab) / maxf(ab.length_squared(), 1e-6), 0.0, 1.0)
		if (ap - ab * t).length() < d:
			return true
	return false


static func _nappe(x: float, z: float) -> float:
	return 0.5 + 0.25 * sin(x * 2.1 + 1.3) * sin(z * 1.7 + 0.4) + 0.25 * sin((x + z) * 1.3 + 2.0)
