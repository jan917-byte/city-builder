extends "res://outils/essai_ouverture.gd"
## --script res://outils/apercu_espaces.gd -- --ouverture --captures
## Les fiches de la place (19), du parc (46), des jardins (48), et d'un îlot bâti (13) pour comparer.


func executer() -> void:
	root.size = Vector2i(1600, 900)
	jeu = Maquette.new()
	root.add_child(jeu)
	jeu.set_process(false)
	jeu.horloge_trafic.stop()
	jeu.moniteur_performances.hide()
	jeu.chemin_sauvegarde = "res://../QGIS/rendus/essai_espaces.wehrau"
	jeu._sur_mode(false)
	jeu.recit.commencer()
	for i in 5:
		await cliquer(jeu.recit._fleche)
	jeu._sur_vitesse(0.0)
	# Sans le guide, aucun verrou d'urgence : les tuiles du bas s'affichent.
	jeu.interface.ouverture = null
	for fid in [19, 46, 48, 13]:
		jeu._viser_objet("i", fid, 120.0)
		jeu._sur_choix("i", fid)
		jeu._rafraichir(true)
		await capture("espaces_%d" % fid)
		jeu.interface._fermer_fiche()
	jeu.queue_free()
	await process_frame
	quit(0)
