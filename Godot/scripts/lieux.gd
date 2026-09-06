extends RefCounted
## Noms éditoriaux séparés de la géométrie : une relance de 07 ne les écrase pas.

const CHEMIN := "res://data/lieux.json"
const GENRES := {"i": "Îlot", "r": "Rue", "b": "Berge"}
var noms := {}

func _init() -> void:
	var brut: Variant = JSON.parse_string(FileAccess.get_file_as_string(CHEMIN))
	if brut is Dictionary:
		noms = brut
	else:
		push_error("Noms des lieux illisibles : " + CHEMIN)

func nom(couche: String, fid: int) -> String:
	return str(noms.get(couche, {}).get(str(fid), "%s %d" % [GENRES.get(couche, "Lieu"), fid]))

func repere(couche: String, fid: int) -> String:
	return "%s · %s %d" % [nom(couche, fid), GENRES.get(couche, "Lieu"), fid]
