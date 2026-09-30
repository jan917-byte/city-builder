extends SceneTree
## --headless --script res://outils/essai_capital.gd
## Le capital politique (décision 95, réglages du 2026-09-30) : ce qui en coûte,
## ce qui en rend, quand, et le refus à zéro.
const Ville := preload("res://scripts/ville.gd")
var echecs := 0

func verifier(ok: bool, quoi: String) -> void:
	print("%s · %s" % ["OK" if ok else "ÉCHEC", quoi])
	if not ok:
		echecs += 1

func _initialize() -> void:
	var v := Ville.new()
	v.charger(JSON.parse_string(FileAccess.get_file_as_string("res://data/wehrau.json")))
	verifier(is_equal_approx(v.capital(0.0), Ville.CAPITAL_DEPART), "Départ à %.0f" % Ville.CAPITAL_DEPART)

	# Les habitants rentrent : rien à la signature, tout à la livraison.
	var ilot := -1
	for fid in v.ilots:
		if v.base("i", fid, "logements_sinistres") > 0.0 and v.cout_reparation_ke("i", fid) < v.caisse_ke(0.0):
			ilot = fid
			break
	var gain := v.base("i", ilot, "logements_sinistres") * Ville.CAPITAL_PAR_LOGEMENT_RENTRE
	verifier(v.reparer("i", ilot, 0.0), "Îlot %d relevé" % ilot)
	verifier(is_equal_approx(v.capital(Ville.RECONSTRUCTION_MOIS - 0.1), Ville.CAPITAL_DEPART),
		"Rien avant la livraison")
	verifier(is_equal_approx(v.capital(Ville.RECONSTRUCTION_MOIS), Ville.CAPITAL_DEPART + gain),
		"Îlot %d livré : %+.1f" % [ilot, gain])

	# Le pont rouvert rapporte à sa livraison.
	v.reinitialiser()
	var pont: int = v.ponts_coupes()[0]
	verifier(v.reparer("r", pont, 0.0), "Pont %d engagé" % pont)
	verifier(is_equal_approx(v.capital(Ville.PONT_MOIS), Ville.CAPITAL_DEPART + Ville.CAPITAL_PONT_ROUVERT),
		"Pont %d livré : +%.0f" % [pont, Ville.CAPITAL_PONT_ROUVERT])

	# Plus personne dehors : une seule fois, au dernier camp livré.
	v.reinitialiser()
	var champs := []
	for fid in v.ilots:
		if v.camp_possible(fid) and v.camp_accessible(fid):
			champs.append(fid)
	verifier(v.abriter(champs[0], 0.0) and v.abriter(champs[1], 1.0), "Deux camps engagés")
	verifier(is_equal_approx(v.capital(0.5), Ville.CAPITAL_DEPART), "Un seul camp livré : rien")
	verifier(is_equal_approx(v.capital(2.0), Ville.CAPITAL_DEPART + Ville.CAPITAL_TOUS_ABRITES),
		"Tout le monde abrité : +%.0f" % Ville.CAPITAL_TOUS_ABRITES)

	# Retirer des places : coûte tout de suite ; un an après, le retour se juge
	# sur la rue (99). Sans `trafic.gd`, la fermeture est simulée par ses rampes.
	var rue := -1
	var voisine := -1
	for fid in v.routes:
		if rue < 0 and v.base("r", fid, "stationnement") >= 20.0 and v.base("r", fid, "charge") >= Ville.CAPITAL_CHARGE_RETIREE_PLEINE:
			rue = fid
		elif voisine < 0 and v.base("r", fid, "charge") <= 0.5:
			voisine = fid
	var cout := v.base("r", rue, "stationnement") * Ville.CAPITAL_PAR_PLACE_RETIREE
	var retour := Ville.STATIONNEMENT_MOIS + Ville.CAPITAL_RETOUR_PLACES_MOIS
	for cas in [["la rue garde ses voitures", 0.0, Ville.CAPITAL_RETOUR_PLACES_X_MIN],
			["la rue se vide sans report", -1.0, Ville.CAPITAL_RETOUR_PLACES_X_MAX],
			["la rue se vide, une voisine prend +%.2f" % (Ville.CAPITAL_REPORT_INSUPPORTABLE / 2.0), -1.0,
				(Ville.CAPITAL_RETOUR_PLACES_X_MIN + Ville.CAPITAL_RETOUR_PLACES_X_MAX) / 2.0]]:
		v.reinitialiser()
		verifier(is_equal_approx(v.capital_commande("r", rue, {"places": true}, 0.0), cout),
			"Rue %d : la fiche annonce −%.1f" % [rue, cout])
		var r := v.commander("r", rue, {"places": true}, 0.0)
		verifier(bool(r["ok"]) and is_equal_approx(float(r["capital"]), cout), "Places retirées")
		if float(cas[1]) < 0.0:
			v.ajouter_rampe("r", rue, "charge", -v.base("r", rue, "charge"), 0.0, 0.0, 6.0)
		if str(cas[0]).contains("voisine"):
			v.ajouter_rampe("r", voisine, "charge", Ville.CAPITAL_REPORT_INSUPPORTABLE / 2.0, 0.0, 0.0, 6.0, rue)
		verifier(is_equal_approx(v.capital(0.0), Ville.CAPITAL_DEPART - cout), "−%.1f au mois de la décision" % cout)
		verifier(is_equal_approx(v.capital(retour - 0.1), Ville.CAPITAL_DEPART - cout), "Rien avant un an")
		verifier(is_equal_approx(v.capital(retour), Ville.CAPITAL_DEPART - cout + cout * float(cas[2])),
			"%s : +%.1f un an après" % [cas[0], cout * float(cas[2])])

	# À zéro, on ne dépense plus : refus sans rien engager, et la cause est dite.
	v.reinitialiser()
	var refus := {}
	var rues := v.routes.keys()
	rues.sort_custom(func(a, b): return v.base("r", a, "stationnement") > v.base("r", b, "stationnement"))
	for fid in rues:
		if v.base("r", fid, "stationnement") <= 0.0:
			break
		var essai := v.commander("r", fid, {"places": true}, 0.0)
		if not bool(essai["ok"]):
			refus = essai
			refus["fid"] = fid
			break
	verifier(not refus.is_empty() and float(refus.get("manque_capital", 0.0)) > 0.0,
		"Refus faute de capital, il en reste %.1f" % v.capital(0.0))
	verifier(v.capital(0.0) >= 0.0, "Jamais sous zéro")
	if not refus.is_empty():
		verifier(not v.stationnement_en_suppression(int(refus["fid"])), "Rien d'engagé au refus")

	# La reprise redonne le même capital : il n'est que l'histoire des décisions.
	var avant := v.capital(20.0)
	var partie := v.exporter_partie()
	v.reinitialiser()
	v.importer_partie(partie)
	verifier(is_equal_approx(v.capital(20.0), avant), "Reprise : %.1f au mois 20" % avant)

	print("%d échec(s)" % echecs)
	quit(1 if echecs > 0 else 0)
