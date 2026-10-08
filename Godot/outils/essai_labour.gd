extends "res://outils/essai_ouverture.gd"
## --script res://outils/essai_labour.gd -- --ouverture [--captures]
## 🏕️🚜 Le champ devient campement, puis le labour le rend au champ (auteur, 2026-10-08).


func executer() -> void:
	root.size = Vector2i(1600, 900)
	jeu = Maquette.new()
	root.add_child(jeu)
	jeu.set_process(false)
	jeu.horloge_trafic.stop()
	jeu.moniteur_performances.hide()
	jeu.chemin_sauvegarde = "res://../QGIS/rendus/essai_labour.wehrau"
	jeu._sur_mode(false)
	jeu.recit.terminer()
	jeu._sur_vitesse(0.0)
	var o = jeu.ouverture
	var ui = jeu.interface
	var v = jeu.ville
	jeu._sur_reset()
	var champs: Array = o._champs_accessibles()
	var nourrit0: float = v.champ_rendement(champs[1], 0.0)
	jeu._sur_commande("i", champs[0], {"camp": true})
	jeu._sur_commande("i", champs[1], {"camp": true})
	actualiser(0.25)
	var camp: int = champs[1]

	# --- Le campement : plus de culture, des personnes logées.
	jeu.examiner("i", camp)
	ui.ouvrir_onglet("campagne")
	ui._maj_fiche()
	verifier(ui._fiche_titre.text.begins_with("Campement"), "Le champ s'appelle campement : %s" % ui._fiche_titre.text)
	verifier("logée" in ui._resume_texte.text or "personne n'y vit" in ui._resume_texte.text,
		"Le résumé dit qui y vit : %s" % ui._resume_texte.text)
	verifier(ui._onglet_grilles["campement_i"].visible and not ui._onglet_grilles["campagne_i"].visible
		and not ui._culture_bloc.visible, "Plus de culture : les tuiles du camp")
	verifier(not ui._labour_bouton.visible, "Habité, il ne se laboure pas")
	await capture("labour_01_campement")

	# --- Tout le monde rentre : le dernier camp posé se vide le premier.
	v.crediter_essai_ke(50000.0)
	var fin := 0.0
	for f in v.ilots:
		if v.base("i", f, "logements_sinistres") > 0.0 and v.reparer("i", int(f), 0.3):
			fin = maxf(fin, 0.3 + v.duree_reparation_mois("i", int(f)))
	var t := fin + 0.1
	actualiser(t)
	verifier(v.camp_abris(camp, t) == 0 and v.labour_possible(camp, t),
		"Les habitants rentrés, le campement vide se laboure (%d containers)" % v.camp_abris(camp, t))
	jeu.examiner("i", camp)
	ui.ouvrir_onglet("campagne")
	ui._maj_fiche()
	verifier(ui._labour_bouton.visible and "personne" in ui._resume_texte.text,
		"La fiche propose « Labourer » : %s" % ui._resume_texte.text)
	await capture("labour_02_vide")
	await cliquer(ui._labour_bouton)
	var caisse0: float = v.caisse_ke(t)
	await cliquer(ui._recap_bouton)
	verifier(v.labour_en_cours(camp, t + 0.01) and v.caisse_ke(t) < caisse0,
		"Labourer se paie et se met en chantier (%.0f k€)" % (caisse0 - v.caisse_ke(t)))
	verifier(not v.est_campement(camp, t + 0.01) and v.champ_rendement(camp, t + 0.01) == 0.0,
		"Pendant le labour, ni campement ni récolte")

	# --- Rendu au champ, en céréales.
	var apres: float = t + v.LABOUR_MOIS + 0.1
	actualiser(apres)
	jeu.examiner("i", camp)
	ui.ouvrir_onglet("campagne")
	ui._maj_fiche()
	verifier(v.champ_cultive(camp, apres) and is_equal_approx(v.champ_rendement(camp, apres), nourrit0),
		"Labouré, il nourrit comme au départ : %.0f personnes" % v.champ_rendement(camp, apres))
	# Les cultures, elles, attendent le levier « pré » comme sur tout champ.
	verifier(ui._fiche_titre.text.begins_with("Champ") and ui._onglet_grilles["campagne_i"].visible
		and ui._fiche_valeurs["culture"].text == "Céréales" and not ui._camp_bloc.visible,
		"La fiche redevient celle d'un champ : %s, %s" % [ui._fiche_titre.text, ui._fiche_valeurs["culture"].text])
	await capture("labour_03_champ")

	# --- La sauvegarde garde le labour.
	jeu._sur_sauvegarde()
	jeu._sur_reset()
	jeu._sur_reprise()
	verifier(v.labour_fini(camp, apres), "La reprise garde le labour")
	print("LABOUR : %d échec(s)" % echecs)
	quit(1 if echecs > 0 else 0)
