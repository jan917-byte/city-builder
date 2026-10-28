extends SceneTree
## --headless --script res://outils/essai_regle.gd
## 🗳️ Le stationnement payant (98, auteur 2026-10-28) : un seuil de confiance, rien de dépensé,
## une recette chaque mois selon les places qui restent.
const Ville := preload("res://scripts/ville.gd")
const Politiques := preload("res://scripts/politiques.gd")
const CLE := "stationnement_payant"
var echecs := 0

func verifier(ok: bool, quoi: String) -> void:
	print("%s · %s" % ["OK" if ok else "ÉCHEC", quoi])
	if not ok:
		echecs += 1

func _initialize() -> void:
	var v := Ville.new()
	v.charger(JSON.parse_string(FileAccess.get_file_as_string("res://data/wehrau.json")))
	var seuil := float(Politiques.REGLES[CLE]["seuil"])
	verifier(not v.signer_regle(CLE, 0.0), "Refusée au départ : confiance %.0f sous le seuil %.0f" % [v.capital(0.0), seuil])

	# Une ouverture ordinaire : deux camps, puis un pont provisoire ; la mairie ouvre à sa livraison.
	var champs := []
	for fid in v.ilots:
		if v.camp_possible(fid) and v.camp_accessible(fid):
			champs.append(fid)
	v.abriter(champs[0], 0.0)
	v.abriter(champs[1], 0.0)
	var pont: int = v.ponts_coupes()[0]
	verifier(v.reparer("r", pont, 0.5, true), "Pont %d provisoire lancé" % pont)
	var t := 0.5
	while not v.reparation_finie("r", pont, t):
		t += 0.05
	print("   confiance à la réouverture du pont (mois %.1f) : %.1f" % [t, v.capital(t)])
	for m in [3.0, 6.0, 9.0, 12.0]:
		print("   … au mois %.0f, camp jamais amélioré : %.1f" % [t + m, v.capital(t + m)])

	var avant := v.capital(t)
	var caisse := v.caisse_ke(t)
	verifier(v.signer_regle(CLE, t), "Signée à la réouverture")
	verifier(is_equal_approx(v.capital(t), avant), "La confiance n'a pas bougé")
	verifier(is_equal_approx(v.caisse_ke(t), caisse), "Rien encaissé à la signature")
	verifier(not v.signer_regle(CLE, t + 1.0), "On ne la signe pas deux fois")

	var places := v.places_stationnement(t)
	var attendu := places * Politiques.STATIONNEMENT_KE_PLACE_MOIS * 12.0
	var recu := v.stationnement_cumule_ke(t + 12.0)
	verifier(absf(recu - attendu) < 0.5, "Un an : %.0f k€ pour %.0f places (%.1f k€/mois)" % [recu, places, v.stationnement_mensuel_ke(t)])

	# Retirer des places retire de la recette, et seulement à partir de là.
	var rue := -1
	for fid in v.routes:
		if v.base("r", fid, "stationnement") >= 50.0:
			rue = fid
			break
	var sans := v.stationnement_cumule_ke(t + 1.0)
	v.supprimer_stationnement(rue, t + 1.0)
	verifier(is_equal_approx(v.stationnement_cumule_ke(t + 1.0), sans), "Le passé ne change pas")
	verifier(v.stationnement_cumule_ke(t + 12.0) < recu - 0.5,
		"Rue %d sans places : %.1f k€/mois au lieu de %.1f" % [rue, v.stationnement_mensuel_ke(t + 12.0), v.stationnement_mensuel_ke(t)])

	# La partie sauvée la garde.
	var etat := v.exporter_partie()
	verifier(etat.has("_regles") and v.valider_partie(etat.duplicate(true)), "La sauvegarde la garde")

	print("%d échec%s" % [echecs, "s" if echecs > 1 else ""])
	quit(1 if echecs > 0 else 0)
