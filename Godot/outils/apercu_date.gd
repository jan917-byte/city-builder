extends "res://outils/essai_ouverture.gd"
## --script res://outils/apercu_date.gd -- --ouverture
## 🗓️ Le coin haut-droit : la date au bord du titre de la fiche d'un îlot, le panneau du temps à sa
## largeur pour les douze mois (auteur, 2026-10-22). → QGIS/rendus/wehrau_date_fiche.png et _ecran.png


func executer() -> void:
	root.size = Vector2i(1600, 900)
	jeu = Maquette.new()
	root.add_child(jeu)
	jeu.set_process(false)
	jeu.horloge_trafic.stop()
	jeu.moniteur_performances.hide()
	jeu._sauter_au_pont()
	jeu.ouverture.pont_termine = true
	var v = jeu.ville
	var fid := -1
	for f in v.ilots:
		if v.concours_utile(int(f)) and not v.est_repare("i", int(f)):
			fid = int(f)
			break
	v.crediter_essai_ke(v.cout_reparation_ke("i", fid, false, "tradition"))
	jeu._sur_commande("i", fid, {"reparer": "tradition"})
	actualiser(jeu.mois + 1.0)
	jeu.examiner("i", fid)
	await process_frame
	var ui = jeu.interface
	var temps: Control = ui._temps_panneau
	var fiche: Control = ui._fiche_panneau
	# L'an 20 : le plus long des « an N » d'une partie de vingt ans.
	for m in 12:
		ui._dater(19.0 * 12.0 + m)
		await process_frame
		verifier(is_equal_approx(temps.get_global_rect().position.x, fiche.get_global_rect().position.x),
			"%s %s : le panneau du temps garde la largeur de la fiche (%.0f px)" % [
				ui._temps_label.text, ui._temps_an.text, temps.size.x])
	ui._dater(jeu.mois)
	await process_frame
	var x_date: float = ui._temps_label.get_global_rect().position.x
	var x_titre: float = ui._fiche_titre.get_global_rect().position.x
	verifier(is_equal_approx(x_date, x_titre), "La date commence au bord du titre (%.0f et %.0f px)" % [x_date, x_titre])
	verifier(temps.get_global_rect().end.y < fiche.get_global_rect().position.y,
		"Le panneau du temps reste au-dessus de la fiche (%.0f px de haut)" % temps.size.y)
	jeu._rafraichir(false)
	await process_frame
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	img.save_png("res://../QGIS/rendus/wehrau_date_ecran.png")
	var r := Rect2i(temps.get_global_rect().merge(fiche.get_global_rect()).grow(12))
	r = r.intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	img.get_region(Rect2i(r.position, Vector2i(r.size.x, mini(r.size.y, 160)))).save_png(
		"res://../QGIS/rendus/wehrau_date_fiche.png")
	print("Échecs : %d" % echecs)
	quit(1 if echecs else 0)
