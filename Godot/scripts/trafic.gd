extends Node3D
# Un flux agrégé figuré : les voitures glissent sur les axes exportés, aucune
# ne navigue. Deux MultiMesh couvrent toute la ville (décision 62).

const Constructeur := preload("res://scripts/constructeur.gd")

const Y_ROULE := 0.72
const Y_GARE := 0.66
const ESPACEMENT_CALME := 48.0
const ESPACEMENT_CHARGE := 7.0
const ESPACEMENT_RESERVE := 12.0
const LONGUEUR_PLACE := 5.5
const ECHANTILLON_STATIONNEMENT := 0.30
const TAILLE_VISIBLE_MAX := 700.0
const PALETTE := [
	Color8(194, 92, 73), Color8(70, 91, 112), Color8(216, 198, 157),
	Color8(116, 130, 119), Color8(151, 116, 92), Color8(205, 207, 198),
]
const VITESSES := {
	"autoroute": 70.0, "boulevard": 50.0, "rue": 30.0,
	"ruelle": 12.0, "rive": 25.0,
}

var ville
var _roulantes := []
var _garees := []
var _mm_roule: MultiMesh
var _mm_gare: MultiMesh
var _node_roule: MultiMeshInstance3D
var _node_gare: MultiMeshInstance3D
var _actif := true
var _visibles_roule := PackedByteArray()
var _visibles_gare := PackedByteArray()
var _dernier_etat := -1.0
var _derniere_charge := -1.0
var _graphe := {}
var _fermees := {}
var _calibration := [1.0, 1.0]
var _indisponibles_connues := ""


func batir(donnees: Dictionary, etat_ville) -> void:
	ville = etat_ville
	var couloirs: Dictionary = donnees["couloirs"]
	_batir_graphe(couloirs)
	var indisponibles := _indisponibles(0.0)
	var reference := _affectation(indisponibles)
	_calibration = [_p95(reference[0]), _p95(reference[1])]
	_reaffecter(0.0, 0.0, indisponibles)
	for fid in ville.routes:
		var cle := str(fid)
		if not couloirs.has(cle):
			continue
		var route: Dictionary = ville.routes[fid]
		var largeur := float(route.get("largeur_m", 0.0))
		for brut in (couloirs[cle][1] as Array):
			var chemin := _chemin(brut)
			if chemin[1] < 8.0:
				continue
			var n := maxi(1, int(floor(float(chemin[1]) / ESPACEMENT_RESERVE)))
			for k in n:
				_roulantes.append({"fid": fid, "p": chemin[0], "cum": chemin[2],
					"L": chemin[1], "s": fmod((k + 0.35) * float(chemin[1]) / n,
					float(chemin[1])), "sens": -1.0 if k % 2 else 1.0,
					"decal": 1.35,
					"rang": k, "max": n})

		var places := int(roundf(ville.valeur("r", fid, "stationnement", 0.0)
			* ECHANTILLON_STATIONNEMENT))
		if places <= 0:
			continue
		var parties: Array = couloirs[cle][1]
		var par_cote := int(ceil(places / 2.0))
		for k in places:
			var brut: Array = parties[k % parties.size()]
			var chemin := _chemin(brut)
			if chemin[1] < LONGUEUR_PLACE:
				continue
			var cote := -1.0 if k % 2 else 1.0
			var s := fmod((int(k / 2) % maxi(par_cote, 1) + 0.5) * LONGUEUR_PLACE,
				float(chemin[1]))
			_garees.append({"fid": fid, "t": _transforme(chemin[0], chemin[2],
				chemin[1], s, cote * maxf(2.7, largeur * 0.30), Y_GARE)})

	_mm_roule = Constructeur.voitures(_roulantes.size(), true)
	_mm_gare = Constructeur.voitures(_garees.size())
	_node_roule = MultiMeshInstance3D.new()
	_node_roule.name = "VoituresRoulantes"
	_node_roule.multimesh = _mm_roule
	_node_roule.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_node_roule)
	_node_gare = MultiMeshInstance3D.new()
	_node_gare.name = "VoituresGarees"
	_node_gare.multimesh = _mm_gare
	_node_gare.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_node_gare)
	for k in _roulantes.size():
		_mm_roule.set_instance_color(k, PALETTE[(k * 5 + 1) % PALETTE.size()])
		var a: Dictionary = _roulantes[k]
		var segment := _segment(a["p"], a["cum"], a["L"], a["s"],
			float(a["decal"]), float(a["sens"]))
		a["t"] = segment[0]
		a["phase"] = segment[1]
		a["segment_m"] = segment[2]
	_visibles_roule.resize(_roulantes.size())
	_visibles_roule.fill(0)
	_maj_roulantes(0.0, true)
	for k in _garees.size():
		var gris := 0.62 + 0.16 * float(k % 5) / 4.0
		_mm_gare.set_instance_color(k, Color(gris, gris * 1.01, gris * 0.98))
	_visibles_gare.resize(_garees.size())
	_visibles_gare.fill(0)
	_maj_garees(0.0, true)
	print(("  trafic : %d voitures roulantes visibles sur %d positions,"
		+ " %d garées sur 3310 places, 2 appels, animation GPU à l'écran")
		% [_compter_visibles(), _roulantes.size(), _garees.size()])


