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

## 🌾 `genre` FORCE le mot du nom de secours : un champ s'appelle « Champ 1082 »
## et jamais « Îlot 1082 » (auteur, 2026-09-18). Il ne touche pas aux noms écrits.
func nom(couche: String, fid: int, genre := "") -> String:
	var mot: String = genre if genre != "" else str(GENRES.get(couche, "Lieu"))
	return str(noms.get(couche, {}).get(str(fid), "%s %d" % [mot, fid]))

func repere(couche: String, fid: int, genre := "") -> String:
	var mot: String = genre if genre != "" else str(GENRES.get(couche, "Lieu"))
	return "%s · %s %d" % [nom(couche, fid, genre), mot, fid]
