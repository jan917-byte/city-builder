extends RefCounted
# 🌿 LA COUCHE D'HERBE D'UN TOIT VERT (auteur, 2026-10-28 : « un peu de volume, de l'herbe,
# que ça dépasse un tout petit peu sur les bords ») : un coussin posé au-dessus de l'acrotère,
# arrondi au bord, frangé d'herbe qui pend. Un toit le montre dès que son rang (UV2.y, posé
# par 07) passe sous la part verdie — la règle du shader.
# 🔄 RETOUR EN ARRIÈRE SIGNALÉ : buissons, touffes modelées (+6 ms par image à 135 000, M1
# Max), mottes (+3 ms), plans croisés (+1,4 ms, des étoiles vues d'en haut), aplat seul et
# cadre de terre : tous retirés le même jour.

const EPAIS := 0.57     # m au-dessus du toit : l'acrotère de 07 (0,45) + 12 cm
const DEBORD := 0.22    # m au-delà du muret, × `_gonfle` (0 à 1,8) : il avance, recule, s'efface
const PAS_BORD := 0.5   # m entre deux points du bord
const BOMBE := 0.07     # m que perd le dessus en arrivant au bord
const LEVRE := 0.10     # m de tranche verticale sous le bord
const FRANGE := 0.40    # m : la plus longue mèche qui pend
const BOSSE := 0.16     # m : le creux le plus profond entre deux bosses du dessus
const MAILLE := 1.2     # m : le pas du dessus, assez fin pour que les bosses s'éclairent
# Nuances (× le vert du dessus au même endroit) : la lèvre, le bout des mèches.
const BORD := 0.88
const PIED := 0.72


## {toits : [p0, p1, p2, rang, rang de montée, suit le toit],
##  bords : [a, b, vers l'intérieur, rang, rang de montée, suit le toit, onglet en a, onglet en b]},
## triés par rang : les toits verdissent dans cet ordre, donc un préfixe suffit.
static func semis(mesh: Mesh) -> Dictionary:
	var toits := []
	var bords := []
	var r := {"toits": toits, "bords": bords}
	if mesh == null or mesh.get_surface_count() == 0:
		return r
	var a: Array = mesh.surface_get_arrays(0)
	var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var nm: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
	var uv = a[Mesh.ARRAY_TEX_UV]
	var uv2 = a[Mesh.ARRAY_TEX_UV2]
	var cu = a[Mesh.ARRAY_CUSTOM0]
	var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX]
	if uv == null or uv2 == null:
		return r
	var c0: PackedFloat32Array = cu if cu != null else PackedFloat32Array()
	# Les mêmes tests que le shader : plat, en hauteur, un toit (UV unitaire), un rang.
	var vus := {}
	var aretes := {}
	for t in range(0, idx.size(), 3):
		var i0 := idx[t]
		if nm[i0].y < 0.995 or v[i0].y < 1.0 or (uv[i0] as Vector2).length() < 0.5:
			continue
		var rang: float = (uv2[i0] as Vector2).y
		if rang >= 1.0 or (uv2[i0] as Vector2).x > 0.0:
			continue
		var monte := c0[i0 * 4] if c0.size() > i0 * 4 + 1 else 0.0
		var suit := c0[i0 * 4 + 1] if c0.size() > i0 * 4 + 1 else 0.0
		toits.append([v[i0], v[idx[t + 1]], v[idx[t + 2]], rang, monte, suit])
		for k in 3:
			var pa := v[idx[t + k]]
			var pb := v[idx[t + (k + 1) % 3]]
			# Le rang dans la clé : deux toits mitoyens ont chacun leur bord, donc leur coussin.
			var cle := "%.4f|%s" % [rang, _cle(pa, pb)]
			vus[cle] = int(vus.get(cle, 0)) + 1
			aretes[cle] = [pa, pb, v[idx[t + (k + 2) % 3]], rang, monte, suit]
	# Une arête vue une seule fois est un bord de toit : l'acrotère.
	var dehors := {}
	for cle in vus:
		if vus[cle] == 1:
			var ar: Array = aretes[cle]
			var dir := Vector3(ar[1] - ar[0]).cross(Vector3.UP).normalized()
			if dir.dot(ar[2] - ar[0]) < 0.0:
				dir = -dir
			bords.append([ar[0], ar[1], dir, ar[3], ar[4], ar[5]])
			for p in [ar[0], ar[1]]:
				var cp := "%.4f|%s" % [ar[3], _cle(p, p)]
				dehors[cp] = dehors.get(cp, Vector3.ZERO) - dir
	# L'onglet d'un coin : la somme des deux normales, allongée pour garder le débord.
	for e in bords:
		for p in [e[0], e[1]]:
			var o: Vector3 = (dehors["%.4f|%s" % [e[3], _cle(p, p)]] as Vector3).normalized()
			e.append(o / maxf(o.dot(-(e[2] as Vector3)), 0.5))
	toits.sort_custom(func(x, y): return float(x[3]) < float(y[3]))
	bords.sort_custom(func(x, y): return float(x[3]) < float(y[3]))
	return r


