extends Node3D
## 🏕️ Le camp de containers posé sur un champ, en un seul MultiMesh.
## Les places sont semées par `07` ; ici on n'en montre que le nombre payé.

const Constructeur := preload("res://scripts/constructeur.gd")
const Materiaux := preload("res://scripts/materiaux.gd")

## Deux containers par logement, côte à côte : l'écart fait l'entrée.
const ECART_M := 1.55
## 🔴 QUATRE TEINTES, ET C'EST UNE EXCEPTION ASSUMÉE à « un sous-type, une
## teinte » : un camp d'urgence est fait de containers de récupération, et
## quatre cents boîtes d'un seul gris se lisent comme un entrepôt. Les couleurs
## sont celles du fret, pas celles de la ville.
const NUANCES := [Color(0.82, 0.83, 0.80), Color(0.55, 0.62, 0.66),
	Color(0.72, 0.45, 0.32), Color(0.78, 0.72, 0.58)]

var _places := {}            # fid champ -> [[x, y, z, lacet], …]
var _boite := Vector3(5.6, 2.6, 2.9)
var _mmi: MultiMeshInstance3D
var _signature := ""


func batir(donnees: Dictionary) -> void:
	var camps: Dictionary = donnees["camps"]
	var b: Array = camps["boite"]
	# `07` donne long × large × haut ; ici Y est la hauteur.
	_boite = Vector3(float(b[0]), float(b[2]), float(b[1]))
	for cle in (camps["places"] as Dictionary):
		_places[int(cle)] = (camps["places"] as Dictionary)[cle]
	_mmi = MultiMeshInstance3D.new()
	_mmi.name = "Containers"
	_mmi.material_override = Materiaux.surface(0.75)
	add_child(_mmi)


## Combien de containers ce champ porterait au maximum — le contrôle de l'export.
func places(fid: int) -> int:
	return (_places.get(fid, []) as Array).size()


## Refait le maillage quand, et seulement quand, un camp change de taille.
func montrer(ville, mois: float) -> void:
	var poses := PackedStringArray()
	var total := 0
	for fid in _places:
		if not ville.camp_livre(int(fid), mois):
			continue
		var n: int = mini(ville.camp_taille(int(fid), mois), places(int(fid)))
		if n <= 0:
			continue
		poses.append("%d:%d" % [int(fid), n])
		total += n
	var signature := ",".join(poses)
	if signature == _signature:
		return
	_signature = signature
	if total == 0:
		_mmi.multimesh = null
		return

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = _mesh_container()
	mm.instance_count = total * 2
	var k := 0
	for cle in poses:
		var morceaux: PackedStringArray = cle.split(":")
		var fid := int(morceaux[0])
		var liste: Array = _places[fid]
		for j in int(morceaux[1]):
			var p: Array = liste[j]
			var base := Vector3(float(p[0]), float(p[1]), float(p[2]))
			var tour := Basis(Vector3.UP, -float(p[3]))
			for cote in [-ECART_M * 0.5, ECART_M * 0.5]:
				var t := Transform3D(tour, base
					+ tour * Vector3(0.0, _boite.y * 0.5, cote))
				mm.set_instance_transform(k, t)
				# ⚠ Espace LINÉAIRE, comme toute teinte qui entre dans le monde.
				mm.set_instance_color(k,
					NUANCES[(fid + j * 3 + k) % NUANCES.size()].srgb_to_linear())
				k += 1
	_mmi.multimesh = mm


## Un container : la boîte, plus un bandeau de toit un ton au-dessous pour que
## deux rangées ne se confondent pas vues de haut.
func _mesh_container() -> ArrayMesh:
	var g := {"v": PackedVector3Array(), "n": PackedVector3Array(),
		"c": PackedColorArray(), "i": PackedInt32Array()}
	Constructeur._boite(g["v"], g["n"], g["c"], g["i"], _boite,
		Vector3.ZERO, Color.WHITE)
	Constructeur._boite(g["v"], g["n"], g["c"], g["i"],
		Vector3(_boite.x * 0.98, 0.10, _boite.z * 0.98),
		Vector3(0.0, _boite.y * 0.5, 0.0), Color(0.62, 0.64, 0.63))
	return Constructeur._surface(g["v"], g["n"], g["c"], g["i"])
