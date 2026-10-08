extends "res://outils/essai_ouverture.gd"
## --script res://outils/essai_deblaiement.gd -- --ouverture [--captures]
## 🧹 Tout déblayer d'un coup, proposé par Trafic après trois rues faites à la main.


func executer() -> void:
	root.size = Vector2i(1600, 900)
	jeu = Maquette.new()
	root.add_child(jeu)
	jeu.set_process(false)
	jeu.horloge_trafic.stop()
	jeu.moniteur_performances.hide()
	jeu.chemin_sauvegarde = "res://../QGIS/rendus/essai_deblaiement.wehrau"
	jeu._sur_mode(false)
	jeu.recit.terminer()
	jeu._sur_vitesse(0.0)
	var o = jeu.ouverture
	var ui = jeu.interface
	var v = jeu.ville
	jeu._sur_reset()
	var champs: Array = o._champs_accessibles()
	v.abriter(champs[0], 0.0)
	v.abriter(champs[1], 0.0)
	actualiser(1.0)
	var pont := 169
	jeu._sur_commande("r", pont, {"reparer": "provisoire"})
	actualiser(1.0)
	verifier(o.etape == "pont_travaux" and not ui.deblaiement_propose(), "Le pont engagé, rien n'est proposé encore")
	var boueuses: Array = ui.rues_a_deblayer()
	var chemin: Array = jeu.trafic.acces_pont(pont, jeu.mois)["obstacles"]
	verifier(not chemin.is_empty() and boueuses[0] in chemin, "Le chemin du pont passe en tête de la file")
	var main := []
	for f in boueuses:
		if main.size() < v.DEBLAIEMENT_SEUIL:
			main.append(f)
	for i in main.size():
		jeu._sur_commande("r", main[i], {"reparer": true})
		verifier(ui.deblaiement_propose() == (i == main.size() - 1),
			"Après %d rue(s) à la main, proposé : %s" % [i + 1, ui.deblaiement_propose()])
	verifier("sous la boue" in ui.retours.journal.back(), "La troisième rue annonce la proposition : %s" % ui.retours.journal.back())
	ui._maj_rail()
	verifier(entouree("trafic"), "La tuile Trafic s'entoure")
	var reste: Array = ui.rues_a_deblayer()
	var cout := 0.0
	for f in reste:
		cout += v.cout_reparation_ke("r", int(f))
	print("DÉBLAIEMENT : %d rues, %.0f k€" % [reste.size(), cout])
	jeu._sur_theme("trafic")
	jeu._repere("faubourg")
	jeu._rafraichir(true)
	ui._maj_rail()
	verifier(not o.visible and ui._calque_panneau.visible and ui._boue_bloc.visible
		and ("%d rues" % reste.size()) in ui._boue_texte.text and not entouree("trafic"),
		"Pendant le chantier du pont, Trafic montre son panneau et propose le reste : %s" % ui._boue_texte.text)
	await capture("deblaiement_01_propose")
	var caisse: float = v.caisse_ke(jeu.mois)
	await cliquer(ui._boue_bouton)
	verifier(is_equal_approx(v.caisse_ke(jeu.mois), caisse - cout) and v.rues_boueuses().is_empty(),
		"Un clic paie %.0f k€ et engage toutes les rues" % cout)
	verifier("Déblaiement de %d rues" % reste.size() in ui.retours.journal.back(), "Le journal dit le déblaiement groupé")
	var en_cours: Array = v.chantiers(jeu.mois)["en_cours"]
	var groupes := en_cours.filter(func(c) -> bool: return c["genre"] == "deblaiement_groupe")
	var seules := en_cours.filter(func(c) -> bool: return c["genre"] == "deblaiement")
	verifier(groupes.size() == 1 and int(groupes[0]["rues"]) == reste.size() and seules.size() == main.size(),
		"Un seul chantier pour les %d rues, les rues faites à la main à part" % reste.size())
	var d: float = v.DEBLAIEMENT_MOIS
	var debut: float = jeu.mois
	actualiser(debut + d * 3.5)
	var livrees := reste.filter(func(f) -> bool: return v.reparation_finie("r", int(f), jeu.mois))
	verifier(livrees.size() == 3, "Les rues se libèrent l'une après l'autre : 3 sur %d après sept jours" % reste.size())
	await capture("deblaiement_02_en_cours")
	jeu._sur_sauvegarde()
	jeu._sur_reset()
	jeu._sur_reprise()
	verifier(v._file_deblaiement.size() == reste.size()
		and not v.reparation_finie("r", int(reste[-1]), jeu.mois), "La reprise garde la file")
	actualiser(debut + d * reste.size() + 0.001)
	verifier(v.reparation_finie("r", int(reste[-1]), jeu.mois) and "Toutes les rues" in str(ui.retours.journal),
		"La dernière rue livrée, le journal le dit")
	verifier(jeu.mois < v._repare["r:%d" % pont] + v.duree_reparation_mois("r", pont),
		"Tout est déblayé avant la fin du pont provisoire")
	await capture("deblaiement_03_fini")
	# 🔄 Le pont livré, le guide laisse choisir l'îlot (auteur, 2026-10-06).
	actualiser(v._repare["r:%d" % pont] + v.duree_reparation_mois("r", pont) + 0.01)
	o.pont_livre_ms -= o.ATTENTE_PONT_MS
	o.actualiser(true)
	await cliquer(o.annonce_second)
	verifier(o.etape == "choix" and o._actions.get_child_count() == 0 and "containers" in o._texte.text,
		"Le pont livré : %s" % o._texte.text)
	await capture("deblaiement_04_choisir_ilot")
	print("DÉBLAIEMENT : %d échec(s)" % echecs)
	jeu.queue_free()
	await process_frame
	quit(1 if echecs else 0)
