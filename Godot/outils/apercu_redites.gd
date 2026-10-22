extends "res://outils/essai_ouverture.gd"
## --script res://outils/apercu_redites.gd -- --ouverture --captures
## Les fiches en chantier, pour chasser ce qu'elles disent deux fois (auteur, 2026-10-22).
## → QGIS/rendus/wehrau_ouverture_redite_N_*.png


func executer() -> void:
	root.size = Vector2i(1600, 900)
	jeu = Maquette.new()
	root.add_child(jeu)
	jeu.set_process(false)
	jeu.horloge_trafic.stop()
	jeu.moniteur_performances.hide()
	jeu.chemin_sauvegarde = "res://../QGIS/rendus/essai_redites.wehrau"
	var o = jeu.ouverture
	jeu._sur_mode(false)
	jeu.recit.commencer()
	for i in 5:
		await cliquer(jeu.recit._fleche)
	jeu._sur_vitesse(0.0)
	var champs: Array = o._champs_accessibles()
	jeu.ville.abriter(champs[0], 0.0)
	jeu.ville.abriter(champs[1], 0.0)
	actualiser(0.25)
	var pont := -1
	var prix := INF
	for fid in jeu.ville.ponts_coupes():
		if jeu.ville.cout_reparation_ke("r", fid) < prix:
			pont = fid
			prix = jeu.ville.cout_reparation_ke("r", fid)
	jeu._sur_commande("r", pont, {"reparer": "provisoire"})
	actualiser(0.3)
	jeu._viser_route(pont, 120.0)
	jeu._sur_choix("r", pont)
	await capture("redite_1_pont_chantier")
	var rue := -1
	for f in jeu.ville.rues_boueuses():
		rue = int(f)
		break
	jeu._sur_commande("r", rue, {"reparer": true})
	actualiser(0.31)
	jeu._viser_route(rue, 120.0)
	jeu._sur_choix("r", rue)
	await capture("redite_2_rue_chantier")
	jeu._sur_commande("i", o.LAVOIR, {"reparer": "tradition"})
	actualiser(0.32)
	jeu._viser_objet("i", o.LAVOIR, 120.0)
	jeu._sur_choix("i", o.LAVOIR)
	await capture("redite_3_ilot_chantier")
	actualiser(0.25 + jeu.ville.duree_reparation_mois("r", pont) + 0.05)
	jeu._viser_route(pont, 120.0)
	jeu._sur_choix("r", pont)
	await capture("redite_4_pont_livre")
	jeu._sur_theme("chantiers")
	jeu.interface._detail_ouvert = true
	jeu.interface._placer_detail()
	jeu.interface.maj_chantiers(jeu.ville.chantiers(jeu.mois))
	await capture("redite_5_chantiers")
	jeu.queue_free()
	await process_frame
	quit(0)