func avancer(mois: float) -> void:
	if not _actif:
		return
	var indisponibles := _indisponibles(mois)
	var signature := _signature(indisponibles)
	if signature != _indisponibles_connues:
		_reaffecter(mois, 0.0, indisponibles)
	if absf(mois - _dernier_etat) > 0.02:
		_maj_garees(mois, false)
	if absf(mois - _derniere_charge) > 0.05:
		_maj_roulantes(mois, false)


func regler_detail(taille_camera: float) -> void:
	var actif := taille_camera <= TAILLE_VISIBLE_MAX
	if actif == _actif:
		return
	_actif = actif
	_node_roule.visible = actif
	_node_gare.visible = actif
	if actif:
		_dernier_etat = -1.0
		_derniere_charge = -1.0


func _maj_roulantes(mois: float, force: bool) -> void:
	_derniere_charge = mois
	# La charge est une propriété de 178 rues, pas de milliers de voitures.
	var etat_routes := {}
	var indisponibles := _indisponibles(mois)
	for fid in ville.routes:
		var praticable := not indisponibles.has(fid)
		var q := float(ville.valeur("r", fid, "charge", mois)) if praticable else 0.0
		var hier := str(ville.routes[fid].get("hierarchie", "rue"))
		var libre := float(VITESSES.get(hier, 30.0)) / 3.6
		etat_routes[fid] = [q, maxf(1.1, libre * (1.0 - 0.92 * q * q)), praticable]
	for k in _roulantes.size():
		var a: Dictionary = _roulantes[k]
		var etat: Array = etat_routes[a["fid"]]
		var q: float = etat[0]
		var esp: float = lerpf(ESPACEMENT_CALME, ESPACEMENT_CHARGE,
			pow(clampf(q / 0.65, 0.0, 1.0), 0.72))
		var visibles: int = maxi(1, int(floor(float(a["L"]) / esp))) \
			if etat[2] else 0
		if int(a["rang"]) >= visibles:
			if force or _visibles_roule[k] == 1:
				_mm_roule.set_instance_transform(k, Transform3D(
					Basis().scaled(Vector3.ZERO), Vector3.ZERO))
				_visibles_roule[k] = 0
			continue
		var apparait := _visibles_roule[k] == 0
		_visibles_roule[k] = 1
		if force or apparait:
			_mm_roule.set_instance_transform(k, a["t"])
		_mm_roule.set_instance_custom_data(k, Color(float(a["phase"]),
			float(etat[1]), float(a["segment_m"]), 1.0))


func _compter_visibles() -> int:
	var n := 0
	for v in _visibles_roule:
		n += int(v)
	return n


## Contrôle de l'essai : roulantes puis garées réellement dessinées sur un fid.
func voitures_visibles_sur(fid: int) -> Array:
	var roulantes := 0
	for k in _roulantes.size():
		if int(_roulantes[k]["fid"]) == fid:
			roulantes += int(_visibles_roule[k])
	var garees := 0
	for k in _garees.size():
		if int(_garees[k]["fid"]) == fid:
			garees += int(_visibles_gare[k])
	return [roulantes, garees]


