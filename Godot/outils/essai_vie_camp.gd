extends "res://outils/essai_ouverture.gd"
## --script res://outils/essai_vie_camp.gd -- --ouverture [--captures]
## 🚿 La vie au camp : un toit rend de la confiance, le camp l'use après le pont, ses demandes la freinent.


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
	jeu._sur_commande("i", champs[1], {"camp": true})
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
	# 🌉 Le premier pont, en provisoire : l'usure attend sa livraison plus un mois.
	var pont: int = v.ponts_coupes()[0]
	jeu._sur_commande("r", pont, {"reparer": "provisoire"})
	var debut: float = v.usure_debut()
	verifier(is_equal_approx(debut, 0.25 + v.duree_reparation_mois("r", pont) + v.CAMP_USURE_APRES_PONT_MOIS),
		"L'usure commence un mois après le pont rouvert : mois %.2f" % debut)
	actualiser(debut - 0.1)
	if o.carte == "pont":
		o._sur_carte(false)
	actualiser(debut - 0.05)
	verifier(not o.annonce.visible and v.capital(debut - 0.05) >= abrite - 0.01,
		"Ni plainte ni baisse pendant le déblaiement")
	o.examiner("i", champs[0])
	verifier(not ui._demandes_bloc.is_visible_in_tree(), "Les demandes attendent la plainte")
	jeu._sur_vitesse(1.0)
	actualiser(debut + 0.05)
	verifier(o.annonce.visible and o.carte == "camp" and jeu.vitesse == 0.0,
		"Les habitants se plaignent, au centre, le temps en pause")
	verifier(absf(v.usure_camp_mois(jeu.mois) - 2.6) < 0.05, "260 au camp usent %.2f par mois" % v.usure_camp_mois(jeu.mois))
	verifier("/mois" in ui._barre_valeurs["capital"].text, "Le compteur dit la baisse : %s" % ui._barre_valeurs["capital"].text)
	await capture("camp_02_plainte")
	var camp: int = o.camp_le_plus_plein()
	await cliquer(o.annonce_principal)
	verifier(not o.annonce.visible and o.plainte == 2, "La carte se ferme")
	verifier(jeu.selection.sel_fid == camp and ui._demandes_bloc.is_visible_in_tree(),
		"« Voir leurs demandes » ouvre le camp et ses trois demandes")
	await cliquer(ui._demande_boutons["sanitaires"])
	await capture("camp_03_demandes")
	await cliquer(ui._recap_bouton)
	verifier(v.demande_engagee("sanitaires"), "Les sanitaires se commandent depuis la fiche du camp")
	var avant: float = v.usure_camp_mois(jeu.mois)
	actualiser(jeu.mois + v.DEMANDES["sanitaires"]["mois"] + 0.05)
	var apres: float = v.usure_camp_mois(jeu.mois)
	verifier(absf(apres - avant * 2.0 / 3.0) < 0.05, "Une demande livrée retire un tiers de l'usure : %.2f → %.2f" % [avant, apres])
	verifier(not o.annonce.visible, "La plainte ne revient pas")
	ui._maj_fiche()
	verifier(ui._demande_boutons["sanitaires"].disabled, "La demande livrée ne se recommande pas")
	await capture("camp_04_sanitaires")

	jeu._sur_sauvegarde()
	jeu._sur_reset()
	verifier(not v.demande_engagee("sanitaires") and o.plainte == 0, "Recommencer oublie le camp")
	jeu._sur_reprise()
	verifier(v.demande_engagee("sanitaires") and o.plainte == 2, "La reprise garde les demandes et la plainte passée")
	print("CAMP : %d échec(s)" % echecs)
	jeu.queue_free()
	await process_frame
	quit(1 if echecs else 0)
