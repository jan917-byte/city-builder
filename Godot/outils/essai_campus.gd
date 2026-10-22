extends "res://outils/essai_ouverture.gd"
## --script res://outils/essai_campus.gd -- --ouverture [--captures]
## 🎓 Le campus, un seul îlot (auteur, 2026-10-22) : il clignote tant qu'on le cherche, et
## chacune de ses trois parties rend l'université, sa fiche et ses études.


func executer() -> void:
	root.size = Vector2i(1600, 900)
	jeu = Maquette.new()
	root.add_child(jeu)
	jeu.set_process(false)
	jeu.horloge_trafic.stop()
	jeu.moniteur_performances.hide()
	jeu._sur_mode(false)
	jeu.recit.terminer()
	jeu._sur_vitesse(0.0)
	jeu.ouverture.premiere_annee = false
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
	verifier(jeu.ville.commander_etude(jeu.mois), "L'étude se commande")
	# 🎓 Pendant l'étude, l'université cliquée dit son avancement et rejoint la colonne (2026-10-22).
	var univ: Button = tuile("universite")
	jeu._rafraichir(true)
	ui._maj_rail()
	verifier(not univ.visible, "L'étude commandée, l'université n'est pas encore dans la colonne")
	actualiser(jeu.mois + jeu.ville.ETUDE_MOIS * 0.5)
	var fid_u := int(ui.LIEUX["universite"]["fid"])
	jeu.selection.sel_couche = "i"
	jeu.selection.sel_fid = fid_u
	jeu._sur_choix("i", fid_u)
	jeu._rafraichir(true)
	ui._maj_rail()
	verifier(ui._fiche_panneau.visible and ui._chantier_bloc.visible
		and ui._chantier_quoi.text == "Étude de la prochaine crue" and "encore" in ui._chantier_reste.text
		and ui._chantier_jauge.pose > 0.3 and ui._chantier_jauge.pose < 0.7,
		"La fiche de l'université montre l'étude à moitié faite : %s, %s, %.2f" % [
			ui._chantier_quoi.text, ui._chantier_reste.text, ui._chantier_jauge.pose])
	verifier(univ.visible and not univ.disabled and not ui._campus_panneau.visible
		and ui._menu_boutons["dangers"].disabled,
		"Cliquée, l'université rejoint la colonne sans ouvrir sa fenêtre ; Dangers attend l'étude")
	await capture("campus_un_00_etude_en_cours")
	await cliquer(univ)
	verifier(ui._campus_panneau.visible and ui._univ_vide.visible and "en cours" in ui._univ_vide.text,
		"Sa tuile ouvre la fenêtre, qui dit l'étude en cours : %s" % ui._univ_vide.text)
	await capture("campus_un_00b_fenetre")
	ui._fermer_campus()
	ui._fermer_fiche()
	# Ce qui éteignait le trait : le guide réduit, un calque ouvert.
	o.ouvert = false
	jeu._sur_theme("chantiers")
	actualiser(jeu.mois + jeu.ville.ETUDE_MOIS + 0.01)
	jeu._sur_vitesse(0.0)
	verifier(o.carte == "etude" and o.annonce.visible, "L'étude rendue paraît")
	await cliquer(o.annonce_principal)
	jeu._rafraichir(true)
	var campus: Array = ui.fids_campus()
	verifier(jeu.theme == "" and o.groupe_carte() == campus and jeu._contour_fids == campus,
		"Trouver l'université : la ville bâtie, le campus sous un trait, guide réduit")
	await capture("campus_un_01_trouver")

	jeu.selection.sel_couche = "i"
	jeu.selection.sel_fid = o.MAISONS
	jeu._sur_choix("i", o.MAISONS)
	jeu._rafraichir(true)
	verifier(ui._fiche_panneau.visible and ui._fiche_fid == o.MAISONS and jeu._contour_fids == campus
		and not o.etude_lue, "Un autre îlot cliqué ouvre sa fiche ; le campus clignote toujours")
	await capture("campus_un_02_autre_ilot")
	ui._fermer_fiche()

	var fid_univ := int(ui.LIEUX["universite"]["fid"])
	for cle in ["institut", "bibliotheque"]:
		var fid := int(ui.LIEUX[cle]["fid"])
		jeu.selection.sel_couche = "i"
		jeu.selection.sel_fid = fid
		jeu._sur_choix("i", fid)
		jeu._rafraichir(true)
		verifier(ui._fiche_fid == fid_univ and jeu.selection.sel_fid == fid_univ
			and ui._fiche_titre.text == ui.lieux.nom("i", fid_univ, "")
			and ui._lieu_ouvert == "universite" and ui._etude_bloc.visible
			and jeu._contour_fids == campus and o.etude_lue,
			"L'îlot de %s rend l'université : sa fiche, l'onglet Études, tout le campus sous le trait" % cle)
	await capture("campus_un_03_universite")

	ui._fermer_campus()
	jeu._rafraichir(true)
	verifier(not ui._fiche_panneau.visible and jeu._contour_fids.is_empty(),
		"La fenêtre fermée, la fiche du campus part avec elle")
	print("CAMPUS : %d échec(s)" % echecs)
	jeu.queue_free()
	await process_frame
	quit(1 if echecs else 0)
