extends "res://outils/essai_ouverture.gd"
## --script res://outils/essai_mairie_pause.gd -- --ouverture
## 🏛️ La première année, la mairie s'ouvre au clic malgré « on rebâtit d'abord » ; ⏸️ la grande
## fenêtre met le jeu en pause et le relance à sa vitesse d'avant (auteur, 2026-10-22).


func executer() -> void:
	root.size = Vector2i(1600, 900)
	jeu = Maquette.new()
	root.add_child(jeu)
	jeu.set_process(false)
	jeu.horloge_trafic.stop()
	jeu.moniteur_performances.hide()
	jeu.chemin_sauvegarde = "res://../QGIS/rendus/essai_mairie_pause.wehrau"
	jeu._sur_mode(false)
	jeu.recit.terminer()
	jeu._sur_vitesse(0.0)
	var o = jeu.ouverture
	var ui = jeu.interface
	jeu._sur_reset()
	var champs: Array = o._champs_accessibles()
	jeu.ville.abriter(champs[0], 0.0)
	jeu.ville.abriter(champs[1], 0.0)
	actualiser(3.0)
	o.premier = {"couche": "r", "fid": jeu.ville.ponts_coupes()[0], "fin": 0.0}
	o._pont_rouvert()
	o.mairie_vue = true
	actualiser(jeu.mois)
	verifier(o.verrou() == "rebatir", "Première année, le pont rouvert : on rebâtit d'abord (%s)" % o.verrou())
	var fid_mairie := int(ui.LIEUX["mairie"]["fid"])
	jeu._sur_vitesse(4.0)
	jeu._sur_choix("i", fid_mairie)
	await process_frame
	verifier(ui._lieu_ouvert == "mairie" and ui._campus_panneau.visible, "Le clic sur la mairie l'ouvre")
	jeu._pause_fenetre()
	verifier(jeu.vitesse == 0.0, "La mairie ouverte, le jeu est en pause")
	ui._fermer_campus()
	jeu._pause_fenetre()
	verifier(jeu.vitesse == 4.0, "La mairie fermée, le temps repart à ×4")
	jeu._sur_vitesse(0.0)
	ui.ouvrir_lieu("mairie")
	jeu._pause_fenetre()
	ui._fermer_campus()
	jeu._pause_fenetre()
	verifier(jeu.vitesse == 0.0, "En pause avant d'ouvrir, la fermeture ne relance rien")
	jeu._sur_vitesse(2.0)
	ui.ouvrir_lieu("mairie")
	jeu._pause_fenetre()
	jeu._sur_vitesse(1.0)
	ui._fermer_campus()
	jeu._pause_fenetre()
	verifier(jeu.vitesse == 1.0, "Une vitesse choisie fenêtre ouverte reste la sienne")
	print("MAIRIE ET PAUSE : %d échec(s)" % echecs)
	jeu.queue_free()
	await process_frame
	quit(1 if echecs > 0 else 0)
