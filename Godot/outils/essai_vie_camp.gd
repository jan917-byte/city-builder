extends "res://outils/essai_ouverture.gd"
## --script res://outils/essai_vie_camp.gd -- --ouverture [--captures]
## 🚿 La vie au camp : un toit rend de la confiance, le camp l'use pendant le chantier du pont, l'améliorer l'arrête.


func executer() -> void:
	plainte_testee = true
	root.size = Vector2i(1600, 900)
	jeu = Maquette.new()
	root.add_child(jeu)
	jeu.set_process(false)
	jeu.horloge_trafic.stop()
	jeu.moniteur_performances.hide()
	jeu.chemin_sauvegarde = "res://../QGIS/rendus/essai_vie_camp.wehrau"
	jeu._sur_mode(false)
	jeu.recit.terminer()
	jeu._sur_vitesse(0.0)
	var o = jeu.ouverture
	var ui = jeu.interface
	var v = jeu.ville
	jeu._sur_reset()
	var depart: float = v.capital(0.0)
	var champs: Array = o._champs_accessibles()
	jeu._sur_commande("i", champs[0], {"camp": true})
	verifier(ui.bulles._bulles.any(func(b): return b.get("cible") == ui._barre_valeurs["caisse"]),
		"La dépense descend sous la caisse")
	verifier(ui.bulles._bulles.any(func(b): return b.has("lieu")),
		"La récolte perdue monte sur le champ dès la mise en place")
	jeu._sur_commande("i", champs[1], {"camp": true})
	for b in ui.bulles._bulles:
		b["age"] = 0.9 + float(b["age"])
	ui.bulles._process(0.0)
	await capture("camp_00_recolte")
	# Un quart de mois à ×1 dure 15 s : ces bulles sont parties avant la livraison.
	for b in ui.bulles._bulles:
		b["age"] = ui.bulles.DUREE
	ui.bulles._process(0.0)
	actualiser(0.25)
	var abrite: float = v.capital(0.25)
	verifier(abrite > depart + 10.0, "Un toit rend de la confiance : %.1f → %.1f" % [depart, abrite])
	verifier(ui.bulles._bulles.any(func(b): return b.has("lieu")),
		"La confiance monte au-dessus du champ livré")
	# Les bulles à mi-course, sinon la capture les prend à leur naissance, transparentes.
	for b in ui.bulles._bulles:
		b["age"] = 0.9 + float(b["age"])
	ui.bulles._process(0.0)
	await capture("camp_00_bulle")
	verifier(v.usure_camp_mois(0.25) == 0.0 and not o.annonce.visible,
		"Le camp n'use rien avant le pont")
	# 🌉 Le premier pont, en provisoire : l'usure part un mois après son lancement, chantier en cours.
	var pont: int = v.ponts_coupes()[0]
	jeu._sur_commande("r", pont, {"reparer": "provisoire"})
	var debut: float = v.usure_debut()
	verifier(is_equal_approx(debut, 0.25 + v.CAMP_USURE_APRES_PONT_MOIS)
		and debut < 0.25 + v.duree_reparation_mois("r", pont),
		"L'usure commence un mois après le lancement du pont, avant sa livraison : mois %.2f" % debut)
	actualiser(debut - 0.05)
	verifier(not o.annonce.visible and v.capital(debut - 0.05) >= abrite - 0.01,
		"Ni plainte ni baisse pendant le déblaiement")
	o.examiner("i", champs[0])
	verifier(not ui._demandes_bloc.is_visible_in_tree(), "Le bouton d'amélioration attend la plainte")
	jeu._sur_vitesse(1.0)
	actualiser(debut + 0.05)
	verifier(o.annonce.visible and o.carte == "camp" and jeu.vitesse == 0.0 and o.etape == "pont_travaux",
		"Les habitants se plaignent pendant le chantier du pont, au centre, le temps en pause")
	verifier(absf(v.usure_camp_mois(jeu.mois) - 2.6) < 0.05, "260 au camp usent %.2f par mois" % v.usure_camp_mois(jeu.mois))
	verifier("/mois" in ui._barre_valeurs["capital"].text, "Le compteur dit la baisse : %s" % ui._barre_valeurs["capital"].text)
	await capture("camp_02_plainte")
	var camp: int = o.camp_le_plus_plein()
	await cliquer(o.annonce_principal)
	verifier(not o.annonce.visible and o.plainte == 2, "La carte se ferme")
	verifier(jeu.selection.sel_fid == camp and ui._demandes_bloc.is_visible_in_tree(),
		"« Voir le campement » ouvre le camp et son bouton d'amélioration")
	verifier(ui._demande_boutons.size() == 1 and "Améliorer le campement" in ui._demande_boutons["amelioration"].text,
		"Un seul bouton : %s" % ui._demande_boutons["amelioration"].text)
	await cliquer(ui._demande_boutons["amelioration"])
	await capture("camp_03_ameliorer")
	await cliquer(ui._recap_bouton)
	verifier(v.demande_engagee("amelioration"), "L'amélioration se commande depuis la fiche du camp")
	verifier(jeu.vitesse == 1.0, "Améliorer le camp relance le temps à ×1 (vitesse %s)" % jeu.vitesse)
	actualiser(jeu.mois + 0.5 * float(v.DEMANDES["amelioration"]["mois"]))
	ui._maj_fiche()
	var lignes: Array = v.chantiers(jeu.mois)["en_cours"].filter(func(c): return c["genre"] == "amelioration")
	verifier(lignes.size() == 1 and absf(float(lignes[0]["part"]) - 0.5) < 0.05
		and ui.retours.chantiers.visible and ui._chantier_bloc.is_visible_in_tree()
		and "campement" in ui._chantier_quoi.text,
		"L'amélioration est un chantier : une ligne en bas à droite, une barre sur la fiche du camp")
	await capture("camp_03b_amelioration_en_cours")
	var avant: float = v.usure_camp_mois(jeu.mois)
	actualiser(jeu.mois + v.DEMANDES["amelioration"]["mois"] + 0.05)
	var apres: float = v.usure_camp_mois(jeu.mois)
	verifier(avant > 2.0 and apres == 0.0, "Le campement amélioré arrête l'usure : %.2f → %.2f" % [avant, apres])
	verifier(not o.annonce.visible, "La plainte ne revient pas")
	ui._maj_fiche()
	verifier(ui._demande_boutons["amelioration"].disabled, "L'amélioration livrée ne se recommande pas")
	await capture("camp_04_ameliore")
	# 🧾 Au clic sur un compteur du haut, pourquoi il monte ou baisse.
	ui.ouvrir_detail("capital")
	var mots: Array = ui._detail_lignes.map(func(l): return str(l[0]))
	verifier(ui._detail_panneau.visible and "Le camp, mois après mois" in mots
		and "Camp : campement amélioré" in mots, "Le détail de la confiance nomme l'usure et l'amélioration : %s" % [mots])
	await capture("camp_05_detail_confiance")
	await cliquer_compteur(ui, "caisse")
	mots = ui._detail_lignes.map(func(l): return str(l[0]))
	var genres: Dictionary = v.depenses_par_genre()
	var somme := 0.0
	for g in genres:
		somme += float(genres[g])
	verifier("Camps" in mots and "Campement amélioré" in mots and "Aide aux personnes sans abri" in mots
		and absf(somme - v._depense_ke) < 0.01 and not genres.has("autres"),
		"Le détail de l'argent range chaque chantier : %s" % [mots])
	await capture("camp_06_detail_argent")
	await cliquer_compteur(ui, "caisse")
	verifier(not ui._detail_panneau.visible, "Un second clic referme le détail")

	jeu._sur_sauvegarde()
	jeu._sur_reset()
	verifier(not v.demande_engagee("amelioration") and o.plainte == 0, "Recommencer oublie le camp")
	jeu._sur_reprise()
	verifier(v.demande_engagee("amelioration") and o.plainte == 2, "La reprise garde l'amélioration et la plainte passée")
	print("CAMP : %d échec(s)" % echecs)
	jeu.queue_free()
	await process_frame
	quit(1 if echecs else 0)


## Un vrai clic sur le compteur du haut : il passe par `gui_input`, comme la souris.
func cliquer_compteur(ui, cle: String) -> void:
	await process_frame
	var pos: Vector2 = (ui._barre_valeurs[cle] as Label).get_parent().get_global_rect().get_center()
	for appui in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = appui
		e.position = pos
		e.global_position = pos
		root.push_input(e, true)
	await process_frame
