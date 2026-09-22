extends Node3D
## Décor temporaire issu du même chantier que la fiche. Cache par lieu, animation GPU.
const Constructeur := preload("res://scripts/constructeur.gd")
const CHANTIER := preload("res://shaders/chantier.gdshader")
const ORANGE := Color(0.92, 0.38, 0.055, 0.0)
const SOMBRE := Color(0.13, 0.18, 0.20, 0.0)

var sites := {}
var actifs := 0
var temps := 0.0
var _donnees: Dictionary
var _noeuds: Dictionary
var _reparations: Dictionary
var _palissade := ShaderMaterial.new()
var _grue := ShaderMaterial.new()
var _reperes: Reperes
var _taille := 1200.0


class Reperes extends Node2D:
	var travaux: Node3D
	var camera: Camera3D

	func _draw() -> void:
		if camera == null:
			return
		for site in travaux.sites.values():
			if not site.visible:
				continue
			var ancre: Vector3 = site.get_meta("repere")
			if camera.is_position_behind(ancre):
				continue
			var p := camera.unproject_position(ancre)
			var souffle := 0.6 + 0.4 * sin(travaux.temps * 2.0)
			draw_circle(p + Vector2(0, 2), 14.0, Color(0.08, 0.14, 0.14, 0.28))
			draw_circle(p, 12.5 + souffle, Color("fff1cc"))
			draw_circle(p, 11.0, Color("e99430"))
			var encre := Color("293d3c")
			draw_line(p + Vector2(-3, 7), p + Vector2(-3, -7), encre, 2.0, true)
			draw_line(p + Vector2(-7, -5), p + Vector2(7, -5), encre, 2.0, true)
			draw_line(p + Vector2(-3, -9), p + Vector2(7, -5), encre, 1.5, true)
			draw_line(p + Vector2(5, -5), p + Vector2(5, 3), encre, 1.5, true)
			draw_line(p + Vector2(5, 3), p + Vector2(2, 3), encre, 1.5, true)
			draw_line(p + Vector2(-6, 7), p + Vector2(0, 7), encre, 2.0, true)


func batir(donnees: Dictionary, noeuds: Dictionary, reparations: Dictionary) -> void:
	_donnees = donnees
	_noeuds = noeuds
	_reparations = reparations
	_palissade.shader = CHANTIER
	_grue.shader = CHANTIER
	_grue.set_shader_parameter("grue", true)
	_reperes = Reperes.new()
	_reperes.travaux = self
	_reperes.visible = false
	add_child(_reperes)
	set_process(false)


func actualiser(ville, mois: float) -> void:
	actifs = 0
	for couche in _noeuds:
		for fid in _noeuds[couche]:
			var cle := "%s%d" % [couche, fid]
			# chantiers() omet le retrait des places ; chantier() couvre aussi les commandes groupées.
			var actif: bool = ville.chantier(couche, fid, mois)["actif"]
			if actif and not sites.has(cle):
				sites[cle] = _batir_site(couche, fid)
			if sites.has(cle):
				(sites[cle] as Node3D).visible = actif
			actifs += int(actif)
	set_process(actifs > 0 and visible)
	_reperes.visible = false
	_reperes.queue_redraw()


func regler_detail(taille: float, camera: Camera3D) -> void:
	_taille = taille
	_reperes.camera = camera
	_reperes.visible = false
	_reperes.queue_redraw()


func _process(delta: float) -> void:
	# Comme le trafic : un mouvement d'ambiance, indépendant de l'accélération des mois.
	temps += delta
	_palissade.set_shader_parameter("temps", temps)
	_grue.set_shader_parameter("temps", temps)
	if _reperes.visible:
		_reperes.queue_redraw()


func _batir_site(couche: String, fid: int) -> Node3D:
	var site := Node3D.new()
	site.name = "%s%d" % [couche, fid]
	var mi: MeshInstance3D = _noeuds[couche][fid]
	var boite := mi.mesh.get_aabb()
	site.set_meta("repere", boite.get_center() + Vector3.UP * (boite.size.y * 0.5 + 12.0))
	add_child(site)
	var lignes := _lignes(couche, fid)
	var pieces := []
	for ligne in lignes:
		_baliser(ligne, pieces)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = BoxMesh.new()
	mm.instance_count = pieces.size()
	for k in pieces.size():
		mm.set_instance_transform(k, pieces[k][0])
		mm.set_instance_custom_data(k, pieces[k][1])
	var barrieres := MultiMeshInstance3D.new()
	barrieres.name = "Palissades"
	barrieres.multimesh = mm
	barrieres.material_override = _palissade
	barrieres.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	site.add_child(barrieres)
	if couche == "i" and not lignes.is_empty():
		_poser_grue(site, fid, lignes[0])
	return site


