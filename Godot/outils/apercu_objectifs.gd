extends "res://outils/essai_ouverture.gd"
## --script res://outils/apercu_objectifs.gd -- --ouverture --captures
## Les objectifs en bas à gauche (auteur, 2026-10-18) : le premier qui se remplit, monte et
## reste au-dessus, pâle ; sa fiole vole jusqu'au compteur de recherche.
## → QGIS/rendus/wehrau_ouverture_objectifs_N_*.png


func attendre(s: float) -> void:
	await create_timer(s).timeout


func executer() -> void:
	root.size = Vector2i(1600, 900)
	jeu = Maquette.new()
	root.add_child(jeu)
	jeu.set_process(false)
	jeu.horloge_trafic.stop()
	jeu.moniteur_performances.hide()
	jeu.chemin_sauvegarde = "res://../QGIS/rendus/essai_objectifs.wehrau"
	var o = jeu.ouverture
	jeu._sur_mode(false)
	jeu.recit.commencer()
	# Sans clic simulé : sur Mac la vraie souris le fait perdre, et l'aperçu ne teste pas le clic.
	for i in 5:
		jeu.recit._fleche.pressed.emit()
		await process_frame
	jeu._sur_vitesse(0.0)
	actualiser(0.0)
	await attendre(0.8)
	await capture("objectifs_1_reloger")
	var champs: Array = o._champs_accessibles()
	jeu.ville.abriter(champs[0], 0.0)
	jeu.ville.abriter(champs[1], 0.0)
	actualiser(0.2)
	await attendre(0.3)
	await capture("objectifs_2_cercle_plein")
	await attendre(0.45)
	await capture("objectifs_3_la_fiole_vole")
	await attendre(0.5)
	await capture("objectifs_4_le_compteur_bondit")
	await attendre(1.5)
	await capture("objectifs_5_le_suivant")
	# Posés à la main : seule la pile des atteints est regardée ici.
	jeu.ville._objectifs["pont"] = 0.3
	jeu.ville._objectifs["ilot"] = 0.4
	actualiser(0.5)
	await attendre(1.0)
	await capture("objectifs_6_trois_atteints")
	jeu._sur_theme("chantiers")
	actualiser(0.25)
	await attendre(0.3)
	await capture("objectifs_7_avec_chantiers")
	jeu.queue_free()
	await process_frame
	quit(0)
