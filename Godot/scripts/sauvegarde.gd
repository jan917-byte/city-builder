extends RefCounted
## Données seules, sans objets exécutables. L'ancienne partie survit à une écriture interrompue.

const CHEMIN := "user://partie.wehrau"
const VERSION := 1
const TAILLE_MAX := 16 * 1024 * 1024

static func ecrire(partie: Dictionary, carte: String, chemin := CHEMIN) -> String:
	var contenu := var_to_bytes(partie)
	var paquet := {"version": VERSION, "carte": carte,
		"empreinte": _empreinte(contenu), "contenu": contenu}
	var temporaire := chemin + ".tmp"
	var f := FileAccess.open(temporaire, FileAccess.WRITE)
	if f == null:
		return "Impossible d'écrire la sauvegarde."
	f.store_var(paquet, false)
	f.flush()
	var erreur := f.get_error()
	f.close()
	if erreur != OK:
		return "Écriture interrompue ; la sauvegarde précédente est conservée."
	if FileAccess.file_exists(chemin):
		if FileAccess.file_exists(chemin + ".bak"):
			if DirAccess.remove_absolute(chemin + ".bak") != OK:
				return "Impossible de remplacer la copie de secours."
		if DirAccess.rename_absolute(chemin, chemin + ".bak") != OK:
			return "Impossible de remplacer la sauvegarde précédente."
	if DirAccess.rename_absolute(temporaire, chemin) != OK:
		if FileAccess.file_exists(chemin + ".bak"):
			DirAccess.rename_absolute(chemin + ".bak", chemin)
		return "Sauvegarde non remplacée ; l'ancienne partie est conservée."
	return ""

static func lire(carte: String, chemin := CHEMIN) -> Dictionary:
	var resultat := _lire(carte, chemin)
	if resultat.has("erreur") and FileAccess.file_exists(chemin + ".bak"):
		var secours := _lire(carte, chemin + ".bak")
		if not secours.has("erreur"):
			secours["secours"] = true
			return secours
	return resultat

static func _lire(carte: String, chemin: String) -> Dictionary:
	var f := FileAccess.open(chemin, FileAccess.READ)
	if f == null:
		return {"erreur": "Aucune sauvegarde disponible."}
	if f.get_length() < 4 or f.get_length() > TAILLE_MAX:
		return {"erreur": "Sauvegarde endommagée ; la partie en cours est conservée."}
	var brut: Variant = f.get_var(false)
	f.close()
	if not brut is Dictionary:
		return {"erreur": "Sauvegarde illisible."}
	if brut.get("version") != VERSION:
		return {"erreur": "Cette version de sauvegarde n'est pas compatible."}
	if brut.get("carte") != carte:
		return {"erreur": "La carte a changé depuis cette sauvegarde."}
	var contenu: Variant = brut.get("contenu")
	if not contenu is PackedByteArray or _empreinte(contenu) != brut.get("empreinte"):
		return {"erreur": "Sauvegarde endommagée ; la partie en cours est conservée."}
	var partie: Variant = bytes_to_var(contenu)
	if not partie is Dictionary:
		return {"erreur": "Sauvegarde incomplète."}
	return {"partie": partie, "secours": false}

static func _empreinte(contenu: PackedByteArray) -> String:
	var h := HashingContext.new()
	h.start(HashingContext.HASH_SHA256)
	h.update(contenu)
	return h.finish().hex_encode()