func _lignes(couche: String, fid: int) -> Array:
	var lignes := []
	var cle := str(fid)
	if couche == "i":
		var ligne := PackedVector3Array()
		for p in _donnees["emprises"].get(cle, []):
			ligne.append(Vector3(p[0], p[1], p[2]))
		if ligne.size() > 2:
			ligne.append(ligne[0])
			lignes.append(ligne)
	elif couche == "b":
		# Les rails exportés suivent le quai, y compris ses rétrécissements.
		var mi: MeshInstance3D = _noeuds[couche][fid]
		var y := mi.mesh.get_aabb().end.y
		for bord in [0, 2]:
			var ligne := PackedVector3Array()
			for p in _donnees["berges_couloir"].get(cle, []):
				ligne.append(Vector3(p[bord], y, p[bord + 1]))
			lignes.append(ligne)
	elif _donnees["couloirs"].has(cle):
		var couloir: Array = _donnees["couloirs"][cle]
		for axe in couloir[1]:
			# Un pont emporté n'a pas de tablier où poser les pieds : fermer ses accès.
			if str(_donnees["objets"]["routes"][cle].get("etat_crue", "")) == "coupe":
				for k in [0, axe.size() - 2]:
					var voisin: int = 2 if k == 0 else k - 2
					var p := Vector3(axe[k], 0.16, axe[k + 1])
					var dir := Vector3(axe[voisin] - axe[k], 0.0, axe[voisin + 1] - axe[k + 1]).normalized()
					var bord := dir.cross(Vector3.UP) * float(couloir[0]) * 0.45
					lignes.append(PackedVector3Array([p - bord, p + bord]))
				continue
			for cote in [-1.0, 1.0]:
				var ligne := PackedVector3Array()
				for k in range(0, axe.size(), 2):
					var p := Vector3(axe[k], 0.16, axe[k + 1])
					var avant := maxi(k - 2, 0)
					var apres := mini(k + 2, axe.size() - 2)
					var direction := Vector3(axe[apres] - axe[avant], 0.0,
						axe[apres + 1] - axe[avant + 1]).normalized()
					ligne.append(p + direction.cross(Vector3.UP) * cote
						* maxf(float(couloir[0]) * 0.5 - 0.65, 0.0))
				lignes.append(ligne)
	return lignes


func _baliser(ligne: PackedVector3Array, pieces: Array) -> void:
	# Échantillonnage en mètres, pas en sommets : une courbe dense ne sature pas de balises.
	var prochain := 3.0
	var parcouru := 0.0
	for k in ligne.size() - 1:
		var a := ligne[k]
		var b := ligne[k + 1]
		var longueur := a.distance_to(b)
		if longueur < 0.01:
			continue
		var direction := (b - a).normalized()
		var base := Basis(direction, Vector3.UP, direction.cross(Vector3.UP)).orthonormalized()
		while prochain < parcouru + longueur:
			var p := a.lerp(b, (prochain - parcouru) / longueur)
			pieces.append([Transform3D(base.scaled_local(Vector3(4.6, 1.35, 0.16)),
				p + Vector3.UP * 1.15), Color(0.0, 0.0, 0.0)])
			for cote in [-1.85, 1.85]:
				pieces.append([Transform3D(base.scaled_local(Vector3(0.16, 1.8, 0.4)),
					p + direction * cote + Vector3.UP * 0.9), Color(1.0, 0.0, 0.0)])
			pieces.append([Transform3D(base.scaled_local(Vector3(0.40, 0.40, 0.40)),
				p + Vector3.UP * 2.05), Color(2.0, prochain * 0.10, 0.0)])
			prochain += 10.0
		parcouru += longueur