## Combien d'entrées montrer pour cette part de toit plat verdie.
static func compte(liste: Array, part_v: float) -> int:
	return liste.bsearch_custom(part_v, func(e, p): return float(e[3]) < float(p))


## Le coussin : un dessus bosselé, un biseau qui déborde du muret plus ou moins selon
## l'endroit, une lèvre, des mèches en touffes. `toits` et `bords` déjà coupés au compte ;
## `dn` = `Ville.rendu_dense`. COLOR.a = combien le sommet suit le vent (`herbe_toit`).
static func couche(toits: Array, bords: Array, dn: Vector3, vert: Color) -> ArrayMesh:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var c := PackedColorArray()
	for e in toits:
		_dessus(v, n, c, e[0], e[1], e[2], EPAIS + montee(e[4], e[5], dn), vert)
	for e in bords:
		var lever := Vector3.UP * montee(e[4], e[5], dn)
		var a: Vector3 = e[0] + lever
		var b: Vector3 = e[1] + lever
		_bord(v, n, c, a, b, -(e[2] as Vector3), e[6], e[7], vert)
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_NORMAL] = n
	arr[Mesh.ARRAY_COLOR] = c
	var m := ArrayMesh.new()
	if not v.is_empty():
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m


## Un bord, par pas de PAS_BORD : le débord suit `_gonfle`, tiré au lieu (deux toits voisins
## et deux images de suite disent pareil) ; les mèches poussent en touffes, de taille inégale.
static func _bord(v: PackedVector3Array, n: PackedVector3Array, c: PackedColorArray,
		a: Vector3, b: Vector3, dh: Vector3, oa: Vector3, ob: Vector3, vert: Color) -> void:
	var long := a.distance_to(b)
	var ns := maxi(1, ceili(long / PAS_BORD))
	# Le bord prolonge le dessus : même creux, même teinte, même lumière à la jonction ;
	# il ne fait que s'arrondir et foncer un peu en descendant (auteur, 2026-10-28 :
	# « la bordure ne s'intègre pas »).
	var pts := []      # [haut, dehors, lèvre]
	var nrm := []
	var col := []
	for i in ns + 1:
		var t := float(i) / ns
		var p := a.lerp(b, t)
		var o: Vector3 = oa if i == 0 else (ob if i == ns else dh)
		var g := _gonfle(p.x, p.z)
		var y := EPAIS - _bosse(p.x, p.z)
		var nt := _normale(p.x, p.z)
		var f := lerpf(1.04, 0.80, _bosse(p.x, p.z) / BOSSE)
		pts.append([p + Vector3.UP * y,
			p + o * DEBORD * g + Vector3.UP * (y - BOMBE * (0.4 + 0.6 * g)),
			p + o * (DEBORD * g + 0.03) + Vector3.UP * (y - BOMBE - LEVRE * (0.5 + 0.5 * g))])
		nrm.append([nt, (nt + dh * 0.8).normalized(), (dh + Vector3.UP * 0.4).normalized()])
		col.append([_teinte(vert, f, 0.0), _teinte(vert, f * 0.96, 0.0), _teinte(vert, f * BORD, 0.0)])
	for i in ns:
		for r in 2:
			var p0: Array = pts[i]
			var p1: Array = pts[i + 1]
			v.append_array([p0[r], p1[r], p1[r + 1], p0[r], p1[r + 1], p0[r + 1]])
			n.append_array([nrm[i][r], nrm[i + 1][r], nrm[i + 1][r + 1], nrm[i][r], nrm[i + 1][r + 1], nrm[i][r + 1]])
			c.append_array([col[i][r], col[i + 1][r], col[i + 1][r + 1], col[i][r], col[i + 1][r + 1], col[i][r + 1]])
	var levre := pts.map(func(q): return q[2])
	# Les mèches : pas, largeur, longueur et biais au hasard, la touffe décidée par le lieu.
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector3i((a + b) * 50.0))
	var nf := (dh + Vector3.UP * 0.3).normalized()
	var s := rng.randf() * 0.1
	while s < long:
		var w := rng.randf_range(0.05, 0.22)
		var t0 := s / long
		var t1 := minf(s + w, long) / long
		s += w * rng.randf_range(0.5, 1.6)
		var x0 := _sur(levre, t0)
		var x1 := _sur(levre, t1)
		var m := (x0 + x1) * 0.5
		var touffu := smoothstep(0.25, 0.75, _bruit(m.x * 0.9 + 31.0, m.z * 0.9 + 7.0))
		var l := FRANGE * touffu * pow(rng.randf(), 0.7)
		if l < 0.04:
			continue
		var cote := (x1 - x0).normalized() * rng.randf_range(-0.10, 0.10)
		var bout := m + cote + dh * rng.randf_range(0.02, 0.10) - Vector3.UP * l
		var cl: Color = col[mini(int(t0 * ns), ns)][2]
		v.append_array([x0, x1, bout])
		n.append_array([nf, nf, nf])
		c.append_array([cl, cl, _teinte(cl, PIED / BORD, 1.0)])


