extends "res://outils/essai_ouverture.gd"
## --script res://outils/apercu_mairie.gd -- --ouverture --captures
## La mairie : cartes alignées par rangée, le fonds en gain vert sur son bouton (auteur, 2026-10-21).
## → QGIS/rendus/wehrau_ouverture_mairie_N_*.png


func executer() -> void:
	root.size = Vector2i(1600, 900)
	jeu = Maquette.new()
	root.add_child(jeu)
	jeu.set_process(false)
	jeu.horloge_trafic.stop()
	jeu.moniteur_performances.hide()
	jeu.chemin_sauvegarde = "res://../QGIS/rendus/essai_mairie.wehrau"
	var ui = jeu.interface
	jeu._sauter_au_pont()
	jeu.ouverture.pont_termine = true
	ui.ouvrir_lieu("mairie")
	await capture("mairie_1_le_fonds")
	jeu.ouverture.tout_ouvert = true
	ui._maj_lieu()
	await capture("mairie_2_tout_ouvert")
	var cartes: Array = []
	for col in ui._mairie_bloc.get_children():
		if (col as Control).visible:
			for c in col.get_children():
				if c is PanelContainer and (c as Control).visible:
					cartes.append(c)
					break
	var h := (cartes[0] as Control).size.y
	verifier(cartes.all(func(c) -> bool: return is_equal_approx((c as Control).size.y, h)),
		"Les premières cartes des %d colonnes ont la même hauteur" % cartes.size())
	# L'étude commandée se suit dans la carte des chantiers, en bleu.
	ui._fermer_lieu()
	var t: float = jeu.mois
	jeu.ville.crediter_essai_ke(jeu.ville.ETUDE_KE)
	verifier(jeu.ville.commander_etude(t), "L'étude de la crue est commandée")
	jeu.trafic.avancer(t + 0.4)
	actualiser(t + 0.4)
	var lignes: Array = jeu.interface.retours.chantiers_lignes
	verifier((lignes[0]["quoi"] as Label).text == "Étude de la prochaine crue"
		and (lignes[0]["bloc"] as Control).visible, "L'étude en cours ouvre la carte des chantiers")
	await capture("mairie_3_etude_en_cours")
	print("Échecs : %d" % echecs)
	quit(1 if echecs else 0)
