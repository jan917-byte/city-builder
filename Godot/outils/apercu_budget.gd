extends "res://outils/essai_ouverture.gd"
## --script res://outils/apercu_budget.gd -- --ouverture --captures
## 🗳️ La fenêtre du budget (124) : elle s'ouvre seule le 1er janvier, le temps en pause, et se vote.
## → QGIS/rendus/wehrau_ouverture_budget_*.png
const Budget := preload("res://scripts/budget.gd")


func executer() -> void:
	root.size = Vector2i(1600, 900)
	jeu = Maquette.new()
	root.add_child(jeu)
	jeu.set_process(false)
	jeu.horloge_trafic.stop()
	jeu.moniteur_performances.hide()
	jeu.chemin_sauvegarde = "res://../QGIS/rendus/essai_budget.wehrau"
	var ui = jeu.interface
	jeu._sauter_au_pont()
	jeu.ouverture.pont_termine = true
	verifier(jeu.ville.signer_regle("stationnement_payant", jeu.mois), "Stationnement payant signé (confiance %.0f)" % jeu.ville.capital(jeu.mois))
	plainte_testee = false
	avancer(Budget.debut_an(2) - 0.05)
	verifier(not ui.fenetre_budget.visible, "Pas de fenêtre en décembre")
	avancer(Budget.debut_an(2) + 0.01)
	verifier(ui.fenetre_budget.visible, "La fenêtre s'ouvre le 1er janvier de l'an 2")
	verifier(ui.grande_fenetre_ouverte(), "Elle compte comme grande fenêtre : le temps s'arrête")
	poser(ui)
	await capture("budget_1_an_2")
	_voter(ui)
	verifier(not ui.fenetre_budget.visible, "Voter la referme")
	avancer(Budget.debut_an(3) + 0.01)
	verifier(ui.fenetre_budget.visible, "Elle revient le 1er janvier de l'an 3")
	poser(ui)
	await capture("budget_2_an_3")
	_voter(ui)
	print("Échecs : %d" % echecs)
	quit(1 if echecs else 0)


## `actualiser` sans le vote d'office d'`essai_ouverture`.
func avancer(mois: float) -> void:
	jeu.mois = mois
	jeu.trafic.avancer(mois)
	jeu._rafraichir(true)
	jeu.ouverture.actualiser(true)


## Le saut de dix mois laisse des chiffres en vol vers les compteurs : ils sont vidés avant l'image.
func poser(ui) -> void:
	ui.bulles.en_vol.clear()
	for cle in ["caisse", "capital"]:
		ui.actualiser_compteur(cle)


func _voter(ui) -> void:
	for n in ui.fenetre_budget._corps.get_children():
		if n is Button:
			(n as Button).pressed.emit()
