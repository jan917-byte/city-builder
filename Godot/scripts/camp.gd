extends Node3D
## 🏕️ Les abris posés sur un champ, en un seul MultiMesh.
## Les places sont semées par `07` ; ici on n'en montre que le nombre payé.

const Constructeur := preload("res://scripts/constructeur.gd")
const MAT_ABRI := preload("res://shaders/container.gdshader")

## 🔄 RETOUR EN ARRIÈRE SIGNALÉ (auteur, 2026-09-18) : c'était DEUX caisses par
## logement, écartées de 1,55 m alors qu'elles font 2,9 m de large — elles
## s'interpénétraient, et un camp de cinq logements montrait dix boîtes
## emmêlées. UN ABRI PAR LOGEMENT PAYÉ : ce qui est à l'écran est le nombre que
## la fiche annonce ; l'occupation en personnes appartient à la simulation.
##
## Les trois cotes viennent de `07` (CAMP_BOITE_M) et se partagent la hauteur.
const PLINTHE_M := 0.18
const CADRE_M := 0.09
## Variation de VALEUR sur la teinte de l'abri, pas une deuxième couleur
## (Direction artistique l.67) : toit, plots, porte et vitres.
## 🔴 QUATRE TEINTES, ET C'EST UNE EXCEPTION ASSUMÉE à « un sous-type, une
## teinte » : un camp se monte avec ce qui arrive, et quatre cents abris d'un
## seul gris se lisent comme un entrepôt. 🔴 PROCHES LES UNES DES AUTRES, en
## revanche : à fort contraste les rangées sortaient en rayures diagonales, et
## on lisait le motif avant le camp.
const NUANCES := [Color(0.84, 0.85, 0.82), Color(0.76, 0.81, 0.81),
	Color(0.83, 0.81, 0.75), Color(0.75, 0.79, 0.80)]

var _places := {}            # fid champ -> [[x, y, z, lacet, rangée], …]
var _boite := Vector3(5.6, 2.6, 2.9)
var _mmi: MultiMeshInstance3D
var _mesh: ArrayMesh
var _signature := ""


func batir(donnees: Dictionary) -> void:
	var camps: Dictionary = donnees["camps"]
	var b: Array = camps["boite"]
	# `07` donne long × large × haut ; ici Y est la hauteur.
	_boite = Vector3(float(b[0]), float(b[2]), float(b[1]))
	for cle in (camps["places"] as Dictionary):
		_places[int(cle)] = (camps["places"] as Dictionary)[cle]
	_mesh = _mesh_abri()
	_mmi = MultiMeshInstance3D.new()
	_mmi.name = "Abris"
	add_child(_mmi)


## Combien d'abris ce champ porterait au maximum — le contrôle de l'export.
func places(fid: int) -> int:
	return (_places.get(fid, []) as Array).size()


## Refait le maillage quand, et seulement quand, un camp change de taille.
func montrer(ville, mois: float) -> void:
	var poses := []
	var signature := PackedStringArray()
	for fid in _places:
		if not ville.camp_livre(int(fid), mois):
			continue
		var n: int = mini(ville.camp_taille(int(fid), mois), places(int(fid)))
		if n <= 0:
			continue
		poses.append([int(fid), n])
		signature.append("%d:%d" % [int(fid), n])
	var sig := ",".join(signature)
	if sig == _signature:
		return
	_signature = sig
	_mmi.multimesh = _maillage(poses)


## 🔎 Le camp d'UN champ, pour la miniature de la fiche. Même recette et mêmes
## places que la ville : l'image promet exactement ce qui sera posé.
func maillage_champ(fid: int, n: int) -> MultiMesh:
	var pris: int = mini(n, places(fid))
	return _maillage([[fid, pris]]) if pris > 0 else null


