extends RefCounted
# 🎓 LES FIGURINES DU CAMPUS (auteur, 2026-10-11 : « une seule maison où on voit bien
# les pilotis, juste un panneau solaire, sans spoiler »). Un objet seul, hors de la
# ville, en primitives. 🔴 Flaggable (90) : formes et teintes choisies par moi.
# Le sol est à y = 0, l'objet centré sur l'origine ; `apercu.figurine` le cadre.

const Ville := preload("res://scripts/ville.gd")

const MAISON := Vector3(7.0, 5.4, 5.6)   # deux niveaux, la maison des pilotis

const ENDUIT := Color("#E9E1D2")
const TUILE := Color("#B4583E")
const VITRE := Color("#4A5560")
const POTEAU := Color("#6E6A64")
const HERBE := Color("#9CBD84")             # `parc` de la palette
const TERRE := Color("#8A7A66")             # `_tronc`
const EAU_CLAIRE := Color("#7EA7C3")        # `riviere`
const EAU_CRUE := Color("#998758")          # `_eau_crue_bord`
const CELLULE := Color("#2E4A6B")
const CADRE := Color("#C9CCD0")
const SEDUM := Color("#8FA868")
const SEDUM_FLEUR := Color("#C9A24A")
const FEUILLAGE := Color("#83A879")         # `_feuillage`
const ROSEAU := Color("#A9A96B")


static func fabriquer(genre: String) -> Node3D:
	var n := Node3D.new()
	match genre:
		"pilotis":
			_sol(n, Vector3(10.5, 1.0, 9.0), HERBE)
			_nappe(n, Vector2(10.5, 9.0), 0.5, EAU_CLAIRE)
			_maison(n, float(Ville.RECONSTRUCTIONS["pilotis"]["hausse_m"]))
		"ruine":
			_sol(n, Vector3(10.5, 1.0, 9.0), HERBE)
			_maison(n, 0.0)
			_nappe(n, Vector2(10.5, 9.0), 1.3, EAU_CRUE)
		"solaire":
			_sol(n, Vector3(2.4, 0.2, 1.9), HERBE)
			_panneau(n)
		"vert":
			_toit_vert(n)
		"eponge":
			_berge(n)
	return n


static func _bloc(n: Node3D, taille: Vector3, centre: Vector3, teinte: Color,
		rotation_deg := Vector3.ZERO) -> MeshInstance3D:
	var m := BoxMesh.new()
	m.size = taille
	return _poser(n, m, centre, teinte, rotation_deg)