## Une affectation agrégée au clic, jamais une navigation par voiture.
func retirer_axe(fid: int, mois: float) -> void:
	if _fermees.has(fid):
		return
	_fermees[fid] = mois
	_reaffecter(mois, 6.0, _indisponibles(mois))
	_derniere_charge = -1.0


func axe_ferme(fid: int) -> bool:
	return _fermees.has(fid)


func report_en_cours(fid: int, mois: float) -> bool:
	return _fermees.has(fid) and mois < float(_fermees[fid]) + 6.0


func _reaffecter(mois: float, duree: float, indisponibles: Dictionary) -> void:
	var brut: Array = _affectation(indisponibles)
	for f in ville.routes:
		var ct: float = pow(minf(1.0, float(brut[0].get(f, 0)) / _calibration[0]), 0.6)
		var cl: float = pow(minf(1.0, float(brut[1].get(f, 0)) / _calibration[1]), 0.6)
		var cible: float = 0.0 if indisponibles.has(f) else \
			clampf(0.55 * ct + 0.45 * cl, 0.0, 1.0)
		ville.ajouter_rampe("r", f, "charge",
			cible - ville.valeur("r", f, "charge", mois), mois, 0.0, duree)
	_indisponibles_connues = _signature(indisponibles)
	_derniere_charge = -1.0
	_dernier_etat = -1.0


func _indisponibles(mois: float) -> Dictionary:
	var out := _fermees.duplicate()
	for fid in ville.routes:
		if not ville.route_praticable(fid, mois):
			out[fid] = true
	return out


static func _signature(indisponibles: Dictionary) -> String:
	var fids := indisponibles.keys()
	fids.sort()
	var morceaux := PackedStringArray()
	for fid in fids:
		morceaux.append(str(fid))
	return ",".join(morceaux)


func reinitialiser() -> void:
	_fermees.clear()
	var indisponibles := _indisponibles(0.0)
	_reaffecter(0.0, 0.0, indisponibles)
	_dernier_etat = -1.0
	_derniere_charge = -1.0


func _batir_graphe(couloirs: Dictionary) -> void:
	for cle in couloirs:
		var fid := int(cle)
		var hier := str(ville.routes[fid].get("hierarchie", "rue"))
		var vitesse := float(VITESSES.get(hier, 30.0)) / 3.6
		for brut in (couloirs[cle][1] as Array):
			for k in range(0, brut.size() - 2, 2):
				var a := Vector2(float(brut[k]), float(brut[k + 1]))
				var b := Vector2(float(brut[k + 2]), float(brut[k + 3]))
				var ka := "%d:%d" % [roundi(a.x * 2.0), roundi(a.y * 2.0)]
				var kb := "%d:%d" % [roundi(b.x * 2.0), roundi(b.y * 2.0)]
				if ka == kb:
					continue
				var t := a.distance_to(b) / vitesse
				if not _graphe.has(ka): _graphe[ka] = []
				if not _graphe.has(kb): _graphe[kb] = []
				_graphe[ka].append([kb, t, fid])
				_graphe[kb].append([ka, t, fid])


func _affectation(fermees: Dictionary) -> Array:
	var degres := {}
	for n in _graphe:
		var deg := 0
		for e in _graphe[n]:
			if not fermees.has(int(e[2])): deg += 1
		degres[n] = deg
	var portes := []
	var carrefours := []
	for n in degres:
		if degres[n] == 1: portes.append(n)
		if degres[n] != 2 and degres[n] > 0: carrefours.append(n)
	return [_accumuler(portes, fermees), _accumuler(carrefours, fermees)]


func _accumuler(noeuds: Array, fermees: Dictionary) -> Dictionary:
	var compte := {}
	for src in noeuds:
		var prec: Dictionary = _dijkstra(src, fermees)
		for cible in noeuds:
			if cible == src or not prec.has(cible): continue
			var u = cible
			while prec.has(u):
				var e: Array = prec[u]
				u = e[0]
				compte[e[1]] = int(compte.get(e[1], 0)) + 1
	return compte


