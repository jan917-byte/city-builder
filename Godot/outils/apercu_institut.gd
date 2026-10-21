extends "res://outils/essai_ouverture.gd"
## --script res://outils/apercu_institut.gd -- --ouverture --captures
## L'institut s'ouvre peu à peu : un achat montre sa suite et un sujet de `ENSUITE` (auteur, 2026-10-21).
## → QGIS/rendus/wehrau_ouverture_institut_N_*.png


func montres(ui) -> Array:
	var out := []
	for cle in ui.Recherche.ORDRE:
		if ui._sujet_montre(cle):
			out.append(cle)
	return out


func executer() -> void:
	root.size = Vector2i(1600, 900)
	jeu = Maquette.new()
	root.add_child(jeu)
	jeu.set_process(false)
	jeu.horloge_trafic.stop()
	jeu.moniteur_performances.hide()
	jeu.chemin_sauvegarde = "res://../QGIS/rendus/essai_institut.wehrau"
	var ui = jeu.interface
	jeu._sauter_au_pont()
	var t: float = jeu.mois
	ui.ouvrir_lieu("institut")
	verifier(montres(ui) == ["pilotis", "parc_inondable", "pont_resistant"], "Avant tout achat : %s" % [montres(ui)])
	await capture("institut_1_avant")
	jeu.ville._recherche["pilotis"] = t
	ui._maj_lieu()
	verifier(montres(ui) == ["pilotis", "densifier", "vert", "parc_inondable", "pont_resistant"],
		"Les pilotis : leur suite et un sujet de plus, %s" % [montres(ui)])
	await capture("institut_2_apres_pilotis")
	jeu.ville._recherche["densifier"] = t
	ui._maj_lieu()
	verifier(montres(ui).size() == 6 and "permeable" in montres(ui), "Densifier : un sujet de plus, %s" % [montres(ui)])
	print("Échecs : %d" % echecs)
	quit(1 if echecs else 0)
