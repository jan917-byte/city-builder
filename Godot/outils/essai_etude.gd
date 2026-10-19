extends "res://outils/essai_ouverture.gd"
## --script res://outils/essai_etude.gd -- --ouverture [--captures]
## 🎓 Après le pont : la mairie (concours, puis étude commandée, 117), l'étude, le campus
## trouvé sur la carte, sa fiche, puis les îlots à rebâtir et les pilotis (auteur, 2026-10-08).


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
	# 🏛️ LA MAIRIE D'ABORD (117) : le pont rouvert n'ouvre qu'elle.
	o.premier = {"couche": "r", "fid": jeu.ville.ponts_coupes()[0], "fin": 0.0}
	o._pont_rouvert()
	ui._maj_rail()
	verifier(o.pont_termine and not o.etude_parue and not o.annonce.visible
		and o.etape == "mairie" and o._texte.text == o.DIRE_MAIRIE,
		"Le pont rouvert, aucune carte : le guide envoie à la mairie : %s" % o._texte.text)
	verifier(not tuile("mairie").disabled and entouree("mairie") and not univ.visible,
		"La tuile de la mairie s'ouvre et s'entoure, l'université reste cachée")
	# La tuile vient de s'ouvrir : la colonne se range à l'image suivante, la flèche avec.
	await process_frame
	ui._maj_rail()
	await capture("mairie_00_appel")
	await cliquer(tuile("mairie"))
	var prog: Dictionary = ui._lieu_lignes["programme_concours"]
	var ligne_etude: Dictionary = ui._lieu_lignes["etude"]
	ui._maj_rail()
	verifier(o.mairie_vue and ui._lieu_ouvert == "mairie" and prog["bloc"].visible
		and not prog["bouton"].disabled and prog["bouton"].text == "Adopter"
		and not ligne_etude["bloc"].visible and not entouree("mairie"),
		"La mairie propose le concours d'urbanisme, 1 point, et pas encore l'étude")
	verifier(ui._campus_panneau.visible and not ui._campus_bloc.visible and ui._fenetre_titre.text == "Mairie"
		and ui._mairie_bloc.visible and not ui._etude_bloc.visible,
		"La mairie s'ouvre dans la grande fenêtre, sans les onglets du campus")
	await capture("mairie_01_concours")
	var points_avant: int = jeu.Recherche.points(jeu.ville, jeu.mois)
	await cliquer(prog["bouton"])
	verifier(jeu.Recherche.points(jeu.ville, jeu.mois) == points_avant - 1 and not prog["bouton"].visible
		and "Adopté" in prog["etat"].text and not ligne_etude["bloc"].visible,
		"Adopter coûte un point ; l'étude attend le concours")
	ui._fermer_lieu()
	verifier(o.concours_offert() and not o.etude_proposee(), "Adopté, le concours s'offre aux îlots")
	jeu._sur_choix("i", o.MAISONS)
	jeu._rafraichir(true)
	var pil: Button = ui._rebatir_boutons["pilotis"]
	verifier(o.carte == "concours" and o.annonce.visible, "La fiche des Forgerons annonce le concours")
	await cliquer(o.annonce_principal)
	jeu._rafraichir(true)
	verifier(ui._rebatir_boutons["tradition"].visible and not pil.visible
		and ui._concours_bouton.visible and not ui._projets_bouton.visible,
		"Deux choix : reconstruire ou le concours ; ni pilotis ni projets")
	await capture("campus_04_deux_choix")
	ui._fermer_fiche()
	# Le concours lancé puis rendu, la mairie propose l'étude.
	verifier(jeu.ville.lancer_concours(o.MAISONS, jeu.mois), "Le concours se lance")
	actualiser(jeu.mois + jeu.ville.CONCOURS_MOIS + 0.01)
	ui._maj_rail()
	verifier(o.etude_proposee() and entouree("mairie")
		and "commander une étude" in str(ui.retours.journal),
		"Le concours rendu, la mairie s'entoure et le bandeau propose l'étude")
	# La fiche de l'îlot de la mairie, puis « Ouvrir la mairie » : la fiche reste à côté.
	var fid_mairie := int(ui.LIEUX["mairie"]["fid"])
	jeu._sur_choix("i", fid_mairie)
	jeu._rafraichir(true)
	verifier(ui._fiche_panneau.visible and ui._lieu_bouton.visible and ui._lieu_bouton.text == "Ouvrir la mairie"
		and ui._lieu_ouvert == "", "L'îlot de la mairie ouvre sa fiche, avec « Ouvrir la mairie »")
	await capture("mairie_01b_fiche")
	await cliquer(ui._lieu_bouton)
	ui._maj_rail()
	verifier(ui._lieu_ouvert == "mairie" and ui._campus_panneau.visible and ui._fiche_panneau.visible,
		"« Ouvrir la mairie » ouvre la fenêtre, la fiche reste à côté")
	verifier(ligne_etude["bloc"].visible and ligne_etude["bouton"].text == "Commander"
		and not entouree("mairie"), "La mairie propose l'étude, en euros")
	await capture("mairie_02_etude")
	var caisse: float = jeu.ville.caisse_ke(jeu.mois)
	await cliquer(ligne_etude["bouton"])
	verifier(jeu.ville.etude_commandee() and not o.etude_parue
		and is_equal_approx(jeu.ville.caisse_ke(jeu.mois), caisse - jeu.ville.ETUDE_KE)
		and "Commandée" in ligne_etude["etat"].text,
		"Commander l'étude paie 80 k€ ; elle n'est pas encore rendue")
	ui._fermer_lieu()
	actualiser(jeu.mois + jeu.ville.ETUDE_MOIS + 0.01)
	# 🎓 Rendue, une seule carte : l'étude (auteur, 2026-10-08).
	verifier(o.etude_parue and o.carte == "etude" and o.annonce.visible
		and jeu.vitesse == 0.0 and not o.annonce_second.visible
		and o.annonce_principal.text == "Trouver l'université",
		"L'étude rendue paraît : une carte au centre, un seul bouton, jeu en pause")
	verifier("étude" in ui.retours.journal[-1], "Le journal dit la parution")
	await capture("campus_00_etude")
	await cliquer(o.annonce_principal)
	jeu._rafraichir(true)
	var campus: Array = o.campus()
	verifier(jeu.selection.sel_fid == -1 and o.groupe_carte() == campus and campus.size() == 3
		and jeu._contour_fids == campus and not ui._fiche_panneau.visible and ui._lieu_ouvert == "",
		"Les trois îlots du campus sont entourés d'un seul trait, aucune fiche ouverte")
	verifier(is_equal_approx(jeu.pivot.taille, o.CADRAGE_UNIVERSITE), "La caméra montre la ville bâtie")
	verifier(not univ.visible and ui._menu_boutons["dangers"].disabled,
		"Pas de raccourci : les tuiles du campus restent cachées, Dangers reste grise")
	o.actualiser(true)
	verifier(o.etape == "etude" and o._texte.text == o.DIRE_UNIVERSITE,
		"Pendant la recherche du campus, le guide dit ce qu'est l'université : %s" % o._texte.text)
	await capture("campus_01_trouver")
	jeu._sur_choix("i", o.MAISONS)
	verifier(not o.etude_lue and ui._fiche_panneau.visible and ui._lieu_ouvert == "",
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
	# 🌊 Trois parties (auteur, 2026-10-09) ; plus de jaune (auteur, 2026-10-19).
	verifier(ui._etude_voir.is_visible_in_tree() and ui._etude_institut.is_visible_in_tree()
		and not ui._etude_voir.has_meta("anneau") and not ui._etude_biblio.has_meta("anneau"),
		"L'étude en trois parties, aucune n'est appelée en jaune")
	await capture("campus_02_fiche")
	await cliquer(ui._etude_voir)
	actualiser(jeu.mois)
	ui._maj_rail()
	verifier(o.prochaine_vue and not ui._campus_panneau.visible and o.rail_appel() == ""
		and not tuile("universite").get_meta("anneau").visible and not ui._fleche.visible,
		"Sur la carte de la prochaine crue, rien n'appelle l'université")
	await capture("campus_02c_dangers_retour")
	await cliquer(tuile("universite"))
	actualiser(jeu.mois)
	verifier(ui._lieu_ouvert == "universite" and jeu.theme == "", "La tuile rouvre l'université")
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
	await cliquer(ui._etude_institut)
	var ligne: Dictionary = ui._lieu_lignes[jeu.Recherche.PILOTIS]
	verifier(ui._lieu_ouvert == "institut" and not ui._etude_bloc.visible and _montres(ui) == ["pilotis", "parc", "berge"]
		and ligne["bouton"].visible and _colonnes(ui) == 2,
		"L'institut, avant tout achat : la crue seule, sur deux colonnes : %s" % ", ".join(_montres(ui)))
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
	# Comme en jeu : abriter, rouvrir le pont, relever le Lavoir, moins le point du concours (117).
	jeu.ville._objectifs["abriter"] = jeu.mois
	jeu.ville._objectifs["pont"] = jeu.mois
	jeu.ville._objectifs["ilot"] = jeu.mois
	ui.ouvrir_lieu("institut")
	var points: int = jeu.Recherche.points(jeu.ville, jeu.mois)
	verifier(points == 2 and points >= jeu.Recherche.prix(jeu.Recherche.PILOTIS) and not ligne["bouton"].disabled,
		"Trois objectifs moins le concours suffisent aux pilotis")
	await cliquer(ligne["bouton"])
	verifier(jeu.Recherche.acquis(jeu.ville, jeu.Recherche.PILOTIS, jeu.mois)
		and jeu.Recherche.points(jeu.ville, jeu.mois) == points - jeu.Recherche.prix(jeu.Recherche.PILOTIS)
		and "pilotis" in str(ui.retours.journal).to_lower(),
		"Au clic, les pilotis sont acquis, les points baissent et le journal le dit")
	ui.ouvrir_lieu("institut")
	verifier("densifier" in _montres(ui) and "solaire" in _montres(ui) and "places" in _montres(ui)
		and not "sedum" in _montres(ui) and _colonnes(ui) == 4,
		"Le premier achat fait, l'institut montre les autres racines et la suite des pilotis : %s" % ", ".join(_montres(ui)))
	await capture("campus_05_institut_suite")
	ui._fermer_lieu()
	jeu._sur_choix("i", o.MAISONS)
	jeu._rafraichir(true)
	verifier(ui._rebatir_boutons["tradition"].visible and not pil.visible and o.carte == "",
		"Les pilotis acquis, la fiche n'en offre toujours pas : ils viennent par le concours")
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
	# 🔴 Un objectif de plus qu'en jeu : le point du concours (117) manque à l'arbre, à régler par l'auteur.
	jeu.ville._objectifs["logements"] = jeu.mois
	jeu.ville._objectifs["densifier"] = jeu.mois
	ui.ouvrir_lieu("institut")
	verifier(not ui._lieu_lignes["pre"]["bloc"].visible and jeu.ville.acquerir_recherche("berge", jeu.mois)
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


func _montres(ui) -> Array:
	var out := []
	for cle in jeu.Recherche.ORDRE:
		if (ui._lieu_lignes[cle]["bloc"] as Control).is_visible_in_tree():
			out.append(cle)
	return out


func _colonnes(ui) -> int:
	var n := 0
	for col in ui._recherche_bloc.get_children():
		n += 1 if (col as Control).visible else 0
	return n
