extends "res://outils/essai_ouverture.gd"
## --script res://outils/essai_progression.gd -- --ouverture [--captures]


func executer() -> void:
	root.size = Vector2i(1600, 900)
	jeu = Maquette.new()
	root.add_child(jeu)
	jeu.set_process(false)
	jeu.horloge_trafic.stop()
	jeu.moniteur_performances.hide()
	jeu.chemin_sauvegarde = "res://../QGIS/rendus/essai_progression.wehrau"
	jeu._sur_mode(false)
	var o = jeu.ouverture
	var retours = jeu.interface.retours
	verifier(jeu.pastilles == null and o._reperes.get_child_count() == 0, "Carte sans pictogrammes ni numéros")
	jeu.recit.commencer()
	verifier(not retours.compteur.visible and not retours.avis.visible, "Le récit masque le compteur et les notifications")
	jeu.recit.terminer()
	jeu._sur_vitesse(0.0)
	verifier(retours.compteur.visible and "260" in retours.besoin.text, "Compteur permanent après le récit")
	o.ouvert = false
	o.actualiser(true)
	verifier(retours.compteur.visible, "Compteur conservé quand le guide est réduit")
	var champ: int = o._champs_accessibles()[0]
	var nourris: float = jeu.ville.nourriture_personnes(0.0)
	o.examiner("i", champ, "camp")
	await cliquer(jeu.interface._recap_bouton)
	verifier(jeu.ville.nourriture_personnes(0.0) < nourris and jeu.ville.sans_toit(0.0) == 260,
		"Coût agricole immédiat, aucune personne relogée avant livraison")
	verifier(retours.preparation.visible and "260" in retours.besoin.text, "Places en préparation séparées du besoin")
	await capture("progression_01_engagement")
	actualiser(0.2)
	verifier("22" in retours.besoin.text and not "construction" in retours.preparation.text, "Le compteur baisse à la livraison")
	verifier("Aide d'urgence" in retours.preparation.text and "9 k€" in retours.preparation.text,
		"Les 22 personnes dehors coûtent leur aide chaque mois")
	verifier(retours.journal.size() >= 3, "Engagement, livraison et relogement sont conservés dans le journal")
	await capture("progression_02_livraison")
	var nb: int = retours.journal.size()
	jeu._sur_sauvegarde()
	jeu._sur_reset()
	jeu._sur_reprise()
	verifier(retours.journal.size() == nb, "La reprise restaure le journal sans rejouer les livraisons")
	actualiser(0.3)
	verifier(retours.journal.size() == nb, "Aucune notification répétée à la pulsation suivante")
	for pont in jeu.ville.ponts_coupes():
		jeu._sur_reset()
		jeu.ville.abriter(champ, 0.0)
		jeu.ville.abriter(o._champs_accessibles()[1], 0.0)
		actualiser(0.2)
		jeu.interface._sur_rail("trafic")
		var caisse: float = jeu.ville.caisse_ke(jeu.mois)
		var acces: Dictionary = jeu.trafic.acces_pont(pont, jeu.mois)
		var prevision: Dictionary = jeu.trafic.prevoir_pont(pont, jeu.mois)
		verifier(acces["possible"] and not acces["obstacles"].is_empty(), "Pont %d : des accès réparables sont proposés" % pont)
		verifier(jeu.ville.caisse_ke(jeu.mois) == caisse and jeu.ville._repare.is_empty(), "Pont %d : diagnostic sans dépense" % pont)
		o._choisir_pont(pont)
		await cliquer(jeu.interface._recap_bouton)
		var fin: float = jeu.mois + jeu.ville.duree_reparation_mois("r", pont)
		actualiser(fin)
		verifier(jeu.ville.reparation_finie("r", pont, fin) and not jeu.trafic.pont_fonctionnel(pont, fin),
			"Pont %d : tablier livré mais accès encore coupé" % pont)
		verifier(o.etape == "pont_acces" and jeu.ville.valeur("r", pont, "charge", fin) == 0.0,
			"Pont %d : ni réussite ni circulation prématurée" % pont)
		verifier(jeu.trafic.voitures_visibles_sur(pont)[0] == 0, "Pont %d : aucune voiture visible sur la traversée inaccessible" % pont)
		if pont == 169:
			o.examiner("r", pont)
			await capture("progression_03_pont_inaccessible")
			o.voir_acces(pont)
			await capture("progression_04_acces")
			jeu._sur_sauvegarde()
			jeu._sur_reset()
			jeu._sur_reprise()
			verifier(o.etape == "pont_acces", "La reprise conserve le pont terminé mais inaccessible")
		var duree := 0.0
		for rue in acces["obstacles"]:
			duree = maxf(duree, jeu.ville.duree_reparation_mois("r", rue))
			jeu._sur_commande("r", rue, {"reparer": true})
		actualiser(fin + duree - 0.001)
		verifier(not jeu.trafic.pont_fonctionnel(pont, jeu.mois), "Pont %d : la commande d'accès ne suffit pas" % pont)
		actualiser(fin + duree)
		verifier(jeu.trafic.pont_fonctionnel(pont, jeu.mois) and o.etape == "pont_livre", "Pont %d : la continuité réelle valide la liaison" % pont)
		verifier(is_equal_approx(jeu.ville.valeur("r", pont, "charge", jeu.mois), prevision["charge_pont"]), "Pont %d : la circulation correspond à la prévision" % pont)
		verifier(jeu.trafic.voitures_visibles_sur(pont)[0] > 0, "Pont %d : les voitures reviennent" % pont)
		if pont == 169:
			await capture("progression_05_liaison")
			# Le verre ajoute ses propres enfants au panneau : on cherche le bouton.
			await cliquer(retours.compteur.find_children("*", "Button", true, false)[0])
			await capture("progression_06_journal")
			await process_frame
			verifier(jeu.interface._fiche_panneau.get_global_rect().end.y < retours.compteur.get_global_rect().position.y,
				"La fiche ne recouvre jamais le compteur")
	# Les dépenses récurrentes disent leur rythme, sans simuler un débit immédiat.
	jeu.interface.ouvrir_lieu("universite")
	await cliquer(jeu.interface._lieu_lignes["sedum"]["bouton"])
	verifier(jeu.ville.recherche_engagee("sedum") and "k€/mois" in retours.journal[-1], "Le financement de recherche annonce son coût mensuel")
	actualiser(jeu.mois + 12.0)
	verifier("recherche achevée" in retours.journal[-1], "Le résultat de recherche est annoncé à son échéance")
	jeu.interface.ouvrir_lieu("mairie")
	await cliquer(jeu.interface._lieu_lignes["subv_vert"]["bouton"])
	verifier("k€/mois" in retours.journal[-1], "Une subvention annonce son coût récurrent")
	await cliquer(jeu.interface._lieu_lignes["subv_vert"]["bouton"])
	verifier("prélèvements terminés" in retours.journal[-1], "L'arrêt de la subvention est conservé dans le journal")
	print("PROGRESSION : %d échec(s)" % echecs)
	jeu.queue_free()
	await process_frame
	quit(1 if echecs else 0)
