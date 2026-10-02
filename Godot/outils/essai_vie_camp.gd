extends "res://outils/essai_ouverture.gd"
## --script res://outils/essai_vie_camp.gd -- --ouverture [--captures]
## 🚿 La vie au camp : un toit rend de la confiance, le camp l'use, ses demandes la freinent.


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
	jeu._sur_commande("i", champs[1], {"camp": true})
	actualiser(0.25)
	var abrite: float = v.capital(0.25)
	verifier(abrite > depart + 10.0, "Un toit rend de la confiance : %.1f → %.1f" % [depart, abrite])
	verifier(absf(v.usure_camp_mois(0.25) - 2.6) < 0.05, "260 au camp usent %.2f par mois" % v.usure_camp_mois(0.25))
	actualiser(1.2)
	verifier(v.capital(1.2) < abrite - 2.0, "La confiance baisse au camp : %.1f → %.1f" % [abrite, v.capital(1.2)])
	verifier("/mois" in ui._barre_valeurs["capital"].text, "Le compteur dit la baisse : %s" % ui._barre_valeurs["capital"].text)
	verifier(not o.annonce.visible, "Pas de plainte avant 5 de confiance usée")
	await capture("camp_01_baisse")

	jeu._sur_vitesse(1.0)
	actualiser(2.3)
	verifier(o.annonce.visible and o.carte == "camp" and jeu.vitesse == 0.0,
		"Les habitants se plaignent, au centre, le temps en pause")
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
	var avant: float = v.usure_camp_mois(2.3)
	actualiser(2.3 + v.DEMANDES["sanitaires"]["mois"] + 0.05)
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
