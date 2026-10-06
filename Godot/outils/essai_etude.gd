extends "res://outils/essai_ouverture.gd"
## --script res://outils/essai_etude.gd -- --ouverture [--captures]
## 🎓 Après le pont : l'étude de l'université, puis Dangers › Prochaine crue.


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

	var univ: Button = ui._rail_lieux[ui.LIEUX_ORDRE.find("universite")]
	verifier(not univ.visible, "Avant le pont, la colonne n'a pas de tuile université")
	# 🚪 Le pont rouvert ne publie rien : on souffle (auteur, 2026-10-06).
	o.carte = "pont"
	o.premier = {"couche": "r", "fid": jeu.ville.ponts_coupes()[0], "fin": 0.0}
	o._sur_carte(true)
	verifier(o.pont_termine and not ui.etude_publiee() and o.etape == "choix"
		and not "prochaine crue" in o._texte.text and not o.annonce.visible,
		"Le pont passé, le guide propose de relever, sans étude : %s" % o._texte.text)
	verifier(not o.concept_ouvert("eponge") and o.levier_ferme("berge") != "", "Sans étude, la ville-éponge reste fermée")
	verifier(o.autorise("i", o.MAISONS), "Sans étude, les îlots sinistrés se relèvent comme avant")
	jeu._sur_vitesse(0.0)
	jeu._sur_choix("r", o.RUE)
	verifier(not o.etude_parue, "Une rue envasée ne fait pas paraître l'étude")
	ui._fermer_fiche()
	# 🎓 L'îlot sinistré ouvert, l'étude paraît : carte au centre, jeu en pause.
	await cliquer(o._actions.get_child(1))
	verifier(o.etude_parue and o.carte == "etude" and o.annonce.visible and jeu.vitesse == 0.0,
		"Ouvrir les Forgerons pour les relever fait paraître l'étude")
	verifier("étude" in ui.retours.journal[-1], "La parution est dans le journal")
	await capture("etude_00_avant_de_relever")
	await cliquer(o.annonce_principal)
	verifier(o.etape == "etude" and o._actions.get_child_count() == 1 and "ville" in o._texte.text
		and not o.annonce.visible,
		"La carte quittée, le guide demande de trouver l'université, un bouton pour la montrer")
	jeu._rafraichir(true)
	var fid_univ := int(ui.LIEUX["universite"]["fid"])
	verifier(jeu.selection.sel_fid == fid_univ and not ui._fiche_panneau.visible and not ui._lieu_panneau.visible,
		"L'université est entourée sur la carte, aucune fiche ouverte")
	verifier(is_equal_approx(jeu.pivot.taille, o.CADRAGE_UNIVERSITE), "La caméra montre la ville bâtie")
	verifier(o.annonce.z_index > ui.bulles.z_index, "La carte du centre passe devant les chiffres qui montent")
	verifier(not univ.visible and not entouree("universite") and ui._rail_lieux[0].disabled
		and ui._menu_boutons["dangers"].disabled,
		"Pas de raccourci : la tuile université reste cachée ; mairie et Dangers restent grises")
	await capture("etude_01_trouver")
	jeu._sur_choix("i", o.MAISONS)
	verifier(not o.etude_lue and ui._fiche_panneau.visible and not ui._lieu_panneau.visible,
		"Un autre îlot ouvre sa fiche, pas l'étude")
	await cliquer(o._actions.get_child(0))
	verifier(jeu.selection.sel_fid == fid_univ and not ui._fiche_panneau.visible,
		"« Montrer l'université » la ré-entoure")
	jeu._sur_choix("i", fid_univ)
	jeu._rafraichir(true)
	verifier(o.etude_lue and univ.visible, "Trouvée, l'université ouvre l'étude et sa tuile apparaît")
	verifier(ui._etude_bloc.visible and "6 à 8 ans" in ui._etude_texte.text, "L'université montre l'étude")
	verifier("19 îlots" in ui._etude_texte.text and "9 cette fois" in ui._etude_texte.text,
		"L'étude compare les deux crues : %s" % ui._etude_texte.text)
	verifier(o.etape == "prochaine" and o._actions.get_child_count() == 0,
		"Le guide montre le chemin sans bouton")
	verifier(not ui._lieu_intro.visible and not ui._lieu_lignes[jeu.Recherche.ORDRE[0]]["bloc"].visible,
		"L'université ne montre que l'étude tant que sa carte n'est pas ouverte")
	await capture("etude_02_universite")
	ui._fermer_lieu()
	jeu._rafraichir(true)
	verifier(entouree("dangers") and not ui._menu_boutons["dangers"].disabled and not entouree("universite"),
		"L'étude lue, Dangers s'ouvre et s'entoure")
	ui._sur_rail("dangers")
	verifier(ui._vue_crue == "prochaine" and jeu.vue_crue == "prochaine" and o.prochaine_vue,
		"L'étude parue, Dangers s'ouvre sur la prochaine crue et repeint la carte")
	jeu._rafraichir(true)
	verifier(not ui._rail_lieux[0].disabled and not ui._menu_boutons["energie"].disabled and not entouree(""),
		"La prochaine crue vue, toute la colonne s'ouvre")
	var p: Dictionary = jeu.ville.prochaine_crue(jeu.mois)
	print("Prochaine crue : %s" % p)
	verifier(int(p["ilots_sous_eau"]) > int(p["ilots_cette_annee"]), "La prochaine crue est plus étendue")
	var bleu: Color = jeu.noeuds["i"][o.MAISONS].get_instance_shader_parameter("calque")
	verifier(bleu.a > 0.5 and bleu.b > bleu.r, "Les Forgerons sont peints en bleu")
	await capture("etude_04_prochaine")
	ui.ouvrir_lieu("universite")
	verifier(not ui._lieu_lignes[jeu.Recherche.ORDRE[0]]["bloc"].visible and ui._etude_bloc.visible,
		"La carte vue, l'université ne montre toujours que l'étude : les sujets viendront plus tard")
	ui._fermer_lieu()
	verifier(o.etape == "choix" and "5,1 m d'eau" in o._texte.text,
		"Après la carte, les Forgerons se choisissent en connaissant l'eau : %s" % o._texte.text)
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
	verifier("Depuis" in ui._prochaine_valeurs["ecart"].text, "Le panneau dit l'écart depuis la parution")
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