func _poser_grue(site: Node3D, fid: int, anneau: PackedVector3Array) -> void:
	var mi: MeshInstance3D = _noeuds["i"][fid]
	var boite := mi.mesh.get_aabb()
	if _reparations["i"].has(fid):
		boite = boite.merge((_reparations["i"][fid] as MeshInstance3D).mesh.get_aabb())
	# Milieu du plus long bord : le mât reste au bord de l'îlot, hors des toitures.
	var ancre := anneau[0]
	var longueur := 0.0
	for k in anneau.size() - 1:
		var l := anneau[k].distance_to(anneau[k + 1])
		if l > longueur:
			longueur = l
			ancre = (anneau[k] + anneau[k + 1]) * 0.5
	var centre := boite.get_center()
	var vers_centre := Vector3(centre.x - ancre.x, 0.0, centre.z - ancre.z).normalized()
	ancre -= vers_centre * 1.6
	# Garde au-dessus du volume livré, même avec deux étages ajoutés.
	var haut := maxf(boite.end.y - ancre.y + 2.0 * float(_donnees["meta"]["etage_m"]) + 9.0, 21.0)
	var portee := clampf(maxf(boite.size.x, boite.size.z) * 0.32, 16.0, 30.0)
	var grue := MeshInstance3D.new()
	grue.name = "Grue"
	grue.mesh = _maillage_grue(haut, portee)
	grue.material_override = _grue
	grue.position = ancre
	grue.rotation.y = atan2(-vers_centre.z, vers_centre.x)
	grue.set_instance_shader_parameter("phase", float(fid) * 1.73)
	# Le bras sort de son AABB au pivotement ; le cache ne doit pas le faire disparaître.
	grue.custom_aabb = AABB(Vector3(-portee, 0.0, -portee), Vector3(portee * 2.0, haut + 4.0, portee * 2.0))
	site.add_child(grue)


func _maillage_grue(haut: float, portee: float) -> ArrayMesh:
	var g := {"v": PackedVector3Array(), "n": PackedVector3Array(),
		"c": PackedColorArray(), "i": PackedInt32Array()}
	_cube(g, Vector3(4.0, 0.7, 4.0), Vector3(0.0, 0.35, 0.0), SOMBRE)
	for x in [-0.65, 0.65]:
		for z in [-0.65, 0.65]:
			_poutre(g, Vector3(x, 0.6, z), Vector3(x, haut, z), 0.20, ORANGE)
	for k in int(ceil(haut / 3.0)):
		var bas := 0.7 + float(k) * 3.0
		var fin := minf(bas + 3.0, haut)
		if fin <= bas:
			continue
		for cote in [-0.65, 0.65]:
			_poutre(g, Vector3(-0.65, bas, cote), Vector3(0.65, fin, cote), 0.13, ORANGE)
			_poutre(g, Vector3(cote, bas, -0.65), Vector3(cote, fin, 0.65), 0.13, ORANGE)
	var mobile := Color(ORANGE, 1.0)
	for z in [-0.55, 0.55]:
		_poutre(g, Vector3(-6.0, haut, z), Vector3(portee, haut, z), 0.23, mobile)
		_poutre(g, Vector3(-6.0, haut + 1.25, z), Vector3(portee, haut + 1.25, z), 0.18, mobile)
		for k in int(ceil((portee + 6.0) / 2.5)):
			var x := -6.0 + k * 2.5
			_poutre(g, Vector3(x, haut, z), Vector3(minf(x + 2.5, portee), haut + 1.25, z), 0.12, mobile)
	_cube(g, Vector3(3.0, 1.8, 2.0), Vector3(-5.0, haut + 0.5, 0.0), Color(SOMBRE, 1.0))
	_cube(g, Vector3(1.8, 1.6, 1.6), Vector3(1.5, haut - 0.4, 0.0), Color(0.24, 0.38, 0.42, 1.0))
	_poutre(g, Vector3(portee * 0.72, haut, 0.0), Vector3(portee * 0.72, haut - 5.5, 0.0), 0.10, Color(SOMBRE, 1.0))
	_cube(g, Vector3(1.1, 0.8, 0.8), Vector3(portee * 0.72, haut - 5.5, 0.0), mobile)
	return Constructeur._surface(g["v"], g["n"], g["c"], g["i"])


func _cube(g: Dictionary, taille: Vector3, centre: Vector3, couleur: Color) -> void:
	Constructeur._boite(g["v"], g["n"], g["c"], g["i"], taille, centre, couleur)


func _poutre(g: Dictionary, a: Vector3, b: Vector3, largeur: float, couleur: Color) -> void:
	var debut: int = g["v"].size()
	_cube(g, Vector3(largeur, a.distance_to(b), largeur), Vector3.ZERO, couleur)
	var rotation := Basis(Quaternion(Vector3.UP, (b - a).normalized()))
	for k in range(debut, g["v"].size()):
		g["v"][k] = rotation * g["v"][k] + (a + b) * 0.5
		g["n"][k] = rotation * g["n"][k]
