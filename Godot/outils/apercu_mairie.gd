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
	# 🗳️ Le stationnement payant : sous le seuil, puis signé sans dépenser la confiance (98).
	var k: float = jeu.ville.capital(jeu.mois)
	await capture_sous_le_seuil(ui, 49.0)
	ui._capital = k
	ui._maj_lieu()
	await capture("mairie_2c_regle_au_dessus")
	(ui._lieu_lignes["regle_stationnement_payant"]["bouton"] as Button).pressed.emit()
	verifier(jeu.ville._regles.has("stationnement_payant") and is_equal_approx(jeu.ville.capital(jeu.mois), k),
		"Stationnement payant signé à %.0f de confiance, sans la dépenser" % k)
	await capture("mairie_3_regle_signee")
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
	await capture("mairie_4_etude_en_cours")
	print("Échecs : %d" % echecs)
	quit(1 if echecs else 0)


## `capture` relit la confiance : on la force APRÈS, le temps d'une image.
func capture_sous_le_seuil(ui, k: float) -> void:
	if not "--captures" in OS.get_cmdline_user_args():
		return
	jeu._rafraichir(false)
	ui._capital = k
	ui._maj_lieu()
	await process_frame
	await RenderingServer.frame_post_draw
	verifier(root.get_texture().get_image().save_png(
		"res://../QGIS/rendus/wehrau_ouverture_mairie_2b_regle_sous_le_seuil.png") == OK,
		"Capture mairie_2b_regle_sous_le_seuil")