func _dijkstra(src, fermees: Dictionary) -> Dictionary:
	var dist := {src: 0.0}
	var prec := {}
	var ouverts := [[0.0, src]]
	while not ouverts.is_empty():
		var meilleur := 0
		for k in range(1, ouverts.size()):
			if float(ouverts[k][0]) < float(ouverts[meilleur][0]): meilleur = k
		var courant: Array = ouverts.pop_at(meilleur)
		var dt := float(courant[0])
		var u = courant[1]
		if dt > float(dist.get(u, INF)) + 0.000001: continue
		for e in _graphe[u]:
			if fermees.has(int(e[2])): continue
			var nd := dt + float(e[1])
			if nd < float(dist.get(e[0], INF)) - 0.000001:
				dist[e[0]] = nd
				prec[e[0]] = [u, int(e[2])]
				ouverts.append([nd, e[0]])
	return prec


static func _p95(compte: Dictionary) -> float:
	var valeurs := compte.values()
	valeurs.sort()
	return maxf(1.0, float(valeurs[int(0.95 * (valeurs.size() - 1))])) \
		if not valeurs.is_empty() else 1.0


func _maj_garees(mois: float, force: bool) -> void:
	if not force and is_equal_approx(mois, _dernier_etat):
		return
	_dernier_etat = mois
	var vus := {}
	for k in _garees.size():
		var a: Dictionary = _garees[k]
		var fid: int = a["fid"]
		var rang := int(vus.get(fid, 0))
		vus[fid] = rang + 1
		var visibles := 0 if not ville.route_praticable(fid, mois) else \
			int(roundf(ville.valeur("r", fid, "stationnement", mois)
			* ECHANTILLON_STATIONNEMENT))
		# 🔄 LE CONTRÔLE NE RELIT PLUS LA MATRICE — corrigé le 2026-08-26. Une
		# base mise à zéro ressortait de `get_instance_transform` en IDENTITÉ,
		# donc l'essai voyait 5 voitures garées sur une rue noyée qui n'en
		# dessinait aucune. On note ce qu'on écrit, comme pour les roulantes.
		_visibles_gare[k] = 1 if rang < visibles else 0
		_mm_gare.set_instance_transform(k, a["t"] if rang < visibles else Transform3D(
			Basis().scaled(Vector3.ZERO), Vector3.ZERO))


static func _chemin(brut: Array) -> Array:
	var pts := PackedVector2Array()
	for k in range(0, brut.size(), 2):
		pts.append(Vector2(float(brut[k]), float(brut[k + 1])))
	var cum := PackedFloat32Array([0.0])
	for k in range(1, pts.size()):
		cum.append(cum[-1] + pts[k - 1].distance_to(pts[k]))
	return [pts, cum[-1], cum]


static func _segment(pts: PackedVector2Array, cum: PackedFloat32Array,
		longueur: float, s: float, decal: float, sens: float) -> Array:
	s = clampf(s, 0.0, longueur)
	var j := 1
	while j < cum.size() - 1 and cum[j] < s:
		j += 1
	var p := pts[j - 1]
	var q := pts[j]
	var segment_m := maxf(p.distance_to(q), 0.01)
	var depart := p if sens > 0.0 else q
	var u := ((q - p) if sens > 0.0 else (p - q)).normalized()
	var phase := s - cum[j - 1] if sens > 0.0 else cum[j] - s
	var pos := depart + Vector2(u.y, -u.x) * decal
	var basis := Basis(Vector3.UP, atan2(u.x, u.y))
	return [Transform3D(basis, Vector3(pos.x, Y_ROULE, pos.y)), phase, segment_m]


static func _transforme(pts: PackedVector2Array, cum: PackedFloat32Array,
		longueur: float, s: float, decal: float, y: float, sens := 1.0) -> Transform3D:
	s = clampf(s, 0.0, longueur)
	var j := 1
	while j < cum.size() - 1 and cum[j] < s:
		j += 1
	var p := pts[j - 1]
	var q := pts[j]
	var u := (q - p).normalized() * sens
	var t := clampf((s - cum[j - 1]) / maxf(cum[j] - cum[j - 1], 0.001), 0.0, 1.0)
	var pos := p.lerp(q, t) + Vector2(u.y, -u.x) * decal
	var basis := Basis(Vector3.UP, atan2(u.x, u.y))
	return Transform3D(basis, Vector3(pos.x, y, pos.y))
