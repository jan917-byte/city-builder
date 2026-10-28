extends "res://outils/essai_ouverture.gd"
## --script res://outils/apercu_budget.gd -- --ouverture --captures
## 🗳️ La fenêtre du budget (124) : elle s'ouvre seule le 1er janvier, le temps en pause, et « Continuer » la ferme.
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
	_fermer(ui)
	verifier(not ui.fenetre_budget.visible, "« Continuer » la referme")
	# 🏛️ Le rappel à la mairie : la même fenêtre, sans rien recevoir de plus.
	ui.ouvrir_lieu("mairie")
	var carte: Dictionary = ui._lieu_lignes["budget"]
	verifier((carte["bloc"] as Control).visible, "La mairie montre la carte « Budget de l'année »")
	verifier((ui._lieu_lignes["fonds"]["bloc"] as Control).visible == not jeu.ville.fonds_recu(jeu.mois),
		"Le fonds reçu laisse sa place au budget ; pas reçu, il reste")
	if not jeu.ville.fonds_recu(jeu.mois):
		jeu.ville.demander_fonds(jeu.mois)
		ui._maj_lieu()
		verifier(not (ui._lieu_lignes["fonds"]["bloc"] as Control).visible, "Le fonds demandé en janvier disparaît")
	poser(ui)
	# Le panneau s'ouvre en fondu : l'image attend qu'il soit posé.
	await create_timer(0.8).timeout
	await capture("budget_3_mairie")
	var caisse: float = jeu.ville.caisse_ke(jeu.mois)
	var journal: int = ui.retours.journal.size()
	(carte["bouton"] as Button).pressed.emit()
	verifier(ui.fenetre_budget.visible, "« Voir le budget » rouvre la fenêtre")
	await capture("budget_4_rappel")
	_fermer(ui)
	verifier(is_equal_approx(jeu.ville.caisse_ke(jeu.mois), caisse) and ui.retours.journal.size() == journal,
		"Le rappel ne reçoit rien et n'écrit rien")
	ui._fermer_lieu()
	avancer(Budget.debut_an(3) + 0.01)
	verifier(ui.fenetre_budget.visible, "Elle revient le 1er janvier de l'an 3")
	poser(ui)
	await capture("budget_2_an_3")
	_fermer(ui)
	print("Échecs : %d" % echecs)
	quit(1 if echecs else 0)


## `actualiser` sans la fermeture d'office d'`essai_ouverture`.
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


func _fermer(ui) -> void:
	for n in ui.fenetre_budget._corps.get_children():
		if n is Button:
			(n as Button).pressed.emit()
