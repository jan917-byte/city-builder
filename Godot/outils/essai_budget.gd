extends SceneTree
## --headless --script res://outils/essai_budget.gd
## 💶 Le budget voté une fois par an (décision 101) : rien entre deux votes, tout
## d'un coup au mois 12, et deux parties jouées différemment votent différemment.
const Ville := preload("res://scripts/ville.gd")
const MAISONS := 59
var echecs := 0

func verifier(ok: bool, quoi: String) -> void:
	print("%s · %s" % ["OK" if ok else "ÉCHEC", quoi])
	if not ok:
		echecs += 1

func _initialize() -> void:
	var donnees: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/wehrau.json"))
	var v := Ville.new()
	v.charger(donnees)

	var tous := 0.0
	for fid in v.ilots:
		tous += v.base("i", fid, "logements") + v.base("i", fid, "logements_sinistres")
	var metres := 0.0
	for fid in v.routes:
		metres += float(v.routes[fid]["longueur_m"])
	verifier(is_equal_approx(tous * v.budget_ke_logement - metres * v.budget_ke_metre,
		Ville.BUDGET_VILLE_ENTIERE_KE_AN), "Ville entière : %.0f k€" % Ville.BUDGET_VILLE_ENTIERE_KE_AN)
	var v0: Dictionary = v.vote_budget(0)
	print("  %.0f €/logement · %.1f €/m · lendemain de la crue : %.0f logements, %.0f m, %.1f k€"
		% [v.budget_ke_logement * 1000.0, v.budget_ke_metre * 1000.0, v0["logements"], v0["metres"], v0["ke"]])
	verifier(float(v0["ke"]) < Ville.BUDGET_VILLE_ENTIERE_KE_AN, "La ville sinistrée vote moins que la ville entière")

	# Rien entre deux votes, tout au vote.
	verifier(v.budget_verse_ke(11.99) == 0.0, "Rien n'est versé avant le mois 12")
	verifier(is_equal_approx(v.budget_verse_ke(12.0), float(v.vote_budget(1)["ke"])), "Le mois 12 verse le budget d'un coup")
	verifier(is_equal_approx(v.caisse_ke(12.0) - v.caisse_ke(11.99),
		float(v.vote_budget(1)["ke"]) - v.AIDE_KE_PERSONNE_MOIS * v.sans_toit(12.0) * 0.01),
		"La caisse saute du montant voté")
	verifier(is_equal_approx(v.mois_avant_budget(5.0), 7.0) and is_equal_approx(v.mois_avant_budget(12.0), 12.0),
		"Compte à rebours : 7 mois au mois 5, 12 au mois du vote")

	# 🔴 LE CONTRÔLE DE LA DÉCISION : reloger vite ou lentement ne vote pas pareil.
	var lent := float(v.vote_budget(1)["ke"])
	verifier(v.reparer("i", MAISONS, 0.0), "Îlot %d relevé au mois 0" % MAISONS)
	verifier(v.reparation_finie("i", MAISONS, 12.0), "Livré avant le premier vote")
	var vite := float(v.vote_budget(1)["ke"])
	var rentres := v.base("i", MAISONS, "logements_sinistres")
	print("  budget de l'an 2 : %.1f k€ sans réparer, %.1f k€ en relevant l'îlot %d" % [lent, vite, MAISONS])
	verifier(is_equal_approx(vite - lent, rentres * v.budget_ke_logement),
		"%.0f logements rentrés : +%.1f k€" % [rentres, rentres * v.budget_ke_logement])

	# Une rue rouverte s'entretient.
	var rue := -1
	for fid in v.routes:
		if not v.route_praticable(fid, 0.0) and not fid in v.ponts_coupes():
			rue = fid
			break
	var avant := float(v.vote_budget(1)["ke"])
	verifier(rue >= 0 and v.reparer("r", rue, 0.0), "Rue %d déblayée" % rue)
	var cout := float(v.routes[rue]["longueur_m"]) * v.budget_ke_metre
	verifier(is_equal_approx(avant - float(v.vote_budget(1)["ke"]), cout),
		"%.0f m de rue rouverte : −%.2f k€" % [float(v.routes[rue]["longueur_m"]), cout])

	# Reprise : le budget se recalcule, rien de plus à sauvegarder.
	var caisse := v.caisse_ke(30.0)
	var partie := v.exporter_partie()
	v.reinitialiser()
	verifier(not is_equal_approx(v.caisse_ke(30.0), caisse), "Recommencer change la caisse")
	v.importer_partie(partie)
	verifier(is_equal_approx(v.caisse_ke(30.0), caisse), "Reprise : même caisse au mois 30")

	print("BUDGET : %d échec(s)" % echecs)
	quit(1 if echecs > 0 else 0)
