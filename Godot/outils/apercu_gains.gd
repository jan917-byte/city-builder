extends "res://outils/essai_ouverture.gd"
## --script res://outils/apercu_gains.gd -- --ouverture --captures
## Un gain rejoint son compteur (auteur, 2026-10-20) : le chiffre monte sur le camp livré ou sur
## la mairie (budget de janvier), puis son icône vole à la confiance ou à la caisse.
## → QGIS/rendus/wehrau_ouverture_gains_N_*.png


func attendre(s: float) -> void:
	await create_timer(s).timeout


func executer() -> void:
	root.size = Vector2i(1600, 900)
	jeu = Maquette.new()
	root.add_child(jeu)
	jeu.set_process(false)
	jeu.horloge_trafic.stop()
	jeu.moniteur_performances.hide()
	jeu.chemin_sauvegarde = "res://../QGIS/rendus/essai_gains.wehrau"
	var o = jeu.ouverture
	var ui = jeu.interface
	jeu._sur_mode(false)
	jeu.recit.commencer()
	for i in 5:
		jeu.recit._fleche.pressed.emit()
		await process_frame
	jeu._sur_vitesse(0.0)
	actualiser(0.0)
	var champ: int = o._champs_accessibles()[0]
	jeu.ville.abriter(champ, 0.0)
	actualiser(0.01)
	await attendre(0.5)
	# Le camp livré : sa confiance monte sur le champ.
	var avant: String = ui._barre_valeurs["capital"].text
	actualiser(1.0)
	await attendre(0.4)
	verifier(ui.bulles.en_vol.has("capital"), "la confiance gagnée vole")
	verifier(ui._barre_valeurs["capital"].text == avant, "la confiance attend l'icône (%s, avant %s)" % [ui._barre_valeurs["capital"].text, avant])
	await capture("gains_1_monte_sur_le_camp")
	await attendre(0.75)
	await capture("gains_2_l_icone_vole")
	# Le +10 attend que le +238 des personnes accueillies ait monté (ECART de bulles.gd).
	await attendre(1.6)
	await capture("gains_3_la_confiance_bondit")
	verifier(not ui.bulles.en_vol.has("capital"), "l'icône est arrivée")
	verifier(ui._barre_valeurs["capital"].text != avant, "la confiance a avancé (%s)" % avant)
	await attendre(1.0)
	# Le budget de janvier : il monte sur la mairie et vole à la caisse.
	actualiser(12.02)
	await attendre(0.4)
	verifier(ui.bulles.en_vol.has("caisse"), "le budget vole")
	await capture("gains_4_le_budget_sur_la_mairie")
	await attendre(0.75)
	await capture("gains_5_vers_la_caisse")
	await attendre(1.6)
	verifier(ui.bulles.en_vol.is_empty(), "plus rien en vol")
	verifier(ui._barre_valeurs["caisse"].text == ui._ville_valeurs["caisse"].text, "la caisse rattrape la ville")
	await capture("gains_6_la_caisse_a_bondi")
	print("gains : %d échec(s)" % echecs)
	jeu.queue_free()
	await process_frame
	quit(echecs)
