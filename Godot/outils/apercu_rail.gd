extends "res://outils/essai_ouverture.gd"
## --script res://outils/apercu_rail.gd -- --ouverture [--nom avant]
## Le rail et les compteurs du haut, tout ouverts, puis agrandis ×2.
## → QGIS/rendus/wehrau_rail_⟨nom⟩.png


func executer() -> void:
	root.size = Vector2i(1600, 900)
	jeu = Maquette.new()
	root.add_child(jeu)
	jeu.set_process(false)
	jeu.horloge_trafic.stop()
	jeu.moniteur_performances.hide()
	jeu.chemin_sauvegarde = "res://../QGIS/rendus/essai_rail.wehrau"
	var ui = jeu.interface
	jeu._sauter_au_pont()
	jeu.ouverture.pont_termine = true
	jeu.ouverture.tout_ouvert = true
	jeu.ouverture.ouvert = false
	actualiser(jeu.mois)
	ui._maj_rail()
	jeu._rafraichir(false)
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	var args := OS.get_cmdline_user_args()
	var nom: String = args[args.find("--nom") + 1] if "--nom" in args else "apres"
	var img := root.get_texture().get_image()
	img.save_png("res://../QGIS/rendus/wehrau_rail_%s.png" % nom)
	# Le coin haut gauche, rail et compteurs, grossi.
	var coin := img.get_region(Rect2i(0, 0, 1000, 560))
	coin.resize(2000, 1120, Image.INTERPOLATE_NEAREST)
	coin.save_png("res://../QGIS/rendus/wehrau_rail_%s_x2.png" % nom)
	print("capture → wehrau_rail_%s.png" % nom)
	quit(0)
