extends "res://outils/essai_ouverture.gd"
## --script res://outils/essai_budget_fiche.gd -- --ouverture [--captures]
## 💶 Le vote annuel à l'écran (101) : le compte à rebours, puis la fiche qui
## arrête le temps au mois 12 et dit pourquoi le budget a bougé.


func executer() -> void:
	root.size = Vector2i(1600, 900)
	jeu = Maquette.new()
	root.add_child(jeu)
	jeu.set_process(false)
	jeu.horloge_trafic.stop()
	jeu.moniteur_performances.hide()
	jeu._sur_mode(false)
	var o = jeu.ouverture
	var retours = jeu.interface.retours
	jeu.recit.commencer()
	while jeu.recit.page + 1 < jeu.recit._pages.size():
		jeu.recit.suivant()
	verifier("3,50 M€" in jeu.recit._texte.text and "dans un an" in jeu.recit._texte.text,
		"La dernière page du récit annonce la somme de départ et le vote dans un an")
	await capture("budget_00_recit")
	jeu.recit.terminer()
	jeu._sur_vitesse(0.0)

	# Tout le monde abrité, l'îlot des maisons relevé avant le premier vote.
	var champs: Array = o._champs_accessibles()
	verifier(jeu.ville.abriter(champs[0], 0.0) and jeu.ville.abriter(champs[1], 0.0), "Relogement engagé")
	# Un an de chantier : engagé au mois 0, il est livré au vote.
	verifier(jeu.ville.reparer("i", o.MAISONS, 0.0), "Îlot %d relevé" % o.MAISONS)
	var rues := 0
	for fid in jeu.ville.routes:
		if rues < 4 and not jeu.ville.route_praticable(fid, 0.0) and not fid in jeu.ville.ponts_coupes():
			rues += int(jeu.ville.reparer("r", fid, 0.0))
	verifier(rues == 4, "Quatre rues déblayées")
	o.pont_termine = true
	o.suite = true
	actualiser(5.0)
	verifier(jeu.ville.budget_verse_ke(5.0) == 0.0, "Rien n'est versé avant le vote")
	verifier(jeu.interface._ville_valeurs["prochain_budget"].text == "budget dans 7 mois",
		"Compte à rebours sous la caisse : « %s »" % jeu.interface._ville_valeurs["prochain_budget"].text)
	await capture("budget_01_compte_a_rebours")

	# Le temps passe le mois 12 à ×12 : il doit s'arrêter PILE dessus.
	actualiser(11.9)
	var caisse: float = jeu.ville.caisse_ke(11.9)
	var nb: int = retours.journal.size()
	jeu._sur_vitesse(12.0)
	jeu._process(1.0)
	var vote: Dictionary = jeu.ville.vote_budget(1)
	verifier(is_equal_approx(jeu.mois, 12.0), "Le temps s'arrête au mois 12 (%.2f)" % jeu.mois)
	verifier(jeu.budget.en_cours() and jeu.vitesse == 0.0, "La fiche du vote s'ouvre, temps en pause")
	verifier(jeu.ville.caisse_ke(12.0) - caisse > float(vote["ke"]) - 5.0,
		"La caisse reçoit %.0f k€ d'un coup" % vote["ke"])
	verifier(retours.journal.size() > nb and "Budget de l'an 2" in retours.journal[-1],
		"Le vote est écrit au journal : « %s »" % retours.journal[-1])
	verifier(jeu.budget._grille.get_child_count() == 6, "Deux lignes : logements et rues")
	verifier(float(vote["logements"]) > float(jeu.ville.vote_budget(0)["logements"]),
		"Les logements rentrés font monter le budget")
	await capture("budget_02_fiche")
	jeu._sur_vitesse(1.0)
	verifier(jeu.vitesse == 0.0, "La lecture ne relance pas le temps tant que la fiche est ouverte")
	await cliquer(jeu.budget.find_children("*", "Button", true, false)[0])
	verifier(not jeu.budget.en_cours() and jeu.vitesse == 12.0, "« Continuer » reprend à ×12")
	jeu._sur_vitesse(0.0)
	await capture("budget_03_apres")

	print("BUDGET À L'ÉCRAN : %d échec(s)" % echecs)
	quit(1 if echecs > 0 else 0)
