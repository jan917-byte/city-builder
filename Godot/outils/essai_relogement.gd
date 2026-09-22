extends SceneTree
## --headless --script res://outils/essai_relogement.gd
const Ville := preload("res://scripts/ville.gd")
var echecs := 0

func verifier(ok: bool, quoi: String) -> void:
	print("%s · %s" % ["OK" if ok else "ÉCHEC", quoi])
	if not ok:
		echecs += 1

func _initialize() -> void:
	var donnees: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/wehrau.json"))
	var v := Ville.new()
	v.charger(donnees)
	var champs: Array[int] = []
	for fid in v.ilots:
		if v.camp_possible(fid) and v.camp_accessible(fid):
			champs.append(fid)
	verifier(champs.size() == 3, "Trois champs accessibles")
	for premier in champs:
		for second in champs:
			if premier == second:
				continue
			v.reinitialiser()
			var besoin := v.sans_toit(0.0)
			verifier(v.camp_capacite(premier) < besoin, "Le champ %d ne suffit pas seul" % premier)
			verifier(v.abriter(premier, 0.0), "Premier camp engagé")
			verifier(v.sans_toit(0.0) == besoin, "Aucun occupant avant livraison")
			verifier(v.abriter(second, 0.25), "Deuxième camp engagé")
			verifier(v.sans_toit(0.5) == 0.0 and v.reloges(0.5) == besoin,
				"Les champs %d et %d relogent tout le monde" % [premier, second])
			verifier(v.camp_taille(premier, 0.5) + v.camp_taille(second, 0.5) == 130,
				"130 logements pour 260 personnes, dernier camp ajusté")
			# 🆘 L'aide d'urgence court jusqu'à chaque livraison : tous dehors
			# jusqu'au premier camp, le reste jusqu'au second.
			var aide := Ville.AIDE_KE_PERSONNE_MOIS * (besoin * Ville.CAMP_MOIS
				+ (besoin - v.camp_capacite(premier)) * 0.25)
			verifier(is_equal_approx(v.aide_cumulee_ke(0.5), aide),
				"Aide d'urgence : %.1f k€ jusqu'au second camp" % aide)
			verifier(is_equal_approx(v.caisse_ke(0.5), Ville.CAISSE_DEPART_KE + 0.5 * Ville.DOTATION_KE_MOIS - 195.0 - aide),
				"195 k€ payés pour les logements, pas pour les occupants")
			var sauvegarde := v.exporter_partie()
			verifier(v.valider_partie(sauvegarde), "Sauvegarde valide")
			v.importer_partie(sauvegarde)
			verifier(v.sans_toit(0.5) == 0.0, "Reprise : tous les occupants conservés")
	# Toute la remise en circulation doit tenir sans dotation ni crédit d'essai.
	for pont in v.ponts_coupes():
		v.reinitialiser()
		verifier(v.abriter(champs[0], 0.0) and v.abriter(champs[1], 0.25),
			"Pont %d : relogement complet engagé" % pont)
		verifier(v.reparer("r", pont, 0.0), "Pont %d : réparation financée au départ" % pont)
		for rue in v.routes:
			if rue not in v.ponts_coupes() and v.cout_reparation_ke("r", rue) > 0.0:
				verifier(v.reparer("r", rue, 0.0), "Pont %d : déblaiement de la rue %d financé au départ" % [pont, rue])
		verifier(v.caisse_ke(0.0) >= 0.0 and v.sans_toit(0.5) == 0.0,
			"Pont %d : tout le relogement et toutes les routes financés, reste %.1f k€" % [pont, v.caisse_ke(0.0)])
	# Un besoin impair ne doit ni disparaître par arrondi, ni créer un habitant.
	v.reinitialiser()
	for fid in v.ilots:
		v.ilots[fid] = v.ilots[fid].duplicate()
		v.ilots[fid]["logements_sinistres"] = 0.0
	v.ilots[champs[0]]["logements_sinistres"] = 1.0
	verifier(v.camp_taille(champs[0], 0.0) == 1, "Une dernière personne commande un logement")
	v.abriter(champs[0], 0.0)
	verifier(v.camp_occupants(champs[0], 0.25) == 1.0 and v.sans_toit(0.25) == 0.0,
		"Une place vacante, aucun occupant fictif")
	print("RELOGEMENT : %d échec(s)" % echecs)
	quit(1 if echecs else 0)
