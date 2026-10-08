extends "res://outils/essai_ouverture.gd"
## --script res://outils/essai_etude.gd -- --ouverture [--captures]
## 🎓 Après le pont : l'étude, puis le campus dans l'ordre (auteur, 2026-10-08) —
## université, Dangers › Prochaine crue, institut, bibliothèque — puis les pilotis.


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
	verifier(not univ.visible and not tuile("institut").visible and not tuile("bibliotheque").visible,
		"Avant le pont, la colonne n'a aucune tuile du campus")
	# 🎓 Le pont fêté, quelques secondes de ville, puis l'étude (auteur, 2026-10-08).
	o.carte = "pont"
	o.premier = {"couche": "r", "fid": jeu.ville.ponts_coupes()[0], "fin": 0.0}
	o._sur_carte(true)
	verifier(o.pont_termine and not ui.etude_publiee() and not o.annonce.visible,
		"La carte du pont quittée, l'étude attend encore")
	jeu._sur_vitesse(0.0)
	await create_timer(o.ATTENTE_ETUDE_S + 0.3).timeout
	verifier(o.etude_parue and o.carte == "etude" and o.annonce.visible and jeu.vitesse == 0.0
		and not o.annonce_second.visible,
		"Quelques secondes plus tard, l'étude paraît : carte au centre, un seul bouton, jeu en pause")
	verifier("étude" in ui.retours.journal[-1], "La parution est dans le journal")
	await capture("campus_00_etude")
	await cliquer(o.annonce_principal)
	jeu._rafraichir(true)
	var fid_univ := int(ui.LIEUX["universite"]["fid"])
	verifier(jeu.selection.sel_fid == fid_univ and o.appel_carte() == fid_univ
		and not ui._fiche_panneau.visible and not ui._lieu_panneau.visible,
		"L'université est entourée et clignote, aucune fiche ouverte")
	verifier(is_equal_approx(jeu.pivot.taille, o.CADRAGE_UNIVERSITE), "La caméra montre la ville bâtie")
	verifier(not univ.visible and ui._menu_boutons["dangers"].disabled,
		"Pas de raccourci : la tuile université reste cachée, Dangers reste grise")
	await capture("campus_01_trouver")
	jeu._sur_choix("i", o.MAISONS)
	verifier(not o.etude_lue and ui._fiche_panneau.visible and not ui._lieu_panneau.visible,
		"Un autre îlot ouvre sa fiche, pas l'étude")
	ui._fermer_fiche()
	jeu._sur_choix("i", fid_univ)
	jeu._rafraichir(true)
	verifier(o.etude_lue and univ.visible and ui._lieu_titre.text == "Université",
		"Trouvée, l'université ouvre l'étude et sa tuile apparaît")
	verifier(ui._etude_bloc.visible and ui._etude_valeurs["dans"].text == "6 à 8 ans", "L'université montre l'étude")
	verifier(not ui._biblio_bloc.visible and not ui._lieu_lignes[jeu.Recherche.PILOTIS]["bloc"].visible,
		"L'université ne montre que l'étude : ni recherche ni livre")
	verifier(ui._lieu_intro.visible and ui._lieu_intro.text == "Publie les études.", "Un nom, un verbe")
	await capture("campus_02_universite")
	ui._fermer_lieu()
	jeu._rafraichir(true)
	verifier(entouree("dangers") and not ui._menu_boutons["dangers"].disabled and not entouree("universite"),
		"L'étude lue, Dangers s'ouvre et s'entoure")
	ui._sur_rail("dangers")
	verifier(ui._vue_crue == "prochaine" and jeu.vue_crue == "prochaine" and o.prochaine_vue,
		"L'étude parue, Dangers s'ouvre sur la prochaine crue et repeint la carte")
	var p: Dictionary = jeu.ville.prochaine_crue(jeu.mois)
	verifier(int(p["ilots_sous_eau"]) > int(p["ilots_cette_annee"]), "La prochaine crue est plus étendue")
	var bleu: Color = jeu.noeuds["i"][o.MAISONS].get_instance_shader_parameter("calque")
	verifier(bleu.a > 0.5 and bleu.b > bleu.r, "Les Forgerons sont peints en bleu")
	await capture("campus_03_prochaine")

	# 🔬 L'INSTITUT : appelé quand on revient à la ville.
	jeu._rafraichir(true)
	var fid_inst := int(ui.LIEUX["institut"]["fid"])
	verifier(o.etape == "institut" and tuile("institut").visible and entouree("institut")
		and jeu.selection.sel_fid != fid_inst,
		"La carte vue, l'institut apparaît dans la colonne, entouré ; la carte attend qu'on quitte Dangers")
	jeu._sur_theme("")
	o.actualiser()   # l'image suivante : `_process` le rappelle
	verifier(jeu.selection.sel_fid == fid_inst and o.appel_carte() == fid_inst
		and is_equal_approx(jeu.pivot.taille, o.CADRAGE_CAMPUS),
		"Revenu à la ville, l'institut est entouré et la caméra montre le campus")
	verifier(o._titre.text == "Institut de recherche" and o._texte.text == "", "Le guide ne dit que son nom")
	await capture("campus_04_institut_appele")
	jeu._sur_choix("i", fid_inst)
	jeu._rafraichir(true)
	var ligne: Dictionary = ui._lieu_lignes[jeu.Recherche.PILOTIS]
	verifier(o.institut_vu and ui._lieu_titre.text == "Institut de recherche" and ligne["bloc"].visible
		and not ui._lieu_lignes["rendement"]["bloc"].visible and not ui._etude_bloc.visible,
		"L'institut ouvre une seule recherche, les pilotis")
	await capture("campus_05_institut")
	await cliquer(ligne["bouton"])
	verifier(jeu.ville.recherche_engagee(jeu.Recherche.PILOTIS), "La recherche sur pilotis est lancée")
	verifier("En cours" in ligne["etat"].text, "L'institut montre la recherche en cours : %s" % ligne["etat"].text)
	await capture("campus_06_recherche_lancee")
	verifier(not entouree("bibliotheque"), "La bibliothèque attend que l'institut soit refermé")
	ui._fermer_lieu()
	o.actualiser()

	# 📖 LA BIBLIOTHÈQUE.
	var fid_bib := int(ui.LIEUX["bibliotheque"]["fid"])
	verifier(o.etape == "bibliotheque" and entouree("bibliotheque") and jeu.selection.sel_fid == fid_bib,
		"L'institut refermé, la bibliothèque est entourée, sur la carte et dans la colonne")
	await capture("campus_07_bibliotheque_appelee")
	jeu._sur_choix("i", fid_bib)
	jeu._rafraichir(true)
	verifier(o.biblio_vue and ui._biblio_bloc.visible and not ui._etude_bloc.visible
		and not ligne["bloc"].visible,
		"La bibliothèque ouvre le livre, et seulement le livre")
	await capture("campus_08_bibliotheque")
	ui._fermer_lieu()
	jeu._rafraichir(true)
	verifier(o.etape == "choix" and o.appel_carte() == -1 and not entouree("institut") and not entouree("bibliotheque"),
		"Le campus visité, le guide rend la main")

	# 🏗️ LES PILOTIS : rien avant la recherche, le bouton après.
	jeu._sur_choix("i", o.MAISONS)
	jeu._rafraichir(true)
	verifier(ui._rebatir_boutons["tradition"].visible and not ui._rebatir_boutons["pilotis"].visible
		and not ui._concours_bouton.visible,
		"Pendant la recherche, les Forgerons ne se relèvent que comme avant, sans concours")
	ui._fermer_fiche()
	actualiser(jeu.mois + float(jeu.Recherche.SUJETS[jeu.Recherche.PILOTIS]["mois"]) + 0.1)
	verifier(jeu.Recherche.acquis(jeu.ville, jeu.Recherche.PILOTIS, jeu.mois)
		and "pilotis" in str(ui.retours.journal), "Six mois plus tard, la recherche est achevée et le journal le dit")
	jeu._sur_choix("i", o.MAISONS)
	jeu._rafraichir(true)
	verifier(ui._rebatir_boutons["tradition"].visible and ui._rebatir_boutons["pilotis"].visible
		and not ui._rebatir_boutons["moderne"].visible and not ui._rebatir_boutons["parc"].visible,
		"La recherche achevée, les Forgerons se relèvent comme avant ou sur pilotis")
	await capture("campus_09_pilotis")
	ui._fermer_fiche()
	p = jeu.ville.prochaine_crue(jeu.mois)
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
	ui._sur_rail("dangers")
	await cliquer(ui._onglets_crue["prochaine"])
	verifier(ui._prochaine_valeurs["baisse"].text != "0 cm", "Le panneau dit l'eau en moins depuis l'étude : %s" % ui._prochaine_valeurs["baisse"].text)
	await capture("etude_05_apres_leviers")
	await cliquer(ui._prochaine_valeurs["levier_culture"])
	verifier(jeu.selection.sel_fid == o.PRE and jeu.theme == "dangers",
		"Le levier ouvre la fiche du champ, la prochaine crue reste à côté")
	await capture("etude_06_levier_pre")

	jeu._sur_sauvegarde()
	jeu._sur_reset()
	verifier(o.etape == "reloger" and not o.etude_lue, "Recommencer oublie l'étude")
	jeu._sur_reprise()
	verifier(o.etude_lue and o.prochaine_vue, "La reprise garde l'étude lue")
	print("ÉTUDE : %d échec(s)" % echecs)
	jeu.queue_free()
	await process_frame
	quit(1 if echecs else 0)
