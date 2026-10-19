extends "res://outils/essai_ouverture.gd"
## --script res://outils/essai_etude.gd -- --ouverture [--captures]
## 🎓 Après le pont : l'étude, le campus trouvé sur la carte, sa fiche, puis les
## îlots à rebâtir et les pilotis (auteur, 2026-10-08).


func executer() -> void:
	root.size = Vector2i(1600, 900)
	jeu = Maquette.new()
	root.add_child(jeu)
	jeu.set_process(false)
	jeu.horloge_trafic.stop()
	jeu.moniteur_performances.hide()
	jeu.chemin_sauvegarde = "res://../QGIS/rendus/essai_etude.wehrau"
	jeu._sur_mode(false)
	jeu.recit.terminer()
	jeu._sur_vitesse(0.0)
	# Le chapitre de l'étude, après la première année (2026-10-18).
	jeu.ouverture.premiere_annee = false
	var o = jeu.ouverture
	var ui = jeu.interface
	jeu._sur_reset()
	var champs: Array = o._champs_accessibles()
	jeu.ville.abriter(champs[0], 0.0)
	jeu.ville.abriter(champs[1], 0.0)
	actualiser(3.0)
	verifier(not ui.etude_publiee(), "Avant le pont, l'étude n'est pas parue")
	jeu.interface._sur_rail("dangers")
	verifier(not ui._onglets_crue["prochaine"].visible, "Avant l'étude, Dangers n'a que ses dégâts")
	jeu._sur_theme("")

	var univ: Button = tuile("universite")
	verifier(not univ.visible and ui._rail_lieux.size() == 2,
		"Avant le pont, la colonne n'a pas l'université, et elle n'a que deux lieux (114)")
	# 🎓 Le pont livré, une seule carte : l'étude (auteur, 2026-10-08).
	o.premier = {"couche": "r", "fid": jeu.ville.ponts_coupes()[0], "fin": 0.0}
	o._pont_rouvert()
	verifier(o.pont_termine and o.etude_parue and o.carte == "etude" and o.annonce.visible
		and jeu.vitesse == 0.0 and not o.annonce_second.visible
		and o.annonce_principal.text == "Trouver l'université",
		"Le pont rouvert, l'étude paraît : une carte au centre, un seul bouton, jeu en pause")
	verifier("rouvert" in str(ui.retours.journal) and "étude" in ui.retours.journal[-1],
		"Le bandeau dit le pont rouvert, le journal la parution")
	await capture("campus_00_etude")
	await cliquer(o.annonce_principal)
	jeu._rafraichir(true)
	var campus: Array = o.campus()
	verifier(jeu.selection.sel_fid == -1 and o.groupe_carte() == campus and campus.size() == 3
		and jeu._contour_fids == campus and not ui._fiche_panneau.visible and not ui._lieu_panneau.visible,
		"Les trois îlots du campus sont entourés d'un seul trait, aucune fiche ouverte")
	verifier(is_equal_approx(jeu.pivot.taille, o.CADRAGE_UNIVERSITE), "La caméra montre la ville bâtie")
	verifier(not univ.visible and ui._menu_boutons["dangers"].disabled,
		"Pas de raccourci : les tuiles du campus restent cachées, Dangers reste grise")
	await capture("campus_01_trouver")
	jeu._sur_choix("i", o.MAISONS)
	verifier(not o.etude_lue and ui._fiche_panneau.visible and not ui._lieu_panneau.visible,
		"Un autre îlot ouvre sa fiche, pas le campus")
	ui._fermer_fiche()
	var fid_inst := int(ui.LIEUX["institut"]["fid"])
	jeu.selection.sel_couche = "i"
	jeu.selection.sel_fid = fid_inst
	jeu._sur_choix("i", fid_inst)
	jeu._rafraichir(true)
	verifier(o.etude_lue and ui._lieu_ouvert == "universite" and ui._campus_panneau.visible
		and ui._fiche_panneau.visible and ui._etude_bloc.visible and ui._etude_voir.visible,
		"N'importe quel îlot du campus ouvre la fenêtre au centre sur l'université et l'étude, sa fiche à côté")
	verifier(jeu._contour_fids == campus, "La fiche ouverte, le trait garde le campus entier")
	verifier(univ.visible and not univ.disabled
		and not ui._menu_boutons["dangers"].disabled and not entouree("dangers"),
		"Le campus trouvé, la tuile de l'université apparaît, Dangers s'ouvre sans être appelée")
	verifier(not ui._biblio_bloc.visible and not ui._lieu_lignes[jeu.Recherche.PILOTIS]["bloc"].visible
		and not ui._leviers_crue["berge"].is_visible_in_tree(),
		"L'onglet de l'université ne montre ni recherche, ni livre, ni levier")
	var noms := []
	for b in ui._campus_bloc.get_children():
		noms.append((b as Button).text)
	verifier(noms == ["Études", "Bibliothèque", "Institut de recherche"],
		"Les onglets dans l'ordre de l'auteur : %s" % ", ".join(noms))
	# 🌊 Trois parties (auteur, 2026-10-09) ; le jaune sur la carte d'abord (auteur, 2026-10-12).
	verifier(ui._etude_voir.is_visible_in_tree() and ui._etude_institut.is_visible_in_tree()
		and ui._etude_voir.get_meta("anneau").visible and not ui._etude_biblio.get_meta("anneau").visible,
		"L'étude en trois parties, la carte de Dangers appelée avant la bibliothèque")
	await capture("campus_02_fiche")
	await cliquer(ui._etude_voir)
	actualiser(jeu.mois)
	ui._maj_rail()
	verifier(o.prochaine_vue and not ui._campus_panneau.visible and o.rail_appel() == "universite"
		and tuile("universite").get_meta("anneau").visible and ui._fleche.visible,
		"Sur la carte de la prochaine crue, la tuile de l'université appelle la suite")
	await capture("campus_02c_dangers_retour")
	await cliquer(tuile("universite"))
	actualiser(jeu.mois)
	verifier(ui._lieu_ouvert == "universite" and jeu.theme == "" and not ui._etude_voir.get_meta("anneau").visible
		and ui._etude_biblio.get_meta("anneau").visible,
		"De retour à l'université, le jaune passe sur la bibliothèque")
	await capture("campus_02d_retour_universite")
	await cliquer(ui._etude_biblio)
	actualiser(jeu.mois)
	# 🌳 Les leviers s'achètent à l'institut (auteur, 2026-10-18).
	verifier(ui._lieu_ouvert == "bibliotheque" and ui._page_ouverte == "eponge"
		and not ui._leviers_crue["berge"].is_visible_in_tree() and not ui._leviers_crue["vert"].is_visible_in_tree()
		and not o.page_nouvelle("eponge"),
		"« Lire à la bibliothèque » ouvre la ville-éponge ; ses leviers attendent l'institut")
	await capture("campus_02a_bibliotheque")
	ui.ouvrir_lieu("universite")
	actualiser(jeu.mois)
	verifier(not ui._etude_biblio.get_meta("anneau").visible, "La page lue, la bibliothèque ne clignote plus")
	await cliquer(ui._etude_institut)
	var ligne: Dictionary = ui._lieu_lignes[jeu.Recherche.PILOTIS]
	verifier(ui._lieu_ouvert == "institut" and ligne["bloc"].visible and ligne["bouton"].visible
		and not ui._etude_bloc.visible and ui._lieu_lignes["berge"]["bouton"].visible
		and ui._lieu_lignes["parc"]["bouton"].visible and ui._lieu_lignes["places"]["bouton"].visible
		and ui._lieu_lignes["sedum"]["bloc"].visible and not ui._lieu_lignes["sedum"]["bouton"].visible
		and "Toits verts" in ui._lieu_lignes["sedum"]["etat"].text
		and not ui._lieu_lignes["rue"]["bouton"].visible,
		"L'institut : chaque racine à acheter (pilotis, parc, berge, places…), le reste grisé dit ce qui manque")
	await capture("campus_02b_institut")
	ui._fermer_campus()
	verifier(not ui._campus_panneau.visible and not ui._fiche_panneau.visible,
		"La croix referme la fenêtre et la fiche du campus")
	jeu._sur_vitesse(4.0)
	ui.maj({}, jeu.mois, jeu.vitesse)
	ui.ouvrir_lieu("bibliotheque")
	verifier(jeu.vitesse == 0.0 and ui._biblio_bloc.visible, "La fenêtre ouverte, le temps s'arrête")
	ui._fermer_campus()
	verifier(jeu.vitesse == 4.0, "Fermée, il repart à ×4")
	jeu._sur_vitesse(0.0)
	jeu._rafraichir(true)
	# Le guide se cache sous la fenêtre ; en jeu, `_process` le rend à l'image suivante.
	o.actualiser()

	# 🏠 REBÂTIR D'ABORD : les îlots sinistrés clignotent, aucune berge proposée.
	verifier(o.etape == "choix" and o.DIRE_ILOT in o._texte.text and o.visible
		and o._actions.get_child_count() == 0,
		"Le campus vu, le guide demande de rebâtir les logements, sans bouton")
	var sinistres: Array = o.ilots_a_rebatir()
	verifier(sinistres.size() > 1 and o.groupe_carte() == sinistres and jeu._contour_fids == sinistres
		and o.MAISONS in sinistres,
		"Les %d îlots sinistrés sont entourés et clignotent" % sinistres.size())
	await capture("campus_03_rebatir")
	jeu._sur_choix("i", o.MAISONS)
	jeu._rafraichir(true)
	var pil: Button = ui._rebatir_boutons["pilotis"]
	verifier(ui._rebatir_boutons["tradition"].visible and pil.visible and pil.disabled
		and "institut" in pil.text and ui._concours_bouton.visible and ui._projets_bouton.visible,
		"Avant la recherche, « Sur pilotis » est grisé et dit où il se met au point ; projets et concours s'offrent")
	await capture("campus_04_pilotis_grise")
	ui._fermer_fiche()
	# Comme en jeu : abriter et rouvrir le pont ont payé deux points.
	jeu.ville._objectifs["abriter"] = jeu.mois
	jeu.ville._objectifs["pont"] = jeu.mois
	ui.ouvrir_lieu("institut")
	var points: int = jeu.Recherche.points(jeu.ville, jeu.mois)
	verifier(points == 2 and points >= jeu.Recherche.prix(jeu.Recherche.PILOTIS) and not ligne["bouton"].disabled,
		"Les deux premiers objectifs suffisent aux pilotis")
	await cliquer(ligne["bouton"])
	verifier(jeu.Recherche.acquis(jeu.ville, jeu.Recherche.PILOTIS, jeu.mois)
		and jeu.Recherche.points(jeu.ville, jeu.mois) == points - jeu.Recherche.prix(jeu.Recherche.PILOTIS)
		and "pilotis" in str(ui.retours.journal).to_lower(),
		"Au clic, les pilotis sont acquis, les points baissent et le journal le dit")
	ui._fermer_lieu()
	jeu._sur_choix("i", o.MAISONS)
	jeu._rafraichir(true)
	verifier(ui._rebatir_boutons["tradition"].visible and pil.visible and not pil.disabled
		and pil.text == "Sur pilotis"
		and not ui._rebatir_boutons["moderne"].visible and not ui._rebatir_boutons["parc"].visible,
		"La recherche achevée, les Forgerons se relèvent comme avant ou sur pilotis")
	await capture("campus_05_pilotis")
	ui._fermer_fiche()
	var p: Dictionary = jeu.ville.prochaine_crue(jeu.mois)
	var avant := float(p["logements_perdus"])

	# Relever les Forgerons remet leurs logements sous l'eau (95).
	jeu._sur_commande("i", o.MAISONS, {"reparer": true})
	var fin: float = jeu.mois + jeu.ville.duree_reparation_mois("i", o.MAISONS)
	jeu.mois = fin
	jeu._rafraichir(true)
	var releve := float(jeu.ville.prochaine_crue(fin)["logements_perdus"])
	verifier(releve > avant + 40.0, "Relever les Forgerons : %d → %d logements perdus" % [int(avant), int(releve)])
	# Une berge et des toits verts la font baisser.
	var eau := float(jeu.ville.prochaine_crue(fin)["eau_pire_m"])
	jeu.ville.crediter_essai_ke(5000.0)
	jeu._sur_commande("b", o.BERGE, {"berge": jeu.ville.BERGE_RENATUREE})
	jeu._sur_commande("i", o.TOIT_PLAT, {"vert": 1.0})
	actualiser(fin + 24.0)
	var apres: Dictionary = jeu.ville.prochaine_crue(jeu.mois)
	verifier(float(apres["eau_pire_m"]) < eau - 0.05, "Berge et toits : %.2f → %.2f m" % [eau, float(apres["eau_pire_m"])])
	ui.ouvrir_lieu("universite")
	ui._sur_rail("dangers")
	verifier(not ui._campus_panneau.visible and ui._diagnostic_panneau.visible,
		"Dangers choisi au rail referme la fenêtre du campus")
	await cliquer(ui._onglets_crue["prochaine"])
	verifier(ui._prochaine_valeurs["baisse"].text != "0 cm", "Le panneau dit l'eau en moins depuis l'étude : %s" % ui._prochaine_valeurs["baisse"].text)
	# 🔄 La carte attend le clic : ses chiffres sont ceux d'avant les leviers.
	var fige: Dictionary = jeu.ville.prochaine_crue(ui.mois_carte_crue)
	verifier(not ui._carte_bouton.disabled and ui._prochaine_valeurs["eau"].text.begins_with(ui._nb(float(fige["eau_pire_m"]), 2)),
		"La carte retarde et le bouton le dit : %s, %s" % [ui._carte_bouton.text, ui._prochaine_valeurs["eau"].text])
	await capture("etude_05_avant_mise_a_jour")
	await cliquer(ui._carte_bouton)
	await create_timer(ui.CARTE_RECUL_S * 0.5).timeout
	actualiser(jeu.mois)
	await capture("etude_05b_recul")
	await create_timer(ui.CARTE_RECUL_S * 0.5 + 0.3).timeout
	actualiser(jeu.mois)
	verifier(is_equal_approx(ui.mois_carte_crue, jeu.mois) and ui._carte_bouton.disabled
		and "(−" in ui._prochaine_valeurs["eau"].text,
		"Au clic l'eau recule jusqu'à aujourd'hui et dit l'écart : %s" % ui._prochaine_valeurs["eau"].text)
	await capture("etude_05c_apres_mise_a_jour")
	ui.ouvrir_lieu("universite")
	actualiser(jeu.mois)
	await capture("etude_05d_universite")
	# 🌳 Deux objectifs de plus : le parc inondable, puis la berge rendue paie le pré.
	jeu.ville._objectifs["ilot"] = jeu.mois
	jeu.ville._objectifs["logements"] = jeu.mois
	ui.ouvrir_lieu("institut")
	verifier(not ui._lieu_lignes["pre"]["bouton"].visible and jeu.ville.acquerir_recherche("berge", jeu.mois)
		and not jeu.ville.acquerir_recherche("pre", jeu.mois),
		"Le pré attend le parc inondable, puis un point de plus")
	verifier(o.objectifs.paru("berge") and o.objectifs.atteint("berge"),
		"Le parc acheté, son objectif paraît ; la berge déjà rendue l'atteint")
	jeu.ville._objectifs["berge"] = jeu.mois
	verifier(jeu.ville.acquerir_recherche("pre", jeu.mois), "Le point de la berge achète le pré")
	actualiser(jeu.mois)
	await capture("etude_05f_institut_arbre")
	ui.ouvrir_lieu("bibliotheque", "eponge")
	actualiser(jeu.mois)
	verifier(ui._leviers_crue["pre"].is_visible_in_tree() and not ui._leviers_crue["vert"].is_visible_in_tree(),
		"À la bibliothèque, le pré acheté s'ouvre, les toits verts attendent")
	await capture("etude_05e_bibliotheque_leviers")
	await cliquer(ui._prochaine_valeurs["levier_culture"])
	verifier(jeu.selection.sel_fid == o.PRE and jeu.theme == "dangers",
		"Le levier de la bibliothèque ouvre la fiche du champ sur la prochaine crue")
	await capture("etude_06_levier_pre")

	jeu._sur_sauvegarde()
	jeu._sur_reset()
	verifier(o.etape == "reloger" and not o.etude_lue, "Recommencer oublie l'étude")
	jeu._sur_reprise()
	verifier(o.etude_lue and o.prochaine_vue, "La reprise garde l'étude lue et la prochaine crue vue")
	print("ÉTUDE : %d échec(s)" % echecs)
	jeu.queue_free()
	await process_frame
	quit(1 if echecs else 0)