static func _poser(n: Node3D, m: Mesh, centre: Vector3, teinte: Color,
		rotation_deg := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.position = centre
	mi.rotation_degrees = rotation_deg
	var mat := StandardMaterial3D.new()
	mat.albedo_color = teinte
	mat.roughness = 0.95
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	mi.material_override = mat
	n.add_child(mi)
	return mi


static func _sol(n: Node3D, taille: Vector3, teinte: Color) -> void:
	_bloc(n, taille, Vector3(0.0, -taille.y * 0.5, 0.0), teinte)


## L'eau qui monte autour : une plaque fine, à `haut` mètres du sol.
static func _nappe(n: Node3D, taille: Vector2, haut: float, teinte: Color) -> void:
	_bloc(n, Vector3(taille.x - 0.02, haut, taille.y - 0.02), Vector3(0.0, haut * 0.5 - 0.01, 0.0),
		teinte)


static func _maison(n: Node3D, levee: float) -> void:
	var t := MAISON
	var y0 := levee
	if levee > 0.0:
		# Six poteaux et la dalle qu'ils portent : c'est ce que la vignette doit montrer.
		for i in 3:
			for j in 2:
				var p := CylinderMesh.new()
				p.top_radius = 0.2
				p.bottom_radius = 0.2
				p.height = levee
				_poser(n, p, Vector3((i - 1) * (t.x * 0.5 - 0.4), levee * 0.5,
					(j - 0.5) * (t.z - 0.8)), POTEAU)
		_bloc(n, Vector3(t.x + 0.2, 0.3, t.z + 0.2), Vector3(0.0, levee - 0.15, 0.0), POTEAU)
		# L'escalier qui descend au sol, sur le pignon.
		for k in 5:
			var h := levee * (k + 1) / 6.0
			_bloc(n, Vector3(0.5, 0.12, 1.1), Vector3(t.x * 0.5 + 0.35 + (4 - k) * 0.5, h, t.z * 0.25),
				POTEAU)
	_bloc(n, Vector3(t.x, t.y, t.z), Vector3(0.0, y0 + t.y * 0.5, 0.0), ENDUIT)
	# Le toit à deux pans, faîte le long de X.
	var toit := PrismMesh.new()
	toit.size = Vector3(t.z + 0.8, 2.4, t.x + 0.6)
	_poser(n, toit, Vector3(0.0, y0 + t.y + 1.2, 0.0), TUILE, Vector3(0.0, 90.0, 0.0))
	# Deux rangées de fenêtres sur la façade et le pignon visibles.
	for etage in 2:
		var y := y0 + 1.5 + etage * 2.6
		for i in 3:
			_bloc(n, Vector3(1.0, 1.3, 0.08), Vector3((i - 1) * 2.2, y, t.z * 0.5 + 0.03), VITRE)
		for i in 2:
			_bloc(n, Vector3(0.08, 1.3, 1.0), Vector3(t.x * 0.5 + 0.03, y, (i - 0.5) * 2.4), VITRE)


static func _panneau(n: Node3D) -> void:
	# Un module de 1,7 × 1,0 m incliné à 30°, sur deux pieds.
	# Tourné vers la caméra de `apercu.figurine` (du côté +X +Z) : de dos, on ne
	# voyait que le cadre.
	var face := Node3D.new()
	face.rotation_degrees = Vector3(0.0, 45.0, 0.0)
	n.add_child(face)
	n = face
	var pivot := Node3D.new()
	pivot.position = Vector3(0.0, 0.75, 0.0)
	pivot.rotation_degrees = Vector3(30.0, 0.0, 0.0)
	n.add_child(pivot)
	_bloc(pivot, Vector3(1.76, 0.05, 1.06), Vector3.ZERO, CADRE)
	for i in 6:
		for j in 3:
			_bloc(pivot, Vector3(0.27, 0.02, 0.31),
				Vector3(-0.725 + i * 0.29, 0.03, -0.33 + j * 0.33), CELLULE)
	# Incliné de 30°, le bord −Z monte : le pied de derrière est le plus haut.
	for x in [-0.7, 0.7]:
		_bloc(n, Vector3(0.05, 0.55, 0.05), Vector3(x, 0.275, 0.4), POTEAU)
		_bloc(n, Vector3(0.05, 0.95, 0.05), Vector3(x, 0.475, -0.4), POTEAU)


static func _toit_vert(n: Node3D) -> void:
	# Le haut d'un immeuble à toit plat : l'acrotère, et le sédum dedans.
	var t := Vector3(8.0, 3.0, 6.0)
	_bloc(n, t, Vector3(0.0, t.y * 0.5, 0.0), ENDUIT)
	for i in 4:
		_bloc(n, Vector3(1.2, 1.4, 0.08), Vector3(-2.7 + i * 1.8, 1.5, t.z * 0.5 + 0.03), VITRE)
	_bloc(n, Vector3(t.x, 0.4, 0.25), Vector3(0.0, t.y + 0.2, t.z * 0.5 - 0.125), ENDUIT)
	_bloc(n, Vector3(t.x, 0.4, 0.25), Vector3(0.0, t.y + 0.2, -t.z * 0.5 + 0.125), ENDUIT)
	_bloc(n, Vector3(0.25, 0.4, t.z), Vector3(t.x * 0.5 - 0.125, t.y + 0.2, 0.0), ENDUIT)
	_bloc(n, Vector3(0.25, 0.4, t.z), Vector3(-t.x * 0.5 + 0.125, t.y + 0.2, 0.0), ENDUIT)
	_bloc(n, Vector3(t.x - 0.5, 0.15, t.z - 0.5), Vector3(0.0, t.y + 0.075, 0.0), SEDUM)
	# Des touffes, tirées une fois pour toutes : la même vignette à chaque partie.
	var hasard := RandomNumberGenerator.new()
	hasard.seed = 7
	for k in 40:
		var s := SphereMesh.new()
		s.radius = hasard.randf_range(0.18, 0.32)
		s.height = s.radius * 1.2
		_poser(n, s, Vector3(hasard.randf_range(-3.6, 3.6), t.y + 0.17,
			hasard.randf_range(-2.6, 2.6)), SEDUM_FLEUR if k % 5 == 0 else SEDUM.darkened(0.1))


static func _berge(n: Node3D) -> void:
	# Une rive en pente douce qui entre dans l'eau, ses roseaux, un saule.
	var pente := PrismMesh.new()
	pente.left_to_right = 0.0
	pente.size = Vector3(6.0, 1.6, 8.0)
	_poser(n, pente, Vector3(0.0, 0.8 - 1.6, 0.0), HERBE)
	_bloc(n, Vector3(5.0, 1.6, 8.0), Vector3(-5.5, -0.8, 0.0), HERBE)
	_bloc(n, Vector3(5.0, 0.4, 8.0), Vector3(5.5, -1.8, 0.0), TERRE)
	# L'eau en volume, du lit à la surface : la pente s'y enfonce.
	_bloc(n, Vector3(9.0, 0.85, 8.0), Vector3(3.5, -1.175, 0.0), EAU_CLAIRE)
	var hasard := RandomNumberGenerator.new()
	hasard.seed = 3
	for k in 24:
		var r := CylinderMesh.new()
		r.top_radius = 0.02
		r.bottom_radius = 0.04
		r.height = hasard.randf_range(0.9, 1.5)
		var x := hasard.randf_range(-1.2, 1.2)
		# Le pied sur la pente : elle descend de 0 à −1,6 m entre x = −3 et 3.
		_poser(n, r, Vector3(x, -1.6 * (x + 3.0) / 6.0 + r.height * 0.5,
			hasard.randf_range(-3.6, 3.6)), ROSEAU)
	var tronc := CylinderMesh.new()
	tronc.top_radius = 0.18
	tronc.bottom_radius = 0.25
	tronc.height = 3.0
	_poser(n, tronc, Vector3(-4.5, 1.5, -1.0), TERRE)
	var houppier := SphereMesh.new()
	houppier.radius = 2.0
	houppier.height = 3.2
	_poser(n, houppier, Vector3(-4.5, 4.0, -1.0), FEUILLAGE)