func _maillage(poses: Array) -> MultiMesh:
	var total := 0
	for p in poses:
		total += int((p as Array)[1])
	if total == 0:
		return null
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = _mesh
	mm.instance_count = total
	var k := 0
	for p in poses:
		var fid: int = int((p as Array)[0])
		var liste: Array = _places[fid]
		for j in int((p as Array)[1]):
			var q: Array = liste[j]
			# 🔴 L'ABRI EST POSÉ SUR SON PIED, comme un arbre : la place semée
			# par `07` est au sol, rien à remonter.
			mm.set_instance_transform(k, Transform3D(
				Basis(Vector3.UP, float(q[3])),
				Vector3(float(q[0]), float(q[1]), float(q[2]))))
			# 🔴 UNE TEINTE PAR RANGÉE, et c'est ce qui fait la différence entre
			# un camp et du poivre et sel : les abris sont bout à bout, donc
			# une rangée est une barre, et une barre a une couleur. La rangée
			# est semée par `07`, elle ne se devine pas ici.
			var rang: int = int(q[4]) if q.size() > 4 else j
			# ⚠ Espace LINÉAIRE, comme toute teinte qui entre dans le monde.
			mm.set_instance_color(k,
				NUANCES[absi(rang + fid) % NUANCES.size()].srgb_to_linear())
			k += 1
	return mm


## Retour au module métallique à toit plat demandé par l'auteur (2026-09-18).
## Les nervures et ouvertures sont dans la matière ; la silhouette seule est maillée.
func _mesh_abri() -> ArrayMesh:
	var g := {"v": PackedVector3Array(), "n": PackedVector3Array(),
		"c": PackedColorArray(), "i": PackedInt32Array()}
	var lg := _boite.x
	var la := _boite.z
	var haut := _boite.y
	var cadre := Color(0.32, 0.39, 0.42, 0.0)
	var beton := Color(0.48, 0.48, 0.44, 0.0)
	# Alpha distingue panneau nervuré (1), toiture (0,5) et ossature (0).
	_piece(g, Vector3(lg - 0.10, haut - PLINTHE_M - 0.12, la - 0.10),
		Vector3(0, (haut + PLINTHE_M - 0.12) * 0.5, 0), Color.WHITE)
	for x in [-lg * 0.5 + CADRE_M * 0.5, lg * 0.5 - CADRE_M * 0.5]:
		for z in [-la * 0.5 + CADRE_M * 0.5, la * 0.5 - CADRE_M * 0.5]:
			_piece(g, Vector3(0.32, PLINTHE_M, 0.32),
				Vector3(x, PLINTHE_M * 0.5, z), beton)
			_piece(g, Vector3(CADRE_M, haut - PLINTHE_M, CADRE_M),
				Vector3(x, (haut + PLINTHE_M) * 0.5, z), cadre)
	for y in [PLINTHE_M + 0.07, haut - 0.065]:
		for z in [-la * 0.5 + 0.045, la * 0.5 - 0.045]:
			_piece(g, Vector3(lg, 0.13, 0.09), Vector3(0, y, z), cadre)
		for x in [-lg * 0.5 + 0.045, lg * 0.5 - 0.045]:
			_piece(g, Vector3(0.09, 0.13, la), Vector3(x, y, 0), cadre)
	_piece(g, Vector3(lg - 0.18, 0.07, la - 0.18),
		Vector3(0, haut - 0.09, 0), Color(0.72, 0.75, 0.76, 0.5))
	# Seuil et casquette donnent une échelle humaine à l'entrée.
	_piece(g, Vector3(1.10, 0.09, 0.46),
		Vector3(-lg * 0.29, 0.045, la * 0.5 + 0.15), beton)
	_piece(g, Vector3(1.22, 0.055, 0.54),
		Vector3(-lg * 0.29, 2.32, la * 0.5 + 0.17), cadre)
	var mesh := Constructeur._surface(g["v"], g["n"], g["c"], g["i"])
	var mat := ShaderMaterial.new()
	mat.shader = MAT_ABRI
	mat.set_shader_parameter("dimensions", _boite)
	mesh.surface_set_material(0, mat)
	return mesh


func _piece(g: Dictionary, taille: Vector3, centre: Vector3, teinte: Color) -> void:
	Constructeur._boite(g["v"], g["n"], g["c"], g["i"], taille, centre, teinte)
