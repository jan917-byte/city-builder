extends "res://outils/essai_ouverture.gd"
## --script res://outils/apercu_retour.gd -- --ouverture --captures
## Retour de jeu du 2026-10-18 : le champ et son camp, le guide du pont, Chantiers après
## « Tout déblayer », la fiche du Lavoir. → QGIS/rendus/wehrau_ouverture_retour_N_*.png


func executer() -> void:
	root.size = Vector2i(1600, 900)
	jeu = Maquette.new()
	root.add_child(jeu)
	jeu.set_process(false)
	jeu.horloge_trafic.stop()
	jeu.moniteur_performances.hide()
	jeu.chemin_sauvegarde = "res://../QGIS/rendus/essai_retour.wehrau"
	var o = jeu.ouverture
	jeu._sur_mode(false)
	jeu.recit.commencer()
	for i in 5:
		await cliquer(jeu.recit._fleche)
	jeu._sur_vitesse(0.0)
	var champs: Array = o._champs_accessibles()
	jeu._sur_choix("i", champs[0])
	await cliquer(jeu.interface._camp_bouton)
	jeu._rafraichir(true)
	await capture("retour_1_champ")
	jeu.interface._vider_pose()
	jeu.interface._fermer_fiche()
	jeu.ville.abriter(champs[0], 0.0)
	jeu.ville.abriter(champs[1], 0.0)
	actualiser(0.1)
	await capture("retour_2_abris_en_route")
	actualiser(0.25)
	await capture("retour_3_choix_du_pont")
	var pont := -1
	var prix := INF
	for fid in jeu.ville.ponts_coupes():
		if jeu.ville.cout_reparation_ke("r", fid) < prix:
			pont = fid
			prix = jeu.ville.cout_reparation_ke("r", fid)
	jeu._sur_commande("r", pont, {"reparer": "provisoire"})
	actualiser(0.3)
	jeu._sur_deblayer_tout()
	actualiser(0.32)
	jeu._sur_theme("chantiers")
	jeu.interface._detail_ouvert = true
	jeu.interface._placer_detail()
	jeu.interface.maj_chantiers(jeu.ville.chantiers(jeu.mois))
	await capture("retour_4_chantiers")
	jeu._sur_theme("")
	actualiser(0.6)
	jeu._viser_objet("i", 62, 120.0)
	jeu._sur_choix("i", 62)
	await cliquer(jeu.interface._rebatir_boutons["tradition"])
	jeu._rafraichir(true)
	await capture("retour_5_lavoir")
	jeu.queue_free()
	await process_frame
	quit(0)