static func _sur(pts: Array, t: float) -> Vector3:
	var f := t * (pts.size() - 1)
	var i := mini(int(f), pts.size() - 2)
	return (pts[i] as Vector3).lerp(pts[i + 1], f - i)


## Combien le coussin déborde ici, × DEBORD : de 0 (collé au muret) à ~1,8.
static func _gonfle(x: float, z: float) -> float:
	return clampf(-0.35 + 1.6 * _bruit(x * 0.45 + 5.0, z * 0.45 + 9.0)
		+ 0.6 * _bruit(x * 1.7, z * 1.7), 0.0, 1.8)


static func _teinte(vert: Color, f: float, vent: float) -> Color:
	return Color(vert.r * f, vert.g * f, vert.b * f, vent)


## Le dessus, redécoupé en mailles de MAILLE et bosselé ; l'ombre des creux se peint aussi.
static func _dessus(v: PackedVector3Array, n: PackedVector3Array, c: PackedColorArray,
		p0: Vector3, p1: Vector3, p2: Vector3, lever: float, vert: Color) -> void:
	var k := maxi(1, ceili(maxf(p0.distance_to(p1), maxf(p1.distance_to(p2), p2.distance_to(p0))) / MAILLE))
	var u := (p1 - p0) / k
	var w := (p2 - p0) / k
	var pt := func(i: int, j: int) -> Vector3:
		var q: Vector3 = p0 + u * i + w * j
		return Vector3(q.x, q.y + lever - _bosse(q.x, q.z), q.z)
	for i in k:
		for j in k - i:
			var tri := [[pt.call(i, j), pt.call(i + 1, j), pt.call(i, j + 1)]]
			if i + j < k - 1:
				tri.append([pt.call(i + 1, j), pt.call(i + 1, j + 1), pt.call(i, j + 1)])
			for t in tri:
				for q in t:
					v.append(q)
					n.append(_normale(q.x, q.z))
					# Le creux plus sombre : de haut, c'est lui qui dit « coussin ».
					c.append(_teinte(vert, lerpf(1.04, 0.80, _bosse(q.x, q.z) / BOSSE), 0.0))


## Profondeur sous le haut du coussin, de 0 à BOSSE : deux octaves de bruit doux, ~5 m et ~2 m.
static func _bosse(x: float, z: float) -> float:
	return BOSSE * clampf(0.65 * _bruit(x * 0.2, z * 0.2) + 0.35 * _bruit(x * 0.5 + 17.0, z * 0.5 + 3.0), 0.0, 1.0)


static func _normale(x: float, z: float) -> Vector3:
	var d := 0.25
	return Vector3(_bosse(x + d, z) - _bosse(x - d, z), 2.0 * d, _bosse(x, z + d) - _bosse(x, z - d)).normalized()


static func _bruit(x: float, z: float) -> float:
	var ix := floorf(x)
	var iz := floorf(z)
	var fx := x - ix
	var fz := z - iz
	fx = fx * fx * (3.0 - 2.0 * fx)
	fz = fz * fz * (3.0 - 2.0 * fz)
	return lerpf(lerpf(_alea(ix, iz), _alea(ix + 1.0, iz), fx),
		lerpf(_alea(ix, iz + 1.0), _alea(ix + 1.0, iz + 1.0), fx), fz)


static func _alea(x: float, z: float) -> float:
	return fposmod(sin(x * 12.9898 + z * 78.233) * 43758.545, 1.0)


## Ce que DENSE_VERTEX (`materiaux.gd`) ajoute au toit : à recopier si l'un change.
static func montee(rang_monte: float, suit: float, dn: Vector3) -> float:
	if suit < 0.5:
		return 0.0
	return dn.z * clampf((dn.x - rang_monte) / maxf(dn.y, 0.001), 0.0, 1.0)


## Au centimètre et sans ordre : deux triangles voisins citent la même arête.
static func _cle(a: Vector3, b: Vector3) -> String:
	var sa := "%d,%d,%d" % [roundi(a.x * 100.0), roundi(a.y * 100.0), roundi(a.z * 100.0)]
	var sb := "%d,%d,%d" % [roundi(b.x * 100.0), roundi(b.y * 100.0), roundi(b.z * 100.0)]
	return sa + "|" + sb if sa < sb else sb + "|" + sa

